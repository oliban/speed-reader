import SwiftUI
import SwiftData

struct TTSReaderView: View {
    let article: Article

    @Environment(\.modelContext) private var modelContext
    @Query private var settingsArray: [AppSettings]

    @State private var ttsService = TTSService()
    @State private var isPlaying: Bool = false
    @State private var isPaused: Bool = false
    @State private var selectedSpeed: Double = 1.0
    @State private var currentSentenceIndex: Int = 0
    @State private var fullText: String = ""
    @State private var sentenceRanges: [NSRange] = []
    @State private var speechStartSentenceIndex: Int = 0  // Tracks which sentence we started speaking from

    // For progress persistence
    @State private var savedProgress: ReadingProgress?
    @State private var words: [String] = []

    // Sleep timer state
    @State private var selectedSleepDuration: Int? = nil  // Duration in minutes, nil means "Off"
    @State private var sleepTimeRemaining: Int = 0  // Remaining time in seconds
    @State private var sleepTimer: Timer? = nil

    // Speed presets as specified
    private let speedPresets: [Double] = [0.5, 1.0, 1.5, 2.0, 3.0, 4.0]

    // Sleep timer presets in minutes
    private let sleepPresets: [Int?] = [nil, 5, 10, 15, 30, 45, 60]

    // Get the selected voice ID from settings
    private var selectedVoiceId: String? {
        settingsArray.first?.selectedVoiceId
    }

    // Format sleep timer remaining time as "MM:SS"
    private var sleepTimeRemainingFormatted: String {
        let minutes = sleepTimeRemaining / 60
        let seconds = sleepTimeRemaining % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // Label for sleep timer menu button
    private var sleepTimerLabel: String {
        if sleepTimeRemaining > 0 {
            return sleepTimeRemainingFormatted
        } else if let duration = selectedSleepDuration {
            return "\(duration) min"
        } else {
            return "Off"
        }
    }

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

                // Progress indicator
                VStack(spacing: 4) {
                    ProgressView(value: Double(currentSentenceIndex + 1), total: Double(max(sentences.count, 1)))
                        .progressViewStyle(.linear)
                        .tint(.accentColor)

                    Text("\(Int(Double(currentSentenceIndex + 1) / Double(max(sentences.count, 1)) * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Progress: \(Int(Double(currentSentenceIndex + 1) / Double(max(sentences.count, 1)) * 100)) percent")

                // Controls section
                VStack(spacing: 16) {
                    // Speed selector
                    VStack(spacing: 8) {
                        Label("Speed", systemImage: "gauge.with.dots.needle.50percent")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ScrollView(.horizontal, showsIndicators: false) {
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
                            .padding(.horizontal, 16)
                        }
                    }
                    .onChange(of: selectedSpeed) { _, newSpeed in
                        // Restart with new speed if currently playing
                        if isPlaying && !isPaused {
                            // Capture current state before async work
                            let sentenceToResumeFrom = currentSentenceIndex
                            print("[DEBUG speedChange] Speed changed to \(newSpeed), restarting from sentence \(sentenceToResumeFrom)")
                            Task {
                                // Use stopForRestart to prevent completion handler from firing
                                await ttsService.stopForRestart()
                                print("[DEBUG speedChange] After stopForRestart, isPlaying=\(isPlaying)")
                                // Update the starting index for the new speech segment
                                speechStartSentenceIndex = sentenceToResumeFrom
                                buildSentenceRanges(startingFrom: sentenceToResumeFrom)
                                print("[DEBUG speedChange] Built \(sentenceRanges.count) sentence ranges starting from index \(speechStartSentenceIndex)")
                                // Re-setup handlers to capture the updated sentenceRanges and speechStartSentenceIndex
                                // Must await to ensure handlers are set before speech starts
                                await setupTTSHandlersAsync()
                                print("[DEBUG speedChange] Handlers re-setup, isPlaying=\(isPlaying)")
                                // Resume from current sentence
                                let textFromCurrent = sentences[sentenceToResumeFrom...].joined(separator: " ")
                                do {
                                    try await ttsService.speak(text: textFromCurrent, speedMultiplier: newSpeed, voiceId: selectedVoiceId)
                                    print("[DEBUG speedChange] speak() completed, isPlaying=\(isPlaying)")
                                    // Add a small delay before clearing restart flag to ensure any pending
                                    // completion handlers from the old utterance have already been processed
                                    try await Task.sleep(nanoseconds: 100_000_000) // 100ms
                                    await ttsService.clearRestartFlag()
                                    print("[DEBUG speedChange] Restart flag cleared, isPlaying=\(isPlaying)")
                                    // Ensure isPlaying is true after speed change completes
                                    // This guards against any race condition with completion handler
                                    if !isPlaying {
                                        print("[DEBUG speedChange] WARNING: isPlaying was false, restoring to true")
                                        isPlaying = true
                                        isPaused = false
                                    }
                                } catch {
                                    await ttsService.clearRestartFlag()
                                    isPlaying = false
                                    print("[DEBUG speedChange] Error during speak: \(error)")
                                }
                            }
                        }
                    }

                    // Sleep timer selector
                    HStack(spacing: 12) {
                        Label("Sleep Timer", systemImage: "moon.zzz")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Menu {
                            ForEach(sleepPresets, id: \.self) { preset in
                                Button {
                                    selectSleepDuration(preset)
                                } label: {
                                    if let minutes = preset {
                                        Label("\(minutes) min", systemImage: selectedSleepDuration == preset ? "checkmark" : "")
                                    } else {
                                        Label("Off", systemImage: selectedSleepDuration == nil ? "checkmark" : "")
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                if sleepTimeRemaining > 0 {
                                    Image(systemName: "timer")
                                        .foregroundStyle(.orange)
                                }
                                Text(sleepTimerLabel)
                                    .font(.body)
                                    .fontWeight(sleepTimeRemaining > 0 ? .semibold : .regular)
                                    .foregroundStyle(sleepTimeRemaining > 0 ? .orange : .primary)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                        }
                        .accessibilityLabel("Sleep Timer: \(sleepTimerLabel)")
                        .accessibilityHint("Double tap to change sleep timer duration")
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
                print("[DEBUG onAppear] TTSReaderView appearing for article: \(article.id)")
                setupTTSHandlers()
                loadWords()
                print("[DEBUG onAppear] Loaded \(words.count) words, sentences.count=\(sentences.count)")
                loadProgress()
                print("[DEBUG onAppear] After loadProgress: currentSentenceIndex=\(currentSentenceIndex)")
            }
            .onDisappear {
                print("[DEBUG onDisappear] TTSReaderView disappearing, currentSentenceIndex=\(currentSentenceIndex)")
                saveProgress()
                stopSleepTimer()
                // Stop TTS to prevent multiple voices playing if user reopens article
                Task {
                    await ttsService.stop()
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
        print("[DEBUG currentWordIndex] currentSentenceIndex=\(currentSentenceIndex)")
        guard currentSentenceIndex > 0 else {
            print("[DEBUG currentWordIndex] currentSentenceIndex <= 0, returning 0")
            return 0
        }

        // Count words in all sentences before current one
        var wordCount = 0
        for i in 0..<min(currentSentenceIndex, sentences.count) {
            let sentenceWords = sentences[i].components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
            wordCount += sentenceWords.count
        }
        print("[DEBUG currentWordIndex] Calculated wordCount=\(wordCount)")
        return wordCount
    }

    /// Calculate sentence index from word index
    private func sentenceIndex(fromWordIndex targetWordIndex: Int) -> Int {
        print("[DEBUG sentenceIndex] targetWordIndex=\(targetWordIndex)")
        guard targetWordIndex > 0 else {
            print("[DEBUG sentenceIndex] targetWordIndex <= 0, returning 0")
            return 0
        }

        var wordCount = 0
        for (index, sentence) in sentences.enumerated() {
            let sentenceWords = sentence.components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
            wordCount += sentenceWords.count
            print("[DEBUG sentenceIndex] Sentence \(index): \(sentenceWords.count) words, cumulative=\(wordCount)")

            if wordCount > targetWordIndex {
                print("[DEBUG sentenceIndex] Found at index \(index)")
                return index
            }
        }
        print("[DEBUG sentenceIndex] Reached end, returning \(max(0, sentences.count - 1))")
        return max(0, sentences.count - 1)
    }

    /// Loads saved reading progress for this article and TTS mode
    private func loadProgress() {
        let articleId = article.id
        print("[DEBUG loadProgress] Looking for progress: articleId=\(articleId), mode=tts")
        // Fetch all progress for this article, then filter by mode in Swift code
        // SwiftData predicates have issues with enum comparisons
        let descriptor = FetchDescriptor<ReadingProgress>(
            predicate: #Predicate { progress in
                progress.articleId == articleId
            }
        )

        do {
            let results = try modelContext.fetch(descriptor)
            print("[DEBUG loadProgress] Found \(results.count) progress records for article")
            // Filter for TTS mode in Swift code instead of predicate
            if let existingProgress = results.first(where: { $0.mode == .tts }) {
                savedProgress = existingProgress
                print("[DEBUG loadProgress] Existing progress found: wordIndex=\(existingProgress.currentWordIndex), totalWords=\(existingProgress.totalWords)")
                // Convert word index to sentence index
                let savedSentenceIndex = sentenceIndex(fromWordIndex: existingProgress.currentWordIndex)
                print("[DEBUG loadProgress] Calculated sentenceIndex=\(savedSentenceIndex) from wordIndex=\(existingProgress.currentWordIndex)")
                if savedSentenceIndex < sentences.count {
                    currentSentenceIndex = savedSentenceIndex
                    print("[DEBUG loadProgress] Set currentSentenceIndex to \(savedSentenceIndex)")
                } else {
                    print("[DEBUG loadProgress] savedSentenceIndex \(savedSentenceIndex) >= sentences.count \(sentences.count), NOT setting")
                }
            } else {
                print("[DEBUG loadProgress] No existing TTS progress found")
            }
        } catch {
            print("[DEBUG loadProgress] Error fetching: \(error)")
            // Silently fail - will start from beginning
        }
    }

    /// Saves current reading progress for this article
    private func saveProgress() {
        guard !words.isEmpty else {
            print("[DEBUG saveProgress] No words, skipping save")
            return
        }

        let wordIndex = currentWordIndex()
        print("[DEBUG saveProgress] Saving: currentSentenceIndex=\(currentSentenceIndex), wordIndex=\(wordIndex), totalWords=\(words.count)")

        if let existingProgress = savedProgress {
            // Update existing progress
            existingProgress.currentWordIndex = wordIndex
            existingProgress.totalWords = words.count
            print("[DEBUG saveProgress] Updated existing progress record")
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
            print("[DEBUG saveProgress] Created new progress record")
        }

        // Force save to ensure persistence
        do {
            try modelContext.save()
            print("[DEBUG saveProgress] Explicit save successful")
        } catch {
            print("[DEBUG saveProgress] Explicit save failed: \(error)")
        }
    }

    // MARK: - Setup

    private func setupTTSHandlers() {
        Task {
            await setupTTSHandlersAsync()
        }
    }

    private func setupTTSHandlersAsync() async {
        print("[DEBUG setupTTSHandlersAsync] Setting up handlers, currentSentenceIndex=\(currentSentenceIndex), speechStartSentenceIndex=\(speechStartSentenceIndex)")
        // Set up speech progress handler
        await ttsService.setSpeechProgressHandler { [self] characterRange in
            print("[DEBUG progressHandler] Called with range \(characterRange), isPlaying=\(isPlaying)")
            self.updateCurrentSentence(for: characterRange)
        }

        // Set up speech completion handler
        await ttsService.setSpeechCompletionHandler { [self] in
            print("[DEBUG completionHandler] Speech finished, resetting to index 0, current isPlaying=\(isPlaying)")
            self.isPlaying = false
            self.isPaused = false
            self.currentSentenceIndex = 0
        }
    }

    private func updateCurrentSentence(for characterRange: NSRange) {
        // Find which sentence contains the current character range
        // sentenceRanges is relative to the text being spoken, which starts at speechStartSentenceIndex
        for (index, sentenceRange) in sentenceRanges.enumerated() {
            if NSIntersectionRange(characterRange, sentenceRange).length > 0 {
                // Add the offset to get the actual sentence index in the full sentences array
                currentSentenceIndex = speechStartSentenceIndex + index
                break
            }
        }
    }

    private func buildSentenceRanges(startingFrom startIndex: Int = 0) {
        let sentencesToSpeak = Array(sentences[startIndex...])
        fullText = sentencesToSpeak.joined(separator: " ")
        sentenceRanges.removeAll()

        // Use UTF-16 code unit counts to match AVSpeechSynthesizer's NSRange reporting
        var currentLocation = 0
        for sentence in sentencesToSpeak {
            let utf16Length = sentence.utf16.count
            sentenceRanges.append(NSRange(location: currentLocation, length: utf16Length))
            // Add 1 for the space separator (space is 1 UTF-16 code unit)
            currentLocation += utf16Length + 1
        }
    }

    // MARK: - Playback Methods

    private func startReading() {
        guard !sentences.isEmpty else { return }

        print("[DEBUG startReading] Called with currentSentenceIndex=\(currentSentenceIndex), sentences.count=\(sentences.count)")

        isPlaying = true
        isPaused = false

        // Start sleep timer if a duration is selected
        if let minutes = selectedSleepDuration {
            startSleepTimer(minutes: minutes)
        }

        // Resume from saved position if available, otherwise start from beginning
        let textToSpeak: String
        if currentSentenceIndex > 0 && currentSentenceIndex < sentences.count {
            // Resume from saved position
            print("[DEBUG startReading] Resuming from saved position: currentSentenceIndex=\(currentSentenceIndex)")
            speechStartSentenceIndex = currentSentenceIndex
            textToSpeak = sentences[currentSentenceIndex...].joined(separator: " ")
        } else {
            // Start from beginning
            print("[DEBUG startReading] Starting from beginning (currentSentenceIndex was \(currentSentenceIndex))")
            currentSentenceIndex = 0
            speechStartSentenceIndex = 0
            textToSpeak = sentences.joined(separator: " ")
        }

        // Build sentence ranges for tracking - must match the text we're speaking
        buildSentenceRanges(startingFrom: speechStartSentenceIndex)

        Task {
            do {
                try await ttsService.speak(text: textToSpeak, speedMultiplier: selectedSpeed, voiceId: selectedVoiceId)
            } catch {
                // Handle error silently for now
                isPlaying = false
                stopSleepTimer()
            }
        }
    }

    private func pauseReading() {
        isPaused = true
        pauseSleepTimer()
        saveProgress()
        print("[DEBUG pauseReading] Pausing at sentence index \(currentSentenceIndex)")
        Task {
            // Use stop instead of pause for immediate effect
            // AVSpeechSynthesizer.pauseSpeaking(at: .immediate) has iOS limitations
            await ttsService.stop()
        }
    }

    private func resumeReading() {
        isPaused = false
        resumeSleepTimer()
        print("[DEBUG resumeReading] Resuming from sentence index \(currentSentenceIndex)")

        // Since we used stop (not pause) for immediate effect, we must restart from current position
        guard currentSentenceIndex < sentences.count else {
            isPlaying = false
            isPaused = false
            return
        }

        // Update tracking state for the new speech segment
        speechStartSentenceIndex = currentSentenceIndex
        let textToSpeak = sentences[currentSentenceIndex...].joined(separator: " ")
        buildSentenceRanges(startingFrom: currentSentenceIndex)

        Task {
            // Re-setup handlers to capture updated state
            await setupTTSHandlersAsync()
            do {
                try await ttsService.speak(text: textToSpeak, speedMultiplier: selectedSpeed, voiceId: selectedVoiceId)
            } catch {
                print("[DEBUG resumeReading] Error: \(error)")
                isPlaying = false
                isPaused = false
            }
        }
    }

    private func stopReading() {
        isPlaying = false
        isPaused = false
        currentSentenceIndex = 0
        speechStartSentenceIndex = 0
        stopSleepTimer()
        sleepTimeRemaining = 0

        Task {
            await ttsService.stop()
        }
    }

    // MARK: - Sleep Timer Methods

    /// Select a sleep timer duration and start/stop the timer accordingly
    private func selectSleepDuration(_ duration: Int?) {
        selectedSleepDuration = duration

        // Stop any existing timer
        stopSleepTimer()

        // If a duration is selected and we're playing, start the timer
        if let minutes = duration, isPlaying && !isPaused {
            startSleepTimer(minutes: minutes)
        } else if duration == nil {
            // Timer turned off
            sleepTimeRemaining = 0
        }
    }

    /// Start the sleep timer countdown
    private func startSleepTimer(minutes: Int) {
        sleepTimeRemaining = minutes * 60

        sleepTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [self] timer in
            if sleepTimeRemaining > 0 {
                sleepTimeRemaining -= 1

                if sleepTimeRemaining == 0 {
                    // Timer expired - pause the reading
                    timer.invalidate()
                    sleepTimer = nil
                    pauseReading()
                    // Reset selected duration so user can set it again
                    selectedSleepDuration = nil
                }
            }
        }
    }

    /// Stop the sleep timer
    private func stopSleepTimer() {
        sleepTimer?.invalidate()
        sleepTimer = nil
    }

    /// Pause the sleep timer (when TTS is paused)
    private func pauseSleepTimer() {
        sleepTimer?.invalidate()
        sleepTimer = nil
        // Keep sleepTimeRemaining so we can resume
    }

    /// Resume the sleep timer (when TTS is resumed)
    private func resumeSleepTimer() {
        guard sleepTimeRemaining > 0, selectedSleepDuration != nil else { return }

        sleepTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [self] timer in
            if sleepTimeRemaining > 0 {
                sleepTimeRemaining -= 1

                if sleepTimeRemaining == 0 {
                    // Timer expired - pause the reading
                    timer.invalidate()
                    sleepTimer = nil
                    pauseReading()
                    // Reset selected duration so user can set it again
                    selectedSleepDuration = nil
                }
            }
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
