import SwiftUI

struct TTSReaderView: View {
    let article: Article

    @State private var ttsService = TTSService()
    @State private var isPlaying: Bool = false
    @State private var isPaused: Bool = false
    @State private var selectedSpeed: Double = 1.0
    @State private var currentSentenceIndex: Int = 0

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
                            }
                        }
                    }
                    .padding()
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
        }
    }

    // MARK: - Playback Methods

    private func startReading() {
        guard !sentences.isEmpty else { return }

        isPlaying = true
        isPaused = false

        Task {
            do {
                // For now, read all sentences as one block
                // Enhanced sentence-by-sentence tracking will be in TTS-004
                let fullText = sentences.joined(separator: " ")
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
