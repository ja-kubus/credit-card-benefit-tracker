//
//  SharedInbox.swift
//  Credit Card Benefit Tracker
//
//  Reads statement files stashed by the Share Extension in the App Group
//  container's Inbox/ directory. Main app target only.
//

import Foundation
import Observation

struct SharedInbox {
    static let suiteName = "group.benefittracker.shared"

    struct InboxFile: Identifiable {
        let url: URL
        let originalName: String
        let data: Data
        var id: URL { url }
    }

    private static var inboxURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: suiteName)?
            .appendingPathComponent("Inbox", isDirectory: true)
    }

    /// Returns pending files from the App Group Inbox (decoding the
    /// `UUID__name` prefix), or [] if none/unavailable.
    /// Identical files (same original name and same content) — e.g. from the
    /// user sharing the same PDF twice — are deduplicated: the first copy is
    /// returned and the extras are deleted from disk.
    static func pendingFiles() -> [InboxFile] {
        guard let inbox = inboxURL,
              let urls = try? FileManager.default.contentsOfDirectory(
                at: inbox, includingPropertiesForKeys: nil
              ) else { return [] }

        var seen = Set<String>()   // "originalName|byteCount" content fingerprint
        var files: [InboxFile] = []

        for url in urls.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            guard let data = try? Data(contentsOf: url) else { continue }
            let fileName = url.lastPathComponent
            // Files are named "<UUID>__<originalName>" by the extension.
            let originalName: String
            if let range = fileName.range(of: "__") {
                originalName = String(fileName[range.upperBound...])
            } else {
                originalName = fileName
            }

            let fingerprint = "\(originalName)|\(data.count)"
            if seen.contains(fingerprint) {
                // Duplicate share of the same file — remove the extra copy.
                try? FileManager.default.removeItem(at: url)
                continue
            }
            seen.insert(fingerprint)
            files.append(InboxFile(url: url, originalName: originalName, data: data))
        }
        return files
    }

    /// Deletes the given inbox file after successful import.
    static func consume(_ file: InboxFile) {
        try? FileManager.default.removeItem(at: file.url)
    }

    /// Deletes everything in the inbox.
    static func clear() {
        guard let inbox = inboxURL,
              let urls = try? FileManager.default.contentsOfDirectory(
                at: inbox, includingPropertiesForKeys: nil
              ) else { return }
        for url in urls {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

/// Hands shared-inbox files off to the statement upload flow.
/// The upload sheet reads `SharedImportCoordinator.shared.filesToImport`
/// (each InboxFile maps to a PickedFile via originalName -> fileName,
/// data -> data) and should clear the array once consumed.
@Observable
final class SharedImportCoordinator {
    static let shared = SharedImportCoordinator()
    var filesToImport: [SharedInbox.InboxFile] = []
    private init() {}
}
