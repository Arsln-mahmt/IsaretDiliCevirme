//
//  VisionService.swift
//  IsaretDiliCevirme
//
//  Created by Mahmut Arslan on 9.03.2026.
//

import Vision
import CoreMedia
import QuartzCore

/// Detects human hand poses in camera frames using Apple's Vision framework.
///
/// Responsibilities:
///   - Run VNDetectHumanHandPoseRequest on each frame
///   - Extract the 21 recognized joint points per hand
///   - Convert Vision-normalized coordinates to a simple HandLandmark model
///   - Throttle processing to ~15 FPS
final class VisionService: @unchecked Sendable {

    // MARK: - Properties

    /// Processing queue for Vision requests.
    private let processingQueue = DispatchQueue(label: "com.isaretdilicevirme.vision", qos: .userInitiated)

    /// Minimum interval between processed frames (~15 FPS).
    private let minimumFrameInterval: TimeInterval = 1.0 / 15.0

    /// Timestamp of the last processed frame.
    private var lastProcessedTime: TimeInterval = 0

    /// Maximum number of hands to detect (Turkish Sign Language can use both hands).
    var maximumHandCount: Int = 2

    // MARK: - All 21 Joint Names

    /// The 21 recognized hand landmark joint names from Vision.
    private let allJointNames: [VNHumanHandPoseObservation.JointName] = [
        .wrist,
        .thumbCMC, .thumbMP, .thumbIP, .thumbTip,
        .indexMCP, .indexPIP, .indexDIP, .indexTip,
        .middleMCP, .middlePIP, .middleDIP, .middleTip,
        .ringMCP, .ringPIP, .ringDIP, .ringTip,
        .littleMCP, .littlePIP, .littleDIP, .littleTip
    ]

    // MARK: - Detection

    /// Processes a sample buffer and returns detected hand landmarks.
    /// - Parameter sampleBuffer: The camera frame to analyze.
    /// - Returns: `nil` if the frame was throttled (skipped), an array of `HandDetection` if processed (may be empty if no hands found).
    func detectHands(in sampleBuffer: CMSampleBuffer) -> [HandDetection]? {
        // Throttle: skip frame if too soon
        let currentTime = CACurrentMediaTime()
        guard currentTime - lastProcessedTime >= minimumFrameInterval else {
            return nil  // Throttled — frame was skipped
        }
        lastProcessedTime = currentTime

        // Get pixel buffer from sample buffer
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return []
        }

        // Create and configure the hand pose request
        let request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = maximumHandCount

        // Run the request synchronously (we're already on a background queue)
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        do {
            try handler.perform([request])
        } catch {
            print("[VisionService] ❌ Hand detection failed: \(error.localizedDescription)")
            return []
        }

        // Parse results
        guard let results = request.results, !results.isEmpty else {
            return []
        }

        return results.compactMap { observation in
            parseObservation(observation)
        }
    }

    // MARK: - Parsing

    /// Extracts the 21 joint landmarks from a single hand observation.
    private func parseObservation(_ observation: VNHumanHandPoseObservation) -> HandDetection? {
        var landmarks: [HandLandmark] = []

        for jointName in allJointNames {
            guard let point = try? observation.recognizedPoint(jointName),
                  point.confidence > 0.3 else {
                continue
            }

            let landmark = HandLandmark(
                id: jointName.rawValue.rawValue,
                x: point.location.x,
                y: point.location.y
            )
            landmarks.append(landmark)
        }

        guard !landmarks.isEmpty else { return nil }

        // Determine chirality
        let chirality: HandDetection.Chirality
        switch observation.chirality {
        case .left:  chirality = .left
        case .right: chirality = .right
        default:     chirality = .unknown
        }

        return HandDetection(landmarks: landmarks, chirality: chirality)
    }
}
