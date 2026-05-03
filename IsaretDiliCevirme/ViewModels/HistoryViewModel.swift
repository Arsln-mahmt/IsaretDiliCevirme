//
//  HistoryViewModel.swift
//  IsaretDiliCevirme
//
//  Created by Mahmut Arslan on 9.03.2026.
//

import SwiftUI

/// Manages the translation history records.
///
/// Stores records in UserDefaults for persistence across app launches.
/// In the future, this could be migrated to Core Data or a remote database.
@Observable
final class HistoryViewModel {

    // MARK: - Properties

    /// All translation records, newest first.
    var records: [TranslationRecord] = []

    /// Records created from the new save flow, even if the local file later disappears.
    var savedVideoRecords: [TranslationRecord] {
        records.filter(\.hasStoredVideoReference)
    }

    /// Key for UserDefaults storage.
    private let storageKey = "translationHistory"
    private let cloudService = FirestoreTranslationService.shared

    // MARK: - Init

    init() {
        loadRecords()
        Task {
            await syncPendingRecords()
            await fetchRemoteRecords()
        }
    }

    // MARK: - Public Methods

    /// Adds a new translation record and saves to storage.
    func addRecord(
        id: UUID = UUID(),
        sentence: String,
        confidence: Double,
        videoFilename: String? = nil,
        syncState: TranslationSyncState = .pendingUpload
    ) {
        let record = TranslationRecord(
            id: id,
            sentence: sentence,
            confidence: confidence,
            localVideoFilename: videoFilename,
            syncState: syncState
        )
        records.insert(record, at: 0) // Newest first
        saveRecords()
        enqueueCloudSync(for: record)
    }

    /// Removes a record at the given offsets.
    func removeRecords(at offsets: IndexSet) {
        let removedRecords = offsets.map { records[$0] }
        records.remove(atOffsets: offsets)
        removedRecords
            .compactMap(\.localVideoFilename)
            .forEach { filename in
                VideoStorage.deleteSavedVideo(named: filename)
            }
        saveRecords()
        removedRecords.forEach(enqueueCloudDelete(for:))
    }

    /// Clears all history.
    func clearAll() {
        let removedRecords = records
        records
            .compactMap(\.localVideoFilename)
            .forEach { filename in
                VideoStorage.deleteSavedVideo(named: filename)
            }
        records.removeAll()
        saveRecords()
        removedRecords.forEach(enqueueCloudDelete(for:))
    }

    func pendingCloudSyncRecords() -> [TranslationRecord] {
        records.filter { $0.syncState != .synced }
    }

    func markRecordAsSynced(id: UUID, remoteDocumentID: String) {
        guard let index = records.firstIndex(where: { $0.id == id }) else { return }
        records[index].syncState = .synced
        records[index].remoteDocumentID = remoteDocumentID
        saveRecords()
    }

    func markRecordAsFailed(id: UUID) {
        guard let index = records.firstIndex(where: { $0.id == id }) else { return }
        records[index].syncState = .failed
        saveRecords()
    }

    // MARK: - Persistence

    private func saveRecords() {
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadRecords() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([TranslationRecord].self, from: data) else {
            return
        }
        records = decoded
    }

    private func enqueueCloudSync(for record: TranslationRecord) {
        Task { [weak self] in
            await self?.syncRecord(record)
        }
    }

    private func enqueueCloudDelete(for record: TranslationRecord) {
        Task { [weak self] in
            await self?.deleteRecordFromCloud(record)
        }
    }

    private func syncPendingRecords() async {
        let pendingRecords = pendingCloudSyncRecords()

        for record in pendingRecords {
            await syncRecord(record)
        }
    }

    private func syncRecord(_ record: TranslationRecord) async {
        guard cloudService.isConfigured else { return }

        do {
            let remoteDocumentID = try await cloudService.sync(record: record)
            await MainActor.run {
                self.markRecordAsSynced(id: record.id, remoteDocumentID: remoteDocumentID)
            }
        } catch {
            await MainActor.run {
                self.markRecordAsFailed(id: record.id)
            }
        }
    }

    private func fetchRemoteRecords() async {
        guard cloudService.isConfigured else { return }

        do {
            let remoteRecords = try await cloudService.fetchRecords()
            await MainActor.run {
                self.mergeRemoteRecords(remoteRecords)
            }
        } catch {
            // Keep the local history as the source of truth if cloud fetch fails.
        }
    }

    private func deleteRecordFromCloud(_ record: TranslationRecord) async {
        guard cloudService.isConfigured else { return }

        do {
            try await cloudService.delete(record: record)
        } catch {
            // Local deletion should not be blocked by a cloud cleanup failure.
        }
    }

    private func mergeRemoteRecords(_ remoteRecords: [TranslationRecord]) {
        guard !remoteRecords.isEmpty else { return }

        var mergedRecords = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })

        for remoteRecord in remoteRecords {
            if let localRecord = mergedRecords[remoteRecord.id] {
                mergedRecords[remoteRecord.id] = TranslationRecord(
                    id: localRecord.id,
                    sentence: remoteRecord.sentence,
                    confidence: remoteRecord.confidence,
                    timestamp: remoteRecord.timestamp,
                    localVideoFilename: localRecord.localVideoFilename ?? remoteRecord.localVideoFilename,
                    syncState: .synced,
                    remoteDocumentID: remoteRecord.remoteDocumentID ?? localRecord.remoteDocumentID
                )
            } else {
                mergedRecords[remoteRecord.id] = remoteRecord
            }
        }

        records = mergedRecords.values.sorted { $0.timestamp > $1.timestamp }
        saveRecords()
    }
}
