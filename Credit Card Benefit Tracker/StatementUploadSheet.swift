//
//  StatementUploadSheet.swift
//  Credit Card Benefit Tracker
//
//  Created by Jacob Michalik on 5/18/26.
//

import SwiftUI
import SwiftData
import CryptoKit

struct StatementUploadSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext

    let userCards: [UserCard]
    let onUploadComplete: () -> Void

    @State private var selectedFiles: [PickedFile] = []
    @State private var selectedIssuer: String = ""
    @State private var selectedCard: UserCard?
    @State private var selectedStatementMonth: Int = {
        // Default to last month (statements cover a completed period)
        let cal = Calendar.current
        let lastMonth = cal.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        return cal.component(.month, from: lastMonth)
    }()
    @State private var selectedStatementYear: Int = {
        let cal = Calendar.current
        let lastMonth = cal.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        return cal.component(.year, from: lastMonth)
    }()
    @State private var userAdjustedMonth = false
    @State private var showDocumentPicker = false
    @State private var isProcessing = false
    @State private var uploadError: ParsingError? = nil
    @State private var showingErrorAlert = false
    @State private var showingSuccessAlert = false
    @State private var successMessage = ""
    @State private var pendingMatches: [BenefitMatch] = []
    @State private var showBenefitReview = false
    @State private var pendingInboxFiles: [SharedInbox.InboxFile] = []

    // Supported issuers
    let issuers = ["Chase", "Discover", "Citi", "American Express", "Capital One"]

    private static let monthNames = ["January", "February", "March", "April", "May", "June",
                                     "July", "August", "September", "October", "November", "December"]

    private var yearOptions: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Array((currentYear - 5)...currentYear).reversed()
    }

    var filteredCards: [UserCard] {
        guard !selectedIssuer.isEmpty else { return [] }
        return userCards.filter { $0.issuer == selectedIssuer }
    }

    var canUpload: Bool {
        !selectedFiles.isEmpty && !selectedIssuer.isEmpty && selectedCard != nil && !isProcessing
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Upload Statement")
                        .font(.headline)
                    Spacer()
                    Button("Cancel") {
                        resetForm()
                        dismiss()
                    }
                    .foregroundStyle(.secondary)
                }
                .padding()

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // File Upload Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("1. Select Statement Files")
                                .font(.subheadline.weight(.semibold))

                            Button {
                                showDocumentPicker = true
                            } label: {
                                HStack {
                                    Image(systemName: "doc.badge.plus")
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Choose files")
                                            .font(.body)
                                            .foregroundStyle(.primary)
                                        Text("PDF or CSV — select one or more")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                            }
                            .foregroundStyle(.primary)

                            if !selectedFiles.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(selectedFiles) { file in
                                        HStack {
                                            Image(systemName: "doc.fill")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            Text(file.fileName)
                                                .font(.caption)
                                                .lineLimit(1)
                                                .truncationMode(.middle)
                                            Spacer()
                                            Button {
                                                selectedFiles.removeAll { $0.id == file.id }
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 8)
                                        .background(Color.gray.opacity(0.08))
                                        .cornerRadius(6)
                                    }
                                }

                                Label("\(selectedFiles.count) file\(selectedFiles.count == 1 ? "" : "s") selected", systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                                    .padding(.horizontal, 8)
                            }
                        }

                        // Issuer Selection
                        VStack(alignment: .leading, spacing: 8) {
                            Text("2. Select Issuer")
                                .font(.subheadline.weight(.semibold))

                            Picker("Issuer", selection: $selectedIssuer) {
                                Text("Select an issuer").tag("")
                                ForEach(issuers, id: \.self) { issuer in
                                    Text(issuer).tag(issuer)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                            .onChange(of: selectedIssuer) {
                                preselectCardIfUnambiguous()
                            }

                            if !selectedIssuer.isEmpty {
                                Label("Issuer selected", systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                                    .padding(.horizontal, 8)
                            }
                        }

                        // Card Selection
                        VStack(alignment: .leading, spacing: 8) {
                            Text("3. Select Card from \(selectedIssuer.isEmpty ? "this issuer" : selectedIssuer)")
                                .font(.subheadline.weight(.semibold))
                                .opacity(selectedIssuer.isEmpty ? 0.5 : 1.0)

                            if filteredCards.isEmpty && !selectedIssuer.isEmpty {
                                Text("No cards found for \(selectedIssuer)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.orange.opacity(0.1))
                                    .cornerRadius(8)
                            } else {
                                Picker("Card", selection: $selectedCard) {
                                    Text("Select a card").tag(UserCard?.none)
                                    ForEach(filteredCards, id: \.self) { card in
                                        Text("\(card.issuer) \(card.name)").tag(card as UserCard?)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                                .disabled(filteredCards.isEmpty)

                                if selectedCard != nil {
                                    Label("Card selected", systemImage: "checkmark.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                        .padding(.horizontal, 8)
                                }
                            }
                        }

                        // Statement Month Selection
                        VStack(alignment: .leading, spacing: 8) {
                            Text("4. Statement Month")
                                .font(.subheadline.weight(.semibold))

                            if selectedFiles.count > 1 {
                                // With multiple files, each statement's month is inferred
                                // per-file from its own transactions, so a single picker
                                // would be misleading. Show an informational note instead.
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "info.circle")
                                        .foregroundStyle(.secondary)
                                    Text("Each statement's month is detected automatically from its transactions.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                            } else {
                                Text("Auto-detected from the transactions in the file. Change these pickers only if you want to override the detected month.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                HStack(spacing: 8) {
                                    Picker("Month", selection: $selectedStatementMonth) {
                                        ForEach(1...12, id: \.self) { month in
                                            Text(Self.monthNames[month - 1]).tag(month)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                                    .onChange(of: selectedStatementMonth) {
                                        userAdjustedMonth = true
                                    }

                                    Picker("Year", selection: $selectedStatementYear) {
                                        ForEach(yearOptions, id: \.self) { year in
                                            Text(String(year)).tag(year)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                                    .onChange(of: selectedStatementYear) {
                                        userAdjustedMonth = true
                                    }
                                }
                            }
                        }

                        Spacer()
                    }
                    .padding()
                }

                Divider()

                // Action Buttons
                HStack(spacing: 12) {
                    Button(role: .cancel) {
                        resetForm()
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        categorizeAndUpload()
                    } label: {
                        if isProcessing {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Categorize & Upload")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canUpload)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                consumeSharedImports()
            }
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPickerView { pickedFiles in
                    selectedFiles.append(contentsOf: pickedFiles)
                    // Try to auto-detect issuer from the first filename
                    if let first = pickedFiles.first {
                        autoDetectIssuer(from: first.fileName)
                    }
                }
            }
            .sheet(isPresented: $showBenefitReview) {
                BenefitMatchReviewSheet(matches: pendingMatches) { applied in
                    showBenefitReview = false
                    // List what was actually checked off in the success popup.
                    if !applied.isEmpty {
                        successMessage += "\n\nBenefits checked off:\n"
                            + applied.map(\.summaryLine).joined(separator: "\n")
                    }
                    // Present the success alert after the sheet dismissal animation completes,
                    // otherwise the alert is dropped mid-dismissal.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showingSuccessAlert = true
                    }
                }
            }
            .alert("Upload Error", isPresented: $showingErrorAlert) {
                Button("OK") {
                    uploadError = nil
                }
            } message: {
                Text(uploadError?.errorDescription ?? "Unknown error")
            }
            .alert("Upload Successful", isPresented: $showingSuccessAlert) {
                Button("Done") {
                    // Give SwiftData a moment to persist, then dismiss
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        resetForm()
                        dismiss()
                    }
                }
            } message: {
                Text(successMessage)
            }
        }
    }

    /// Pulls files handed off by the Share Extension (via SharedImportCoordinator)
    /// into the picker state. Files are NOT removed from the App Group inbox yet —
    /// they're kept in `pendingInboxFiles` and deleted only after a successful upload,
    /// so a cancel or failure leaves them on disk for a retry next launch.
    private func consumeSharedImports() {
        let inboxFiles = SharedImportCoordinator.shared.filesToImport
        guard !inboxFiles.isEmpty else { return }

        // Skip files already in the picker (e.g. the same PDF shared twice)
        let existingNames = Set(selectedFiles.map { $0.fileName.lowercased() })
        let newFiles = inboxFiles.filter { !existingNames.contains($0.originalName.lowercased()) }

        selectedFiles.append(contentsOf: newFiles.map {
            PickedFile(fileName: $0.originalName, data: $0.data)
        })
        if let first = newFiles.first {
            autoDetectIssuer(from: first.originalName)
        }

        pendingInboxFiles += newFiles
        SharedImportCoordinator.shared.filesToImport = []
    }

    private func autoDetectIssuer(from fileName: String) {
        let lowerFileName = fileName.lowercased()

        if lowerFileName.contains("chase") {
            selectedIssuer = "Chase"
        } else if lowerFileName.contains("discover") {
            selectedIssuer = "Discover"
        } else if lowerFileName.contains("citi") || lowerFileName.contains("citibank") {
            selectedIssuer = "Citi"
        } else if lowerFileName.contains("amex") || lowerFileName.contains("american express") {
            selectedIssuer = "American Express"
        } else if lowerFileName.contains("capital one") || lowerFileName.contains("capitalone") {
            selectedIssuer = "Capital One"
        }

        preselectCardIfUnambiguous()
    }

    /// If the user owns exactly one card from the selected issuer, select it automatically.
    private func preselectCardIfUnambiguous() {
        let cards = filteredCards
        if cards.count == 1 {
            selectedCard = cards[0]
        } else if let current = selectedCard, current.issuer != selectedIssuer {
            // Clear a stale selection from a different issuer
            selectedCard = nil
        }
    }

    /// Determine the statement month by majority vote over the parsed transactions.
    /// Falls back to the picker values if no rows or no valid date can be built.
    /// - Parameter allowManualOverride: only true for single-file uploads, where the
    ///   visible month picker is meaningful. For multi-file uploads each file's month
    ///   is always inferred from its own transactions, never forced to the picker value.
    private func inferredStatementMonth(from rows: [StatementRow], allowManualOverride: Bool) -> Date {
        let pickerDate = Calendar.current.date(
            from: DateComponents(year: selectedStatementYear, month: selectedStatementMonth, day: 1)
        ) ?? Date()

        // Honor a manual picker override only in the single-file case.
        if allowManualOverride, userAdjustedMonth {
            return pickerDate
        }

        guard !rows.isEmpty else { return pickerDate }

        let cal = Calendar.current
        var counts: [DateComponents: Int] = [:]
        for row in rows {
            let comps = cal.dateComponents([.year, .month], from: row.transactionDate)
            counts[comps, default: 0] += 1
        }

        guard let majority = counts.max(by: { $0.value < $1.value })?.key,
              let year = majority.year, let month = majority.month,
              let date = cal.date(from: DateComponents(year: year, month: month, day: 1)) else {
            return pickerDate
        }
        return date
    }

    private func categorizeAndUpload() {
        guard !selectedFiles.isEmpty,
              !selectedIssuer.isEmpty,
              let card = selectedCard else {
            return
        }

        isProcessing = true
        let filesToProcess = selectedFiles
        let issuer = selectedIssuer

        DispatchQueue.global(qos: .userInitiated).async {
            // Parse all files off the main thread
            let parseResults: [(file: PickedFile, result: Result<ParsedStatement, ParsingError>)] = filesToProcess.map { file in
                (file, StatementParser.parseStatement(from: file.data, fileName: file.fileName, issuer: issuer))
            }

            DispatchQueue.main.async {
                isProcessing = false

                var uploadedStatements = 0
                var totalNewRows = 0
                var totalDuplicatesSkipped = 0
                var failures: [String] = []  // "fileName: error"
                var allNewlyInsertedRows: [StatementRow] = []
                var newStatementHashes: [(hash: String, rows: [StatementRow])] = []

                for (file, result) in parseResults {
                    switch result {
                    case .success(let parsedStatement):
                        print("✅ Parsed \(parsedStatement.fileName): \(parsedStatement.rows.count) transactions")

                        // Check for duplicate STATEMENT (same file content already uploaded).
                        // Content-based SHA-256, so a renamed re-upload is also caught.
                        let contentHash = generateUploadHash(for: file.data)
                        let isDuplicateStatement = card.statements.contains { statement in
                            statement.uploadHash == contentHash
                        }

                        if isDuplicateStatement {
                            failures.append("\(file.fileName): This statement has already been uploaded")
                            continue
                        }

                        // Check for DUPLICATE TRANSACTIONS (same date, merchant, amount)
                        let existingRows = card.statements.flatMap { $0.rows }
                        var duplicateCount = 0
                        var filteredRows: [StatementRow] = []

                        for newRow in parsedStatement.rows {
                            let isDuplicateTransaction = existingRows.contains { existingRow in
                                existingRow.transactionDate == newRow.transactionDate
                                    && existingRow.transactionDescription.lowercased() == newRow.transactionDescription.lowercased()
                                    && existingRow.amount == newRow.amount
                            }

                            if isDuplicateTransaction {
                                duplicateCount += 1
                            } else {
                                filteredRows.append(newRow)
                            }
                        }

                        print("   ✓ Filtered \(parsedStatement.rows.count) → \(filteredRows.count) (skipped \(duplicateCount))")

                        if filteredRows.isEmpty {
                            failures.append("\(file.fileName): All transactions are duplicates. No new transactions to add.")
                            continue
                        }

                        // Create new statement with filtered rows
                        let newStatement = Statement(
                            cardID: card.catalogCardID,
                            fileName: parsedStatement.fileName,
                            issuer: parsedStatement.issuer
                        )
                        newStatement.statementMonth = inferredStatementMonth(
                            from: filteredRows,
                            allowManualOverride: filesToProcess.count == 1
                        )

                        // Compact, human-readable statement name, e.g. "CSR · Jun '26".
                        let normalizedName = Self.normalizedStatementName(
                            catalogCardID: card.catalogCardID,
                            issuer: parsedStatement.issuer,
                            month: newStatement.statementMonth
                        )

                        // A statement for the same card + month already exists → treat as a duplicate.
                        if card.statements.contains(where: { $0.fileName.lowercased() == normalizedName.lowercased() }) {
                            failures.append("\(file.fileName): A statement for \(Self.monthLabel(newStatement.statementMonth)) already exists for this card. Delete it first to re-upload.")
                            continue
                        }
                        newStatement.fileName = normalizedName

                        newStatement.rows = filteredRows
                        // Overwrite the timestamp-based hash from Statement.init with a stable
                        // content digest so future duplicate checks work across launches.
                        newStatement.uploadHash = contentHash

                        // Add to context and card
                        modelContext.insert(newStatement)
                        card.statements.append(newStatement)

                        uploadedStatements += 1
                        totalNewRows += filteredRows.count
                        totalDuplicatesSkipped += duplicateCount
                        allNewlyInsertedRows.append(contentsOf: filteredRows)
                        newStatementHashes.append((hash: contentHash, rows: filteredRows))

                    case .failure(let error):
                        print("❌ Parse error for \(file.fileName): \(error.errorDescription ?? "Unknown error")")
                        failures.append("\(file.fileName): \(error.errorDescription ?? "Unknown error")")
                    }
                }

                if uploadedStatements == 0 {
                    // All files failed
                    uploadError = .fileReadError(failures.joined(separator: "\n"))
                    showingErrorAlert = true
                    return
                }

                // Build combined success message
                var message = "Uploaded \(uploadedStatements) statement\(uploadedStatements == 1 ? "" : "s"), \(totalNewRows) transaction\(totalNewRows == 1 ? "" : "s")"
                if totalDuplicatesSkipped > 0 {
                    message += " (\(totalDuplicatesSkipped) duplicate\(totalDuplicatesSkipped == 1 ? "" : "s") skipped)"
                }
                if !failures.isEmpty {
                    message += "\n\nFailed:\n" + failures.joined(separator: "\n")
                }
                successMessage = message
                onUploadComplete()

                // Upload succeeded — now it's safe to delete shared-inbox files from disk.
                for inboxFile in pendingInboxFiles {
                    SharedInbox.consume(inboxFile)
                }
                pendingInboxFiles = []

                // Check for benefit auto-completion matches before showing success.
                // Matched per statement so each match records which statement it
                // came from (dedupe keeps one match per benefit completion).
                var seenCompletions = Set<ObjectIdentifier>()
                var matches: [BenefitMatch] = []
                for entry in newStatementHashes {
                    for match in BenefitMatcher.findMatches(card: card, in: entry.rows, sourceHash: entry.hash) {
                        let key = ObjectIdentifier(match.completion)
                        if seenCompletions.insert(key).inserted {
                            matches.append(match)
                        }
                    }
                }
                if !matches.isEmpty {
                    pendingMatches = matches
                    showBenefitReview = true
                } else {
                    showingSuccessAlert = true
                }
            }
        }
    }

    private func resetForm() {
        selectedFiles = []
        selectedIssuer = ""
        selectedCard = nil
        userAdjustedMonth = false
        pendingMatches = []
        successMessage = ""
        // Not-yet-uploaded shared files stay on disk in the inbox so they can be
        // re-offered on the next launch/foreground; just drop our in-memory list.
        pendingInboxFiles = []

        let cal = Calendar.current
        let lastMonth = cal.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        selectedStatementMonth = cal.component(.month, from: lastMonth)
        selectedStatementYear = cal.component(.year, from: lastMonth)
    }

    /// Stable content-based digest of the file's data (SHA-256, hex-encoded).
    private func generateUploadHash(for data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// "MMM yyyy" label for a statement month, e.g. "Jun 2026".
    static func monthLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMM yyyy"
        return f.string(from: date)
    }

    /// Compact "MMM ''yy" label for a statement month, e.g. "Jun '26".
    static func shortMonthLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMM ''yy"
        return f.string(from: date)
    }

    /// Known-card abbreviations keyed by catalogCardID.
    private static let cardAbbreviations: [String: String] = [
        "chase_sapphire_reserve": "CSR",
        "chase_sapphire_preferred": "CSP",
        "chase_freedom_unlimited": "CFU",
        "chase_freedom_flex": "CFF",
        "american_express_platinum_card": "Amex Plat",
        "american_express_gold_card": "Amex Gold",
        "american_express_hilton_honors_aspire_card": "Hilton Aspire",
        "american_express_hilton_honors_surpass_card": "Hilton Surpass",
        "capital_one_venture_x": "Venture X",
        "capital_one_venture": "Venture",
        "citi_strata_premier": "Strata Premier",
        "citi_double_cash": "Double Cash",
        "discover_it_cash_back": "Discover it"
    ]

    /// Short issuer abbreviation used when falling back to a derived label.
    private static func issuerAbbrev(_ issuer: String) -> String {
        switch issuer {
        case "American Express": return "Amex"
        case "Capital One": return "C1"
        case "Bank of America": return "BofA"
        case "U.S. Bank": return "USB"
        case "Wells Fargo": return "WF"
        default: return issuer
        }
    }

    /// A compact, human-readable card label derived from catalogCardID + issuer.
    /// Uses a curated abbreviation map for common cards, and otherwise strips the
    /// issuer prefix from the catalogCardID, title-cases the remainder, and prefixes
    /// the issuer abbreviation, capping the length.
    static func abbreviatedCardLabel(catalogCardID: String, issuer: String) -> String {
        if let known = cardAbbreviations[catalogCardID] {
            return known
        }

        let issuerAbbr = issuerAbbrev(issuer)

        // Strip a leading issuer prefix from the catalogCardID (e.g. "chase_",
        // "american_express_") so we don't repeat the issuer in the label.
        let issuerPrefix = issuer.lowercased()
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: " ", with: "_")
        var remainder = catalogCardID
        if remainder.hasPrefix(issuerPrefix + "_") {
            remainder = String(remainder.dropFirst(issuerPrefix.count + 1))
        }

        let words = remainder
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
        var cardPortion = words.joined(separator: " ")
        if cardPortion.count > 18 {
            cardPortion = String(cardPortion.prefix(18)).trimmingCharacters(in: .whitespaces)
        }

        if cardPortion.isEmpty {
            return issuerAbbr
        }
        return "\(issuerAbbr) \(cardPortion)"
    }

    /// Compact, human-readable statement name: "<AbbrevCard> · <Mon ''yy>",
    /// e.g. "CSR · Jun '26". Still unique per card + month, so the duplicate
    /// (same card + month) check keeps working.
    static func normalizedStatementName(catalogCardID: String, issuer: String, month: Date) -> String {
        "\(abbreviatedCardLabel(catalogCardID: catalogCardID, issuer: issuer)) · \(shortMonthLabel(month))"
    }
}

#Preview {
    @Previewable @State var cards: [UserCard] = []
    StatementUploadSheet(userCards: cards) {}
        .modelContainer(for: [UserCard.self, Statement.self, StatementRow.self], inMemory: true)
}
