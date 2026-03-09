//
//  HandLandmark.swift
//  IsaretDiliCevirme
//
//  Created by Mahmut Arslan on 9.03.2026.
//

import Foundation

/// Represents a single hand landmark point detected by Vision.
/// Each hand has 21 recognized joint points (e.g., wrist, thumb tip, index finger tip, etc.).
struct HandLandmark: Identifiable {
    /// Unique identifier combining the joint name, e.g. "VNHLKTTIP"
    let id: String

    /// Normalized x-coordinate (0...1, origin at bottom-left in Vision coordinates)
    let x: CGFloat

    /// Normalized y-coordinate (0...1, origin at bottom-left in Vision coordinates)
    let y: CGFloat
}

/// Represents a full hand detection with all its landmark points.
struct HandDetection: Identifiable {
    let id = UUID()
    let landmarks: [HandLandmark]
    let chirality: Chirality

    enum Chirality: String {
        case left
        case right
        case unknown
    }
}
