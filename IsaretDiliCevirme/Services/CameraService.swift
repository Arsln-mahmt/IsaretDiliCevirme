//
//  CameraService.swift
//  IsaretDiliCevirme
//
//  Created by Mahmut Arslan on 9.03.2026.
//

import AVFoundation
import UIKit

// MARK: - CameraServiceDelegate

/// Protocol to receive camera frame updates.
@MainActor
protocol CameraServiceDelegate: AnyObject {
    /// Called when a new video frame is available for processing.
    nonisolated func cameraService(_ service: CameraService, didOutput sampleBuffer: CMSampleBuffer)
}

@MainActor
protocol CameraServiceRecordingDelegate: AnyObject {
    /// Called when the active video recording finishes writing to disk.
    nonisolated func cameraService(_ service: CameraService, didFinishRecordingTo outputURL: URL, error: Error?)
}

// MARK: - CameraService

/// Manages the AVCaptureSession to capture camera frames.
///
/// Responsibilities:
///   - Configure the rear camera for video capture
///   - Stream frames via delegate callback on a background queue
///   - Provide the AVCaptureSession for live preview
final class CameraService: NSObject, @unchecked Sendable {

    // MARK: - Properties

    /// The capture session — exposed so the preview layer can use it.
    let captureSession = AVCaptureSession()

    /// Background dispatch queue for camera output processing.
    private let sessionQueue = DispatchQueue(label: "com.isaretdilicevirme.camera.session")
    private let outputQueue  = DispatchQueue(label: "com.isaretdilicevirme.camera.output")

    /// Delegate that receives captured frames.
    weak var delegate: (any CameraServiceDelegate)?

    /// Delegate that receives recording completion callbacks.
    weak var recordingDelegate: (any CameraServiceRecordingDelegate)?

    /// Whether the session is currently running.
    private(set) var isRunning = false

    /// Current camera position.
    private(set) var currentPosition: AVCaptureDevice.Position = .front

    /// Movie output used for local sentence recordings.
    private let movieOutput = AVCaptureMovieFileOutput()

    // MARK: - Configuration

    /// Configures camera input and output. Call once before starting.
    func configure() {
        sessionQueue.async { [weak self] in
            self?.setupSession()
        }
    }

    private func setupSession() {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .high

        // Remove existing inputs and outputs to allow safe reconfiguration
        captureSession.inputs.forEach { captureSession.removeInput($0) }
        captureSession.outputs.forEach { captureSession.removeOutput($0) }

        // Camera input
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentPosition),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            print("[CameraService] ❌ Could not access camera at position \(currentPosition).")
            captureSession.commitConfiguration()
            return
        }

        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }

        // Video data output
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: outputQueue)

        if captureSession.canAddOutput(output) {
            captureSession.addOutput(output)
        }

        if captureSession.canAddOutput(movieOutput) {
            captureSession.addOutput(movieOutput)
        }

        // Set video orientation to portrait
        if let connection = output.connection(with: .video) {
            if connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
            // Mirror the front camera
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = currentPosition == .front
            }
        }

        if let connection = movieOutput.connection(with: .video) {
            if connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = currentPosition == .front
            }
        }

        captureSession.commitConfiguration()
    }

    // MARK: - Session Control

    /// Switches between front and back camera.
    func switchCamera() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.currentPosition = self.currentPosition == .front ? .back : .front
            let wasRunning = self.captureSession.isRunning
            
            if wasRunning {
                self.captureSession.stopRunning()
            }
            
            self.setupSession()
            
            if wasRunning {
                self.captureSession.startRunning()
            }
        }
    }

    /// Starts the capture session on the background queue.
    func start() {
        sessionQueue.async { [weak self] in
            guard let self, !self.captureSession.isRunning else { return }
            self.captureSession.startRunning()
            self.isRunning = true
        }
    }

    /// Stops the capture session.
    func stop() {
        sessionQueue.async { [weak self] in
            guard let self, self.captureSession.isRunning else { return }
            self.captureSession.stopRunning()
            self.isRunning = false
        }
    }

    func startRecording(to outputURL: URL) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard !self.movieOutput.isRecording else { return }

            if FileManager.default.fileExists(atPath: outputURL.path()) {
                try? FileManager.default.removeItem(at: outputURL)
            }

            self.movieOutput.startRecording(to: outputURL, recordingDelegate: self)
        }
    }

    func stopRecording() {
        sessionQueue.async { [weak self] in
            guard let self, self.movieOutput.isRecording else { return }
            self.movieOutput.stopRecording()
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        delegate?.cameraService(self, didOutput: sampleBuffer)
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate

extension CameraService: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: (any Error)?
    ) {
        recordingDelegate?.cameraService(self, didFinishRecordingTo: outputFileURL, error: error)
    }
}
