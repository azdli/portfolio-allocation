// Total market value, gain and return, and a bar per account.

import SwiftUI

struct SummaryCard: View {
    let snapshot: PortfolioSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                CardHeading("Total market value", height: CardHeadingHeight.top)
                Text(Fmt.currency(snapshot.totalValue))
                    .font(.system(size: 38, weight: .semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }

            HStack(spacing: 10) {
                StatTile(title: "Unrealized gain", value: Fmt.signedCurrency(snapshot.gain), tint: Palette.tone(snapshot.gain))
                StatTile(title: "Return", value: snapshot.returnFraction.map(Fmt.signedPercent) ?? "—", tint: Palette.tone(snapshot.gain))
                StatTile(title: "Cost basis", value: Fmt.currency(snapshot.totalCost))
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                CardHeading("By account")
                ForEach(snapshot.accounts) { line in
                    AccountBar(line: line)
                }
            }
        }
        .card()
    }
}

private struct AccountBar: View {
    let line: PortfolioSnapshot.AccountLine

    var body: some View {
        VStack(spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(line.account.brokerage)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Text(line.account.name)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(gainText)
                    .font(.callout)
                    .foregroundStyle(Palette.tone(line.gain))
                Text(Fmt.currency(line.value))
                    .fontWeight(.semibold)
                    .frame(minWidth: 100, alignment: .trailing)
                Text(Fmt.percent(line.share))
                    .foregroundStyle(.secondary)
                    .frame(width: 48, alignment: .trailing)
            }
            .monospacedDigit()

            Capsule()
                .fill(.quaternary)
                .frame(height: 3)
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        Capsule()
                            .fill(.secondary)
                            .frame(width: max(0, proxy.size.width * line.share))
                    }
                }
        }
        .accessibilityElement(children: .combine)
    }

    private var gainText: String {
        let percent = line.returnFraction.map { " (\(Fmt.signedPercent($0)))" } ?? ""
        return Fmt.signedCurrency(line.gain, decimals: 0) + percent
    }
}
