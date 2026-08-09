//
//  LinkedAccountsView.swift
//  Credit Card Benefit Tracker
//
//  Beta account-linking UI. The user signs in with Apple, then connects a card
//  through Stripe Financial Connections. Bank credentials are entered ONLY on
//  the bank's page inside Stripe's sheet — this app never sees them. Imported
//  transactions are stored on the device as Statements/StatementRows.
//
//  NOTE: "Sign in with Apple" requires enabling the capability in Xcode →
//  Signing & Capabilities before it works at runtime. Account linking requires
//  the Stripe SDK package (github.com/stripe/stripe-ios →
//  StripeFinancialConnections) added to the app target.
//

import SwiftUI
import SwiftData
import AuthenticationServices

struct LinkedAccountsView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var isSignedIn = LinkBackendClient.shared.isSignedIn
    @State private var accounts: [LinkedAccount] = []
    @State private var isBusy = false
    @State private var statusMessage: String?
    @State private var errorMessage: String?

    var body: some View {
        List {
            privacySection

            if isSignedIn {
                connectSection
                accountsSection
            } else {
                signInSection
            }

            if let statusMessage {
                Section {
                    Label(statusMessage, systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(Color.appLeaf)
                }
            }
            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Linked Accounts (Beta)")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if isBusy {
                ProgressView().scaleEffect(1.3)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
            }
        }
        .task {
            if isSignedIn { await loadAccounts() }
        }
    }

    // MARK: - Sections

    private var privacySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Label("Your privacy", systemImage: "lock.shield.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.appCoral)
                Text("Securely connect a card to import transactions automatically. Your bank login is entered only on your bank's page via Stripe — this app never sees your credentials. Imported transactions are stored on your device.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    private var signInSection: some View {
        Section("Get started") {
            Text("Sign in to link a card.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                handleAppleSignIn(result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 46)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        }
    }

    private var connectSection: some View {
        Section {
            Button {
                Task { await connect() }
            } label: {
                Label("Connect a Card", systemImage: "creditcard.fill")
                    .foregroundStyle(Color.appCoral)
            }
            Button {
                Task { await syncNow() }
            } label: {
                Label("Sync now", systemImage: "arrow.triangle.2.circlepath")
            }
        }
    }

    private var accountsSection: some View {
        Section("Linked accounts") {
            if accounts.isEmpty {
                Text("No accounts linked yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(accounts) { account in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(account.name.isEmpty ? account.institution : account.name)
                                .font(.subheadline.weight(.semibold))
                            Text(accountSubtitle(account))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(role: .destructive) {
                            Task { await disconnect(account) }
                        } label: {
                            Text("Disconnect").font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private func accountSubtitle(_ account: LinkedAccount) -> String {
        var parts: [String] = []
        if !account.institution.isEmpty { parts.append(account.institution) }
        if !account.lastFour.isEmpty { parts.append("•••• \(account.lastFour)") }
        return parts.joined(separator: " ")
    }

    // MARK: - Actions

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure(let error):
            errorMessage = "Sign in failed: \(error.localizedDescription)"
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let token = String(data: tokenData, encoding: .utf8) else {
                errorMessage = "Could not read Apple identity token."
                return
            }
            Task {
                isBusy = true
                defer { isBusy = false }
                do {
                    try await LinkBackendClient.shared.authenticateWithApple(identityToken: token)
                    isSignedIn = true
                    await loadAccounts()
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Full connect flow: create a Stripe session, present the sheet, then
    /// confirm with the backend and sync.
    private func connect() async {
        errorMessage = nil
        statusMessage = nil
        do {
            // 1. Ask the backend for a Financial Connections session.
            isBusy = true
            let session = try await LinkBackendClient.shared.createLinkSession()
            isBusy = false

            // 2. Present Stripe's sheet (bank login happens entirely inside it).
            let outcome = await StripeConnect.present(clientSecret: session.clientSecret)

            switch outcome {
            case .canceled:
                return
            case .failed(let message):
                errorMessage = message
                return
            case .completed:
                break
            }

            // 3. Confirm the link server-side and pull transactions.
            isBusy = true
            defer { isBusy = false }
            accounts = try await LinkBackendClient.shared.completeLink(sessionId: session.sessionId)
            let count = try await LinkSyncService.sync(modelContext: modelContext)
            statusMessage = "Connected. Imported \(count) new transactions."
        } catch {
            isBusy = false
            errorMessage = error.localizedDescription
        }
    }

    private func loadAccounts() async {
        do {
            accounts = try await LinkBackendClient.shared.accounts()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func syncNow() async {
        isBusy = true
        defer { isBusy = false }
        errorMessage = nil
        do {
            let count = try await LinkSyncService.sync(modelContext: modelContext)
            statusMessage = "Imported \(count) new transactions."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func disconnect(_ account: LinkedAccount) async {
        isBusy = true
        defer { isBusy = false }
        do {
            try await LinkBackendClient.shared.unlink(accountId: account.id)
            accounts.removeAll { $0.id == account.id }
            statusMessage = "Disconnected \(account.name.isEmpty ? account.institution : account.name)."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
