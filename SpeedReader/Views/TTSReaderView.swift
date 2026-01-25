import SwiftUI

struct TTSReaderView: View {
    let article: Article

    @State private var ttsService = TTSService()
    @State private var isPlaying: Bool = false
    @State private var isPaused: Bool = false
    @State private var selectedSpeed: Double = 1.0
    @State private var currentSentenceIndex: Int = 0
    @State private var fullText: String = ""
    @State private var sentenceRanges: [NSRange] = []

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
                                .accessibilityAddTraits(.isHeader)

                            // Article content with sentence highlighting
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(Array(sentences.enumerated()), id: \.offset) { index, sentence in
                                    Text(sentence)
                                        .font(.body)
                                        .padding(8)
                                        .background(
                                            index == currentSentenceIndex && isPlaying && !isPaused
                                                ? Color.accentColor.opacity(0.2)
                                                : Color.clear
                                        )
                                        .cornerRadius(8)
                                        .id(index)
                                        .accessibilityLabel(sentence)
                                        .accessibilityAddTraits(index == currentSentenceIndex && isPlaying && !isPaused ? .isSelected : [])
                                }
                            }
                        }
                        .padding(16)
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
                        Label("Speed", systemImage: "gauge.with.dots.needle.50percent")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            ForEach(speedPresets, id: \.self) { speed in
                                Button {
                                    selectedSpeed = speed
                                } label: {
                                    Text("\(speed, specifier: "%.1f")x")
                                        .font(.body)
                                        .fontWeight(selectedSpeed == speed ? .semibold : .regular)
                                        .frame(minWidth: 44)
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 8)
                                }
                                .buttonStyle(.bordered)
                                .tint(selectedSpeed == speed ? .accentColor : .secondary)
                                .accessibilityLabel("\(speed, specifier: "%.1f") times speed")
                                .accessibilityAddTraits(selectedSpeed == speed ? .isSelected : [])
                            }
                        }
                    }

                    // Playback controls
                    HStack(spacing: 32) {
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
                        .accessibilityLabel("Stop")

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
                        .accessibilityLabel(isPaused || !isPlaying ? "Play" : "Pause")
                    }
                    .padding(.vertical, 8)
                }
                .padding(16)
                .background(Color(.systemBackground))
            }
            .navigationTitle("Reader")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                setupTTSHandlers()
            }
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
}
