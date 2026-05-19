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

struct PickedFile {
    let fileName: String
    let data: Data
}

struct DocumentPickerView: UIViewControllerRepresentable {
    @Environment(\.dismiss) var dismiss
    var completion: (PickedFile) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [
            .commaSeparatedText,  // CSV
            .pdf
        ])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
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
            if let url = urls.first {
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
                    let fileName = url.lastPathComponent
                    let pickedFile = PickedFile(fileName: fileName, data: data)
                    parent.completion(pickedFile)
                    parent.dismiss()
                } catch {
                    // If reading fails, we can still try to pass the URL
                    // but this should rarely happen now
                    print("Error reading file: \(error)")
                    parent.dismiss()
                }
            }
        }
    }
}
