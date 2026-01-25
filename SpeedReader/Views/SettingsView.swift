import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsArray: [AppSettings]
    @State private var focusColor: Color = .red

    private var settings: AppSettings? {
        settingsArray.first
    }

    var body: some View {
        NavigationStack {
            Form {
                if let settings = settings {
                    // RSVP Settings Section
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Speed")
                                Spacer()
                                Text("\(settings.rsvpSpeed) WPM")
                                    .foregroundColor(.secondary)
                            }
                            Slider(
                                value: Binding(
                                    get: { Double(settings.rsvpSpeed) },
                                    set: { settings.rsvpSpeed = Int($0) }
                                ),
                                in: 120...900,
                                step: 10
                            )
                        }
                    } header: {
                        Text("RSVP")
                    } footer: {
                        Text("Configure Rapid Serial Visual Presentation reading speed")
                    }

                    // TTS Settings Section
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Speed Multiplier")
                                Spacer()
                                Text(String(format: "%.1fx", settings.ttsSpeedMultiplier))
                                    .foregroundColor(.secondary)
                            }
                            Slider(
                                value: Binding(
                                    get: { settings.ttsSpeedMultiplier },
                                    set: { settings.ttsSpeedMultiplier = $0 }
                                ),
                                in: 0.5...4.0,
                                step: 0.1
                            )
                        }

                        HStack {
                            Text("Voice")
                            Spacer()
                            Text(settings.selectedVoiceId ?? "Default")
                                .foregroundColor(.secondary)
                        }
                    } header: {
                        Text("Text-to-Speech")
                    } footer: {
                        Text("Configure audio reading preferences")
                    }

                    // Appearance Settings Section
                    Section {
                        ColorPicker("Focus Color", selection: $focusColor)
                            .onChange(of: focusColor) { _, newColor in
                                settings.focusColor = newColor.toHex() ?? "#FF3B30"
                            }

                        // Preview of focus letter
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Preview")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            HStack(spacing: 0) {
                                Spacer()
                                FocusLetterPreview(word: "Reading", focusColor: focusColor)
                                Spacer()
                            }
                            .padding(.vertical, 12)
                            .background(Color(.systemBackground))
                            .cornerRadius(8)
                        }
                    } header: {
                        Text("Appearance")
                    } footer: {
                        Text("Customize the reading interface appearance")
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                ensureSettingsExist()
                if let settings = settings {
                    focusColor = Color(hex: settings.focusColor) ?? .red
                }
            }
        }
    }

    private func ensureSettingsExist() {
        if settingsArray.isEmpty {
            let newSettings = AppSettings()
            modelContext.insert(newSettings)
        }
    }
}

// Helper extension to convert hex string to Color
extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    func toHex() -> String? {
        guard let components = UIColor(self).cgColor.components else { return nil }
        let r, g, b: Double
        if components.count >= 3 {
            r = components[0]
            g = components[1]
            b = components[2]
        } else {
            // Grayscale
            r = components[0]
            g = components[0]
            b = components[0]
        }
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}

// MARK: - Focus Letter Preview

struct FocusLetterPreview: View {
    let word: String
    let focusColor: Color

    private var focusIndex: Int {
        // Standard ORP (Optimal Recognition Point) calculation
        let length = word.count
        switch length {
        case 1: return 0
        case 2...5: return 1
        case 6...9: return 2
        case 10...13: return 3
        default: return 4
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(word.enumerated()), id: \.offset) { index, character in
                Text(String(character))
                    .font(.system(size: 32, weight: .medium, design: .monospaced))
                    .foregroundColor(index == focusIndex ? focusColor : .primary)
            }
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: AppSettings.self, inMemory: true)
}
