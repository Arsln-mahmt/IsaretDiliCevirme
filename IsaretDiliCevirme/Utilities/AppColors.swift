//
//  AppColors.swift
//  IsaretDiliCevirme
//
//  Created by Mahmut Arslan on 9.03.2026.
//

import SwiftUI

// MARK: - Centralized Color System
//
// All UI colors are defined here. Reference these throughout the project
// instead of using inline hex values or named system colors.
// Grouped by semantic purpose for easy discovery and maintenance.

enum AppColors {

    // MARK: - Brand / Primary

    /// Primary brand color — indigo blue. Used for active tab icons, accent highlights, checkmarks.
    static let primary       = Color(hex: 0x667EEA)

    /// Secondary brand color — purple. Used as the gradient end-point alongside `primary`.
    static let primaryDark   = Color(hex: 0x764BA2)

    /// Standard brand gradient (indigo → purple), used on center tab button, onboarding, accent bars.
    static let primaryGradient: [Color] = [primary, primaryDark]

    // MARK: - Accent Colors

    /// Vivid blue, used for technology labels and info section headers.
    static let accentBlue      = Color(hex: 0x4FACFE)

    /// Cyan-teal blue, used as a gradient pair with `accentBlue` (e.g. onboarding page 3).
    static let accentCyan      = Color(hex: 0x00F2FE)

    /// Soft pink/magenta, for LSTM/deep-learning references and onboarding page 2 gradient start.
    static let accentPink      = Color(hex: 0xF093FB)

    /// Coral-red, for architecture pipeline steps, "How it Works" headers, onboarding page 2 gradient end.
    static let accentRed       = Color(hex: 0xF5576C)

    /// Warm orange, for SwiftUI technology icon.
    static let accentOrange    = Color(hex: 0xFF6B35)

    /// Vivid green, for FastAPI / backend technology icon.
    static let accentGreen     = Color(hex: 0x00C853)

    // MARK: - Onboarding Gradients

    /// Page 1 gradient (indigo → purple).
    static let onboardingGradient1: [Color] = [primary, primaryDark]

    /// Page 2 gradient (pink → coral).
    static let onboardingGradient2: [Color] = [accentPink, accentRed]

    /// Page 3 gradient (blue → cyan).
    static let onboardingGradient3: [Color] = [accentBlue, accentCyan]

    // MARK: - Hand Landmark Detection

    /// Skeleton line color for the left hand.
    static let landmarkLeftHand  = Color.cyan

    /// Skeleton line color for the right hand.
    static let landmarkRightHand = Color.green

    /// Skeleton line color when chirality is unknown.
    static let landmarkUnknown   = Color.white

    /// Joint circle color for fingertip landmarks.
    static let landmarkTip       = Color.yellow

    /// Joint circle color for non-tip landmarks (knuckles, wrist, etc.).
    static let landmarkJoint     = Color.white

    // MARK: - Camera Overlay

    /// Text and icons on the camera overlay (always white for readability on camera feed).
    static let cameraOverlayText = Color.white

    /// Status dot: camera running.
    static let statusActive      = Color.green

    /// Status dot: camera stopped.
    static let statusInactive    = Color.red

    /// "Open Settings" button background on the permission-denied screen.
    static let permissionButton  = Color.blue

    /// Camera-screen background when no permission is granted.
    static let cameraBackground  = Color.black

    // MARK: - Tab Bar

    /// Active tab icon/label in the standard (non-camera) tab bar.
    static let tabActive   = primary

    /// Inactive tab icon/label in the standard tab bar.
    static let tabInactive = Color.gray

    /// Active tab icon on the camera's transparent tab bar.
    static let tabCameraActive   = Color.white

    /// Inactive tab icon on the camera's transparent tab bar.
    static let tabCameraInactive = Color.white.opacity(0.5)
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}
