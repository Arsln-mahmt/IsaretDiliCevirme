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

    /// Key for UserDefaults storage.
    private let storageKey = "translationHistory"

    // MARK: - Init

    init() {
        loadRecords()
    }

    // MARK: - Public Methods

    /// Adds a new translation record and saves to storage.
    func addRecord(word: String, confidence: Double) {
        let record = TranslationRecord(word: word, confidence: confidence)
        records.insert(record, at: 0) // Newest first
        saveRecords()
    }

    /// Removes a record at the given offsets.
    func removeRecords(at offsets: IndexSet) {
        records.remove(atOffsets: offsets)
        saveRecords()
    }

    /// Clears all history.
    func clearAll() {
        records.removeAll()
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
}
