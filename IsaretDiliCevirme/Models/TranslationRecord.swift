//
//  TranslationRecord.swift
//  IsaretDiliCevirme
//
//  Created by Mahmut Arslan on 9.03.2026.
//

import Foundation

/// A single translation history entry.
struct TranslationRecord: Identifiable, Codable {
    let id: UUID
    let word: String
    let confidence: Double
    let timestamp: Date

    init(word: String, confidence: Double, timestamp: Date = .now) {
        self.id = UUID()
        self.word = word
        self.confidence = confidence
        self.timestamp = timestamp
    }

    /// Formatted time string for display (e.g., "14:32")
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: timestamp)
    }

    /// Confidence as percentage string (e.g., "92%")
    var confidenceText: String {
        "\(Int(confidence * 100))%"
    }
}
