//
//  LandmarkOverlayView.swift
//  IsaretDiliCevirme
//
//  Created by Mahmut Arslan on 9.03.2026.
//

import SwiftUI

/// Draws hand landmark points and skeleton connections as an overlay on top of the camera preview.
///
/// Vision returns coordinates in a normalized coordinate system (0...1) with the origin at
/// the **bottom-left**. SwiftUI has the origin at the **top-left**, so we flip the Y axis.
struct LandmarkOverlayView: View {

    let handDetections: [HandDetection]

    /// Skeleton connections between joints for drawing lines.
    private let connections: [(String, String)] = [
        // Thumb
        ("VNHLKWRI", "VNHLKTCMC"), ("VNHLKTCMC", "VNHLKTMP"), ("VNHLKTMP", "VNHLKTIP"), ("VNHLKTIP", "VNHLKTTIP"),
        // Index finger
        ("VNHLKWRI", "VNHLKIMCP"), ("VNHLKIMCP", "VNHLKIPIP"), ("VNHLKIPIP", "VNHLKIDIP"), ("VNHLKIDIP", "VNHLKITIP"),
        // Middle finger
        ("VNHLKWRI", "VNHLKMMCP"), ("VNHLKMMCP", "VNHLKMPIP"), ("VNHLKMPIP", "VNHLKMDIP"), ("VNHLKMDIP", "VNHLKMTIP"),
        // Ring finger
        ("VNHLKWRI", "VNHLKRMCP"), ("VNHLKRMCP", "VNHLKRPIP"), ("VNHLKRPIP", "VNHLKRDIP"), ("VNHLKRDIP", "VNHLKRTIP"),
        // Little finger
        ("VNHLKWRI", "VNHLKLMCP"), ("VNHLKLMCP", "VNHLKLPIP"), ("VNHLKLPIP", "VNHLKLDIP"), ("VNHLKLDIP", "VNHLKLTIP"),
        // Palm connections
        ("VNHLKIMCP", "VNHLKMMCP"), ("VNHLKMMCP", "VNHLKRMCP"), ("VNHLKRMCP", "VNHLKLMCP")
    ]

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height

            ForEach(handDetections) { detection in
                // Draw skeleton lines
                ForEach(Array(connections.enumerated()), id: \.offset) { _, connection in
                    if let from = detection.landmarks.first(where: { $0.id == connection.0 }),
                       let to = detection.landmarks.first(where: { $0.id == connection.1 }) {
                        Path { path in
                            path.move(to: convertPoint(x: from.x, y: from.y, in: CGSize(width: width, height: height)))
                            path.addLine(to: convertPoint(x: to.x, y: to.y, in: CGSize(width: width, height: height)))
                        }
                        .stroke(
                            connectionColor(for: detection.chirality),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round)
                        )
                    }
                }

                // Draw joint circles
                ForEach(detection.landmarks) { landmark in
                    let point = convertPoint(x: landmark.x, y: landmark.y, in: CGSize(width: width, height: height))

                    Circle()
                        .fill(jointColor(for: landmark.id))
                        .frame(width: jointSize(for: landmark.id), height: jointSize(for: landmark.id))
                        .shadow(color: jointColor(for: landmark.id).opacity(0.6), radius: 4)
                        .position(point)
                }
            }
        }
    }

    // MARK: - Coordinate Conversion

    /// Converts Vision's normalized coordinates to SwiftUI coordinates.
    /// Vision: origin at bottom-left, (0,0) to (1,1)
    /// SwiftUI: origin at top-left
    private func convertPoint(x: CGFloat, y: CGFloat, in size: CGSize) -> CGPoint {
        CGPoint(
            x: x * size.width,
            y: (1 - y) * size.height  // Flip Y axis
        )
    }

    // MARK: - Colors

    /// Color for skeleton lines based on hand chirality.
    private func connectionColor(for chirality: HandDetection.Chirality) -> Color {
        switch chirality {
        case .left:    return AppColors.landmarkLeftHand.opacity(0.7)
        case .right:   return AppColors.landmarkRightHand.opacity(0.7)
        case .unknown: return AppColors.landmarkUnknown.opacity(0.7)
        }
    }

    /// Color for joint points — fingertips get accent color, others get white.
    private func jointColor(for jointId: String) -> Color {
        if jointId.hasSuffix("TIP") {
            return AppColors.landmarkTip
        }
        return AppColors.landmarkJoint
    }

    /// Size for joint circles — fingertips are larger.
    private func jointSize(for jointId: String) -> CGFloat {
        if jointId.hasSuffix("TIP") {
            return 12
        }
        return 8
    }
}
