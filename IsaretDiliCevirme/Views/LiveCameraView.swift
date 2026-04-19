//
//  LiveCameraView.swift
//  IsaretDiliCevirme
//
//  Created by Mahmut Arslan on 9.03.2026.
//

import SwiftUI

/// Main view that displays the camera feed with hand landmark overlay.
///
/// Layout (bottom to top):
///   1. Camera preview (full screen)
///   2. Landmark overlay (circles + skeleton lines)
///   3. Sentence display area (accumulated words)
///   4. Status bar (top) showing detection info
struct LiveCameraView: View {

    @State private var viewModel = LiveTranslationViewModel()

    var body: some View {
        ZStack {
            // MARK: - Camera Preview
            if viewModel.cameraPermissionGranted {
                CameraPreviewView(session: viewModel.cameraService.captureSession)
                    .ignoresSafeArea()
            } else {
                // Permission not granted view
                noCameraPermissionView
            }

            // MARK: - Main Overlay
            VStack(spacing: 0) {
                statusBar
                
                Spacer()
                
                // Backend connection error banner
                if let errorMessage = viewModel.errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                        Text(errorMessage)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.red.opacity(0.85))
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut, value: viewModel.errorMessage)
                }
                
                // Last detected word badge (instant feedback)
                lastWordBadge
                
                // Accumulated sentence display
                sentenceOverlay
                
                // Compact bottom bar
                bottomInfoBar
            }
        }
        .onAppear {
            viewModel.startSession()
        }
        .onDisappear {
            viewModel.stopSession()
        }
        .statusBarHidden(true)
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack {
            // Backend connection indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(viewModel.isBackendConnected ? Color.green : (viewModel.isCameraRunning ? Color.orange : AppColors.statusInactive))
                    .frame(width: 10, height: 10)
                
                Text(viewModel.isBackendConnected ? "Bağlı" : (viewModel.isCameraRunning ? "Bağlanıyor..." : "Kapalı"))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppColors.cameraOverlayText)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.ultraThinMaterial, in: Capsule())

            Spacer()

            // Hand count badge
            if !viewModel.handDetections.isEmpty {
                Label("\(viewModel.handDetections.count) el", systemImage: "hand.raised.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.cameraOverlayText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial, in: Capsule())
            }

            // Camera switch button
            Button {
                viewModel.switchCamera()
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(AppColors.cameraOverlayText)
                    .padding(8)
                    .background(.ultraThinMaterial, in: Circle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
        .padding(.bottom, 10)
        .background(
            LinearGradient(
                colors: [AppColors.cameraBackground.opacity(0.6), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }
    
    // MARK: - Last Detected Word Badge
    
    @ViewBuilder
    private var lastWordBadge: some View {
        if !viewModel.lastDetectedWord.isEmpty && !viewModel.isSentenceComplete {
            Text(viewModel.lastDetectedWord)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.blue.opacity(0.6))
                )
                .padding(.bottom, 8)
                .transition(.scale.combined(with: .opacity))
                .animation(.easeInOut(duration: 0.2), value: viewModel.lastDetectedWord)
        }
    }
    
    // MARK: - Sentence Overlay
    
    @ViewBuilder
    private var sentenceOverlay: some View {
        if !viewModel.currentSentence.isEmpty {
            VStack(spacing: 10) {
                // Sentence text with speak button
                HStack(spacing: 12) {
                    Text(viewModel.currentSentence)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                    
                    // Completion indicator
                    if viewModel.isSentenceComplete {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.green)
                            .transition(.scale)
                    }
                }
                
                // Action buttons row
                HStack(spacing: 12) {
                    // Speak button
                    Button {
                        if viewModel.isSpeaking {
                            viewModel.stopSpeaking()
                        } else {
                            viewModel.speakSentence()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: viewModel.isSpeaking ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .font(.system(size: 14))
                                .symbolEffect(.variableColor.iterative, isActive: viewModel.isSpeaking)
                            Text(viewModel.isSpeaking ? "Durdur" : "Seslendir")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(viewModel.isSpeaking ? Color.orange.opacity(0.6) : Color.blue.opacity(0.5))
                        )
                    }
                    
                    // Clear button
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.clearSentence()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                            Text("Temizle")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.2))
                        )
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.7))
            )
            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
            .transition(.scale.combined(with: .opacity))
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.currentSentence)
        }
    }

    // MARK: - Compact Bottom Info Bar

    private var bottomInfoBar: some View {
        HStack(spacing: 12) {
            if !viewModel.handDetections.isEmpty {
                ForEach(viewModel.handDetections) { detection in
                    HStack(spacing: 6) {
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(
                                detection.chirality == .left
                                    ? AppColors.landmarkLeftHand
                                    : AppColors.landmarkRightHand
                            )
                        Text(detection.chirality == .left ? "Sol" : "Sağ")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppColors.cameraOverlayText)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                }
            }
            
            Spacer()
            
            // Status text
            Text(viewModel.statusMessage)
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundStyle(AppColors.cameraOverlayText.opacity(0.7))
                .lineLimit(1)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .padding(.bottom, 90)
    }

    // MARK: - No Camera Permission View

    private var noCameraPermissionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundStyle(AppColors.tabInactive)

            Text("Kamera İzni Gerekli")
                .font(.title2.bold())
                .foregroundStyle(AppColors.cameraOverlayText)

            Text("İşaret dili algılamak için kamera erişimine izin vermeniz gerekiyor.")
                .font(.body)
                .foregroundStyle(AppColors.tabInactive)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            } label: {
                Text("Ayarları Aç")
                    .font(.headline)
                    .foregroundStyle(AppColors.cameraOverlayText)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 14)
                    .background(AppColors.permissionButton, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.cameraBackground)
    }
}

#Preview {
    LiveCameraView()
}

