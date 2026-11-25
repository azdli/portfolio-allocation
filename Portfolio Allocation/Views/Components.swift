// Shared building blocks for the app

import SwiftUI

struct CardModifier: ViewModifier {
    @Environment(\.colorSchemeContrast) private var contrast
    var padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Palette.card)
            .clipShape(.rect(cornerRadius: 14, style: .continuous))
            .overlay {
                // With Increase Contrast, macOS outlines surfaces clearly; the card follows suit.
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(contrast == .increased ? Color.secondary : Color(nsColor: .separatorColor), lineWidth: 1)
            }
    }
}

extension View {
    func card(padding: CGFloat = 20) -> some View {
        modifier(CardModifier(padding: padding))
    }

    /// The window surface behind the cards.
    func pageBackground() -> some View {
        background(Palette.page)
    }

    /// fixed-width table column
    func cell(_ width: CGFloat, alignment: Alignment = .trailing) -> some View {
        frame(width: width, alignment: alignment)
    }
}

/// A sheet title in its own band
struct SheetHeader: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            Divider()
        }
    }
}

/// Heights for `CardHeading`. Both top cards use `top` so their headings line up
enum CardHeadingHeight {
    static let standard: CGFloat = 28
    static let top: CGFloat = 36
}

/// heading used at the top of each card.
struct CardHeading<Accessory: View>: View {
    let title: String
    var height: CGFloat = CardHeadingHeight.standard
    @ViewBuilder var accessory: Accessory

    var body: some View {
        HStack(alignment: .center) {
            Text(title.uppercased())
                .font(.subheadline.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            accessory
        }
        .frame(height: height)
    }
}

extension CardHeading where Accessory == EmptyView {
    init(_ title: String, height: CGFloat = CardHeadingHeight.standard) {
        self.title = title
        self.height = height
        self.accessory = EmptyView()
    }
}

struct StatTile: View {
    let title: String
    let value: String
    var tint: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.band, in: .rect(cornerRadius: 10, style: .continuous))
    }
}
