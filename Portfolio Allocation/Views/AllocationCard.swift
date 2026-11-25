// A donut chart and legend by holding or asset class.

import Charts
import SwiftUI

struct AllocationCard: View {
    let snapshot: PortfolioSnapshot
    @State private var grouping: AllocationGrouping = .holding
    @State private var highlighted: String?

    private let legendRowHeight: CGFloat = 40
    private let legendHeaderHeight: CGFloat = 24

    var body: some View {
        let slices = snapshot.slices(for: grouping)

        VStack(alignment: .leading, spacing: 18) {
            CardHeading(title: "Allocation", height: CardHeadingHeight.top) {
                // `.tabs` (macOS 27's Liquid Glass tab style)
                Picker("Group by", selection: $grouping) {
                    ForEach(AllocationGrouping.allCases) { grouping in
                        Text(grouping.label).tag(grouping)
                    }
                }
                .pickerStyle(.tabs)
                .labelsHidden()
                .controlSize(.extraLarge)
                .fixedSize()
            }

            HStack(alignment: .top, spacing: 28) {
                DonutChart(
                    slices: slices,
                    total: snapshot.totalValue,
                    centerTitle: centerTitle(count: slices.count),
                    highlighted: $highlighted
                )
                .frame(width: 200, height: 200)

                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        Spacer()
                        Text("Actual").frame(width: 60, alignment: .trailing)
                        Text("Target").frame(width: 56, alignment: .trailing)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(height: legendHeaderHeight)
                    Divider()

                    ForEach(slices) { slice in
                        LegendRow(slice: slice, isDimmed: highlighted != nil && highlighted != slice.id)
                            .frame(height: legendRowHeight)
                            .onHover { isHovering in
                                if isHovering {
                                    highlighted = slice.id
                                } else if highlighted == slice.id {
                                    highlighted = nil
                                }
                            }
                        Divider().opacity(0.5)
                    }
                }
                .frame(
                    minHeight: legendHeaderHeight + CGFloat(snapshot.maxLegendRows) * (legendRowHeight + 1),
                    alignment: .top
                )
            }
        }
        .animation(.easeOut(duration: 0.15), value: highlighted)
        .onChange(of: grouping) { highlighted = nil }
        .card()
    }

    private func centerTitle(count: Int) -> String {
        switch grouping {
        case .holding: count == 1 ? "1 holding" : "\(snapshot.holdings.count) holdings"
        case .assetClass: count == 1 ? "1 asset class" : "\(count) asset classes"
        }
    }
}

private struct LegendRow: View {
    let slice: PortfolioSnapshot.Slice
    let isDimmed: Bool

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(slice.color)
                .frame(width: 12, height: 12)
            VStack(alignment: .leading, spacing: 1) {
                Text(slice.label)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Text(slice.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(Fmt.percent(slice.share))
                .fontWeight(.semibold)
                .frame(width: 60, alignment: .trailing)
            Text(slice.targetFraction.map { Fmt.target($0 * 100) } ?? "—")
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .trailing)
        }
        .monospacedDigit()
        .contentShape(Rectangle())
        .opacity(isDimmed ? 0.35 : 1)
        .accessibilityElement(children: .combine)
    }
}

/// A donut whose slices highlight under the pointer. Every slice has the same 2 pt gap and keeps its true size; one thinner than the gap can't draw but keeps a `minimumHoverArc` hover zone.
private struct DonutChart: View {
    let slices: [PortfolioSnapshot.Slice]
    let total: Double
    let centerTitle: String
    @Binding var highlighted: String?

    private let innerRatio: CGFloat = 0.62
    private let minimumHoverArc: CGFloat = 24

    /// Slices with nothing in them have no arc to draw or hover.
    private var drawn: [PortfolioSnapshot.Slice] {
        slices.filter { $0.value > 0 }
    }

    var body: some View {
        ZStack {
            Chart(drawn) { slice in
                SectorMark(
                    angle: .value("Value", slice.value),
                    innerRadius: .ratio(innerRatio),
                    angularInset: 1
                )
                .cornerRadius(2)
                .foregroundStyle(slice.color)
                .opacity(highlighted == nil || highlighted == slice.id ? 1 : 0.3)
                .accessibilityLabel(slice.label)
                .accessibilityValue(Fmt.percent(slice.share))
            }
            .chartLegend(.hidden)
            .chartOverlay { _ in
                GeometryReader { proxy in
                    Color.clear
                        .contentShape(Rectangle())
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let point):
                                highlighted = sliceID(at: point, in: proxy.size)
                            case .ended:
                                highlighted = nil
                            }
                        }
                }
            }

            centerLabel
                .allowsHitTesting(false)
        }
    }

    private var centerLabel: some View {
        let slice = slices.first { $0.id == highlighted }
        return VStack(spacing: 2) {
            Text(slice?.label ?? centerTitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(Fmt.currency(slice?.value ?? total, decimals: 0))
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let slice {
                Text(Fmt.percent(slice.share))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: 112)
    }

    private func sliceID(at point: CGPoint, in size: CGSize) -> String? {
        let dx = point.x - size.width / 2
        let dy = point.y - size.height / 2
        let outer = min(size.width, size.height) / 2
        let radius = (dx * dx + dy * dy).squareRoot()
        guard radius <= outer, radius >= outer * innerRatio else { return nil }

        // Pointer measurement
        var angle = Double(atan2(dx, -dy))
        if angle < 0 { angle += 2 * .pi }

        let sum = drawn.reduce(0) { $0 + $1.value }
        guard sum > 0 else { return nil }

        // Each slice's span in radians.
        var spans: [(id: String, start: Double, end: Double)] = []
        var running = 0.0
        for slice in drawn {
            let start = running / sum * 2 * .pi
            running += slice.value
            spans.append((slice.id, start, running / sum * 2 * .pi))
        }

        // widen each slices's hover zone to the minimum arc at mid-ring, taking the nearest if two widened zones overlap.
        let midRadius = Double(outer * (1 + innerRatio) / 2)
        let minimumSpan = Double(minimumHoverArc) / midRadius
        var nearestTiny: (id: String, distance: Double)?
        for span in spans where span.end - span.start < minimumSpan {
            let center = (span.start + span.end) / 2
            var distance = abs(angle - center)
            distance = min(distance, 2 * .pi - distance)
            if distance <= minimumSpan / 2, distance < (nearestTiny?.distance ?? .infinity) {
                nearestTiny = (span.id, distance)
            }
        }
        if let nearestTiny { return nearestTiny.id }

        return spans.first { angle <= $0.end }?.id ?? spans.last?.id
    }
}
