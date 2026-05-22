//
//  StatementParser.swift
//  Credit Card Benefit Tracker
//
//  Created by Jacob Michalik on 5/18/26.
//

import Foundation
import PDFKit

struct ParsedStatement {
    let fileName: String
    let issuer: String
    let rows: [StatementRow]
}

class StatementParser {
    
    // MARK: - Main Parse Function (from Data)
    
    static func parseStatement(from data: Data, fileName: String, issuer: String) -> Result<ParsedStatement, ParsingError> {
        // Detect format from file extension
        if fileName.lowercased().hasSuffix(".pdf") {
            return parsePDF(data: data, fileName: fileName, issuer: issuer)
        } else {
            return parseCSV(data: data, fileName: fileName, issuer: issuer)
        }
    }
    
    // MARK: - Legacy Parse Function (from URL) - kept for backwards compatibility
    
    static func parseStatement(from url: URL, issuer: String) -> Result<ParsedStatement, ParsingError> {
        do {
            let data = try Data(contentsOf: url)
            let fileName = url.lastPathComponent
            return parseStatement(from: data, fileName: fileName, issuer: issuer)
        } catch {
            return .failure(.fileReadError(error.localizedDescription))
        }
    }
    
    // MARK: - CSV Parsing
    
    private static func parseCSV(data: Data, fileName: String, issuer: String) -> Result<ParsedStatement, ParsingError> {
        guard let csvString = String(data: data, encoding: .utf8) else {
            print("❌ Could not decode CSV data as UTF8")
            return .failure(.invalidEncoding)
        }
        
        let lines = csvString.components(separatedBy: .newlines).filter { !$0.isEmpty }
        print("📊 CSV Parser - Issuer: \(issuer), Lines: \(lines.count)")
        
        switch issuer.lowercased() {
        case "amex", "american express":
            print("   Using Amex parser...")
            return parseAmexCSV(lines: lines, fileName: fileName)
        case "chase":
            print("   Using Chase parser...")
            return parseChaseCSV(lines: lines, fileName: fileName)
        case "discover":
            print("   Using Discover parser...")
            return parseDiscoverCSV(lines: lines, fileName: fileName)
        case "capital one":
            print("   Using Capital One parser...")
            return parseCapitalOneCSV(lines: lines, fileName: fileName)
        case "citi", "citibank":
            print("   Using Citi parser...")
            return parseCitiCSV(lines: lines, fileName: fileName)
        default:
            print("   Using generic parser...")
            return parseGenericCSV(lines: lines, fileName: fileName, issuer: issuer)
        }
    }
    
    // MARK: - Amex Parser
    
    private static func parseAmexCSV(lines: [String], fileName: String) -> Result<ParsedStatement, ParsingError> {
        var rows: [StatementRow] = []
        
        print("   🔍 Amex Parser: Checking \(lines.count) lines")
        if lines.count > 0 {
            print("      Header (line 0): \(lines[0])")
        }
        
        // Amex format: Date, Reference, Amount, Description
        for (index, line) in lines.enumerated() {
            if index == 0 { continue } // Skip header
            if line.trimmingCharacters(in: .whitespaces).isEmpty { continue } // Skip empty lines
            
            let components = parseCSVLine(line)
            
            if index == 1 && components.count < 4 {
                print("      Sample data row (line 1): \(line)")
                print("      Parsed components (\(components.count)): \(components)")
            }
            
            guard components.count >= 4 else { continue }
            
            let dateStr = components[0].trimmingCharacters(in: .whitespaces)
            let amountStr = components[2].trimmingCharacters(in: CharacterSet(charactersIn: "$, "))
            let descStr = components[3].trimmingCharacters(in: CharacterSet(charactersIn: "\" "))
            
            guard !dateStr.isEmpty, !amountStr.isEmpty else { continue }
            guard let amount = Double(amountStr) else { continue }
            guard let date = parseDate(dateStr) else { continue }
            
            let category = CategoryDetector.detect(merchant: descStr, issuer: "amex")
            
            let row = StatementRow(
                transactionDate: date,
                category: category,
                amount: abs(amount),
                transactionDescription: descStr
            )
            rows.append(row)
        }
        
        print("      ✅ Parsed \(rows.count) transactions")
        return .success(ParsedStatement(fileName: fileName, issuer: "American Express", rows: rows))
    }
    
    // MARK: - Chase Parser
    
    private static func parseChaseCSV(lines: [String], fileName: String) -> Result<ParsedStatement, ParsingError> {
        var rows: [StatementRow] = []
        
        // Chase format: Transaction Date, Post Date, Merchant Name, Category, Type, Amount
        for (index, line) in lines.enumerated() {
            if index == 0 { continue } // Skip header
            if line.trimmingCharacters(in: .whitespaces).isEmpty { continue }
            
            let components = parseCSVLine(line)
            guard components.count >= 6 else { continue }
            
            let dateStr = components[0].trimmingCharacters(in: .whitespaces)
            let merchantStr = components[2].trimmingCharacters(in: CharacterSet(charactersIn: "\" "))
            let amountStr = components[5].trimmingCharacters(in: CharacterSet(charactersIn: "$, "))
            
            guard !dateStr.isEmpty, !amountStr.isEmpty else { continue }
            guard let amount = Double(amountStr) else { continue }
            guard let date = parseDate(dateStr) else { continue }
            
            let category = CategoryDetector.detect(merchant: merchantStr, issuer: "chase")
            
            let row = StatementRow(
                transactionDate: date,
                category: category,
                amount: abs(amount),
                transactionDescription: merchantStr
            )
            rows.append(row)
        }
        
        return .success(ParsedStatement(fileName: fileName, issuer: "Chase", rows: rows))
    }
    
    // MARK: - Discover Parser
    
    private static func parseDiscoverCSV(lines: [String], fileName: String) -> Result<ParsedStatement, ParsingError> {
        var rows: [StatementRow] = []
        
        // Discover format: Trans. Date, Post Date, Merchant Name, Category, Amount
        for (index, line) in lines.enumerated() {
            if index == 0 { continue } // Skip header
            if line.trimmingCharacters(in: .whitespaces).isEmpty { continue }
            
            let components = parseCSVLine(line)
            guard components.count >= 5 else { continue }
            
            let dateStr = components[0].trimmingCharacters(in: .whitespaces)
            let merchantStr = components[2].trimmingCharacters(in: CharacterSet(charactersIn: "\" "))
            let amountStr = components[4].trimmingCharacters(in: CharacterSet(charactersIn: "$, "))
            
            guard !dateStr.isEmpty, !amountStr.isEmpty else { continue }
            guard let amount = Double(amountStr) else { continue }
            guard let date = parseDate(dateStr) else { continue }
            
            let category = CategoryDetector.detect(merchant: merchantStr, issuer: "discover")
            
            let row = StatementRow(
                transactionDate: date,
                category: category,
                amount: abs(amount),
                transactionDescription: merchantStr
            )
            rows.append(row)
        }
        
        return .success(ParsedStatement(fileName: fileName, issuer: "Discover", rows: rows))
    }
    
    // MARK: - Capital One Parser
    
    private static func parseCapitalOneCSV(lines: [String], fileName: String) -> Result<ParsedStatement, ParsingError> {
        var rows: [StatementRow] = []
        
        // Capital One format: Transaction Date, Posted Date, Merchant, Category, Amount
        for (index, line) in lines.enumerated() {
            if index == 0 { continue } // Skip header
            if line.trimmingCharacters(in: .whitespaces).isEmpty { continue }
            
            let components = parseCSVLine(line)
            guard components.count >= 5 else { continue }
            
            let dateStr = components[0].trimmingCharacters(in: .whitespaces)
            let merchantStr = components[2].trimmingCharacters(in: CharacterSet(charactersIn: "\" "))
            let amountStr = components[4].trimmingCharacters(in: CharacterSet(charactersIn: "$,- "))
            
            guard !dateStr.isEmpty, !amountStr.isEmpty else { continue }
            guard let amount = Double(amountStr) else { continue }
            guard let date = parseDate(dateStr) else { continue }
            
            let category = CategoryDetector.detect(merchant: merchantStr, issuer: "capital one")
            
            let row = StatementRow(
                transactionDate: date,
                category: category,
                amount: abs(amount),
                transactionDescription: merchantStr
            )
            rows.append(row)
        }
        
        return .success(ParsedStatement(fileName: fileName, issuer: "Capital One", rows: rows))
    }
    
    // MARK: - Citi Parser
    
    private static func parseCitiCSV(lines: [String], fileName: String) -> Result<ParsedStatement, ParsingError> {
        var rows: [StatementRow] = []
        
        // Citi format: Transaction Date, Posted Date, Description, Debit, Credit
        for (index, line) in lines.enumerated() {
            if index == 0 { continue } // Skip header
            if line.trimmingCharacters(in: .whitespaces).isEmpty { continue }
            
            let components = parseCSVLine(line)
            guard components.count >= 5 else { continue }
            
            let dateStr = components[0].trimmingCharacters(in: .whitespaces)
            let descStr = components[2].trimmingCharacters(in: CharacterSet(charactersIn: "\" "))
            let debitStr = components[3].trimmingCharacters(in: CharacterSet(charactersIn: "$, "))
            let creditStr = components[4].trimmingCharacters(in: CharacterSet(charactersIn: "$, "))
            
            guard !dateStr.isEmpty, !descStr.isEmpty else { continue }
            
            // Try debit first, then credit
            var amount: Double? = nil
            if !debitStr.isEmpty {
                amount = Double(debitStr)
            } else if !creditStr.isEmpty {
                amount = Double(creditStr)
            }
            
            guard let amountValue = amount else { continue }
            guard let date = parseDate(dateStr) else { continue }
            
            let category = CategoryDetector.detect(merchant: descStr, issuer: "citi")
            
            let row = StatementRow(
                transactionDate: date,
                category: category,
                amount: abs(amountValue),
                transactionDescription: descStr
            )
            rows.append(row)
        }
        
        return .success(ParsedStatement(fileName: fileName, issuer: "Citi", rows: rows))
    }
    
    // MARK: - Generic CSV Parser
    
    private static func parseGenericCSV(lines: [String], fileName: String, issuer: String) -> Result<ParsedStatement, ParsingError> {
        var rows: [StatementRow] = []
        
        // Try to auto-detect columns
        for (index, line) in lines.enumerated() {
            if index == 0 { continue } // Skip header
            
            let components = parseCSVLine(line)
            guard components.count >= 3 else { continue }
            
            // Assume: first column is date, last column is amount, middle is description
            guard let date = parseDate(components[0]) else { continue }
            guard let amount = Double(components.last?.trimmingCharacters(in: CharacterSet(charactersIn: "$,-")) ?? "") else { continue }
            
            let description = components.dropFirst().dropLast().joined(separator: " ")
            let category = CategoryDetector.detect(merchant: description, issuer: issuer)
            
            let row = StatementRow(
                transactionDate: date,
                category: category,
                amount: abs(amount),
                transactionDescription: description
            )
            rows.append(row)
        }
        
        return .success(ParsedStatement(fileName: fileName, issuer: issuer, rows: rows))
    }
    
    // MARK: - PDF Parsing
    
    private static func parsePDF(data: Data, fileName: String, issuer: String) -> Result<ParsedStatement, ParsingError> {
        guard let pdfDocument = PDFDocument(data: data) else {
            print("❌ Failed to create PDF document from data")
            return .failure(.invalidPDF)
        }
        
        print("📄 Parsing PDF: \(fileName)")
        print("   Pages: \(pdfDocument.pageCount)")
        
        var fullText = ""
        for i in 0..<pdfDocument.pageCount {
            if let page = pdfDocument.page(at: i) {
                fullText += page.string ?? ""
            }
        }
        
        print("   Extracted text length: \(fullText.count) characters")
        
        // If text extraction failed, return error
        if fullText.trimmingCharacters(in: .whitespaces).isEmpty {
            print("   ⚠️  PDF text extraction returned empty")
            return .failure(.fileReadError("Could not extract text from PDF - it may be image-based or encrypted"))
        }
        
        // Parse based on issuer
        switch issuer.lowercased() {
        case "amex", "american express":
            print("   Using Amex PDF parser...")
            return parseAmexPDF(text: fullText, fileName: fileName)
        case "chase":
            print("   Using Chase PDF parser...")
            return parseChaseOrDiscoverPDF(text: fullText, fileName: fileName, issuer: "Chase")
        case "discover":
            print("   Using Discover PDF parser...")
            return parseDiscoverPDF(text: fullText, fileName: fileName)
        case "capital one":
            print("   Using Capital One PDF parser...")
            return parseCapitalOnePDF(text: fullText, fileName: fileName)
        case "citi", "citibank":
            print("   Using Citi PDF parser...")
            return parsecitiPDF(text: fullText, fileName: fileName)
        default:
            print("   Using generic PDF parser...")
            return parseGenericPDF(text: fullText, fileName: fileName, issuer: issuer)
        }
    }
    
    // MARK: - Amex PDF Parser
    
    private static func parseAmexPDF(text: String, fileName: String) -> Result<ParsedStatement, ParsingError> {
        var rows: [StatementRow] = []
        let lines = text.components(separatedBy: .newlines)
        
        print("   🔍 Amex PDF: Looking for transactions in \(lines.count) lines...")
        
        var inTransactionSection = false
        var currentDate: Date? = nil
        var currentMerchant = ""
        var linesSinceDate = 0
        
        // DEBUG: Show lines around potential section headers
        for (index, line) in lines.enumerated() {
            let lower = line.lowercased()
            if lower.contains("detail") || lower.contains("transactions") || lower.contains("statement") {
                print("      [Line \(index)]: \(line.prefix(100))")
            }
        }
        
        let datePattern = "^(0?[1-9]|1[0-2])/(0?[1-9]|[12][0-9]|3[01])/\\d{2,4}"
        let dateRegex = try? NSRegularExpression(pattern: datePattern)
        
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Skip empty lines
            if trimmed.isEmpty { continue }
            
            // Look for the NEW CHARGES transaction section header
            // Support multiple formats:
            // 1. "DETAIL ⧫ CASH ADVANCE" (standard Amex)
            // 2. Just "DETAIL" with diamond symbol somewhere on line
            // 3. "TRANSACTIONS" (for Aspire/other variants)
            let lowerTrimmed = trimmed.lowercased()
            let hasDetailMarker = lowerTrimmed.contains("detail") && trimmed.contains("⧫")
            let hasTransactionMarker = lowerTrimmed.contains("transactions")
            
            if hasDetailMarker || (hasTransactionMarker && lowerTrimmed.contains("charge")) {
                inTransactionSection = true
                print("      📍 Found transaction section (header) at line \(index): \(trimmed)")
                continue
            }
            
            // Fallback: if we haven't found a section header yet, and we're past line 50 (past any preamble),
            // and we find a date line, that's likely the start of transactions
            if !inTransactionSection && index > 50 && !lowerTrimmed.contains("name") && !lowerTrimmed.contains("address") {
                if let regex = dateRegex {
                    let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
                    if regex.firstMatch(in: trimmed, range: range) != nil {
                        inTransactionSection = true
                        print("      📍 Found transaction section (date fallback) at line \(index): \(trimmed.prefix(80))")
                        // Don't continue - process this line as a date
                    }
                }
            }
            
            // Stop at section end markers
            if inTransactionSection && (trimmed.lowercased().contains("continued on next page") ||
                                       trimmed.lowercased().contains("continued on reverse") ||
                                       trimmed.lowercased().contains("fees charged") ||
                                       trimmed.lowercased().contains("interest charged") ||
                                       trimmed.lowercased().contains("trailing interest") ||
                                       trimmed.lowercased().contains("total charges") ||
                                       (trimmed.lowercased().contains("total") && trimmed.contains("$"))) {
                inTransactionSection = false
                print("      🛑 Reached end of transactions at line \(index): \(trimmed)")
                continue
            }
            
            if !inTransactionSection { continue }
            
            // Skip header lines and metadata
            if trimmed.lowercased().contains("summary") ||
               trimmed.lowercased().contains("jacob t michalik") ||
               trimmed.lowercased().contains("card ending") ||
               (trimmed.lowercased().contains("amount") && !trimmed.contains("$")) ||
               (trimmed.contains("⧫") && !trimmed.contains("$")) {
                continue
            }
            
            // Check if line starts with a date (MM/DD/YY or MM/DD/YYYY format)
            if let regex = dateRegex {
                let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
                if regex.firstMatch(in: trimmed, range: range) != nil {
                    // Save previous transaction if exists
                    if let date = currentDate, !currentMerchant.isEmpty {
                        print("      ⚠️  Transaction without amount: \(currentMerchant)")
                    }
                    
                    // Extract date and merchant from this line
                    let components = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true).map(String.init)
                    if components.count >= 1, let date = parseDate(components[0]) {
                        currentDate = date
                        currentMerchant = components.count > 1 ? components[1] : ""
                        linesSinceDate = 0
                        print("      📅 Found date: \(components[0]) | Merchant: \(currentMerchant)")
                    }
                    continue
                }
            }
            
            // If we have a date and this line contains $ (with or without diamond), it's the amount
            if let date = currentDate, trimmed.contains("$") {
                if let amount = parseAmount(trimmed) {
                    let category = CategoryDetector.detect(merchant: currentMerchant, issuer: "amex")
                    let row = StatementRow(
                        transactionDate: date,
                        category: category,
                        amount: amount,
                        transactionDescription: currentMerchant
                    )
                    rows.append(row)
                    print("      ✓ Parsed: \(trimmed) | \(currentMerchant) | $\(amount)")
                    currentDate = nil
                    currentMerchant = ""
                }
                continue
            }
            
            // Otherwise, if we have a date and no merchant yet, this is additional merchant info
            if currentDate != nil && currentMerchant.isEmpty && linesSinceDate < 2 {
                currentMerchant = trimmed
                linesSinceDate += 1
                print("      🏪 Found merchant (line \(linesSinceDate)): \(trimmed)")
                continue
            }
            
            // If we have a date and merchant, but this isn't the amount yet, append to merchant
            if currentDate != nil && !currentMerchant.isEmpty && !trimmed.contains("$") && linesSinceDate < 2 {
                currentMerchant += " " + trimmed
                linesSinceDate += 1
                print("      🏪 Appended to merchant: \(currentMerchant)")
            }
        }
        
        print("      ✅ Found \(rows.count) transactions")
        return .success(ParsedStatement(fileName: fileName, issuer: "American Express", rows: rows))
    }
    
    
    // MARK: - Capital One PDF Parser
    
    private static func parseCapitalOnePDF(text: String, fileName: String) -> Result<ParsedStatement, ParsingError> {
        var rows: [StatementRow] = []
        let lines = text.components(separatedBy: .newlines)
        
        print("   🔍 Capital One PDF: Looking for transactions in \(lines.count) lines...")
        
        var inTransactionSection = false
        // Capital One uses: "Mar 18 Mar 20 Description $10.00" format
        let datePattern = #"^(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+\d{1,2}\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+\d{1,2}\s+"#
        
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Skip empty lines
            if trimmed.isEmpty { continue }
            
            // Look for the "Transactions" section marker
            if trimmed.lowercased().contains("transactions") && trimmed.lowercased().contains("#") {
                inTransactionSection = true
                print("      📍 Found transaction section at line \(index)")
                continue
            }
            
            // Stop at section end markers
            if inTransactionSection && (trimmed.lowercased().contains("total transactions") ||
                                       trimmed.lowercased().contains("fees") ||
                                       trimmed.lowercased().contains("interest charged")) {
                inTransactionSection = false
                print("      🛑 Reached end of transactions at line \(index)")
                continue
            }
            
            if !inTransactionSection { continue }
            
            // Check if line starts with Capital One date pattern (Mon DD Mon DD)
            if let regex = try? NSRegularExpression(pattern: datePattern, options: .caseInsensitive) {
                let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
                if regex.firstMatch(in: trimmed, range: range) != nil {
                    // Parse the transaction line
                    // Format: Trans Date Post Date Description Amount
                    // Example: Mar 18 Mar 20 HCTRA EZ TAG REBILL281-875-3279TX $10.00
                    
                    // Split by spaces to find the amount (last $ amount)
                    let components = trimmed.split(separator: " ").map(String.init)
                    
                    // Find the amount (last component starting with $)
                    guard let amountIndex = components.lastIndex(where: { $0.starts(with: "$") }) else { continue }
                    let amountStr = components[amountIndex]
                    
                    // First two components are Trans Date (Mon DD)
                    // Third component is Post Month, Fourth is Post Day
                    // So we take components[0] + " " + components[1] as transaction date
                    let currentYear = Calendar.current.component(.year, from: Date())
                    let dateStr = "\(components[0]) \(components[1]) \(currentYear)"
                    guard let transDate = parseDate(dateStr) else { continue }
                    guard let amount = parseAmount(String(amountStr)) else { continue }
                    
                    // Description is everything between post date (position 2-3) and amount
                    // Skip Trans Date (0), Trans Day (1), Post Month (2), Post Day (3)
                    let descriptionParts = components.dropFirst(4).dropLast()
                    let description = descriptionParts.joined(separator: " ")
                    
                    guard !description.isEmpty else { continue }
                    
                    let category = CategoryDetector.detect(merchant: description, issuer: "capital one")
                    let row = StatementRow(
                        transactionDate: transDate,
                        category: category,
                        amount: amount,
                        transactionDescription: description
                    )
                    rows.append(row)
                    print("      ✓ Parsed: \(dateStr) | \(description) | $\(amount)")
                }
            }
        }
        
        print("      ✅ Found \(rows.count) transactions")
        return .success(ParsedStatement(fileName: fileName, issuer: "Capital One", rows: rows))
    }
    
    
    // MARK: - Discover PDF Parser
    
    private static func parseDiscoverPDF(text: String, fileName: String) -> Result<ParsedStatement, ParsingError> {
        var rows: [StatementRow] = []
        let lines = text.components(separatedBy: .newlines)
        
        print("   🔍 Discover PDF: Looking for transactions in \(lines.count) lines...")
        
        var inTransactionSection = false
        let datePattern = #"^(0?[1-9]|1[0-2])/(0?[1-9]|[12][0-9]|3[01])\s+"#
        
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Skip empty lines
            if trimmed.isEmpty { continue }
            
            // Look for the "Transactions" section marker
            if trimmed.uppercased().contains("TRANS.") && trimmed.uppercased().contains("PURCHASES") && trimmed.uppercased().contains("AMOUNT") {
                inTransactionSection = true
                print("      📍 Found transaction section at line \(index)")
                continue
            }
            
            // Stop at section end markers
            if inTransactionSection && (trimmed.uppercased().contains("REWARDS") ||
                                       trimmed.uppercased().contains("FEES AND INTEREST") ||
                                       trimmed.lowercased().contains("total fees")) {
                inTransactionSection = false
                print("      🛑 Reached end of transactions at line \(index)")
                continue
            }
            
            if !inTransactionSection { continue }
            
            // Skip header lines
            if trimmed.uppercased().contains("TRANS.") ||
               trimmed.uppercased().contains("PURCHASES") ||
               trimmed.uppercased().contains("MERCHANT") ||
               trimmed.uppercased().contains("CATEGORY") ||
               trimmed.uppercased().contains("AMOUNT") {
                continue
            }
            
            // Check if line starts with a date pattern (MM/DD)
            if let regex = try? NSRegularExpression(pattern: datePattern) {
                let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
                if regex.firstMatch(in: trimmed, range: range) != nil {
                    // Parse the transaction line
                    // Format: Trans Date Merchant Info Category Amount
                    // Example: 07/23 PAYPAL *NINTENDO 888-221-1161 CA Merchandise $4.32
                    
                    // Extract the date at the beginning
                    let dateEndIndex = trimmed.firstIndex(where: { $0 == " " }) ?? trimmed.endIndex
                    let dateStr = String(trimmed[..<dateEndIndex])
                    
                    // Get the rest of the line after the date
                    let remainder = String(trimmed[dateEndIndex...]).trimmingCharacters(in: .whitespaces)
                    
                    // Split by space to find the amount (last component starting with $)
                    let components = remainder.split(separator: " ").map(String.init)
                    
                    // Find the amount (last component starting with $)
                    guard let amountIndex = components.lastIndex(where: { $0.starts(with: "$") }) else { continue }
                    let amountStr = components[amountIndex]
                    
                    // Parse the date - add year
                    let currentYear = Calendar.current.component(.year, from: Date())
                    let dateWithYear = "\(dateStr)/\(currentYear)"
                    
                    guard let transDate = parseDate(dateWithYear) else { continue }
                    guard let amount = parseAmount(String(amountStr)) else { continue }
                    
                    // Description is everything between date and amount
                    let descriptionParts = components.dropLast()
                    let description = descriptionParts.joined(separator: " ")
                    
                    guard !description.isEmpty else { continue }
                    
                    let category = CategoryDetector.detect(merchant: description, issuer: "discover")
                    let row = StatementRow(
                        transactionDate: transDate,
                        category: category,
                        amount: amount,
                        transactionDescription: description
                    )
                    rows.append(row)
                    print("      ✓ Parsed: \(dateStr) | \(description) | $\(amount)")
                }
            }
        }
        
        print("      ✅ Found \(rows.count) transactions")
        return .success(ParsedStatement(fileName: fileName, issuer: "Discover", rows: rows))
    }
    
    // MARK: - Chase/Discover PDF Parser
    
    private static func parseChaseOrDiscoverPDF(text: String, fileName: String, issuer: String) -> Result<ParsedStatement, ParsingError> {
        var rows: [StatementRow] = []
        let lines = text.components(separatedBy: .newlines)
        
        print("   🔍 \(issuer) PDF: Looking for transactions in \(lines.count) lines...")
        
        var inTransactionSection = false
        let datePattern = #"^(0?[1-9]|1[0-2])/(0?[1-9]|[12][0-9]|3[01])\s+"#
        
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Skip empty lines
            if trimmed.isEmpty { continue }
            
            // Look for the "ACCOUNT ACTIVITY" section marker (Chase) or transaction table header
            if trimmed.uppercased().contains("ACCOUNT ACTIVITY") ||
               (trimmed.lowercased().contains("date") && trimmed.lowercased().contains("merchant") && trimmed.lowercased().contains("amount")) {
                inTransactionSection = true
                print("      📍 Found transaction section at line \(index)")
                continue
            }
            
            // Stop at section end markers
            if inTransactionSection && (trimmed.uppercased().contains("INTEREST CHARGES") ||
                                       trimmed.uppercased().contains("PAGE") ||
                                       trimmed.uppercased().contains("TOTALS YEAR-TO-DATE")) {
                inTransactionSection = false
                print("      🛑 Reached end of transactions at line \(index)")
                continue
            }
            
            if !inTransactionSection { continue }
            
            // Skip header lines
            if trimmed.lowercased().contains("date of") ||
               trimmed.lowercased().contains("transaction") ||
               trimmed.lowercased().contains("merchant name") ||
               trimmed.contains("$") && trimmed.contains("Amount") {
                continue
            }
            
            // Check if line starts with a date pattern (MM/DD)
            if let regex = try? NSRegularExpression(pattern: datePattern) {
                let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
                if regex.firstMatch(in: trimmed, range: range) != nil {
                    // Extract the date at the beginning
                    let dateEndIndex = trimmed.firstIndex(where: { $0 == " " }) ?? trimmed.endIndex
                    let dateStr = String(trimmed[..<dateEndIndex])
                    
                    // Get the rest of the line after the date
                    let remainder = String(trimmed[dateEndIndex...]).trimmingCharacters(in: .whitespaces)
                    
                    // Split by space to find the amount (last component starting with $ or -)
                    let components = remainder.split(separator: " ").map(String.init)
                    
                    // Find the amount (last component that looks like a number with $ or -)
                    guard let amountIndex = components.lastIndex(where: {
                        $0.starts(with: "$") || $0.starts(with: "-") || Double($0) != nil
                    }) else { continue }
                    
                    let amountStr = components[amountIndex]
                    
                    // Parse the date - add year
                    let currentYear = Calendar.current.component(.year, from: Date())
                    let dateWithYear = "\(dateStr)/\(currentYear)"
                    
                    guard let transDate = parseDate(dateWithYear) else { continue }
                    guard let amount = parseAmount(String(amountStr)) else { continue }
                    
                    // Skip payments and credits (they start with - or contain PAYMENT/CREDIT)
                    if amountStr.starts(with: "-") || remainder.uppercased().contains("PAYMENT") || remainder.uppercased().contains("CREDIT") {
                        print("      ⊘ Skipped payment/credit: \(remainder)")
                        continue
                    }
                    
                    // Description is everything between date and amount
                    let descriptionParts = components.dropLast()
                    let description = descriptionParts.joined(separator: " ")
                    
                    guard !description.isEmpty else { continue }
                    
                    let category = CategoryDetector.detect(merchant: description, issuer: issuer.lowercased())
                    let row = StatementRow(
                        transactionDate: transDate,
                        category: category,
                        amount: abs(amount),
                        transactionDescription: description
                    )
                    rows.append(row)
                    print("      ✓ Parsed: \(dateStr) | \(description) | $\(abs(amount))")
                }
            }
        }
        
        print("      ✅ Found \(rows.count) transactions")
        return .success(ParsedStatement(fileName: fileName, issuer: issuer, rows: rows))
    }
    
    
    // MARK: - Citi PDF Parser
    
    private static func parsecitiPDF(text: String, fileName: String) -> Result<ParsedStatement, ParsingError> {
        var rows: [StatementRow] = []
        let lines = text.components(separatedBy: .newlines)
        
        print("   🔍 Citi PDF: Looking for transactions in \(lines.count) lines...")
        
        var inTransactionSection = false
        let datePattern = #"^(0?[1-9]|1[0-2])/(0?[1-9]|[12][0-9]|3[01])\s+(0?[1-9]|1[0-2])/(0?[1-9]|[12][0-9]|3[01])\s+"#
        
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Skip empty lines
            if trimmed.isEmpty { continue }
            
            // Look for the "Standard Purchases" section marker
            if trimmed.lowercased().contains("standard purchases") {
                inTransactionSection = true
                print("      📍 Found transaction section at line \(index)")
                continue
            }
            
            // Stop at section end markers
            if inTransactionSection && (trimmed.lowercased().contains("fees charged") ||
                                       trimmed.lowercased().contains("interest charged") ||
                                       trimmed.lowercased().contains("total fees") ||
                                       trimmed.lowercased().contains("account messages")) {
                inTransactionSection = false
                print("      🛑 Reached end of transactions at line \(index)")
                continue
            }
            
            if !inTransactionSection { continue }
            
            // Skip header lines
            if trimmed.lowercased().contains("trans.") ||
               trimmed.lowercased().contains("post") ||
               trimmed.lowercased().contains("description") ||
               trimmed.lowercased().contains("amount") ||
               trimmed.lowercased().contains("payments, credits") ||
               trimmed.lowercased().contains("autopay") ||
               trimmed.uppercased().contains("AUTOPAY") {
                continue
            }
            
            // Skip payments (they contain AUTOPAY or start with -)
            if trimmed.uppercased().contains("AUTOPAY") || trimmed.starts(with: "-") {
                print("      ⊘ Skipped payment: \(trimmed)")
                continue
            }
            
            // Check if line starts with a date pattern (MM/DD MM/DD)
            if let regex = try? NSRegularExpression(pattern: datePattern) {
                let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
                if regex.firstMatch(in: trimmed, range: range) != nil {
                    // Parse the transaction line
                    // Format: Trans Date Post Date Description Amount
                    // Example: 03/29 03/29 SIGNATURE LAMAR AUSTIN TX $42.89
                    
                    let components = trimmed.split(separator: " ").map(String.init)
                    
                    print("      🔍 Citi line components (\(components.count)): \(components)")
                    
                    // Find the amount (last component starting with $)
                    guard let amountIndex = components.lastIndex(where: { $0.starts(with: "$") }) else {
                        print("      ⚠️  No $ amount found in components")
                        continue
                    }
                    let amountStr = components[amountIndex]
                    
                    // The first component should be the transaction date
                    // Add current year since Citi PDFs don't include the year
                    let currentYear = Calendar.current.component(.year, from: Date())
                    let dateWithYear = "\(components[0])/\(currentYear)"
                    
                    guard let transDate = parseDate(dateWithYear) else {
                        print("      ⚠️  Could not parse date: \(dateWithYear)")
                        continue
                    }
                    guard let amount = parseAmount(String(amountStr)) else {
                        print("      ⚠️  Could not parse amount: \(amountStr)")
                        continue
                    }
                    
                    // Description is everything between post date and amount
                    // We need to skip Trans Date and Post Date (first 2 components), then take everything until amount
                    let descriptionParts = components.dropFirst(2).dropLast()
                    let description = descriptionParts.joined(separator: " ")
                    
                    guard !description.isEmpty else {
                        print("      ⚠️  Empty description")
                        continue
                    }
                    
                    let category = CategoryDetector.detect(merchant: description, issuer: "citi")
                    let row = StatementRow(
                        transactionDate: transDate,
                        category: category,
                        amount: amount,
                        transactionDescription: description
                    )
                    rows.append(row)
                    print("      ✓ Parsed: \(components[0]) | \(description) | $\(amount)")
                }
            }
        }
        
        print("      ✅ Found \(rows.count) transactions")
        return .success(ParsedStatement(fileName: fileName, issuer: "Citi", rows: rows))
    }
    
    // MARK: - Generic PDF Parser
    
    private static func parseGenericPDF(text: String, fileName: String, issuer: String) -> Result<ParsedStatement, ParsingError> {
        // Fall back to treating extracted text as CSV-like lines
        let lines = text.components(separatedBy: .newlines)
        return parseGenericCSV(lines: lines, fileName: fileName, issuer: issuer)
    }
    
    // MARK: - Helper Functions
    
    private static func parseCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var currentField = ""
        var inQuotes = false
        
        for char in line {
            if char == "\"" {
                inQuotes = !inQuotes
            } else if char == "," && !inQuotes {
                result.append(currentField)
                currentField = ""
            } else {
                currentField.append(char)
            }
        }
        
        result.append(currentField)
        return result
    }
    
    private static func parseDate(_ dateString: String) -> Date? {
        let formatters = [
            "MM/dd/yyyy",
            "M/d/yyyy",
            "yyyy-MM-dd",
            "dd/MM/yyyy",
            "d/M/yyyy",
            "MMM d, yyyy",
            "MMM d yyyy",
            "MM/dd",           // Date without year (defaults to current year)
            "M/d",             // Date without year (defaults to current year)
            "MMM d",           // Month and day without year
            "MMM dd"           // Month and day without year
        ]
        
        let trimmed = dateString.trimmingCharacters(in: .whitespaces)
        
        for format in formatters {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US_POSIX")
            
            if let date = formatter.date(from: trimmed) {
                // If the format doesn't include a year, add the current year
                if !format.contains("yyyy") && !format.contains("yy") {
                    // The formatter will use a default year (usually 2000), so we need to adjust
                    var dateComponents = Calendar.current.dateComponents([.month, .day], from: date)
                    let currentYear = Calendar.current.component(.year, from: Date())
                    dateComponents.year = currentYear
                    if let adjustedDate = Calendar.current.date(from: dateComponents) {
                        return adjustedDate
                    }
                }
                return date
            }
        }
        
        return nil
    }
    
    private static func parseAmount(_ amountString: String) -> Double? {
        let cleaned = amountString
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "⧫", with: "")  // Remove diamond symbol
        
        return Double(cleaned)
    }
}

// MARK: - Category Detector

struct CategoryDetector {
    static func detect(merchant: String, issuer: String) -> String {
        let lowerMerchant = merchant.lowercased()
        
        // Restaurant keywords
        if lowerMerchant.contains(regex: "restaurant|cafe|coffee|bar|grill|bistro|steakhouse|pizza|burger|diner|pub|tavern|brewery|winery|steak|noodle|sushi|seafood|bbq|buffet|food truck|fast food|takeout|delivery|pho|omakase|brunch|breakfast|lunch|dinner|dessert|ice cream|bakery|patisserie|donut|bagel|juice|smoothie|tea|espresso|latte|cappuccino|mocha|kombucha|cocktail|happy hour|tapas|gastropub|food hall") {
            return "Restaurants"
        }
        
        // Supermarket keywords
        if lowerMerchant.contains(regex: "whole foods|trader joe|safeway|kroger|albertson|publix|instacart|amazon fresh|sprouts|wegmans|winco|harris teeter|ralphs|smith|H-E-B|giant|food lion|meijer|stop & shop|grocery|supermarket") {
            return "Supermarkets"
        }
        
        // Flight keywords
        if lowerMerchant.contains(regex: "united|american|delta|southwest|frontier|alaska|spirit|jetblue|flight|airline|kayak|expedia|orbitz|skyscanner|farecompare|travelocity|aeromexico|lufthansa|air france|british airways|emirates|qatar|singapore airlines|virgin atlantic") {
            return "Flights"
        }
        
        // Hotel keywords
        if lowerMerchant.contains(regex: "hilton|marriott|hyatt|four seasons|ritz|intercontinental|radisson|wyndham|best western|ihg|choice|starwood|caesars|mgm|hotel|resort|inn") {
            return "Hotels"
        }
        
        // Travel-related (flights + hotels combined)
        if lowerMerchant.contains(regex: "travel|booking|airbnb|vrbo|hostel|motel") {
            return "Hotels"
        }
        
        // Default
        return "Other"
    }
}

// MARK: - String Extension for Regex

extension String {
    func contains(regex pattern: String) -> Bool {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            let range = NSRange(self.startIndex..<self.endIndex, in: self)
            return regex.firstMatch(in: self, options: [], range: range) != nil
        } catch {
            return false
        }
    }
}

// MARK: - Parsing Error

enum ParsingError: LocalizedError {
    case fileReadError(String)
    case invalidEncoding
    case invalidPDF
    case noTransactionsFound
    
    var errorDescription: String? {
        switch self {
        case .fileReadError(let message):
            return "Could not read file: \(message)"
        case .invalidEncoding:
            return "File encoding is not supported"
        case .invalidPDF:
            return "Could not parse PDF file"
        case .noTransactionsFound:
            return "No transactions found in statement"
        }
    }
}
