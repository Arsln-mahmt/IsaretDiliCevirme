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
///   3. Status bar (top) showing detection info
struct LiveCameraView: View {

    @State private var viewModel = LiveTranslationViewModel()

    var body: some View {
        ZStack {
            // MARK: - Camera Preview
            if viewModel.cameraPermissionGranted {
                CameraPreviewView(session: viewModel.cameraService.captureSession)
                    .ignoresSafeArea()

                // MARK: - Landmark Overlay
                LandmarkOverlayView(handDetections: viewModel.handDetections)
                    .ignoresSafeArea()
            } else {
                // Permission not granted view
                noCameraPermissionView
            }

            // MARK: - Status Overlay
            VStack {
                statusBar
                Spacer()
                detectionInfoBar
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
            // Status indicator
            Circle()
                .fill(viewModel.isCameraRunning ? AppColors.statusActive : AppColors.statusInactive)
                .frame(width: 10, height: 10)

            Text(viewModel.statusMessage)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(AppColors.cameraOverlayText)

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

    // MARK: - Detection Info Bar

    private var detectionInfoBar: some View {
        VStack(spacing: 8) {
            if !viewModel.handDetections.isEmpty {
                ForEach(viewModel.handDetections) { detection in
                    HStack(spacing: 12) {
                        Image(systemName: "hand.raised.fill")
                            .foregroundStyle(
                                detection.chirality == .left
                                    ? AppColors.landmarkLeftHand
                                    : AppColors.landmarkRightHand
                            )

                        Text(detection.chirality == .left ? "Sol El" : "Sağ El")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppColors.cameraOverlayText)

                        Text("•")
                            .foregroundStyle(AppColors.tabInactive)

                        Text("\(detection.landmarks.count) nokta")
                            .font(.system(size: 13, weight: .regular, design: .monospaced))
                            .foregroundStyle(AppColors.cameraOverlayText.opacity(0.8))

                        Spacer()
                    }
                }
            } else {
                HStack {
                    Image(systemName: "hand.raised.slash")
                        .foregroundStyle(AppColors.tabInactive)
                    Text("El algılanmadı — Elinizi kameraya gösterin")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(AppColors.tabInactive)
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 16)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 100)
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
