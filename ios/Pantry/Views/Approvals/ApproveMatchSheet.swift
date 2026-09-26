import SwiftUI

/// Canvas 4.2 "Approve a match".
struct ApproveMatchSheet: View {
    let item: ReviewItem
    let index: Int
    let total: Int
    var onResolved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedCandidateId: String?
    @State private var isWorking = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Check this match · \(index) of \(total)")
                    .font(.mono(13)).tracking(0.6).foregroundStyle(Theme.accentText)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 16, weight: .medium)).foregroundStyle(Theme.ink)
                        .frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("MA WROTE").font(.mono(12)).tracking(0.6).foregroundStyle(Theme.secondaryText)
                        Text("\u{201c}\(item.rawText)\u{201d}").font(.mono(22)).foregroundStyle(Theme.ink)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radius))

                    VStack(spacing: 10) {
                        ForEach(Array(item.candidates.enumerated()), id: \.element.id) { i, candidate in
                            Button {
                                selectedCandidateId = candidate.catalogItemId
                            } label: {
                                HStack(alignment: .top, spacing: 14) {
                                    Circle()
                                        .strokeBorder(isSelected(candidate) ? Theme.ink : Theme.border, lineWidth: 1.5)
                                        .frame(width: 22, height: 22)
                                        .overlay(Circle().fill(Theme.ink).frame(width: 12, height: 12).opacity(isSelected(candidate) ? 1 : 0))
                                    VStack(alignment: .leading, spacing: 4) {
                                        if i == 0 { Chip(text: "Most likely", background: Theme.chipNeutralAlt, foreground: Theme.chipNeutralText) }
                                        Text(candidate.name).font(.mono(16, weight: .medium)).foregroundStyle(Theme.ink)
                                        Text(candidate.reason).font(.mono(13)).foregroundStyle(Theme.secondaryText).fixedSize(horizontal: false, vertical: true)
                                    }
                                    Spacer(minLength: 8)
                                    if let price = candidate.price { Text("₹ \(Int(price))").font(.mono(15)).foregroundStyle(Theme.ink) }
                                }
                                .padding(16)
                                .background(Theme.card)
                                .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(isSelected(candidate) ? Theme.ink : Theme.border, lineWidth: isSelected(candidate) ? 1.5 : 1))
                                .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
            }

            VStack(spacing: 6) {
                Button {
                    approve()
                } label: {
                    if isWorking { ProgressView().tint(Theme.background) } else if let name = selectedCandidateName {
                        Text("Use \(name)")
                    } else {
                        Text("Use this match")
                    }
                }
                .buttonStyle(.pantryPrimary)
                .disabled(isWorking)

                Button { remove() } label: {
                    Text("Remove from list").font(.mono(16, weight: .medium)).foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity).frame(height: 54)
                }
                .disabled(isWorking)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(Theme.background)
        .onAppear { selectedCandidateId = item.candidates.first?.catalogItemId }
    }

    private var selectedCandidateName: String? {
        item.candidates.first(where: { $0.catalogItemId == selectedCandidateId })?.name
    }

    private func isSelected(_ candidate: MatchCandidateDTO) -> Bool { candidate.catalogItemId == selectedCandidateId }

    private func approve() {
        isWorking = true
        Task {
            try? await APIClient.shared.approveMatch(orderItemId: item.id, catalogItemId: selectedCandidateId)
            isWorking = false
            dismiss()
            onResolved()
        }
    }

    private func remove() {
        isWorking = true
        Task {
            try? await APIClient.shared.rejectMatch(orderItemId: item.id)
            isWorking = false
            dismiss()
            onResolved()
        }
    }
}
