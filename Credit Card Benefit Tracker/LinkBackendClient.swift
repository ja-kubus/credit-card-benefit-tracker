//
//  LinkBackendClient.swift
//  Credit Card Benefit Tracker
//
//  Talks to YOUR backend, which holds the Stripe secret key and performs all
//  sensitive operations. This app only ever holds a backend SESSION token
//  (stored in the Keychain) — never a Stripe secret, never bank credentials.
//

import Foundation
import Security

// MARK: - Models

struct LinkedAccount: Codable, Identifiable, Hashable {
    var id: String            // Stripe Financial Connections account id (fca_...)
    var name: String          // display name (from `displayName`)
    var institution: String
    var lastFour: String      // from `last4`
    var category: String      // e.g. "credit"
    var subcategory: String   // e.g. "credit_card"

    enum CodingKeys: String, CodingKey {
        case id
        case name = "displayName"
        case institution
        case lastFour = "last4"
        case category
        case subcategory
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        institution = (try? c.decode(String.self, forKey: .institution)) ?? ""
        lastFour = (try? c.decode(String.self, forKey: .lastFour)) ?? ""
        category = (try? c.decode(String.self, forKey: .category)) ?? ""
        subcategory = (try? c.decode(String.self, forKey: .subcategory)) ?? ""
    }
}

struct RemoteTransaction: Codable, Identifiable, Hashable {
    var id: String
    var accountId: String
    var accountName: String
    var date: Date
    var description: String
    var amount: Double
    var status: String
    var category: String

    enum CodingKeys: String, CodingKey {
        case id, accountId, accountName, date, description, amount, status, category
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        accountId = try c.decode(String.self, forKey: .accountId)
        accountName = (try? c.decode(String.self, forKey: .accountName)) ?? ""
        description = (try? c.decode(String.self, forKey: .description)) ?? ""
        status = (try? c.decode(String.self, forKey: .status)) ?? ""
        category = (try? c.decode(String.self, forKey: .category)) ?? ""

        // amount may arrive as a Double or a String like "12.34"
        if let d = try? c.decode(Double.self, forKey: .amount) {
            amount = d
        } else if let s = try? c.decode(String.self, forKey: .amount), let d = Double(s) {
            amount = d
        } else {
            amount = 0
        }

        // date arrives as "YYYY-MM-DD"
        let dateString = (try? c.decode(String.self, forKey: .date)) ?? ""
        date = RemoteTransaction.dayFormatter.date(from: dateString) ?? Date()
    }

    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}

// MARK: - Response envelopes (backend wraps payloads in an object)

private struct SessionResponse: Decodable {
    let clientSecret: String
    let sessionId: String
}
private struct AccountsResponse: Decodable { let accounts: [LinkedAccount] }
private struct TransactionsResponse: Decodable { let transactions: [RemoteTransaction] }

// MARK: - Errors

enum LinkBackendError: LocalizedError {
    case notAuthenticated
    case badResponse(status: Int)
    case missingToken
    case missingField

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "You are not signed in."
        case .badResponse(let status): return "Server error (HTTP \(status))."
        case .missingToken: return "Could not read the sign-in token."
        case .missingField: return "The server returned an unexpected response."
        }
    }
}

// MARK: - Keychain helper

enum KeychainHelper {
    private static let service = "com.creditcardbenefittracker.linking"

    static func set(_ value: String, for key: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        SecItemAdd(add as CFDictionary, nil)
    }

    static func get(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Backend client

actor LinkBackendClient {
    static let shared = LinkBackendClient()

    private let sessionKey = "backend_session_token"
    private let baseURL = StripeLinkConfig.backendBaseURL

    nonisolated var isSignedIn: Bool {
        KeychainHelper.get("backend_session_token") != nil
    }

    // MARK: Auth

    /// POST /auth/apple — exchanges an Apple identity token for a backend session
    /// token, which is stored in the Keychain.
    func authenticateWithApple(identityToken: String) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("auth/apple"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["identityToken": identityToken])

        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response)

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let token = json?["sessionToken"] as? String else {
            throw LinkBackendError.missingToken
        }
        KeychainHelper.set(token, for: sessionKey)
    }

    func signOut() {
        KeychainHelper.delete(sessionKey)
    }

    // MARK: Linking

    /// POST /link/session — asks the backend to create a Stripe Financial
    /// Connections session. Returns the client_secret to hand to the Stripe SDK
    /// and the session id to confirm with afterwards.
    func createLinkSession() async throws -> (clientSecret: String, sessionId: String) {
        let request = try authorizedRequest(path: "link/session", method: "POST", jsonBody: [:])
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response)
        let decoded = try Self.decoder.decode(SessionResponse.self, from: data)
        return (decoded.clientSecret, decoded.sessionId)
    }

    /// POST /link/complete — after the Stripe sheet finishes, tell the backend to
    /// read the linked accounts and subscribe them to transaction refreshes.
    func completeLink(sessionId: String) async throws -> [LinkedAccount] {
        let request = try authorizedRequest(path: "link/complete", method: "POST", jsonBody: ["sessionId": sessionId])
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response)
        return try Self.decoder.decode(AccountsResponse.self, from: data).accounts
    }

    /// GET /accounts — the currently linked accounts.
    func accounts() async throws -> [LinkedAccount] {
        let request = try authorizedRequest(path: "accounts", method: "GET")
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response)
        return try Self.decoder.decode(AccountsResponse.self, from: data).accounts
    }

    /// GET /transactions?since=YYYY-MM-DD
    func transactions(since: Date) async throws -> [RemoteTransaction] {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("transactions"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "since", value: RemoteTransaction.dayFormatter.string(from: since))
        ]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        try attachAuth(&request)

        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response)
        return try Self.decoder.decode(TransactionsResponse.self, from: data).transactions
    }

    /// POST /unlink — disconnect an account by its Stripe FC account id.
    func unlink(accountId: String) async throws {
        let request = try authorizedRequest(path: "unlink", method: "POST", jsonBody: ["accountId": accountId])
        let (_, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response)
    }

    // MARK: Helpers

    private func authorizedRequest(path: String, method: String, jsonBody: [String: Any]? = nil) throws -> URLRequest {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        try attachAuth(&request)
        if let jsonBody {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: jsonBody)
        }
        return request
    }

    private func attachAuth(_ request: inout URLRequest) throws {
        guard let token = KeychainHelper.get(sessionKey) else {
            throw LinkBackendError.notAuthenticated
        }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    private static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            throw LinkBackendError.badResponse(status: http.statusCode)
        }
    }

    private static let decoder = JSONDecoder()
}
