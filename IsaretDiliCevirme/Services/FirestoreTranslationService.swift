//
//  FirestoreTranslationService.swift
//  IsaretDiliCevirme
//
//  Created by Codex on 3.05.2026.
//

import Foundation
import FirebaseCore
import FirebaseFirestore

final class FirestoreTranslationService {
    static let shared = FirestoreTranslationService()

    private let database = Firestore.firestore()
    private let userDefaults = UserDefaults.standard
    private let deviceIdentifierKey = "firestoreDeviceIdentifier"

    private lazy var deviceIdentifier: String = {
        if let existingIdentifier = userDefaults.string(forKey: deviceIdentifierKey),
           !existingIdentifier.isEmpty {
            return existingIdentifier
        }

        let newIdentifier = UUID().uuidString
        userDefaults.set(newIdentifier, forKey: deviceIdentifierKey)
        return newIdentifier
    }()

    private init() {}

    var isConfigured: Bool {
        FirebaseApp.app() != nil
    }

    func sync(record: TranslationRecord) async throws -> String {
        guard isConfigured else {
            throw FirestoreTranslationError.firebaseNotConfigured
        }

        let documentID = record.remoteDocumentID ?? record.id.uuidString
        try await translationsCollection()
            .document(documentID)
            .setData(recordPayload(for: record), merge: true)
        return documentID
    }

    func fetchRecords() async throws -> [TranslationRecord] {
        guard isConfigured else { return [] }

        let snapshot = try await translationsCollection()
            .order(by: "timestamp", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap(makeRecord(from:))
    }

    func delete(record: TranslationRecord) async throws {
        guard isConfigured else { return }

        let documentID = record.remoteDocumentID ?? record.id.uuidString
        try await translationsCollection()
            .document(documentID)
            .delete()
    }

    private func translationsCollection() -> CollectionReference {
        database
            .collection("devices")
            .document(deviceIdentifier)
            .collection("translations")
    }

    private func recordPayload(for record: TranslationRecord) -> [String: Any] {
        var payload: [String: Any] = [
            "id": record.id.uuidString,
            "sentence": record.sentence,
            "confidence": record.confidence,
            "timestamp": Timestamp(date: record.timestamp),
            "syncState": TranslationSyncState.synced.rawValue,
            "deviceIdentifier": deviceIdentifier,
            "hasLocalVideo": record.localVideoFilename != nil,
            "updatedAt": FieldValue.serverTimestamp()
        ]

        if let localVideoFilename = record.localVideoFilename {
            payload["localVideoFilename"] = localVideoFilename
        }

        if let correctedSentence = record.correctedSentence {
            payload["correctedSentence"] = correctedSentence
            payload["isCorrected"] = true
        }

        if let correctionTimestamp = record.correctionTimestamp {
            payload["correctionTimestamp"] = Timestamp(date: correctionTimestamp)
        }

        return payload
    }

    private func makeRecord(from document: QueryDocumentSnapshot) -> TranslationRecord? {
        let data = document.data()

        guard let sentence = data["sentence"] as? String else {
            return nil
        }

        let identifier = UUID(uuidString: (data["id"] as? String) ?? document.documentID) ?? UUID()
        let confidence = data["confidence"] as? Double ?? 0
        let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? .now
        let localVideoFilename = data["localVideoFilename"] as? String
        let correctedSentence = data["correctedSentence"] as? String
        let correctionTimestamp = (data["correctionTimestamp"] as? Timestamp)?.dateValue()

        return TranslationRecord(
            id: identifier,
            sentence: sentence,
            confidence: confidence,
            timestamp: timestamp,
            localVideoFilename: localVideoFilename,
            correctedSentence: correctedSentence,
            correctionTimestamp: correctionTimestamp,
            syncState: .synced,
            remoteDocumentID: document.documentID
        )
    }
}

enum FirestoreTranslationError: LocalizedError {
    case firebaseNotConfigured

    var errorDescription: String? {
        switch self {
        case .firebaseNotConfigured:
            return "Firebase henüz yapılandırılmadı."
        }
    }
}
