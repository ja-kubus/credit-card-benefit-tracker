//
//  TellerBackendClient.swift
//  Credit Card Benefit Tracker
//
//  Talks to YOUR backend, which holds the Teller access tokens and performs all
//  sensitive operations. This app only ever holds a backend SESSION token
//  (stored in the Keychain), never a Teller access token or bank credentials.
//

import Foundation
import Security

// MARK: - Models

struct LinkedAccount: Codable, Identifiable, Hashable {
    var linkId: String?
    var id: String
    var name: String
    var lastFour: String
    var type: String
    var institution: String
}

struct RemoteTransaction: Codable, Identifiable, Hashable {
    var id: String
    var accountId: String
    var accountName: String
    var date: Date
    var description: String
    var amount: Double
    var category: String

    enum CodingKeys: String, CodingKey {
        case id, accountId, accountName, date, description, amount, category
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        accountId = try c.decode(String.self, forKey: .accountId)
        accountName = (try? c.decode(String.self, forKey: .accountName)) ?? ""
        description = (try? c.decode(String.self, forKey: .description)) ?? ""
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

// MARK: - Errors

enum TellerBackendError: LocalizedError {
    case notAuthenticated
    case badResponse(status: Int)
    case missingToken

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "You are not signed in."
        case .badResponse(let status): return "Server error (HTTP \(status))."
        case .missingToken: return "Could not read the sign-in token."
        }
    }
}

// MARK: - Keychain helper

enum KeychainHelper {
    private static let service = "com.creditcardbenefittracker.teller"

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

actor TellerBackendClient {
    static let shared = TellerBackendClient()

    private let sessionKey = "backend_session_token"
    private let baseURL = TellerConfig.backendBaseURL

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
            throw TellerBackendError.missingToken
        }
        KeychainHelper.set(token, for: sessionKey)
    }

    func signOut() {
        KeychainHelper.delete(sessionKey)
    }

    // MARK: Linking

    /// POST /link — sends the transient Teller access token to the backend so it
    /// can store it and return the accounts it unlocked.
    func link(accessToken: String, enrollmentId: String, institution: String) async throws -> [LinkedAccount] {
        let body: [String: Any] = [
            "accessToken": accessToken,
            "enrollmentId": enrollmentId,
            "institution": institution
        ]
        let request = try authorizedRequest(path: "link", method: "POST", jsonBody: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response)
        return try Self.decoder.decode([LinkedAccount].self, from: data)
    }

    /// GET /accounts — the currently linked accounts.
    func accounts() async throws -> [LinkedAccount] {
        let request = try authorizedRequest(path: "accounts", method: "GET")
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response)
        return try Self.decoder.decode([LinkedAccount].self, from: data)
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
        return try Self.decoder.decode([RemoteTransaction].self, from: data)
    }

    /// POST /unlink
    func unlink(linkId: String) async throws {
        let request = try authorizedRequest(path: "unlink", method: "POST", jsonBody: ["linkId": linkId])
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
            throw TellerBackendError.notAuthenticated
        }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    private static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            throw TellerBackendError.badResponse(status: http.statusCode)
        }
    }

    private static let decoder = JSONDecoder()
}
