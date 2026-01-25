import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsArray: [AppSettings]

    private var settings: AppSettings {
        if let existing = settingsArray.first {
            return existing
        } else {
            let newSettings = AppSettings()
            modelContext.insert(newSettings)
            return newSettings
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                // RSVP Settings Section
                Section {
                    HStack {
                        Text("Speed")
                        Spacer()
                        Text("\(settings.rsvpSpeed) WPM")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("RSVP")
                } footer: {
                    Text("Configure Rapid Serial Visual Presentation reading speed")
                }

                // TTS Settings Section
                Section {
                    HStack {
                        Text("Speed Multiplier")
                        Spacer()
                        Text(String(format: "%.1fx", settings.ttsSpeedMultiplier))
                            .foregroundColor(.secondary)
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
                    HStack {
                        Text("Focus Color")
                        Spacer()
                        Circle()
                            .fill(Color(hex: settings.focusColor) ?? .red)
                            .frame(width: 24, height: 24)
                    }
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("Customize the reading interface appearance")
                }
            }
            .navigationTitle("Settings")
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
}

#Preview {
    SettingsView()
        .modelContainer(for: AppSettings.self, inMemory: true)
}
