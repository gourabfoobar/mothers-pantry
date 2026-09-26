import SwiftUI
import ActivityKit

/// The 4-stage progress bar with a truck-icon marker at the current stage —
/// canvas 5.1/5.2, redrawn for the widget (dark surface, light strokes).
struct StageProgressBar: View {
    let stage: PantryOrderStage

    private let labels = ["Placed", "Packed", "On the way", "Delivered"]

    var body: some View {
        VStack(spacing: 10) {
            GeometryReader { geo in
                let segmentWidth = (geo.size.width - 3 * 4) / 4
                HStack(spacing: 4) {
                    ForEach(0..<4, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(i <= stage.progressIndex ? Color.white : Color.white.opacity(0.28))
                            .frame(height: 3)
                    }
                }
                .frame(height: 26)
                .overlay(alignment: .leading) {
                    let markerCenter = CGFloat(stage.progressIndex) * (segmentWidth + 4) + segmentWidth
                    ZStack {
                        Circle().fill(Theme.accent).frame(width: 26, height: 26)
                        Image(systemName: "shippingbox.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.white)
                    }
                    .offset(x: markerCenter - 13)
                }
            }
            .frame(height: 26)

            HStack {
                ForEach(Array(labels.enumerated()), id: \.offset) { i, label in
                    Text(label)
                        .font(.mono(12))
                        .fontWeight(i == stage.progressIndex ? .bold : .regular)
                        .foregroundStyle(.white.opacity(i <= stage.progressIndex ? 1 : 0.6))
                    if i < 3 { Spacer() }
                }
            }
        }
    }
}

private func stage(for state: PantryOrderActivityAttributes.ContentState) -> PantryOrderStage {
    PantryOrderStage(rawValue: state.stage) ?? .placed
}

/// The header row (seal, stage label, ETA) — Lock Screen only; the Dynamic
/// Island's expanded regions render their own leading/trailing instead.
struct LiveActivityHeader: View {
    let attributes: PantryOrderActivityAttributes
    let state: PantryOrderActivityAttributes.ContentState

    var body: some View {
        let currentStage = stage(for: state)
        HStack(spacing: 12) {
            SealMark(size: 34, background: Theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("Ma's order · \(attributes.providerName)")
                    .font(.mono(13))
                    .foregroundStyle(.white.opacity(0.75))
                Text(currentStage.label)
                    .font(.mono(17, weight: .bold))
                    .foregroundStyle(.white)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if let etaDate = state.etaDate, currentStage != .delivered {
                    Text(etaDate, style: .time)
                        .font(.mono(22, weight: .semibold))
                        .foregroundStyle(.white)
                } else {
                    Text(state.etaText)
                        .font(.mono(20, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Text(currentStage == .delivered ? "delivered" : "arriving")
                    .font(.mono(12))
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
    }
}

/// Progress bar + courier/total row (+ optional call buttons) — shared by
/// the Lock Screen card and the Dynamic Island's expanded `.bottom` region.
struct LiveActivityBody: View {
    let state: PantryOrderActivityAttributes.ContentState
    var showCallButtons = false

    var body: some View {
        let currentStage = stage(for: state)
        VStack(alignment: .leading, spacing: 16) {
            StageProgressBar(stage: currentStage)

            HStack {
                if let courier = state.courierName, let distance = state.courierDistanceKm, currentStage == .onTheWay {
                    Text("\(courier) is \(String(format: "%.1f", distance)) km away")
                } else {
                    Text(" ")
                }
                Spacer()
                Text("\(state.itemCount) items · ₹ \(Int(state.total))")
            }
            .font(.mono(13))
            .foregroundStyle(.white.opacity(0.8))

            if showCallButtons {
                HStack(spacing: 8) {
                    callButton(title: "Call \(state.courierName ?? "driver")")
                    callButton(title: "Call Ma")
                }
            }
        }
    }

    private func callButton(title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "phone.fill").font(.system(size: 12))
            Text(title).font(.mono(14))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 40)
        .background(Color.white.opacity(0.16))
        .clipShape(Capsule())
    }
}

/// The full Lock Screen card — header + body together.
struct LiveActivityCard: View {
    let attributes: PantryOrderActivityAttributes
    let state: PantryOrderActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            LiveActivityHeader(attributes: attributes, state: state)
            LiveActivityBody(state: state)
        }
    }
}

/// The Dynamic Island's compact leading/trailing content — the seal and a
/// short countdown, matching canvas 5.2.
struct CompactEta: View {
    let state: PantryOrderActivityAttributes.ContentState

    var body: some View {
        if let etaDate = state.etaDate {
            Text(timerInterval: Date()...etaDate, countsDown: true, showsHours: false)
                .font(.mono(14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 46)
        } else {
            Text(state.etaText).font(.mono(14, weight: .bold)).foregroundStyle(.white)
        }
    }
}
