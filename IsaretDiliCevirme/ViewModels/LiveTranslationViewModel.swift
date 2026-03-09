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
///   3. Detected landmarks are published to the UI via @Published
@Observable
final class LiveTranslationViewModel: @unchecked Sendable {

    // MARK: - Published Properties

    /// Current detected hand landmarks to render in the view.
    var handDetections: [HandDetection] = []

    /// Whether the camera is currently active.
    var isCameraRunning = false

    /// Status message for the user.
    var statusMessage = "Kamera başlatılıyor..."

    /// Whether camera permission has been granted.
    var cameraPermissionGranted = false

    // MARK: - Services

    let cameraService = CameraService()
    private let visionService = VisionService()

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

    private func setupAndStartCamera() {
        cameraService.delegate = self
        cameraService.configure()
        cameraService.start()
        isCameraRunning = true
        statusMessage = "El algılama aktif"
    }
}

// MARK: - CameraServiceDelegate

extension LiveTranslationViewModel: CameraServiceDelegate {
    /// Called on the camera output queue when a new frame arrives.
    nonisolated func cameraService(_ service: CameraService, didOutput sampleBuffer: CMSampleBuffer) {
        // Run Vision detection on the current (background) queue
        // Returns nil if throttled (skipped), [] if no hands found, [detections] if hands found
        guard let detections = visionService.detectHands(in: sampleBuffer) else {
            return  // Frame was throttled — don't update UI
        }

        // Hop to main actor to update published properties
        Task { @MainActor [weak self] in
            self?.handDetections = detections
        }
    }
}
