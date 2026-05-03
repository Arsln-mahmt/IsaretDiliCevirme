//
//  TranslationRecord.swift
//  IsaretDiliCevirme
//
//  Created by Mahmut Arslan on 9.03.2026.
//

import Foundation

enum TranslationSyncState: String, Codable {
    case pendingUpload
    case synced
    case failed
}

/// A single translation history entry.
struct TranslationRecord: Identifiable, Codable {
    let id: UUID
    let sentence: String
    let confidence: Double
    let timestamp: Date
    let localVideoFilename: String?
    var syncState: TranslationSyncState
    var remoteDocumentID: String?

    init(
        id: UUID = UUID(),
        sentence: String,
        confidence: Double,
        timestamp: Date = .now,
        localVideoFilename: String? = nil,
        syncState: TranslationSyncState = .pendingUpload,
        remoteDocumentID: String? = nil
    ) {
        self.id = id
        self.sentence = sentence
        self.confidence = confidence
        self.timestamp = timestamp
        self.localVideoFilename = localVideoFilename
        self.syncState = syncState
        self.remoteDocumentID = remoteDocumentID
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

    /// Formatted date and time string for display.
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }

    var hasVideo: Bool {
        guard let localVideoFilename else { return false }
        return VideoStorage.fileExists(named: localVideoFilename)
    }

    var hasStoredVideoReference: Bool {
        localVideoFilename != nil
    }

    var localVideoURL: URL? {
        guard let localVideoFilename else { return nil }
        return VideoStorage.savedVideoURL(for: localVideoFilename)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case sentence
        case word
        case confidence
        case timestamp
        case localVideoFilename
        case syncState
        case remoteDocumentID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        sentence = try container.decodeIfPresent(String.self, forKey: .sentence)
            ?? container.decode(String.self, forKey: .word)
        confidence = try container.decodeIfPresent(Double.self, forKey: .confidence) ?? 0
        timestamp = try container.decodeIfPresent(Date.self, forKey: .timestamp) ?? .now
        localVideoFilename = try container.decodeIfPresent(String.self, forKey: .localVideoFilename)
        syncState = try container.decodeIfPresent(TranslationSyncState.self, forKey: .syncState) ?? .pendingUpload
        remoteDocumentID = try container.decodeIfPresent(String.self, forKey: .remoteDocumentID)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(sentence, forKey: .sentence)
        try container.encode(confidence, forKey: .confidence)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encodeIfPresent(localVideoFilename, forKey: .localVideoFilename)
        try container.encode(syncState, forKey: .syncState)
        try container.encodeIfPresent(remoteDocumentID, forKey: .remoteDocumentID)
    }
}
