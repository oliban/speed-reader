import SwiftUI
import SwiftData

/// RSVP playback state machine states
enum RSVPState {
    case idle       // Initial state, no text loaded
    case ready      // Text loaded, ready to play
    case playing    // Currently playing (timer running)
    case paused     // Playback paused
    case finished   // Reached end of text
}

/// View for displaying RSVP (Rapid Serial Visual Presentation) reading
struct RSVPReaderView: View {
    let article: Article

    @Environment(\.modelContext) private var modelContext
    @Query private var settingsArray: [AppSettings]

    @State private var currentWordIndex: Int = 0
    @State private var words: [String] = []
    @State private var state: RSVPState = .idle
    @State private var timer: Timer?

    private var settings: AppSettings? {
        settingsArray.first
    }

    private var focusColor: Color {
        guard let settings = settings,
              let color = Color(hex: settings.focusColor) else {
            return .red
        }
        return color
    }

    private var currentWord: String {
        guard currentWordIndex < words.count else { return "" }
        return words[currentWordIndex]
    }

    private var currentRSVPWord: RSVPWord {
        splitWord(currentWord)
    }

    /// Computed property to check if currently playing
    private var isPlaying: Bool {
        state == .playing
    }

    var body: some View {
        VStack {
            Spacer()

            // Word display area
            WordDisplayView(
                rsvpWord: currentRSVPWord,
                focusColor: focusColor
            )

            Spacer()

            // Playback controls
            HStack(spacing: 40) {
                // Reset button
                Button(action: reset) {
                    Image(systemName: "backward.end.fill")
                        .font(.title2)
                }
                .disabled(state == .idle)

                // Play/Pause button
                Button(action: togglePlayPause) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.largeTitle)
                }
                .disabled(state == .idle)
            }
            .padding(.vertical, 20)

            // Progress indicator
            if !words.isEmpty {
                ProgressView(value: Double(currentWordIndex), total: Double(max(words.count - 1, 1)))
                    .padding(.horizontal, 40)

                Text("\(currentWordIndex + 1) / \(words.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)

                // State indicator for debugging/visibility
                Text(stateDescription)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }

            Spacer()
        }
        .navigationTitle("RSVP Reader")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadText()
            ensureSettingsExist()
        }
        .onDisappear {
            stopTimer()
        }
    }

    /// Human-readable state description
    private var stateDescription: String {
        switch state {
        case .idle: return "Idle"
        case .ready: return "Ready"
        case .playing: return "Playing"
        case .paused: return "Paused"
        case .finished: return "Finished"
        }
    }

    // MARK: - State Machine Transitions

    /// Loads text and transitions from IDLE to READY
    private func loadText() {
        let text = article.content.isEmpty ? article.title : article.content
        words = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        if !words.isEmpty {
            currentWordIndex = 0
            state = .ready
        }
    }

    /// Starts playback - transitions from READY or PAUSED to PLAYING
    private func play() {
        guard state == .ready || state == .paused || state == .finished else { return }

        // If finished, restart from beginning
        if state == .finished {
            currentWordIndex = 0
        }

        state = .playing
        startTimer()
    }

    /// Pauses playback - transitions from PLAYING to PAUSED
    private func pause() {
        guard state == .playing else { return }

        stopTimer()
        state = .paused
    }

    /// Handles reaching the end of text - transitions to FINISHED
    private func reachedEnd() {
        stopTimer()
        state = .finished
    }

    /// Resets to beginning - transitions to READY
    private func reset() {
        stopTimer()
        currentWordIndex = 0
        if !words.isEmpty {
            state = .ready
        } else {
            state = .idle
        }
    }

    /// Toggle between play and pause
    private func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    // MARK: - Timer Management

    private func startTimer() {
        let wpm = settings?.rsvpSpeed ?? 300
        let interval = 60.0 / Double(wpm)

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            advanceWord()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func advanceWord() {
        if currentWordIndex < words.count - 1 {
            currentWordIndex += 1
        } else {
            reachedEnd()
        }
    }

    // MARK: - Helper Methods

    private func ensureSettingsExist() {
        if settingsArray.isEmpty {
            let newSettings = AppSettings()
            modelContext.insert(newSettings)
        }
    }

    /// Splits a word into left part, focus letter, and right part for RSVP display
    private func splitWord(_ word: String) -> RSVPWord {
        guard !word.isEmpty else {
            return RSVPWord(leftPart: "", focusLetter: "", rightPart: "")
        }
        let focusIndex = word.count / 2
        let characters = Array(word)

        let leftPart = String(characters[..<focusIndex])
        let focusLetter = String(characters[focusIndex])
        let rightPart = focusIndex + 1 < characters.count ? String(characters[(focusIndex + 1)...]) : ""

        return RSVPWord(
            leftPart: leftPart,
            focusLetter: focusLetter,
            rightPart: rightPart
        )
    }
}

/// Displays a single word with the focus letter highlighted
struct WordDisplayView: View {
    let rsvpWord: RSVPWord
    let focusColor: Color

    var body: some View {
        HStack(spacing: 0) {
            // Left part - normal color, right-aligned
            Text(rsvpWord.leftPart)
                .font(.system(size: 40, weight: .medium, design: .monospaced))
                .foregroundColor(.primary)
                .frame(minWidth: 100, alignment: .trailing)

            // Focus letter - accent color
            Text(rsvpWord.focusLetter)
                .font(.system(size: 40, weight: .bold, design: .monospaced))
                .foregroundColor(focusColor)

            // Right part - normal color, left-aligned
            Text(rsvpWord.rightPart)
                .font(.system(size: 40, weight: .medium, design: .monospaced))
                .foregroundColor(.primary)
                .frame(minWidth: 100, alignment: .leading)
        }
        .padding(.horizontal, 20)
    }
}

#Preview {
    NavigationStack {
        RSVPReaderView(article: Article(
            url: "https://example.com",
            title: "Sample Article",
            content: "This is a sample article with some text to demonstrate the RSVP reader functionality."
        ))
    }
    .modelContainer(for: [Article.self, AppSettings.self], inMemory: true)
}
