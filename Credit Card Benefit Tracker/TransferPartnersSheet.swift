//
//  TransferPartnersSheet.swift
//  Credit Card Benefit Tracker
//
//  Lists a card's transferable-points partners (airlines + hotels) and ratios.
//

import SwiftUI

struct TransferPartnersSheet: View {
    let program: TransferProgram
    @Environment(\.dismiss) private var dismiss

    private var airlines: [TransferPartner] { program.partners.filter { $0.kind == .airline } }
    private var hotels: [TransferPartner] { program.partners.filter { $0.kind == .hotel } }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(program.displayName)
                            .font(.headline)
                        Text("Move your points to these partners. Ratio shows points given : miles/points received.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }

                if !airlines.isEmpty {
                    Section("Airlines") {
                        ForEach(airlines) { partner in row(partner, icon: "airplane") }
                    }
                }

                if !hotels.isEmpty {
                    Section("Hotels") {
                        ForEach(hotels) { partner in row(partner, icon: "bed.double.fill") }
                    }
                }

                Section {
                    Text("Partners and ratios change often — confirm on the issuer's site before transferring. Transfers are usually one-way and can't be reversed.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Transfer Partners")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.appCoral)
                }
            }
        }
    }

    private func row(_ partner: TransferPartner, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(partner.name)
                .font(.subheadline)
            Spacer()
            Text(partner.ratio)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.appLeaf)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.appLeaf.opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(.vertical, 2)
    }
}
