import SwiftUI

/// Design tokens — one place for the brand look.
///
/// Apply `Theme.accent` per component. Do NOT set a global `.tint()` on the
/// window content: it blanks the titles of AppKit-backed menu Pickers
/// (observed on macOS 26, the AI provider picker rendered empty).
enum Theme {
    /// Brand peach, matching the app icon.
    static let accent = Color(red: 1.00, green: 0.54, blue: 0.30)
    static let accentSoft = Color(red: 1.00, green: 0.62, blue: 0.39)

    static let priorityHigh = Color(red: 0.90, green: 0.28, blue: 0.30)
    static let priorityNormal = Color(red: 0.29, green: 0.56, blue: 0.85)
    static let priorityLow = Color(red: 0.61, green: 0.63, blue: 0.66)

    static let cardBackground = Color(nsColor: .controlBackgroundColor)
    static let hairline = Color.primary.opacity(0.07)

    /// Soft canvas behind card lists.
    static var canvas: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            Color.primary.opacity(0.035)
        }
    }
}

/// Shared card chrome: rounded, hairline border, one static soft shadow.
/// `compositingGroup` flattens layers first so the shadow is rendered once,
/// not per-subview (a real cost when a whole list scrolls or re-renders).
struct CardStyle: ViewModifier {
    var highlighted = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Theme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(highlighted ? Theme.accent.opacity(0.45) : Theme.hairline,
                                  lineWidth: 1)
            )
            .compositingGroup()
            .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
    }
}

extension View {
    func cardStyle(highlighted: Bool = false) -> some View {
        modifier(CardStyle(highlighted: highlighted))
    }
}
