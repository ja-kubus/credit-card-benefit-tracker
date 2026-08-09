//
//  LinkedAccountsView.swift
//  Credit Card Benefit Tracker
//
//  Beta account-linking UI. The user signs in with Apple, then connects a card
//  through Teller Connect. Bank credentials are entered ONLY on the bank's page
//  inside Teller — this app never sees them. Imported transactions are stored on
//  the device as Statements/StatementRows.
//
//  NOTE: "Sign in with Apple" requires enabling the capability in Xcode →
//  Signing & Capabilities before it works at runtime. The code compiles without
//  the entitlement, but the button will fail at runtime until it is enabled.
//

import SwiftUI
import SwiftData
import AuthenticationServices

struct LinkedAccountsView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var isSignedIn = TellerBackendClient.shared.isSignedIn
    @State private var accounts: [LinkedAccount] = []
    @State private var showConnectSheet = false
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
        .sheet(isPresented: $showConnectSheet) {
            TellerConnectView(
                onSuccess: { accessToken, enrollmentId, institution in
                    showConnectSheet = false
                    handleLink(accessToken: accessToken, enrollmentId: enrollmentId, institution: institution)
                },
                onExit: {
                    showConnectSheet = false
                }
            )
            .ignoresSafeArea()
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
                Text("Securely connect a card to import transactions automatically. Your bank login is entered only on your bank's page via Teller — this app never sees your credentials. Imported transactions are stored on your device.")
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
                errorMessage = nil
                statusMessage = nil
                showConnectSheet = true
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
                            Text(account.name).font(.subheadline.weight(.semibold))
                            Text("\(account.institution) •••• \(account.lastFour)")
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
                    try await TellerBackendClient.shared.authenticateWithApple(identityToken: token)
                    isSignedIn = true
                    await loadAccounts()
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func handleLink(accessToken: String, enrollmentId: String, institution: String) {
        Task {
            isBusy = true
            defer { isBusy = false }
            do {
                // The accessToken is transient — sent to the backend, never stored here.
                let linked = try await TellerBackendClient.shared.link(
                    accessToken: accessToken,
                    enrollmentId: enrollmentId,
                    institution: institution
                )
                accounts = linked
                let count = try await TellerSyncService.sync(modelContext: modelContext)
                statusMessage = "Linked \(institution). Imported \(count) new transactions."
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func loadAccounts() async {
        do {
            accounts = try await TellerBackendClient.shared.accounts()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func syncNow() async {
        isBusy = true
        defer { isBusy = false }
        errorMessage = nil
        do {
            let count = try await TellerSyncService.sync(modelContext: modelContext)
            statusMessage = "Imported \(count) new transactions."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func disconnect(_ account: LinkedAccount) async {
        let linkId = account.linkId ?? account.id
        isBusy = true
        defer { isBusy = false }
        do {
            try await TellerBackendClient.shared.unlink(linkId: linkId)
            accounts.removeAll { $0.id == account.id }
            statusMessage = "Disconnected \(account.name)."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
