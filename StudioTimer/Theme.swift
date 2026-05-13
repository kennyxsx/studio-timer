// StudioTimer/Theme.swift
import SwiftUI

enum Theme {
    // Color tokens (semantic names match the studio CSS)
    static let primary = Color(red: 245/255, green: 242/255, blue: 243/255)   // #f5f2f3
    static let accent = Color(red: 197/255, green: 120/255, blue: 92/255)     // #c5785c
    static let base100 = Color(red: 13/255, green: 13/255, blue: 14/255)      // #0d0d0e
    static let base200 = Color(red: 26/255, green: 26/255, blue: 28/255)      // #1a1a1c
    static let base300 = Color(red: 39/255, green: 39/255, blue: 42/255)      // #27272a
    static let textSecondary = Color(red: 245/255, green: 242/255, blue: 243/255).opacity(0.6)
    static let textTertiary = Color(red: 245/255, green: 242/255, blue: 243/255).opacity(0.4)

    // Geometry
    static let radiusCard: CGFloat = 24
    static let radiusField: CGFloat = 12

    // Motion
    static let easing: Animation = .timingCurve(0.4, 0, 0.2, 1, duration: 0.3)

    // Standard paddings
    static let spaceCard: CGFloat = 20
    static let spaceField: CGFloat = 16
}

/// A common surface treatment — `.studio-card` from the web equivalent.
struct StudioCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Theme.spaceCard)
            .background(Theme.base200, in: RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous))
    }
}

extension View {
    func studioCard() -> some View { modifier(StudioCard()) }
}
