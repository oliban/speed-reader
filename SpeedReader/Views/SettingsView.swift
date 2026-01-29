import SwiftUI
import SwiftData
import AVFoundation

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
                                Label("Speed", systemImage: "speedometer")
                                    .font(.body)
                                    .foregroundStyle(Color.adaptivePrimaryText)
                                Spacer()
                                Text("\(settings.rsvpSpeed) WPM")
                                    .font(.body.monospacedDigit())
                                    .foregroundStyle(Color.signalRed)
                            }
                            Slider(
                                value: Binding(
                                    get: { Double(settings.rsvpSpeed) },
                                    set: { settings.rsvpSpeed = Int($0) }
                                ),
                                in: 120...900,
                                step: 10
                            )
                            .tint(Color.signalRed)
                            .accessibilityLabel("Reading speed")
                            .accessibilityValue("\(settings.rsvpSpeed) words per minute")
                        }
                    } header: {
                        Text("RSVP")
                            .srOverlineStyle()
                            .foregroundStyle(Color.ash)
                    } footer: {
                        Text("Configure Rapid Serial Visual Presentation reading speed")
                            .font(.caption)
                            .foregroundStyle(Color.adaptiveSecondaryText)
                    }
                    .listRowBackground(Color.adaptiveCard)

                    // TTS Settings Section
                    Section {
                        Picker(selection: Binding(
                            get: { settings.ttsSpeedMultiplier },
                            set: { settings.ttsSpeedMultiplier = $0 }
                        )) {
                            Text("0.5x").tag(0.5)
                            Text("0.75x").tag(0.75)
                            Text("1x").tag(1.0)
                            Text("1.5x").tag(1.5)
                            Text("2x").tag(2.0)
                            Text("3x").tag(3.0)
                            Text("4x").tag(4.0)
                        } label: {
                            Label("Default Speed", systemImage: "gauge.with.dots.needle.33percent")
                                .font(.body)
                                .foregroundStyle(Color.adaptivePrimaryText)
                        }
                        .tint(Color.iceBlue)

                        NavigationLink {
                            VoicePickerView(selectedVoiceId: Binding(
                                get: { settings.selectedVoiceId },
                                set: { settings.selectedVoiceId = $0 }
                            ))
                        } label: {
                            HStack {
                                Label("Voice", systemImage: "person.wave.2")
                                    .font(.body)
                                    .foregroundStyle(Color.adaptivePrimaryText)
                                Spacer()
                                Text(voiceDisplayName(for: settings.selectedVoiceId))
                                    .font(.body)
                                    .foregroundStyle(Color.iceBlue)
                            }
                        }
                    } header: {
                        Text("Text-to-Speech")
                            .srOverlineStyle()
                            .foregroundStyle(Color.ash)
                    } footer: {
                        Text("Default speed applied to new TTS sessions")
                            .font(.caption)
                            .foregroundStyle(Color.adaptiveSecondaryText)
                    }
                    .listRowBackground(Color.adaptiveCard)

                    // Appearance Settings Section
                    Section {
                        Picker(selection: Binding(
                            get: { settings.appearanceMode },
                            set: { settings.appearanceMode = $0 }
                        )) {
                            Label("System", systemImage: "circle.lefthalf.filled").tag("system")
                            Label("Light", systemImage: "sun.max").tag("light")
                            Label("Dark", systemImage: "moon").tag("dark")
                        } label: {
                            Label("Theme", systemImage: "paintbrush")
                                .font(.body)
                                .foregroundStyle(Color.adaptivePrimaryText)
                        }

                        ColorPicker(selection: $focusColor) {
                            Label("Focus Color", systemImage: "eyedropper")
                                .font(.body)
                                .foregroundStyle(Color.adaptivePrimaryText)
                        }
                        .onChange(of: focusColor) { _, newColor in
                            settings.focusColor = newColor.toHex() ?? "#FF3B30"
                        }
                        .accessibilityLabel("Focus color picker")

                        // Preview of focus letter
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Preview")
                                .font(.caption)
                                .foregroundStyle(Color.adaptiveSecondaryText)

                            HStack(spacing: 0) {
                                Spacer()
                                FocusLetterPreview(word: "Reading", focusColor: focusColor)
                                Spacer()
                            }
                            .padding(.vertical, 12)
                            .background(Color.adaptiveBackground)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.adaptiveBorder, lineWidth: 1)
                            )
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Focus letter preview showing the word Reading")
                    } header: {
                        Text("Appearance")
                            .srOverlineStyle()
                            .foregroundStyle(Color.ash)
                    } footer: {
                        Text("Customize the reading interface appearance")
                            .font(.caption)
                            .foregroundStyle(Color.adaptiveSecondaryText)
                    }
                    .listRowBackground(Color.adaptiveCard)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.adaptiveBackground)
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

    private func voiceDisplayName(for voiceId: String?) -> String {
        guard let voiceId = voiceId else { return "Default" }
        if let voice = AVSpeechSynthesisVoice(identifier: voiceId) {
            return voice.name
        }
        return "Default"
    }
}

// MARK: - Voice Picker View

struct VoicePickerView: View {
    @Binding var selectedVoiceId: String?
    @State private var speechSynthesizer = AVSpeechSynthesizer()
    @State private var previewingVoiceId: String?

    private var voicesByLanguage: [(language: String, voices: [AVSpeechSynthesisVoice])] {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        let grouped = Dictionary(grouping: allVoices) { voice -> String in
            let locale = Locale(identifier: voice.language)
            return locale.localizedString(forIdentifier: voice.language) ?? voice.language
        }
        return grouped.sorted { $0.key < $1.key }.map { (language: $0.key, voices: $0.value.sorted { $0.name < $1.name }) }
    }

    var body: some View {
        List {
            // Default option
            Section {
                Button {
                    selectedVoiceId = nil
                } label: {
                    HStack {
                        Text("System Default")
                            .foregroundColor(Color.adaptivePrimaryText)
                        Spacer()
                        if selectedVoiceId == nil {
                            Image(systemName: "checkmark")
                                .foregroundColor(Color.adaptiveAccent)
                        }
                    }
                }
            }
            .listRowBackground(Color.adaptiveCard)

            // Voices grouped by language
            ForEach(voicesByLanguage, id: \.language) { group in
                Section {
                    ForEach(group.voices, id: \.identifier) { voice in
                        HStack {
                            Button {
                                selectedVoiceId = voice.identifier
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(voice.name)
                                            .foregroundColor(Color.adaptivePrimaryText)
                                        if voice.quality == .enhanced {
                                            Text("Enhanced")
                                                .font(.caption)
                                                .foregroundColor(Color.iceBlue)
                                        }
                                    }
                                    Spacer()
                                    if selectedVoiceId == voice.identifier {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(Color.adaptiveAccent)
                                    }
                                }
                            }

                            Button {
                                previewVoice(voice)
                            } label: {
                                Image(systemName: previewingVoiceId == voice.identifier ? "stop.circle.fill" : "play.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(Color.adaptiveAccent)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                } header: {
                    Text(group.language)
                        .srOverlineStyle()
                        .foregroundStyle(Color.ash)
                }
                .listRowBackground(Color.adaptiveCard)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.adaptiveBackground)
        .navigationTitle("Select Voice")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
    }

    private func previewVoice(_ voice: AVSpeechSynthesisVoice) {
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
            if previewingVoiceId == voice.identifier {
                previewingVoiceId = nil
                return
            }
        }

        previewingVoiceId = voice.identifier
        let utterance = AVSpeechUtterance(string: "Hello, this is a preview of my voice.")
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        speechSynthesizer.speak(utterance)

        // Reset preview state when done (approximate duration)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if previewingVoiceId == voice.identifier {
                previewingVoiceId = nil
            }
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
                    .font(.custom("JetBrainsMono-Bold", size: 32))
                    .foregroundColor(index == focusIndex ? focusColor : Color.adaptivePrimaryText)
            }
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: AppSettings.self, inMemory: true)
}
