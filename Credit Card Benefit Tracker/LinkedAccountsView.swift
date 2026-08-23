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
    @EnvironmentObject private var subscriptions: SubscriptionManager
    @Query(sort: \UserCard.dateAdded) private var userCards: [UserCard]
    @Query private var accountMaps: [LinkedAccountMap]

    @State private var isSignedIn = LinkBackendClient.shared.isSignedIn
    @State private var accounts: [LinkedAccount] = []
    @State private var isBusy = false
    @State private var statusMessage: String?
    @State private var errorMessage: String?
    @State private var showAddCard = false
    // Account awaiting a card assignment once the user finishes adding a card.
    @State private var pendingAssignAccountId: String?
    // Account the user tapped Disconnect on, awaiting confirmation.
    @State private var accountPendingDisconnect: LinkedAccount?
    @State private var showDeleteAllConfirm = false
    @State private var showPaywall = false

    var body: some View {
        List {
            privacySection

            if isSignedIn {
                if subscriptions.canLinkAccounts {
                    connectSection
                } else {
                    upgradeSection
                }
                accountsSection
                manageSection
            } else {
                if subscriptions.canLinkAccounts {
                    signInSection
                } else {
                    upgradeSection
                }
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
            // Make sure entitlement/trial state is current before gating linking.
            await subscriptions.refreshEntitlements()
            subscriptions.evaluateTrial()
            if isSignedIn { await loadAccounts() }
        }
        .sheet(isPresented: $showAddCard, onDismiss: handleAddCardDismiss) {
            AddCardView()
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(contextMessage: "Connect your cards automatically with Concierge Premium or Max.")
        }
        .confirmationDialog(
            "Disconnect this account?",
            isPresented: Binding(
                get: { accountPendingDisconnect != nil },
                set: { if !$0 { accountPendingDisconnect = nil } }
            ),
            titleVisibility: .visible,
            presenting: accountPendingDisconnect
        ) { account in
            Button("Disconnect & remove transactions", role: .destructive) {
                Task { await disconnect(account) }
            }
            Button("Cancel", role: .cancel) { accountPendingDisconnect = nil }
        } message: { _ in
            Text("This stops syncing and removes the transactions imported from this account. Your card and any manually uploaded statements are kept.")
        }
        .confirmationDialog(
            "Delete all linked data?",
            isPresented: $showDeleteAllConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete everything", role: .destructive) {
                Task { await deleteAllData() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Disconnects every linked account, deletes all imported transactions from this device, and erases your data on our server. Your wallet cards and manually uploaded statements are kept. This cannot be undone.")
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
        } footer: {
            Text("\(accounts.count) of \(subscriptions.maxLinkedCards) linked cards used on your \(subscriptions.effectiveTierName) plan.")
        }
    }

    private var upgradeSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Label("Automatic card linking", systemImage: "lock.fill")
                    .font(.subheadline.weight(.semibold))
                Text("Connect your cards to import transactions automatically with Concierge Premium (5 cards) or Max (10 cards). Manual statement upload stays free.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button {
                    showPaywall = true
                } label: {
                    Text("See plans")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.appCoral)
            }
            .padding(.vertical, 4)
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
                    VStack(alignment: .leading, spacing: 8) {
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
                                accountPendingDisconnect = account
                            } label: {
                                Text("Disconnect").font(.caption.weight(.semibold))
                            }
                            .buttonStyle(.borderless)
                        }

                        cardAssignmentRow(for: account)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var manageSection: some View {
        Section("Manage") {
            Button {
                signOut()
            } label: {
                Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
            }
            Button(role: .destructive) {
                showDeleteAllConfirm = true
            } label: {
                Label("Delete all linked data", systemImage: "trash")
                    .foregroundStyle(.red)
            }
        }
    }

    private func accountSubtitle(_ account: LinkedAccount) -> String {
        var parts: [String] = []
        if !account.institution.isEmpty { parts.append(account.institution) }
        if !account.lastFour.isEmpty { parts.append("•••• \(account.lastFour)") }
        return parts.joined(separator: " ")
    }

    /// Row that shows which wallet card a linked account is assigned to, with a
    /// menu to (re)assign it. Until a card is chosen, the imported transactions
    /// are stored but not shown anywhere — so this is emphasized when unmapped.
    @ViewBuilder
    private func cardAssignmentRow(for account: LinkedAccount) -> some View {
        let mapped = mappedCard(for: account)
        Menu {
            if userCards.isEmpty {
                Text("No cards in your wallet yet")
            } else {
                ForEach(userCards) { card in
                    Button {
                        assign(account, to: card)
                    } label: {
                        if mapped?.persistentModelID == card.persistentModelID {
                            Label(card.name, systemImage: "checkmark")
                        } else {
                            Text(card.name)
                        }
                    }
                }
            }
            Divider()
            Button {
                pendingAssignAccountId = account.id
                showAddCard = true
            } label: {
                Label("Add a card from catalog…", systemImage: "plus")
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: mapped == nil ? "exclamationmark.circle.fill" : "creditcard.fill")
                    .foregroundStyle(mapped == nil ? .orange : Color.appLeaf)
                Text(mapped == nil ? "Assign to a card to see transactions" : "Card: \(mapped!.name)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(mapped == nil ? .orange : .primary)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(0.06))
            )
        }
        .buttonStyle(.borderless)
    }

    private func mappedCard(for account: LinkedAccount) -> UserCard? {
        guard let catalogID = accountMaps.first(where: { $0.accountId == account.id })?.catalogCardID else { return nil }
        return userCards.first(where: { $0.catalogCardID == catalogID })
    }

    private func assign(_ account: LinkedAccount, to card: UserCard) {
        LinkSyncService.assign(
            accountId: account.id,
            to: card,
            accountDisplayName: account.name,
            institution: account.institution,
            lastFour: account.lastFour,
            modelContext: modelContext
        )
        let label = account.name.isEmpty ? account.institution : account.name
        statusMessage = "Assigned \(label) to \(card.name). Its transactions now appear under that card."
    }

    /// After the user adds a card from the catalog, auto-assign it to the account
    /// they were mapping (convenience for the common single-add case).
    private func handleAddCardDismiss() {
        defer { pendingAssignAccountId = nil }
        guard let accountId = pendingAssignAccountId,
              let account = accounts.first(where: { $0.id == accountId }),
              mappedCard(for: account) == nil,
              let newest = userCards.sorted(by: { $0.dateAdded > $1.dateAdded }).first
        else { return }
        assign(account, to: newest)
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
        // Enforce the plan's card cap before incurring any connection cost.
        guard accounts.count < subscriptions.maxLinkedCards else {
            errorMessage = "You've reached your plan's limit of \(subscriptions.maxLinkedCards) linked cards. Upgrade or disconnect a card to add more."
            showPaywall = true
            return
        }
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
            // Auto-inherit a prior card assignment for reconnected accounts
            // (same institution + last-4) so the user needn't reassign.
            for account in accounts {
                LinkSyncService.inheritMappingIfPossible(
                    accountId: account.id,
                    institution: account.institution,
                    lastFour: account.lastFour,
                    accountDisplayName: account.name,
                    modelContext: modelContext
                )
            }
            let count = try await LinkSyncService.sync(modelContext: modelContext)
            statusMessage = "Connected. Imported \(count) new transactions."
        } catch {
            isBusy = false
            errorMessage = error.localizedDescription
        }
    }

    private func loadAccounts() async {
        do {
            let fetched = try await LinkBackendClient.shared.accounts()
            accounts = fetched
            // Authoritative list succeeded — clean up any on-device data for
            // accounts that are no longer active (disconnected elsewhere/earlier).
            LinkSyncService.reconcile(
                activeAccountIds: Set(fetched.map { $0.id }),
                modelContext: modelContext
            )
        } catch {
            // Do NOT reconcile on error — the list isn't authoritative and we
            // must not wipe still-valid data.
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

    private func signOut() {
        Task {
            await LinkBackendClient.shared.signOut()
            isSignedIn = false
            accounts = []
            statusMessage = "Signed out."
        }
    }

    private func deleteAllData() async {
        isBusy = true
        defer { isBusy = false }
        errorMessage = nil
        do {
            try await LinkBackendClient.shared.deleteMyData()
            let removed = LinkSyncService.removeAllLinkedData(modelContext: modelContext)
            accounts = []
            statusMessage = "Deleted all linked data (\(removed) statements removed)."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func disconnect(_ account: LinkedAccount) async {
        accountPendingDisconnect = nil
        isBusy = true
        defer { isBusy = false }
        do {
            try await LinkBackendClient.shared.unlink(accountId: account.id)
            accounts.removeAll { $0.id == account.id }
            // Remove the imported transactions + mapping for this account.
            let removed = LinkSyncService.removeData(forAccountId: account.id, modelContext: modelContext)
            let label = account.name.isEmpty ? account.institution : account.name
            statusMessage = removed > 0
                ? "Disconnected \(label) and removed \(removed) imported transactions."
                : "Disconnected \(label)."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
