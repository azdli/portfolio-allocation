// Formatting functions

import Foundation

/// Pure formatting helpers, usable from any thread.
nonisolated enum Fmt {
    static func currency(_ value: Double, decimals: Int = 2) -> String {
        value.formatted(.currency(code: "USD").precision(.fractionLength(decimals)))
    }

    /// Signed currency, no sign for Zero.
    static func signedCurrency(_ value: Double, decimals: Int = 2) -> String {
        guard abs(value) >= 0.005 else { return currency(0, decimals: decimals) }
        return value.formatted(.currency(code: "USD").precision(.fractionLength(decimals)).sign(strategy: .always()))
    }

    /// Decimal to percent
    static func percent(_ fraction: Double, decimals: Int = 1) -> String {
        fraction.formatted(.percent.precision(.fractionLength(decimals)))
    }

    /// Signed percent, no sign for Zero
    static func signedPercent(_ fraction: Double) -> String {
        guard abs(fraction) >= 0.00005 else { return percent(0, decimals: 2) }
        return fraction.formatted(.percent.precision(.fractionLength(2)).sign(strategy: .always()))
    }

    /// Target to percent
    static func target(_ percentValue: Double) -> String {
        (percentValue / 100).formatted(.percent.precision(.fractionLength(0...2)))
    }

    /// Offset from target
    static func points(_ fraction: Double) -> String {
        let points = fraction * 100
        guard abs(points) >= 0.05 else { return "on target" }
        return (points > 0 ? "+" : "−") + abs(points).formatted(.number.precision(.fractionLength(1))) + " pts"
    }

    static func shares(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...4)))
    }

    static func approximateShares(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }

    static func parse(_ text: String) -> Double? {
        let cleaned = text.filter { "0123456789.-".contains($0) }
        guard !cleaned.isEmpty else { return nil }
        return Double(cleaned)
    }
}
