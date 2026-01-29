//
//  SRPrimaryButton.swift
//  SpeedReader
//
//  Brutalist-style primary button for "Hyperfocus Noir" design system
//

import SwiftUI

// MARK: - SRPrimaryButton

struct SRPrimaryButton: View {
    let title: String
    let action: () -> Void
    var isLoading: Bool = false
    var isDisabled: Bool = false
    var isFullWidth: Bool = true

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            guard !isLoading && !isDisabled else { return }
            action()
        }) {
            buttonContent
        }
        .buttonStyle(SRPrimaryButtonStyle(
            isPressed: $isPressed,
            isLoading: isLoading,
            isDisabled: isDisabled,
            isFullWidth: isFullWidth
        ))
        .disabled(isDisabled || isLoading)
    }

    @ViewBuilder
    private var buttonContent: some View {
        HStack(spacing: 8) {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.8)
            }

            Text(title.uppercased())
                .font(.system(size: 15, weight: .semibold))
                .tracking(0.1 * 15) // 0.1em at 15pt
                .foregroundColor(.white)
                .opacity(isLoading ? 0.7 : 1.0)
        }
        .frame(maxWidth: isFullWidth ? .infinity : nil)
        .padding(.vertical, 16)
        .padding(.horizontal, 32)
    }
}

// MARK: - SRPrimaryButtonStyle

struct SRPrimaryButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool
    let isLoading: Bool
    let isDisabled: Bool
    let isFullWidth: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(backgroundView(isPressed: configuration.isPressed))
            .clipShape(Rectangle()) // Brutalist sharp corners (radius: 0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.srQuick, value: configuration.isPressed)
            .opacity(isDisabled ? 0.5 : 1.0)
            .onChange(of: configuration.isPressed) { _, newValue in
                isPressed = newValue
            }
    }

    @ViewBuilder
    private func backgroundView(isPressed: Bool) -> some View {
        Color.adaptiveAccent
            .brightness(isPressed ? -0.1 : 0)
    }
}

// MARK: - Convenience Initializers

extension SRPrimaryButton {
    /// Creates a primary button with default full-width behavior
    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
        self.isLoading = false
        self.isDisabled = false
        self.isFullWidth = true
    }

    /// Creates a primary button with loading state
    init(_ title: String, isLoading: Bool, action: @escaping () -> Void) {
        self.title = title
        self.action = action
        self.isLoading = isLoading
        self.isDisabled = false
        self.isFullWidth = true
    }
}

// MARK: - Preview

#Preview("Primary Button States") {
    VStack(spacing: 24) {
        // Default state
        SRPrimaryButton(title: "Start Reading", action: {})

        // Loading state
        SRPrimaryButton(title: "Loading", action: {}, isLoading: true)

        // Disabled state
        SRPrimaryButton(title: "Disabled", action: {}, isDisabled: true)

        // Non-full-width
        SRPrimaryButton(title: "Compact", action: {}, isFullWidth: false)
    }
    .padding(24)
    .background(Color.adaptiveBackground)
}

#Preview("Dark Mode") {
    VStack(spacing: 24) {
        SRPrimaryButton(title: "Start Reading", action: {})
        SRPrimaryButton(title: "Loading", action: {}, isLoading: true)
        SRPrimaryButton(title: "Disabled", action: {}, isDisabled: true)
    }
    .padding(24)
    .background(Color.voidBlack)
    .preferredColorScheme(.dark)
}

#Preview("Light Mode") {
    VStack(spacing: 24) {
        SRPrimaryButton(title: "Start Reading", action: {})
        SRPrimaryButton(title: "Loading", action: {}, isLoading: true)
        SRPrimaryButton(title: "Disabled", action: {}, isDisabled: true)
    }
    .padding(24)
    .background(Color.paper)
    .preferredColorScheme(.light)
}
