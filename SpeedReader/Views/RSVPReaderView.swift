import SwiftUI
import SwiftData

/// View for displaying RSVP (Rapid Serial Visual Presentation) reading
struct RSVPReaderView: View {
    let article: Article

    @Environment(\.modelContext) private var modelContext
    @Query private var settingsArray: [AppSettings]

    @State private var currentWordIndex: Int = 0
    @State private var words: [String] = []
    @State private var isPlaying: Bool = false
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

    var body: some View {
        VStack {
            Spacer()

            // Word display area
            WordDisplayView(
                rsvpWord: currentRSVPWord,
                focusColor: focusColor
            )

            Spacer()

            // Progress indicator
            if !words.isEmpty {
                ProgressView(value: Double(currentWordIndex), total: Double(max(words.count - 1, 1)))
                    .padding(.horizontal, 40)

                Text("\(currentWordIndex + 1) / \(words.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }

            Spacer()
        }
        .navigationTitle("RSVP Reader")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadWords()
            ensureSettingsExist()
        }
        .onDisappear {
            stopTimer()
        }
    }

    private func loadWords() {
        let text = article.extractedText ?? article.title
        words = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        // Resume from saved position if available
        currentWordIndex = min(article.currentWordIndex, max(words.count - 1, 0))
    }

    private func ensureSettingsExist() {
        if settingsArray.isEmpty {
            let newSettings = AppSettings()
            modelContext.insert(newSettings)
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        isPlaying = false
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
            extractedText: "This is a sample article with some text to demonstrate the RSVP reader functionality."
        ))
    }
    .modelContainer(for: [Article.self, AppSettings.self], inMemory: true)
}
