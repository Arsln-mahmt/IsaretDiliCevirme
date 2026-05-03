//
//  VideoStorage.swift
//  IsaretDiliCevirme
//
//  Created by Codex on 3.05.2026.
//

import Foundation

enum VideoStorage {

    private static let folderName = "TranslationVideos"

    static func makeTemporaryRecordingURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("translation-\(UUID().uuidString)")
            .appendingPathExtension("mov")
    }

    static func persistRecording(from temporaryURL: URL, recordID: UUID) throws -> String {
        let filename = "\(recordID.uuidString).mov"
        let destinationURL = try savedVideosDirectory()
            .appendingPathComponent(filename, isDirectory: false)

        if FileManager.default.fileExists(atPath: destinationURL.path()) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        try FileManager.default.moveItem(at: temporaryURL, to: destinationURL)
        return filename
    }

    static func savedVideoURL(for filename: String) -> URL? {
        try? savedVideosDirectory()
            .appendingPathComponent(filename, isDirectory: false)
    }

    static func fileExists(named filename: String) -> Bool {
        guard let url = savedVideoURL(for: filename) else { return false }
        return FileManager.default.fileExists(atPath: url.path())
    }

    static func deleteSavedVideo(named filename: String) {
        guard let url = savedVideoURL(for: filename) else { return }
        deleteFile(at: url)
    }

    static func deleteFile(at url: URL) {
        guard FileManager.default.fileExists(atPath: url.path()) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private static func savedVideosDirectory() throws -> URL {
        let baseDirectory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let directory = baseDirectory.appendingPathComponent(folderName, isDirectory: true)

        if !FileManager.default.fileExists(atPath: directory.path()) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        return directory
    }
}
