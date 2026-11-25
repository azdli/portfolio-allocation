// Colour pallette for the app

import AppKit
import SwiftUI

extension NSColor {
    nonisolated convenience init(rgb: UInt32) {
        self.init(
            srgbRed: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension NSColor {
    /// WCAG relative luminance (0 for black, 1 for white), used to check text contrast.
    nonisolated var relativeLuminance: Double {
        guard let srgb = usingColorSpace(.sRGB) else { return 0 }
        func linear(_ channel: CGFloat) -> Double {
            let c = Double(channel)
            return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(srgb.redComponent) + 0.7152 * linear(srgb.greenComponent) + 0.0722 * linear(srgb.blueComponent)
    }
}

extension Color {
    /// A color that follows the system's light or dark appearance.
    nonisolated init(light: UInt32, dark: UInt32) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? NSColor(rgb: dark) : NSColor(rgb: light)
        })
    }
}

/// Chart, gain/loss and surface colors. Everything else in the app uses system colors.
enum Palette {
    // MARK: Surfaces

    // The window and control backgrounds are the same color on macOS 27, so cards sit on a page a
    // step darker (light mode), or are a step lighter than the window (dark mode).

    /// The window behind the cards. Dark matches the system window color.
    static let page = Color(light: 0xF2F2F2, dark: 0x1E1E1E)
    static let card = Color(light: 0xFFFFFF, dark: 0x2A2A2A)
    /// Bands inside a card (column headings, totals, stat tiles); system fills follow Increase Contrast.
    static let band = Color(nsColor: .tertiarySystemFill)
    /// A lighter band for rows nested under another row.
    static let nestedBand = Color(nsColor: .quaternarySystemFill)

    /// Checked with a color-vision validator: in this order each color stays distinguishable from its
    /// neighbor, which is why slices are colored by position.
    private static let series: [Color] = [
        Color(light: 0x257DE0, dark: 0x338CED), // blue
        Color(light: 0xF47230, dark: 0xE76624), // orange
        Color(light: 0x00B894, dark: 0x00A888), // aqua
        Color(light: 0xF2A600, dark: 0xD28E05), // yellow
        Color(light: 0xEE7FAC, dark: 0xE24D8B), // magenta
        Color(light: 0x008A17, dark: 0x0AAC23), // green
        Color(light: 0x6A4CE2, dark: 0x9887EF), // violet
        Color(light: 0xEC4647, dark: 0xEB6263), // red
    ]

    /// "Other" slices are gray so they read as the leftovers.
    static let other = Color(light: 0x9A9AA0, dark: 0x7C7C82)

    /// Colors for `count` slices in donut order. The ring wraps, so with seven slices the last two
    /// swap to keep violet off blue.
    static func sliceColors(count: Int) -> [Color] {
        let order = count == 7 ? [0, 1, 2, 3, 4, 6, 5] : Array(0..<min(max(count, 0), series.count))
        return order.map { series[$0] }
    }

    static let gain = Color(light: 0x1A7F37, dark: 0x3FB950)
    /// Dark is at least 4.5:1 on the dark card, its nested rows and its total row.
    static let loss = Color(light: 0xB42318, dark: 0xFF7069)
    static let warning = Color(light: 0x8A4B00, dark: 0xF0A050)

    /// The system accent for text like "Buy $1,200", nudged just enough to reach 4.5:1 contrast on
    /// every card surface.
    static let accentText = Color(nsColor: NSColor(name: nil, dynamicProvider: readableAccent))

    /// Relative luminance of the toughest surface (a total-row band) in each appearance.
    private nonisolated static func readableAccent(for appearance: NSAppearance) -> NSColor {
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        var accent = NSColor(rgb: 0x007AFF)
        appearance.performAsCurrentDrawingAppearance {
            accent = NSColor.controlAccentColor.usingColorSpace(.sRGB) ?? accent
        }
        let surfaceLuminance = isDark ? 0.0356 : 0.896
        let toward = isDark ? NSColor.white : NSColor.black

        func contrast(_ color: NSColor) -> Double {
            let text = color.relativeLuminance
            return (max(text, surfaceLuminance) + 0.05) / (min(text, surfaceLuminance) + 0.05)
        }

        var color = accent
        var fraction: CGFloat = 0
        while contrast(color) < 4.5, fraction < 1 {
            fraction += 0.02
            color = accent.blended(withFraction: fraction, of: toward)?.usingColorSpace(.sRGB) ?? color
        }
        return color
    }

    static func tone(_ value: Double) -> Color {
        if value > 0.005 { return gain }
        if value < -0.005 { return loss }
        return .secondary
    }
}
