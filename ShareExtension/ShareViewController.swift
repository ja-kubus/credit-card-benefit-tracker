//
//  ShareViewController.swift
//  ShareExtension
//
//  Receives PDF/CSV statement files from the share sheet and stashes them
//  in the App Group container's Inbox/ directory. The main app picks them
//  up on next foreground and pre-fills the statement upload flow.
//

import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {

    private static let appGroupID = "group.benefittracker.shared"
    private static let acceptedTypes = [
        "com.adobe.pdf",
        "public.comma-separated-values-text",
        "public.file-url"
    ]

    private var savedCount = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        processAttachments()
    }

    // MARK: - Attachment handling

    private func processAttachments() {
        guard let inboxURL = Self.inboxDirectory() else {
            fail(message: "App Group container unavailable")
            return
        }

        let providers = (extensionContext?.inputItems as? [NSExtensionItem])?
            .compactMap(\.attachments)
            .flatMap { $0 } ?? []

        let group = DispatchGroup()

        for provider in providers {
            guard let typeID = Self.acceptedTypes.first(where: {
                provider.hasItemConformingToTypeIdentifier($0)
            }) else { continue }

            group.enter()
            provider.loadFileRepresentation(forTypeIdentifier: typeID) { [weak self] url, error in
                defer { group.leave() }
                guard let self, let url, error == nil else { return }
                // loadFileRepresentation's URL is deleted when this closure
                // returns, so copy synchronously here.
                let destination = inboxURL.appendingPathComponent(
                    "\(UUID().uuidString)__\(url.lastPathComponent)"
                )
                do {
                    try FileManager.default.copyItem(at: url, to: destination)
                    DispatchQueue.main.async { self.savedCount += 1 }
                } catch {
                    // Skip this file; others may still succeed.
                }
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            if self.savedCount > 0 {
                self.showConfirmationUI()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    self.extensionContext?.completeRequest(returningItems: nil)
                }
            } else {
                self.fail(message: "No supported files found")
            }
        }
    }

    private static func inboxDirectory() -> URL? {
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            return nil
        }
        let inbox = container.appendingPathComponent("Inbox", isDirectory: true)
        try? FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
        return inbox
    }

    private func fail(message: String) {
        let error = NSError(
            domain: "ShareExtension",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
        extensionContext?.cancelRequest(withError: error)
    }

    // MARK: - UI

    private func showConfirmationUI() {
        let checkmark = UIImageView(image: UIImage(
            systemName: "checkmark.circle.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 56, weight: .medium)
        ))
        checkmark.tintColor = .systemGreen
        checkmark.contentMode = .scaleAspectFit

        let titleLabel = UILabel()
        titleLabel.text = savedCount == 1
            ? "Saved to Benefit Tracker"
            : "\(savedCount) files saved to Benefit Tracker"
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.textAlignment = .center

        let captionLabel = UILabel()
        captionLabel.text = "Open the app to finish importing"
        captionLabel.font = .preferredFont(forTextStyle: .subheadline)
        captionLabel.textColor = .secondaryLabel
        captionLabel.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [checkmark, titleLabel, captionLabel])
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24)
        ])
    }
}
