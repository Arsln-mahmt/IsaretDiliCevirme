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

    /// Whether a local video recording is currently active.
    var isRecordingVideo = false

    /// Whether a recording stop/save operation is currently in progress.
    var isFinalizingRecording = false

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
    private let historyViewModel: HistoryViewModel
    private var hasConfiguredSession = false
    
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

    /// Per-word confidence samples used to build a sentence-level confidence.
    private var sentenceConfidenceSamples: [Double] = []

    /// Temporary URL while a sentence capture is being recorded.
    private var activeRecordingURL: URL?

    /// Whether the active recording should be deleted after finishing.
    private var discardRecordingOnFinish = false

    /// Whether the current recording should be persisted when the file output finishes.
    private var saveRecordingOnFinish = false

    var recordButtonTitle: String {
        if isFinalizingRecording {
            return "Kaydediliyor..."
        }
        return isRecordingVideo ? "Kaydı Bitir" : "Kayda Başla"
    }

    var canToggleRecording: Bool {
        cameraPermissionGranted && !isFinalizingRecording
    }

    init(historyViewModel: HistoryViewModel = HistoryViewModel()) {
        self.historyViewModel = historyViewModel
    }

    // MARK: - Lifecycle

    /// Requests camera permission and starts the pipeline.
    func startSession() {
        if hasConfiguredSession {
            cameraService.start()
            isCameraRunning = true
            statusMessage = "El algılama ve Çeviri aktif"
            return
        }

        checkCameraPermission()
    }

    /// Stops the camera session.
    func stopSession() {
        if activeRecordingURL != nil {
            discardRecordingOnFinish = true
            saveRecordingOnFinish = false
            cameraService.stopRecording()
        }
        cameraService.stop()
        isCameraRunning = false
        isFinalizingRecording = false
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
        cameraService.recordingDelegate = self
        if !hasConfiguredSession {
            cameraService.configure()
            hasConfiguredSession = true
        }
        cameraService.start()
        isCameraRunning = true
        statusMessage = "El algılama ve Çeviri aktif"
    }
    
    // MARK: - Sentence Management
    
    /// Adds a confirmed word to the current sentence.
    private func addWordToSentence(_ word: String, confidence: Double) {
        // Don't add if it's the same as the last word in our sentence
        guard word != previousWord else { return }
        
        sentenceWords.append(word)
        sentenceConfidenceSamples.append(confidence)
        previousWord = word
        currentSentence = sentenceWords.joined(separator: " ")
        isSentenceComplete = false
    }
    
    /// Clears the current sentence and resets all state for a fresh start.
    func clearSentence(shouldDiscardPendingCapture: Bool = true) {
        if shouldDiscardPendingCapture {
            discardPendingCapture()
        }

        sentenceWords.removeAll()
        sentenceConfidenceSamples.removeAll()
        previousWord = ""
        pendingWord = ""
        sameWordCount = 0
        currentSentence = ""
        lastDetectedWord = ""
        isSentenceComplete = false
        statusMessage = "El algılama ve Çeviri aktif"
        stopSpeaking()
    }

    func toggleRecording() {
        guard canToggleRecording else { return }

        if isRecordingVideo {
            stopManualRecording()
        } else {
            startManualRecording()
        }
    }
    
    // MARK: - Text-to-Speech
    
    /// Speaks the current sentence aloud in Turkish.
    func speakSentence() {
        let textToSpeak = currentSentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !textToSpeak.isEmpty else { return }

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Ses oturumu başlatılamadı."
            statusMessage = "⚠️ Seslendirilemedi"
            return
        }
        
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

        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            // No-op: speech already stopped, so audio session cleanup failure is non-fatal.
        }
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

    private var currentSentenceConfidence: Double {
        guard !sentenceConfidenceSamples.isEmpty else { return 0 }
        let total = sentenceConfidenceSamples.reduce(0, +)
        return total / Double(sentenceConfidenceSamples.count)
    }

    private func startManualRecording() {
        discardPendingCapture()
        resetSentenceState()

        let temporaryURL = VideoStorage.makeTemporaryRecordingURL()
        activeRecordingURL = temporaryURL
        discardRecordingOnFinish = false
        saveRecordingOnFinish = false
        isFinalizingRecording = false
        isRecordingVideo = true
        isSentenceComplete = false
        errorMessage = nil
        statusMessage = "🔴 Kayıt başladı"
        cameraService.startRecording(to: temporaryURL)
    }

    private func stopManualRecording() {
        guard activeRecordingURL != nil else { return }
        saveRecordingOnFinish = true
        discardRecordingOnFinish = false
        isFinalizingRecording = true
        statusMessage = "💾 Kayıt işleniyor..."
        cameraService.stopRecording()
    }

    private func discardPendingCapture() {
        saveRecordingOnFinish = false
        isFinalizingRecording = false

        if isRecordingVideo {
            discardRecordingOnFinish = true
        }

        guard activeRecordingURL != nil else { return }
        cameraService.stopRecording()
    }

    private func persistRecordedTranslation(from outputURL: URL) {
        let trimmedSentence = currentSentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSentence.isEmpty else {
            VideoStorage.deleteFile(at: outputURL)
            statusMessage = "⚠️ Cümle oluşmadığı için kayıt silindi"
            return
        }

        let recordID = UUID()

        do {
            let savedFilename = try VideoStorage.persistRecording(from: outputURL, recordID: recordID)
            historyViewModel.addRecord(
                id: recordID,
                sentence: trimmedSentence,
                confidence: currentSentenceConfidence,
                videoFilename: savedFilename,
                syncState: .pendingUpload
            )

            statusMessage = "Kayıt geçmişe eklendi"
            resetSentenceState()
        } catch {
            errorMessage = "Video kaydedilemedi."
            statusMessage = "⚠️ Kayıt başarısız"
        }
    }

    private func resetSentenceState() {
        sentenceWords.removeAll()
        sentenceConfidenceSamples.removeAll()
        previousWord = ""
        pendingWord = ""
        sameWordCount = 0
        currentSentence = ""
        lastDetectedWord = ""
        isSentenceComplete = false
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
                                        self.addWordToSentence(word, confidence: result.confidence_score)
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
                            self.errorMessage = "Sunucuya bağlanılamıyor."
                            self.statusMessage = "⚠️ Sunucu bağlantısı yok"
                        }
                    }
                }
                
                self.isPredicting = false
            }
        }
    }
}

extension LiveTranslationViewModel: CameraServiceRecordingDelegate {
    nonisolated func cameraService(_ service: CameraService, didFinishRecordingTo outputURL: URL, error: Error?) {
        Task { @MainActor [weak self] in
            guard let self else { return }

            self.isRecordingVideo = false
            self.isFinalizingRecording = false
            self.activeRecordingURL = nil

            if error != nil {
                self.saveRecordingOnFinish = false
                self.discardRecordingOnFinish = false
                self.errorMessage = "Video kaydı tamamlanamadı."
                self.statusMessage = "⚠️ Video kaydı başarısız"
                VideoStorage.deleteFile(at: outputURL)
                return
            }

            if self.discardRecordingOnFinish {
                self.discardRecordingOnFinish = false
                self.saveRecordingOnFinish = false
                VideoStorage.deleteFile(at: outputURL)
                return
            }

            if self.saveRecordingOnFinish {
                self.saveRecordingOnFinish = false
                self.persistRecordedTranslation(from: outputURL)
                return
            }

            VideoStorage.deleteFile(at: outputURL)
        }
    }
}
