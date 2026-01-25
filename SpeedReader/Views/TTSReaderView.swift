import SwiftUI
import SwiftData

struct TTSReaderView: View {
    let article: Article

    @Environment(\.modelContext) private var modelContext

    @State private var ttsService = TTSService()
    @State private var isPlaying: Bool = false
    @State private var isPaused: Bool = false
    @State private var selectedSpeed: Double = 1.0
    @State private var currentSentenceIndex: Int = 0
    @State private var fullText: String = ""
    @State private var sentenceRanges: [NSRange] = []

    // For progress persistence
    @State private var savedProgress: ReadingProgress?
    @State private var words: [String] = []

    // Speed presets as specified
    private let speedPresets: [Double] = [0.5, 1.0, 1.5, 2.0, 3.0, 4.0]

    // Parse content into sentences for basic highlighting
    private var sentences: [String] {
        // Simple sentence splitting - can be enhanced in TTS-004
        let content = article.content
        let sentenceEndings = CharacterSet(charactersIn: ".!?")
        var result: [String] = []
        var currentSentence = ""

        for char in content {
            currentSentence.append(char)
            if sentenceEndings.contains(char.unicodeScalars.first!) {
                let trimmed = currentSentence.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    result.append(trimmed)
                }
                currentSentence = ""
            }
        }

        // Add remaining text if any
        let trimmed = currentSentence.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            result.append(trimmed)
        }

        return result.isEmpty ? [article.content] : result
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Article text display with current sentence highlighted
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            // Title
                            Text(article.title)
                                .font(.title)
                                .fontWeight(.bold)
                                .padding(.bottom, 8)

                            // Article content with sentence highlighting
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(Array(sentences.enumerated()), id: \.offset) { index, sentence in
                                    Text(sentence)
                                        .padding(8)
                                        .background(
                                            index == currentSentenceIndex && isPlaying && !isPaused
                                                ? Color.yellow.opacity(0.3)
                                                : Color.clear
                                        )
                                        .cornerRadius(4)
                                        .id(index)
                                }
                            }
                        }
                        .padding()
                    }
                    .onChange(of: currentSentenceIndex) { oldValue, newValue in
                        // Auto-scroll to keep current sentence visible
                        if isPlaying && !isPaused {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(newValue, anchor: .center)
                            }
                        }
                    }
                }

                Divider()

                // Controls section
                VStack(spacing: 16) {
                    // Speed selector
                    VStack(spacing: 8) {
                        Text("Speed")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        HStack(spacing: 12) {
                            ForEach(speedPresets, id: \.self) { speed in
                                Button {
                                    selectedSpeed = speed
                                } label: {
                                    Text("\(speed, specifier: "%.1f")x")
                                        .font(.subheadline)
                                        .fontWeight(selectedSpeed == speed ? .bold : .regular)
                                        .frame(minWidth: 50)
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                }
                                .buttonStyle(.bordered)
                                .tint(selectedSpeed == speed ? .blue : .gray)
                            }
                        }
                    }

                    // Playback controls
                    HStack(spacing: 24) {
                        // Stop button
                        Button {
                            stopReading()
                        } label: {
                            Image(systemName: "stop.fill")
                                .font(.title2)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.bordered)
                        .disabled(!isPlaying && !isPaused)

                        // Play/Pause button
                        Button {
                            if isPlaying && !isPaused {
                                pauseReading()
                            } else if isPaused {
                                resumeReading()
                            } else {
                                startReading()
                            }
                        } label: {
                            Image(systemName: isPaused || !isPlaying ? "play.fill" : "pause.fill")
                                .font(.title)
                                .frame(width: 60, height: 60)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.vertical, 8)
                }
                .padding()
                .background(Color(.systemBackground))
            }
            .navigationTitle("Reader")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                setupTTSHandlers()
                loadWords()
                loadProgress()
            }
            .onDisappear {
                saveProgress()
            }
        }
    }

    // MARK: - Progress Persistence

    /// Load words array for tracking total word count
    private func loadWords() {
        let text = article.content.isEmpty ? article.title : article.content
        words = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
    }

    /// Calculate current word index based on sentence index
    private func currentWordIndex() -> Int {
        guard currentSentenceIndex > 0 else { return 0 }

        // Count words in all sentences before current one
        var wordCount = 0
        for i in 0..<min(currentSentenceIndex, sentences.count) {
            let sentenceWords = sentences[i].components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
            wordCount += sentenceWords.count
        }
        return wordCount
    }

    /// Calculate sentence index from word index
    private func sentenceIndex(fromWordIndex targetWordIndex: Int) -> Int {
        guard targetWordIndex > 0 else { return 0 }

        var wordCount = 0
        for (index, sentence) in sentences.enumerated() {
            let sentenceWords = sentence.components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
            wordCount += sentenceWords.count

            if wordCount > targetWordIndex {
                return index
            }
        }
        return max(0, sentences.count - 1)
    }

    /// Loads saved reading progress for this article and TTS mode
    private func loadProgress() {
        let articleId = article.id
        let descriptor = FetchDescriptor<ReadingProgress>(
            predicate: #Predicate { progress in
                progress.articleId == articleId && progress.mode == .tts
            }
        )

        do {
            let results = try modelContext.fetch(descriptor)
            if let existingProgress = results.first {
                savedProgress = existingProgress
                // Convert word index to sentence index
                let savedSentenceIndex = sentenceIndex(fromWordIndex: existingProgress.currentWordIndex)
                if savedSentenceIndex < sentences.count {
                    currentSentenceIndex = savedSentenceIndex
                }
            }
        } catch {
            // Silently fail - will start from beginning
        }
    }

    /// Saves current reading progress for this article
    private func saveProgress() {
        guard !words.isEmpty else { return }

        let wordIndex = currentWordIndex()

        if let existingProgress = savedProgress {
            // Update existing progress
            existingProgress.currentWordIndex = wordIndex
            existingProgress.totalWords = words.count
        } else {
            // Create new progress entry
            let newProgress = ReadingProgress(
                articleId: article.id,
                currentWordIndex: wordIndex,
                totalWords: words.count,
                mode: .tts
            )
            modelContext.insert(newProgress)
            savedProgress = newProgress
        }
    }

    // MARK: - Setup

    private func setupTTSHandlers() {
        Task {
            // Set up speech progress handler
            await ttsService.setSpeechProgressHandler { [self] characterRange in
                self.updateCurrentSentence(for: characterRange)
            }

            // Set up speech completion handler
            await ttsService.setSpeechCompletionHandler { [self] in
                self.isPlaying = false
                self.isPaused = false
                self.currentSentenceIndex = 0
            }
        }
    }

    private func updateCurrentSentence(for characterRange: NSRange) {
        // Find which sentence contains the current character range
        for (index, sentenceRange) in sentenceRanges.enumerated() {
            if NSIntersectionRange(characterRange, sentenceRange).length > 0 {
                currentSentenceIndex = index
                break
            }
        }
    }

    private func buildSentenceRanges() {
        fullText = sentences.joined(separator: " ")
        sentenceRanges.removeAll()

        var currentLocation = 0
        for sentence in sentences {
            let length = sentence.count
            sentenceRanges.append(NSRange(location: currentLocation, length: length))
            // Add 1 for the space separator
            currentLocation += length + 1
        }
    }

    // MARK: - Playback Methods

    private func startReading() {
        guard !sentences.isEmpty else { return }

        isPlaying = true
        isPaused = false
        currentSentenceIndex = 0

        // Build sentence ranges for tracking
        buildSentenceRanges()

        Task {
            do {
                try await ttsService.speak(text: fullText, speedMultiplier: selectedSpeed)
            } catch {
                // Handle error silently for now
                isPlaying = false
            }
        }
    }

    private func pauseReading() {
        isPaused = true
        saveProgress()
        Task {
            await ttsService.pause()
        }
    }

    private func resumeReading() {
        isPaused = false
        Task {
            await ttsService.resume()
        }
    }

    private func stopReading() {
        isPlaying = false
        isPaused = false
        currentSentenceIndex = 0

        Task {
            await ttsService.stop()
        }
    }
}

#Preview {
    TTSReaderView(
        article: Article(
            url: "https://example.com/article",
            title: "Sample Article",
            content: "This is a sample article. It has multiple sentences. Each sentence will be highlighted as it is read."
        )
    )
    .modelContainer(for: [Article.self, ReadingProgress.self], inMemory: true)
}
