//
//  SRTextField.swift
//  SpeedReader
//
//  A dark-themed text field for the "Hyperfocus Noir" design system.
//

import SwiftUI

/// A styled text field component following the Hyperfocus Noir design system.
///
/// Design specifications:
/// - Background: Charcoal (#1C1C1F) in dark mode, Cream (#F2F2EF) in light mode
/// - Text: Bone (#E8E8EC) in dark mode, Graphite (#1A1A1A) in light mode
/// - Placeholder: Ash (#6E6E7A)
/// - Border: 1pt Smoke (#2C2C30), Signal Red (#FF2D55) when focused
/// - Corner radius: 8pt
/// - Padding: 16pt
/// - Font: SF Pro Text Regular 17pt (srBody)
struct SRTextField: View {
    let placeholder: String
    @Binding var text: String
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("", text: $text, prompt: promptText)
            .font(.srBody)
            .foregroundColor(.adaptivePrimaryText)
            .padding(16)
            .background(Color.adaptiveSecondary)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColor, lineWidth: 1)
            )
            .focused($isFocused)
            .animation(.srQuick, value: isFocused)
    }

    private var promptText: Text {
        Text(placeholder)
            .foregroundColor(.ash)
    }

    private var borderColor: Color {
        isFocused ? .signalRed : .adaptiveBorder
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 24) {
        // Light mode preview
        VStack(spacing: 16) {
            Text("Light Mode")
                .font(.srHeadline)
                .foregroundColor(.graphite)

            SRTextField(
                placeholder: "Enter URL...",
                text: .constant("")
            )

            SRTextField(
                placeholder: "With text",
                text: .constant("https://example.com")
            )
        }
        .padding()
        .background(Color.paper)
        .environment(\.colorScheme, .light)

        // Dark mode preview
        VStack(spacing: 16) {
            Text("Dark Mode")
                .font(.srHeadline)
                .foregroundColor(.bone)

            SRTextField(
                placeholder: "Enter URL...",
                text: .constant("")
            )

            SRTextField(
                placeholder: "With text",
                text: .constant("https://example.com")
            )
        }
        .padding()
        .background(Color.voidBlack)
        .environment(\.colorScheme, .dark)
    }
    .padding()
}
