//
//  LiveTranslationViewModel.swift
//  IsaretDiliCevirme
//
//  Created by Mahmut Arslan on 9.03.2026.
//

import SwiftUI
import AVFoundation
import Combine

/// ViewModel that orchestrates the camera → Vision → UI pipeline.
///
/// Flow:
///   1. CameraService captures frames
///   2. Each frame is sent to VisionService for hand pose detection
///   3. Periodically, frames are sent to PredictionService for YOLOv8 translating
///   4. Words are accumulated into a sentence; sentence completes on 3s hand absence
@Observable
final class LiveTranslationViewModel: @unchecked Sendable {

    // MARK: - Published Properties

    /// Current detected hand landmarks to render in the view.
    var handDetections: [HandDetection] = []
    
    /// The accumulated sentence built from detected sign language words.
    var currentSentence: String = ""
    
    /// The latest single word detected (shown briefly as feedback).
    var lastDetectedWord: String = ""
    
    /// Whether the sentence has been marked as complete (hands gone for 3s).
    var isSentenceComplete = false
    
    /// Whether the text-to-speech engine is currently speaking.
    var isSpeaking = false

    /// Whether the camera is currently active.
    var isCameraRunning = false

    /// Status message for the user.
    var statusMessage = "Kamera başlatılıyor..."

    /// Whether camera permission has been granted.
    var cameraPermissionGranted = false
    
    /// Connection status to the backend server.
    var isBackendConnected = false
    
    /// Error message to display to the user, if any.
    var errorMessage: String? = nil
    
    /// Counts consecutive API failures — shows error after threshold.
    private var consecutiveFailures = 0
    private let failureThreshold = 3

    // MARK: - Services

    let cameraService = CameraService()
    private let visionService = VisionService()
    private let predictionService = PredictionService()
    
    // MARK: - Text-to-Speech
    
    /// The speech synthesizer for reading sentences aloud in Turkish.
    private let speechSynthesizer = AVSpeechSynthesizer()
    
    /// Turkish language voice identifier.
    private let turkishLanguageCode = "tr-TR"
    
    // MARK: - API Throttling
    private var lastPredictionTime: TimeInterval = 0
    private var isPredicting = false
    
    // MARK: - Sentence Building
    
    /// Words accumulated in the current sentence.
    private var sentenceWords: [String] = []
    
    /// The last word that was added to the sentence (to prevent duplicates).
    private var previousWord: String = ""
    
    /// The word currently being "confirmed" by repeated detections.
    private var pendingWord: String = ""
    
    /// How many times the pending word has been seen consecutively.
    /// We require seeing the same word at least 2 times before adding it,
    /// to reduce false positives. (Stability filter)
    private var sameWordCount = 0
    private let requiredConfirmations = 2
    
    /// Timer that fires when hands disappear — marks sentence as complete after 3 seconds.
    private var sentenceCompleteTimer: Timer?
    private let sentenceCompletionDelay: TimeInterval = 3.0
    
    /// Tracks whether hands are currently visible.
    private var handsAreVisible = false

    // MARK: - Lifecycle

    /// Requests camera permission and starts the pipeline.
    func startSession() {
        checkCameraPermission()
    }

    /// Stops the camera session.
    func stopSession() {
        cameraService.stop()
        isCameraRunning = false
        statusMessage = "Kamera durduruldu"
        sentenceCompleteTimer?.invalidate()
    }

    // MARK: - Camera Permission

    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraPermissionGranted = true
            setupAndStartCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    self?.cameraPermissionGranted = granted
                    if granted {
                        self?.setupAndStartCamera()
                    } else {
                        self?.statusMessage = "Kamera izni gerekli"
                    }
                }
            }
        default:
            cameraPermissionGranted = false
            statusMessage = "Kamera izni gerekli. Lütfen Ayarlar'dan izin verin."
        }
    }

    // MARK: - Camera Setup

    /// Switches between front and rear cameras.
    func switchCamera() {
        cameraService.switchCamera()
    }

    private func setupAndStartCamera() {
        cameraService.delegate = self
        cameraService.configure()
        cameraService.start()
        isCameraRunning = true
        statusMessage = "El algılama ve Çeviri aktif"
    }
    
    // MARK: - Sentence Management
    
    /// Adds a confirmed word to the current sentence.
    private func addWordToSentence(_ word: String) {
        // Don't add if it's the same as the last word in our sentence
        guard word != previousWord else { return }
        
        sentenceWords.append(word)
        previousWord = word
        currentSentence = sentenceWords.joined(separator: " ")
        isSentenceComplete = false
    }
    
    /// Clears the current sentence and resets all state for a fresh start.
    func clearSentence() {
        sentenceWords.removeAll()
        previousWord = ""
        pendingWord = ""
        sameWordCount = 0
        currentSentence = ""
        lastDetectedWord = ""
        isSentenceComplete = false
        statusMessage = "El algılama ve Çeviri aktif"
        stopSpeaking()
    }
    
    // MARK: - Text-to-Speech
    
    /// Speaks the current sentence aloud in Turkish.
    func speakSentence() {
        let textToSpeak = currentSentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !textToSpeak.isEmpty else { return }
        
        // Stop any ongoing speech first
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        
        let utterance = AVSpeechUtterance(string: textToSpeak)
        utterance.voice = AVSpeechSynthesisVoice(language: turkishLanguageCode)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        isSpeaking = true
        speechSynthesizer.speak(utterance)
        
        // Monitor when speaking is done
        // AVSpeechSynthesizer doesn't have async API, so we poll briefly
        Task { @MainActor in
            // Wait until speech finishes
            while self.speechSynthesizer.isSpeaking {
                try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s
            }
            self.isSpeaking = false
        }
    }
    
    /// Stops any ongoing speech.
    func stopSpeaking() {
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
    }
    
    /// Called when hands disappear — starts the 3-second countdown to mark sentence as complete.
    private func startSentenceCompletionTimer() {
        sentenceCompleteTimer?.invalidate()
        
        // Only start timer if we actually have words in the sentence
        guard !sentenceWords.isEmpty else { return }
        
        sentenceCompleteTimer = Timer.scheduledTimer(withTimeInterval: sentenceCompletionDelay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, !self.sentenceWords.isEmpty else { return }
                self.isSentenceComplete = true
                self.statusMessage = "✅ Cümle tamamlandı"
                // Reset the previous word so the user can start a new word if they raise hands again
                self.previousWord = ""
                self.sameWordCount = 0
            }
        }
    }
    
    /// Cancels the sentence completion timer (hands appeared again).
    private func cancelSentenceCompletionTimer() {
        sentenceCompleteTimer?.invalidate()
        sentenceCompleteTimer = nil
    }
}

// MARK: - CameraServiceDelegate

extension LiveTranslationViewModel: CameraServiceDelegate {
    /// Called on the camera output queue when a new frame arrives.
    nonisolated func cameraService(_ service: CameraService, didOutput sampleBuffer: CMSampleBuffer) {
        // Run Vision detection on the current (background) queue
        if let detections = visionService.detectHands(in: sampleBuffer) {
            let handsFound = !detections.isEmpty
            
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.handDetections = detections
                
                if handsFound && !self.handsAreVisible {
                    // Hands just appeared — cancel any pending sentence completion
                    self.handsAreVisible = true
                    self.cancelSentenceCompletionTimer()
                    
                    // If the previous sentence was marked complete, start fresh
                    if self.isSentenceComplete {
                        self.clearSentence()
                    }
                } else if !handsFound && self.handsAreVisible {
                    // Hands just disappeared — start the completion timer
                    self.handsAreVisible = false
                    self.startSentenceCompletionTimer()
                }
            }
        }
        
        // ML Prediction API Call (Throttle to approx. 1 frame every 0.8 seconds)
        let currentTime = CACurrentMediaTime()
        if !isPredicting && (currentTime - lastPredictionTime) > 0.8 {
            let isFrontCamera = cameraService.currentPosition == .front
            guard let image = sampleBuffer.toUIImage(frontCamera: isFrontCamera) else { return }
            
            self.lastPredictionTime = currentTime
            self.isPredicting = true
            
            Task { [weak self] in
                guard let self = self else { return }
                
                do {
                    if let result = try await self.predictionService.predictFromImage(image: image) {
                        await MainActor.run {
                            // Mark backend as connected
                            self.isBackendConnected = true
                            self.consecutiveFailures = 0
                            self.errorMessage = nil
                            
                            if !result.predicted_text.isEmpty {
                                let word = result.predicted_text
                                
                                // Stability filter: require seeing the same NEW word multiple times
                                // before adding it to the sentence
                                if word == self.previousWord {
                                    // Same word as already in sentence — completely ignore, no action
                                    // Don't update lastDetectedWord so the badge stays clean
                                } else if word == self.pendingWord {
                                    // Same new word seen again — increment confirmation counter
                                    self.sameWordCount += 1
                                    self.lastDetectedWord = word
                                    
                                    // Add word once it's confirmed enough times
                                    if self.sameWordCount >= self.requiredConfirmations {
                                        self.addWordToSentence(word)
                                        self.pendingWord = ""
                                        self.sameWordCount = 0
                                    }
                                } else {
                                    // Different word — start tracking this new one
                                    self.pendingWord = word
                                    self.sameWordCount = 1
                                    self.lastDetectedWord = word
                                }
                                
                                self.statusMessage = "🔤 \(word) (%\(Int(result.confidence_score * 100)))"
                            } else {
                                // Backend returned empty — no gesture detected
                                // Don't touch the sentence, just update status
                                self.lastDetectedWord = ""
                                self.pendingWord = ""
                                self.sameWordCount = 0
                                self.statusMessage = "🔍 Hareket algılanmadı..."
                            }
                        }
                    }
                } catch {
                    print("[LiveTranslationViewModel] ❌ API Error: \(error.localizedDescription)")
                    
                    await MainActor.run {
                        self.consecutiveFailures += 1
                        self.isBackendConnected = false
                        
                        if self.consecutiveFailures >= self.failureThreshold {
                            self.errorMessage = "Sunucuya bağlanılamıyor. Backend çalışıyor mu?"
                            self.statusMessage = "⚠️ Sunucu bağlantısı yok"
                        }
                    }
                }
                
                self.isPredicting = false
            }
        }
    }
}
