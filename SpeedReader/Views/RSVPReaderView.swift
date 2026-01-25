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

    // Query for existing reading progress for this article and RSVP mode
    @State private var savedProgress: ReadingProgress?

    @State private var currentWordIndex: Int = 0
    @State private var words: [String] = []
    @State private var state: RSVPState = .idle
    @State private var timer: Timer?
    @State private var currentSpeed: Double = 300
    @State private var showContext: Bool = false
    @State private var tokenizedText: TokenizedText?

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

    /// Returns the current paragraph index for the current word
    private var currentParagraphIndex: Int? {
        guard let tokenizedText = tokenizedText,
              currentWordIndex < tokenizedText.paragraphIndices.count else {
            return nil
        }
        return tokenizedText.paragraphIndices[currentWordIndex]
    }

    /// Returns the current paragraph text
    private var currentParagraph: String? {
        guard let tokenizedText = tokenizedText,
              let paragraphIndex = currentParagraphIndex,
              paragraphIndex < tokenizedText.paragraphs.count else {
            return nil
        }
        return tokenizedText.paragraphs[paragraphIndex]
    }

    /// Returns the index of the current word within its paragraph
    private var wordIndexInParagraph: Int? {
        guard let tokenizedText = tokenizedText,
              let currentParagraphIdx = currentParagraphIndex else {
            return nil
        }

        var indexInParagraph = 0
        for i in 0..<currentWordIndex {
            if tokenizedText.paragraphIndices[i] == currentParagraphIdx {
                indexInParagraph += 1
            }
        }
        return indexInParagraph
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top spacer - weighted to give more space to word display
            Spacer()
                .frame(minHeight: 60)

            // Word display area - FIXED HEIGHT container for stable reading
            WordDisplayView(
                rsvpWord: currentRSVPWord,
                focusColor: focusColor
            )
            .frame(maxWidth: .infinity)
            .frame(height: 120) // Fixed height - word display never changes size
            .padding(.vertical, 20)

            // Context view - collapsible section showing current paragraph
            // Stays visible during playback if user has expanded it
            if tokenizedText != nil {
                ContextView(
                    isExpanded: $showContext,
                    currentParagraph: currentParagraph,
                    currentWord: currentWord,
                    wordIndexInParagraph: wordIndexInParagraph,
                    focusColor: focusColor
                )
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .opacity(isPlaying && !showContext ? 0.0 : 1.0)
                .animation(.easeInOut(duration: 0.3), value: isPlaying)
            }

            Spacer()
                .frame(minHeight: 40)

            // Controls section - fades during playback to reduce distraction
            VStack(spacing: 12) {
                // Playback controls - fade during playback except play/pause
                HStack(spacing: 24) {
                    // Reset button
                    Button(action: reset) {
                        Image(systemName: "backward.end.fill")
                            .font(.body)
                            .frame(width: 36, height: 36)
                    }
                    .disabled(state == .idle)
                    .accessibilityLabel("Reset to beginning")
                    .opacity(isPlaying ? 0.0 : 1.0)

                    // Skip backward button (5 words)
                    Button(action: skipBackward) {
                        Image(systemName: "gobackward.5")
                            .font(.body)
                            .frame(width: 36, height: 36)
                    }
                    .disabled(state == .idle)
                    .accessibilityLabel("Skip back 5 words")
                    .opacity(isPlaying ? 0.0 : 1.0)

                    // Play/Pause button - always visible (slightly faded when playing)
                    Button(action: togglePlayPause) {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.title2)
                            .frame(width: 50, height: 50)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(state == .idle)
                    .accessibilityLabel(isPlaying ? "Pause" : "Play")
                    .opacity(isPlaying ? 0.4 : 1.0)

                    // Skip forward button (5 words)
                    Button(action: skipForward) {
                        Image(systemName: "goforward.5")
                            .font(.body)
                            .frame(width: 36, height: 36)
                    }
                    .disabled(state == .idle)
                    .accessibilityLabel("Skip forward 5 words")
                    .opacity(isPlaying ? 0.0 : 1.0)
                }
                .animation(.easeInOut(duration: 0.3), value: isPlaying)

                // Speed slider - hidden during playback
                HStack(spacing: 8) {
                    Image(systemName: "speedometer")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text("\(Int(currentSpeed))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 32, alignment: .trailing)

                    Slider(value: $currentSpeed, in: 120...900, step: 10)
                        .onChange(of: currentSpeed) { _, newValue in
                            updateSpeed(to: Int(newValue))
                        }
                        .accessibilityLabel("Reading speed")
                        .accessibilityValue("\(Int(currentSpeed)) words per minute")

                    Text("WPM")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)
                .opacity(isPlaying ? 0.0 : 1.0)
                .animation(.easeInOut(duration: 0.3), value: isPlaying)

                // Progress indicator - always show progress bar, hide details when playing
                if !words.isEmpty {
                    VStack(spacing: 4) {
                        ProgressView(value: Double(currentWordIndex), total: Double(max(words.count - 1, 1)))
                            .accessibilityLabel("Reading progress")
                            .accessibilityValue("Word \(currentWordIndex + 1) of \(words.count)")

                        HStack(spacing: 8) {
                            Text("\(currentWordIndex + 1)/\(words.count)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            Text("·")
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            HStack(spacing: 2) {
                                Image(systemName: stateIcon)
                                    .font(.caption2)
                                Text(stateDescription)
                                    .font(.caption2)
                            }
                            .foregroundStyle(.secondary)
                        }
                        .opacity(isPlaying ? 0.0 : 1.0)
                        .animation(.easeInOut(duration: 0.3), value: isPlaying)
                    }
                    .padding(.horizontal, 24)
                }
            }
            .padding(.bottom, 16)
        }
        .navigationTitle("RSVP Reader")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadText()
            ensureSettingsExist()
            // Note: loadProgress() is called after words are populated in loadText()
            // Initialize currentSpeed from saved settings
            if let settings = settings {
                currentSpeed = Double(settings.rsvpSpeed)
            }
        }
        .onDisappear {
            stopTimer()
            saveProgress()
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

    /// SF Symbol icon for current state
    private var stateIcon: String {
        switch state {
        case .idle: return "circle"
        case .ready: return "circle.fill"
        case .playing: return "play.circle.fill"
        case .paused: return "pause.circle.fill"
        case .finished: return "checkmark.circle.fill"
        }
    }

    // MARK: - State Machine Transitions

    /// Loads text and transitions from IDLE to READY
    private func loadText() {
        let text = article.content.isEmpty ? article.title : article.content

        // Use TextTokenizer to tokenize text and get paragraph mappings
        Task {
            let tokenizer = TextTokenizer()
            let result = await tokenizer.tokenize(text)

            await MainActor.run {
                tokenizedText = result
                words = result.words

                if !words.isEmpty {
                    state = .ready
                    // Load progress after words are populated
                    loadProgress()
                }
            }
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
        saveProgress()
    }

    // MARK: - Progress Persistence

    /// Loads saved reading progress for this article and RSVP mode
    private func loadProgress() {
        let articleId = article.id
        // Fetch all progress for this article, then filter by mode in Swift code
        // SwiftData predicates have issues with enum comparisons
        let descriptor = FetchDescriptor<ReadingProgress>(
            predicate: #Predicate { progress in
                progress.articleId == articleId
            }
        )

        do {
            let results = try modelContext.fetch(descriptor)
            // Filter for RSVP mode in Swift code instead of predicate
            if let existingProgress = results.first(where: { $0.mode == .rsvp }) {
                savedProgress = existingProgress
                // Only restore position if within valid range
                if existingProgress.currentWordIndex < words.count {
                    currentWordIndex = existingProgress.currentWordIndex
                    // If we have a saved position, transition to ready state
                    if currentWordIndex > 0 && state == .ready {
                        state = .paused
                    }
                }
            }
        } catch {
            // Silently fail - will start from beginning
        }
    }

    /// Saves current reading progress for this article
    private func saveProgress() {
        guard !words.isEmpty else { return }

        if let existingProgress = savedProgress {
            // Update existing progress
            existingProgress.currentWordIndex = currentWordIndex
            existingProgress.totalWords = words.count
        } else {
            // Create new progress entry
            let newProgress = ReadingProgress(
                articleId: article.id,
                currentWordIndex: currentWordIndex,
                totalWords: words.count,
                mode: .rsvp
            )
            modelContext.insert(newProgress)
            savedProgress = newProgress
        }
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

    /// Skip backward 5 words
    private func skipBackward() {
        currentWordIndex = max(0, currentWordIndex - 5)

        // If we were finished and skip back, transition to ready or paused state
        if state == .finished {
            state = .ready
        }
    }

    /// Skip forward 5 words
    private func skipForward() {
        let maxIndex = words.count - 1
        currentWordIndex = min(maxIndex, currentWordIndex + 5)

        // If we reach the end while not playing, transition to finished
        if currentWordIndex >= maxIndex && state != .playing {
            state = .finished
        }
    }

    /// Update the playback speed
    private func updateSpeed(to wpm: Int) {
        // Save the speed to settings
        if let settings = settings {
            settings.rsvpSpeed = wpm
        }

        // If currently playing, restart timer with new speed
        if state == .playing {
            stopTimer()
            startTimer()
        }
    }

    // MARK: - Timer Management

    private func startTimer() {
        let interval = 60.0 / currentSpeed

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

/// Displays a single word with the focus letter highlighted at a fixed center position.
/// Uses absolute positioning to ensure the focus letter is always at the exact same
/// screen location regardless of word length.
struct WordDisplayView: View {
    let rsvpWord: RSVPWord
    let focusColor: Color

    // Font configuration
    private let fontSize: CGFloat = 48

    // Monospaced font character width is approximately 0.6 * fontSize
    private var charWidth: CGFloat { fontSize * 0.6 }

    var body: some View {
        GeometryReader { geometry in
            let centerX = geometry.size.width / 2
            let centerY = geometry.size.height / 2
            // Half the character width - distance from center to edge of focus letter
            let halfChar = charWidth / 2

            ZStack {
                // Focus letter - always at exact center of screen
                Text(rsvpWord.focusLetter)
                    .font(.system(size: fontSize, weight: .bold, design: .monospaced))
                    .foregroundColor(focusColor)
                    .fixedSize()
                    .position(x: centerX, y: centerY)

                // Left part - right-aligned, positioned so right edge meets left edge of focus letter
                Text(rsvpWord.leftPart)
                    .font(.system(size: fontSize, weight: .medium, design: .monospaced))
                    .foregroundColor(.primary)
                    .fixedSize()
                    .frame(maxWidth: centerX - halfChar, alignment: .trailing)
                    .position(x: (centerX - halfChar) / 2, y: centerY)

                // Right part - left-aligned, positioned so left edge meets right edge of focus letter
                Text(rsvpWord.rightPart)
                    .font(.system(size: fontSize, weight: .medium, design: .monospaced))
                    .foregroundColor(.primary)
                    .fixedSize()
                    .frame(maxWidth: centerX - halfChar, alignment: .leading)
                    .position(x: centerX + halfChar + (centerX - halfChar) / 2, y: centerY)
            }
        }
    }
}

/// Collapsible context view showing the current paragraph with the current word highlighted
struct ContextView: View {
    @Binding var isExpanded: Bool
    let currentParagraph: String?
    let currentWord: String
    let wordIndexInParagraph: Int?
    let focusColor: Color

    var body: some View {
        DisclosureGroup(
            isExpanded: $isExpanded,
            content: {
                if let paragraph = currentParagraph {
                    HighlightedParagraphView(
                        paragraph: paragraph,
                        currentWord: currentWord,
                        wordIndexInParagraph: wordIndexInParagraph,
                        highlightColor: focusColor
                    )
                    .padding(.top, 8)
                } else {
                    Text("No context available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
            },
            label: {
                HStack {
                    Image(systemName: "text.alignleft")
                        .foregroundColor(.secondary)
                    Text("Context")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        )
        .tint(.secondary)
    }
}

/// View that displays a paragraph with the current word highlighted
struct HighlightedParagraphView: View {
    let paragraph: String
    let currentWord: String
    let wordIndexInParagraph: Int?
    let highlightColor: Color

    var body: some View {
        let words = paragraph.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

        // Build attributed text with highlighted word
        Text(buildAttributedString(words: words))
            .font(.system(size: 14))
            .lineSpacing(4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(8)
    }

    private func buildAttributedString(words: [String]) -> AttributedString {
        var result = AttributedString()

        for (index, word) in words.enumerated() {
            var attributedWord = AttributedString(word)

            // Highlight the current word
            if let targetIndex = wordIndexInParagraph, index == targetIndex {
                attributedWord.backgroundColor = highlightColor.opacity(0.3)
                attributedWord.foregroundColor = .primary
            }

            result.append(attributedWord)

            // Add space between words (except after the last word)
            if index < words.count - 1 {
                result.append(AttributedString(" "))
            }
        }

        return result
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
