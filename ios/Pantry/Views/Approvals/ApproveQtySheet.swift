import SwiftUI

/// Canvas 4.3 "Approve rounded-down qty".
struct ApproveQtySheet: View {
    let item: ReviewItem
    let index: Int
    let total: Int
    var onResolved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isWorking = false

    /// Parses "2 × 2 kg" into a segment count for the pack-fill visual.
    private var packCount: Int {
        guard let desc = item.packDescription, let match = desc.split(separator: "×").first,
              let n = Int(match.trimmingCharacters(in: .whitespaces)) else { return 1 }
        return max(1, n)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Not enough in stock · \(index) of \(total)")
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

                    VStack(spacing: 12) {
                        HStack(spacing: 6) {
                            ForEach(0..<5, id: \.self) { i in
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(i < packCount ? Theme.ink : Color.clear)
                                    .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(i < packCount ? Theme.ink : Theme.secondaryText, style: StrokeStyle(lineWidth: 1.5, dash: i < packCount ? [] : [4])))
                                    .frame(height: 44)
                            }
                        }
                        HStack {
                            (Text("We can send ") + Text(formattedApproved).foregroundStyle(Theme.ink).bold() + Text(" · \(item.packDescription ?? "")"))
                                .font(.mono(13)).foregroundStyle(Theme.secondaryText)
                            Spacer()
                            Text("asked \(formattedQty(item.requestedQty)) \(item.requestedUnit)").font(.mono(13)).foregroundStyle(Theme.secondaryText)
                        }
                    }

                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "shield.fill").foregroundStyle(Theme.chipNeutralText)
                        Text("We always round **down**, never up — Ma never receives more than she asked for.")
                            .font(.mono(13)).foregroundStyle(Theme.chipNeutralText).fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .background(Theme.chipNeutralAlt)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radius))

                    HStack {
                        Text("\(item.catalogItemName ?? item.rawText) · \(formattedApproved)").font(.mono(15)).foregroundStyle(Theme.ink)
                        Spacer()
                        if let total = item.lineTotal { Text("₹ \(Int(total))").font(.mono(15)).foregroundStyle(Theme.ink) }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
            }

            VStack(spacing: 8) {
                Button {
                    approve()
                } label: {
                    if isWorking { ProgressView().tint(Theme.background) } else { Text("Approve \(formattedApproved)") }
                }
                .buttonStyle(.pantryPrimary)
                .disabled(isWorking)

                Button { reject() } label: {
                    Text("Reject · skip").font(.mono(15)).foregroundStyle(Theme.accentText)
                        .frame(maxWidth: .infinity).frame(height: 50)
                        .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.border, lineWidth: 1))
                }
                .disabled(isWorking)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(Theme.background)
    }

    private var formattedApproved: String { "\(formattedQty(item.approvedQty ?? 0)) \(item.requestedUnit)" }

    private func formattedQty(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(format: "%.1f", value)
    }

    private func approve() {
        isWorking = true
        Task {
            try? await APIClient.shared.approveQty(orderItemId: item.id)
            isWorking = false
            dismiss()
            onResolved()
        }
    }

    private func reject() {
        isWorking = true
        Task {
            try? await APIClient.shared.rejectQty(orderItemId: item.id)
            isWorking = false
            dismiss()
            onResolved()
        }
    }
}
