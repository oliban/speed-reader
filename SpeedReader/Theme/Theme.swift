//
//  Theme.swift
//  SpeedReader
//
//  Hyperfocus Noir Color Palette
//

import SwiftUI
import UIKit

// MARK: - Dark Mode Colors

extension Color {
    /// Void Black - Primary background (Dark Mode)
    /// Hex: #0A0A0B
    static let voidBlack = Color(red: 10/255, green: 10/255, blue: 11/255)

    /// Ink Black - Cards, elevated surfaces (Dark Mode)
    /// Hex: #141416
    static let inkBlack = Color(red: 20/255, green: 20/255, blue: 22/255)

    /// Charcoal - Inputs, secondary surfaces (Dark Mode)
    /// Hex: #1C1C1F
    static let charcoal = Color(red: 28/255, green: 28/255, blue: 31/255)

    /// Smoke - Borders, dividers (Dark Mode)
    /// Hex: #2C2C30
    static let smoke = Color(red: 44/255, green: 44/255, blue: 48/255)

    /// Ash - Secondary text (Dark Mode)
    /// Hex: #6E6E7A
    static let ash = Color(red: 110/255, green: 110/255, blue: 122/255)

    /// Bone - Primary text (Dark Mode)
    /// Hex: #E8E8EC
    static let bone = Color(red: 232/255, green: 232/255, blue: 236/255)

    /// Signal Red - Focus letter, primary accent (Dark Mode)
    /// Hex: #FF2D55
    static let signalRed = Color(red: 255/255, green: 45/255, blue: 85/255)

    /// Electric Amber - Progress indicators
    /// Hex: #FFB800
    static let electricAmber = Color(red: 255/255, green: 184/255, blue: 0/255)

    /// Ice Blue - TTS mode accent
    /// Hex: #64D2FF
    static let iceBlue = Color(red: 100/255, green: 210/255, blue: 255/255)
}

// MARK: - Light Mode Colors

extension Color {
    /// Paper - Primary background (Light Mode)
    /// Hex: #FAFAF8
    static let paper = Color(red: 250/255, green: 250/255, blue: 248/255)

    /// Cream - Cards (Light Mode)
    /// Hex: #F2F2EF
    static let cream = Color(red: 242/255, green: 242/255, blue: 239/255)

    /// Graphite - Primary text (Light Mode)
    /// Hex: #1A1A1A
    static let graphite = Color(red: 26/255, green: 26/255, blue: 26/255)

    /// Crimson - Focus letter accent (Light Mode)
    /// Hex: #D91A3C
    static let crimson = Color(red: 217/255, green: 26/255, blue: 60/255)
}

// MARK: - Adaptive Colors

extension Color {
    /// Adaptive primary background color
    /// Dark: Void Black (#0A0A0B) | Light: Paper (#FAFAF8)
    static let adaptiveBackground = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 10/255, green: 10/255, blue: 11/255, alpha: 1)
            : UIColor(red: 250/255, green: 250/255, blue: 248/255, alpha: 1)
    })

    /// Adaptive card/elevated surface color
    /// Dark: Ink Black (#141416) | Light: Cream (#F2F2EF)
    static let adaptiveCard = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 20/255, green: 20/255, blue: 22/255, alpha: 1)
            : UIColor(red: 242/255, green: 242/255, blue: 239/255, alpha: 1)
    })

    /// Adaptive secondary surface color
    /// Dark: Charcoal (#1C1C1F) | Light: Cream (#F2F2EF)
    static let adaptiveSecondary = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 28/255, green: 28/255, blue: 31/255, alpha: 1)
            : UIColor(red: 242/255, green: 242/255, blue: 239/255, alpha: 1)
    })

    /// Adaptive border/divider color
    /// Dark: Smoke (#2C2C30) | Light: Light gray
    static let adaptiveBorder = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 44/255, green: 44/255, blue: 48/255, alpha: 1)
            : UIColor(red: 220/255, green: 220/255, blue: 218/255, alpha: 1)
    })

    /// Adaptive primary text color
    /// Dark: Bone (#E8E8EC) | Light: Graphite (#1A1A1A)
    static let adaptivePrimaryText = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 232/255, green: 232/255, blue: 236/255, alpha: 1)
            : UIColor(red: 26/255, green: 26/255, blue: 26/255, alpha: 1)
    })

    /// Adaptive secondary text color
    /// Dark: Ash (#6E6E7A) | Light: Medium gray
    static let adaptiveSecondaryText = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 110/255, green: 110/255, blue: 122/255, alpha: 1)
            : UIColor(red: 100/255, green: 100/255, blue: 105/255, alpha: 1)
    })

    /// Adaptive focus/accent color
    /// Dark: Signal Red (#FF2D55) | Light: Crimson (#D91A3C)
    static let adaptiveAccent = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 255/255, green: 45/255, blue: 85/255, alpha: 1)
            : UIColor(red: 217/255, green: 26/255, blue: 60/255, alpha: 1)
    })
}
