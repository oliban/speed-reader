import SwiftUI

// MARK: - Typography System for "Hyperfocus Noir" Design

extension Font {
    /// RSVP Word: JetBrains Mono Bold, 56pt
    /// Monospaced for consistent letter positioning during rapid serial visual presentation
    static let rsvpWord: Font = .custom("JetBrainsMono-Bold", size: 56)

    /// Headlines: SF Pro Display Bold, 28pt
    /// Use with .srHeadlineStyle() modifier to apply -0.015em tracking
    static let srHeadline: Font = .system(size: 28, weight: .bold, design: .default)

    /// Body: SF Pro Text Regular, 17pt
    static let srBody: Font = .system(size: 17, weight: .regular, design: .default)

    /// Overlines: SF Pro Text Semibold, 11pt
    /// Use with .srOverlineStyle() modifier to apply 0.1em tracking and uppercase
    static let srOverline: Font = .system(size: 11, weight: .semibold, design: .default)
}

// MARK: - Typography View Modifiers

struct HeadlineStyleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.srHeadline)
            .tracking(-0.015 * 28) // -0.015em at 28pt
    }
}

struct OverlineStyleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.srOverline)
            .tracking(0.1 * 11) // 0.1em at 11pt
            .textCase(.uppercase)
    }
}

struct BodyStyleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.srBody)
    }
}

struct RSVPWordStyleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.rsvpWord)
    }
}

// MARK: - View Extensions

extension View {
    /// Applies SF Pro Display Bold 28pt with -0.015em tracking
    func srHeadlineStyle() -> some View {
        modifier(HeadlineStyleModifier())
    }

    /// Applies SF Pro Text Semibold 11pt with 0.1em tracking and UPPERCASE
    func srOverlineStyle() -> some View {
        modifier(OverlineStyleModifier())
    }

    /// Applies SF Pro Text Regular 17pt
    func srBodyStyle() -> some View {
        modifier(BodyStyleModifier())
    }

    /// Applies JetBrains Mono Bold 56pt for RSVP display
    func rsvpWordStyle() -> some View {
        modifier(RSVPWordStyleModifier())
    }
}
