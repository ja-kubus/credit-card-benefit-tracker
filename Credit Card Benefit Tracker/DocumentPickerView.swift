//
//  DocumentPickerView.swift
//  Credit Card Benefit Tracker
//
//  Created by Jacob Michalik on 5/18/26.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - File Container to hold file data and metadata

struct PickedFile: Identifiable {
    let id = UUID()
    let fileName: String
    let data: Data
}

struct DocumentPickerView: UIViewControllerRepresentable {
    @Environment(\.dismiss) var dismiss
    var completion: ([PickedFile]) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [
            .commaSeparatedText,  // CSV
            .pdf
        ])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPickerView

        init(_ parent: DocumentPickerView) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            var pickedFiles: [PickedFile] = []

            for url in urls {
                // Start accessing the security-scoped resource
                let shouldStopAccessing = url.startAccessingSecurityScopedResource()
                defer {
                    if shouldStopAccessing {
                        url.stopAccessingSecurityScopedResource()
                    }
                }

                // Read the file data WHILE we still have permission
                do {
                    let data = try Data(contentsOf: url)
                    pickedFiles.append(PickedFile(fileName: url.lastPathComponent, data: data))
                } catch {
                    print("Error reading file \(url.lastPathComponent): \(error)")
                }
            }

            if !pickedFiles.isEmpty {
                parent.completion(pickedFiles)
            }
            parent.dismiss()
        }
    }
}
