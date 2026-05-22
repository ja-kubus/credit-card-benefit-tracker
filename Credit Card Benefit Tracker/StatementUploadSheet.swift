//
//  StatementUploadSheet.swift
//  Credit Card Benefit Tracker
//
//  Created by Jacob Michalik on 5/18/26.
//

import SwiftUI
import SwiftData

struct StatementUploadSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let userCards: [UserCard]
    let onUploadComplete: () -> Void
    
    @State private var selectedFile: PickedFile?
    @State private var selectedIssuer: String = ""
    @State private var selectedCard: UserCard?
    @State private var showDocumentPicker = false
    @State private var isProcessing = false
    @State private var uploadError: ParsingError? = nil
    @State private var showingErrorAlert = false
    @State private var showingSuccessAlert = false
    @State private var successMessage = ""
    
    // Supported issuers
    let issuers = ["Chase", "Discover", "Citi", "American Express", "Capital One"]
    
    var filteredCards: [UserCard] {
        guard !selectedIssuer.isEmpty else { return [] }
        return userCards.filter { $0.issuer == selectedIssuer }
    }
    
    var canUpload: Bool {
        selectedFile != nil && !selectedIssuer.isEmpty && selectedCard != nil && !isProcessing
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
                            Text("1. Select Statement File")
                                .font(.subheadline.weight(.semibold))
                            
                            Button {
                                showDocumentPicker = true
                            } label: {
                                HStack {
                                    Image(systemName: "doc.badge.plus")
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(selectedFile?.fileName ?? "Choose a file")
                                            .font(.body)
                                            .foregroundStyle(.primary)
                                        Text("PDF or CSV")
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
                            
                            if selectedFile != nil {
                                Label("File selected", systemImage: "checkmark.circle.fill")
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
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPickerView { pickedFile in
                    selectedFile = pickedFile
                    // Try to auto-detect issuer from filename
                    autoDetectIssuer(from: pickedFile.fileName)
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
    }
    
    private func categorizeAndUpload() {
        guard let pickedFile = selectedFile,
              !selectedIssuer.isEmpty,
              let card = selectedCard else {
            return
        }
        
        isProcessing = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Parse statement using Data directly (already read from file)
            let result = StatementParser.parseStatement(from: pickedFile.data, fileName: pickedFile.fileName, issuer: selectedIssuer)
            
            DispatchQueue.main.async {
                isProcessing = false
                
                switch result {
                case .success(let parsedStatement):
                    print("✅ Parsed statement: \(parsedStatement.fileName)")
                    print("   Issuer: \(parsedStatement.issuer)")
                    print("   Transactions found: \(parsedStatement.rows.count)")
                    
                    // Check for duplicate STATEMENT (same file already uploaded)
                    let isDuplicateStatement = card.statements.contains { statement in
                        statement.uploadHash == generateUploadHash(
                            cardID: card.catalogCardID,
                            fileName: parsedStatement.fileName,
                            issuer: parsedStatement.issuer
                        )
                    }
                    
                    if isDuplicateStatement {
                        uploadError = .fileReadError("This statement has already been uploaded")
                        showingErrorAlert = true
                        return
                    }
                    
                    // Check for duplicate FILENAME (same statement name already exists)
                    let hasSameName = card.statements.contains { statement in
                        statement.fileName.lowercased() == parsedStatement.fileName.lowercased()
                    }
                    
                    if hasSameName {
                        print("   ⚠️  Statement with filename '\(parsedStatement.fileName)' already exists")
                        uploadError = .fileReadError("A statement named '\(parsedStatement.fileName)' already exists for this card. Please delete it first if you want to re-upload.")
                        showingErrorAlert = true
                        return
                    }
                    
                    // Check for DUPLICATE TRANSACTIONS (same date, merchant, amount)
                    var duplicateCount = 0
                    var filteredRows: [StatementRow] = []
                    
                    // DEBUG: Log existing statements and rows
                    print("   🔍 Checking for duplicates...")
                    print("      Card has \(card.statements.count) existing statement(s)")
                    let existingRows = card.statements.flatMap { $0.rows }
                    print("      Total existing rows: \(existingRows.count)")
                    
                    if !existingRows.isEmpty {
                        print("      ─ Existing rows sample:")
                        for (idx, row) in existingRows.prefix(3).enumerated() {
                            let formatter = DateFormatter()
                            formatter.dateFormat = "MM/dd/yyyy"
                            let dateStr = formatter.string(from: row.transactionDate)
                            print("         [\(idx)] \(dateStr) | \(row.transactionDescription) | $\(String(format: "%.2f", row.amount))")
                        }
                    }
                    
                    print("      ─ Parsed rows sample (incoming):")
                    for (idx, row) in parsedStatement.rows.prefix(3).enumerated() {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "MM/dd/yyyy"
                        let dateStr = formatter.string(from: row.transactionDate)
                        print("         [\(idx)] \(dateStr) | \(row.transactionDescription) | $\(String(format: "%.2f", row.amount))")
                    }
                    
                    for newRow in parsedStatement.rows {
                        let isDuplicateTransaction = card.statements.flatMap { $0.rows }.contains { existingRow in
                            let isSameDate = existingRow.transactionDate == newRow.transactionDate
                            let isSameMerchant = existingRow.transactionDescription.lowercased() == newRow.transactionDescription.lowercased()
                            let isSameAmount = existingRow.amount == newRow.amount
                            
                            return isSameDate && isSameMerchant && isSameAmount
                        }
                        
                        if isDuplicateTransaction {
                            duplicateCount += 1
                            let formatter = DateFormatter()
                            formatter.dateFormat = "MM/dd/yyyy"
                            let dateStr = formatter.string(from: newRow.transactionDate)
                            print("      ⚠️  Duplicate: \(dateStr) | \(newRow.transactionDescription) | $\(String(format: "%.2f", newRow.amount))")
                        } else {
                            filteredRows.append(newRow)
                        }
                    }
                    
                    print("      ✓ Filtered \(parsedStatement.rows.count) → \(filteredRows.count) (skipped \(duplicateCount))")
                    
                    if filteredRows.isEmpty {
                        uploadError = .fileReadError("All transactions in this statement are duplicates. No new transactions to add.")
                        showingErrorAlert = true
                        return
                    }
                    
                    // Create new statement with filtered rows
                    let newStatement = Statement(
                        cardID: card.catalogCardID,
                        fileName: parsedStatement.fileName,
                        issuer: parsedStatement.issuer
                    )
                    newStatement.rows = filteredRows
                    
                    // Add to context and card
                    modelContext.insert(newStatement)
                    card.statements.append(newStatement)
                    
                    // Success message with info about duplicates
                    let rowCount = filteredRows.count
                    if duplicateCount > 0 {
                        successMessage = "Successfully uploaded \(parsedStatement.fileName)\n\(rowCount) new transaction\(rowCount == 1 ? "" : "s") added\n(\(duplicateCount) duplicate\(duplicateCount == 1 ? "" : "s") skipped)"
                    } else {
                        successMessage = "Successfully uploaded \(parsedStatement.fileName) with \(rowCount) transaction\(rowCount == 1 ? "" : "s")"
                    }
                    showingSuccessAlert = true
                    onUploadComplete()
                    
                case .failure(let error):
                    print("❌ Parse error: \(error.errorDescription ?? "Unknown error")")
                    uploadError = error
                    showingErrorAlert = true
                }
            }
        }
    }
    
    private func resetForm() {
        selectedFile = nil
        selectedIssuer = ""
        selectedCard = nil
    }
    
    private func generateUploadHash(cardID: String, fileName: String, issuer: String) -> String {
        let input = "\(cardID)_\(fileName)_\(issuer)"
        return String(input.hashValue)
    }
}

#Preview {
    @Previewable @State var cards: [UserCard] = []
    StatementUploadSheet(userCards: cards) {}
        .modelContainer(for: [UserCard.self, Statement.self, StatementRow.self], inMemory: true)
}
