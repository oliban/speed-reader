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
    @State private var tappedSentenceIndex: Int? = nil  // For tap feedback animation

    // For progress persistence
    @State private var savedProgress: ReadingProgress?
    @State private var words: [String] = []

    // Sleep timer state
    @State private var selectedSleepDuration: Int? = nil  // Duration in minutes, nil means "Off"
    @State private var sleepTimeRemaining: Int = 0  // Remaining time in seconds
    @State private var sleepTimer: Timer? = nil

    // Flag to prevent redundant handler setup
    @State private var handlersConfigured: Bool = false

    // Flag to trigger initial scroll after progress is loaded
    @State private var shouldScrollToSavedPosition: Bool = false

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

    /// Determine background color for a sentence based on current state
    private func sentenceBackgroundColor(for index: Int) -> Color {
        // Brief highlight for tapped sentence (feedback animation)
        if index == tappedSentenceIndex {
            return Color.iceBlue.opacity(0.4)
        }
        // Current playing sentence highlight
        if index == currentSentenceIndex && isPlaying && !isPaused {
            return Color.iceBlue.opacity(0.2)
        }
        // Current position when paused/stopped (dimmer highlight)
        if index == currentSentenceIndex && !isPlaying {
            return Color.iceBlue.opacity(0.1)
        }
        return Color.clear
    }

    /// Determine if current sentence should show left border highlight
    private func shouldShowLeftBorder(for index: Int) -> Bool {
        return index == currentSentenceIndex && (isPlaying || isPaused || index == tappedSentenceIndex)
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
                                .srHeadlineStyle()
                                .foregroundStyle(Color.adaptivePrimaryText)
                                .padding(.bottom, 8)
                                .accessibilityAddTraits(.isHeader)

                            // Article content with sentence highlighting
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(Array(sentences.enumerated()), id: \.offset) { index, sentence in
                                    HStack(spacing: 0) {
                                        // Left border highlight for current sentence
                                        Rectangle()
                                            .fill(shouldShowLeftBorder(for: index) ? Color.iceBlue : Color.clear)
                                            .frame(width: 3)

                                        Text(sentence)
                                            .srBodyStyle()
                                            .foregroundStyle(Color.adaptivePrimaryText)
                                            .padding(8)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .background(
                                        sentenceBackgroundColor(for: index)
                                    )
                                    .cornerRadius(8)
                                    .id(index)
                                    .accessibilityLabel(sentence)
                                    .accessibilityAddTraits(index == currentSentenceIndex && isPlaying && !isPaused ? .isSelected : [])
                                    .onTapGesture {
                                        jumpToSentence(index)
                                    }
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
                    .onChange(of: shouldScrollToSavedPosition) { oldValue, newValue in
                        // Scroll to saved position when progress is loaded
                        if newValue && currentSentenceIndex > 0 {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    proxy.scrollTo(currentSentenceIndex, anchor: .center)
                                }
                            }
                            shouldScrollToSavedPosition = false
                        }
                    }
                }

                Rectangle()
                    .fill(Color.adaptiveBorder)
                    .frame(height: 1)

                // Progress indicator - custom thin progress bar
                VStack(spacing: 4) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Track
                            Rectangle()
                                .fill(Color.smoke)
                                .frame(height: 3)
                                .cornerRadius(1.5)

                            // Fill
                            Rectangle()
                                .fill(Color.iceBlue)
                                .frame(width: geometry.size.width * CGFloat(currentSentenceIndex + 1) / CGFloat(max(sentences.count, 1)), height: 3)
                                .cornerRadius(1.5)
                        }
                    }
                    .frame(height: 3)

                    Text("\(Int(Double(currentSentenceIndex + 1) / Double(max(sentences.count, 1)) * 100))%")
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveSecondaryText)
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
                            .foregroundStyle(Color.adaptiveSecondaryText)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(speedPresets, id: \.self) { speed in
                                    Button {
                                        selectedSpeed = speed
                                    } label: {
                                        Text("\(speed, specifier: "%.1f")x")
                                            .font(.body)
                                            .fontWeight(selectedSpeed == speed ? .semibold : .regular)
                                            .foregroundStyle(selectedSpeed == speed ? Color.iceBlue : Color.ash)
                                            .frame(minWidth: 44)
                                            .padding(.vertical, 8)
                                            .padding(.horizontal, 8)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(selectedSpeed == speed ? Color.iceBlue : Color.smoke, lineWidth: 1)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 8)
                                                            .fill(selectedSpeed == speed ? Color.iceBlue.opacity(0.15) : Color.clear)
                                                    )
                                            )
                                    }
                                    .buttonStyle(.plain)
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
                            print("[DEBUG speedChange] Speed changed to \(newSpeed), restarting sentence \(currentSentenceIndex)")
                            Task {
                                // Use stopForRestart to prevent completion handler from firing
                                await ttsService.stopForRestart()
                                // Re-setup handlers with fresh closure captures
                                handlersConfigured = false
                                await setupTTSHandlersAsync()
                                // Speak current sentence with new speed - completion handler will auto-advance
                                speakCurrentSentence()
                                // Small delay then clear restart flag
                                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                                await ttsService.clearRestartFlag()
                            }
                        }
                    }

                    // Sleep timer selector
                    HStack(spacing: 12) {
                        Label("Sleep Timer", systemImage: "moon.zzz")
                            .font(.caption)
                            .foregroundStyle(Color.adaptiveSecondaryText)

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
                                        .foregroundStyle(Color.electricAmber)
                                }
                                Text(sleepTimerLabel)
                                    .font(.body)
                                    .fontWeight(sleepTimeRemaining > 0 ? .semibold : .regular)
                                    .foregroundStyle(sleepTimeRemaining > 0 ? Color.electricAmber : Color.adaptivePrimaryText)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption2)
                                    .foregroundStyle(Color.adaptiveSecondaryText)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color.adaptiveSecondary)
                            .cornerRadius(8)
                        }
                        .accessibilityLabel("Sleep Timer: \(sleepTimerLabel)")
                        .accessibilityHint("Double tap to change sleep timer duration")
                    }

                    // Playback controls
                    HStack(spacing: 32) {
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
                                .foregroundStyle(Color.voidBlack)
                                .frame(width: 60, height: 60)
                                .background(
                                    Circle()
                                        .fill(Color.iceBlue)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(isPaused || !isPlaying ? "Play" : "Pause")
                    }
                    .padding(.vertical, 8)
                }
                .padding(16)
                .background(Color.adaptiveCard)
            }
            .background(Color.adaptiveBackground)
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
                // Clean up TTS resources to prevent memory leaks and observer accumulation
                Task {
                    await ttsService.cleanup()
                }
                // Reset handlers flag so they can be set up again if view reappears
                handlersConfigured = false
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
                    shouldScrollToSavedPosition = true
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
        // Only set up handlers once to prevent accumulation of closures
        guard !handlersConfigured else {
            print("[DEBUG setupTTSHandlersAsync] Handlers already configured, skipping")
            return
        }

        print("[DEBUG setupTTSHandlersAsync] Setting up handlers, currentSentenceIndex=\(currentSentenceIndex)")
        // Set up speech progress handler - with sentence-by-sentence TTS, this just confirms current sentence
        await ttsService.setSpeechProgressHandler { characterRange in
            print("[DEBUG progressHandler] Speaking sentence \(self.currentSentenceIndex), range \(characterRange)")
        }

        // Set up speech completion handler - auto-advance to next sentence
        await ttsService.setSpeechCompletionHandler {
            print("[DEBUG completionHandler] Sentence \(self.currentSentenceIndex) finished, isPlaying=\(self.isPlaying)")

            // Check if there are more sentences to speak
            let nextIndex = self.currentSentenceIndex + 1
            if nextIndex < self.sentences.count && self.isPlaying && !self.isPaused {
                // Advance to next sentence and speak it
                self.currentSentenceIndex = nextIndex
                print("[DEBUG completionHandler] Auto-advancing to sentence \(nextIndex)")
                self.speakCurrentSentence()
            } else {
                // Reached the end or stopped
                print("[DEBUG completionHandler] Reached end or stopped, resetting")
                self.isPlaying = false
                self.isPaused = false
                self.currentSentenceIndex = 0
            }
        }

        handlersConfigured = true
    }

    // MARK: - Playback Methods

    /// Speak the current sentence only (sentence-by-sentence TTS to avoid device stuttering)
    private func speakCurrentSentence() {
        guard currentSentenceIndex < sentences.count else {
            print("[DEBUG speakCurrentSentence] No more sentences, stopping")
            isPlaying = false
            isPaused = false
            currentSentenceIndex = 0
            return
        }

        let sentence = sentences[currentSentenceIndex]
        print("[DEBUG speakCurrentSentence] Speaking sentence \(currentSentenceIndex): \"\(sentence.prefix(50))...\"")

        Task {
            do {
                try await ttsService.speak(text: sentence, speedMultiplier: selectedSpeed, voiceId: selectedVoiceId)
            } catch {
                print("[DEBUG speakCurrentSentence] Error: \(error)")
                isPlaying = false
                isPaused = false
            }
        }
    }

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
        if currentSentenceIndex <= 0 || currentSentenceIndex >= sentences.count {
            print("[DEBUG startReading] Starting from beginning (currentSentenceIndex was \(currentSentenceIndex))")
            currentSentenceIndex = 0
        } else {
            print("[DEBUG startReading] Resuming from saved position: currentSentenceIndex=\(currentSentenceIndex)")
        }

        // Speak just the current sentence - completion handler will auto-advance
        speakCurrentSentence()
    }

    private func pauseReading() {
        isPaused = true
        pauseSleepTimer()
        saveProgress()
        print("[DEBUG pauseReading] Pausing at sentence index \(currentSentenceIndex)")
        Task {
            // Use stopForRestart to suppress completion handler (which would reset currentSentenceIndex)
            // AVSpeechSynthesizer.pauseSpeaking(at: .immediate) has iOS limitations
            await ttsService.stopForRestart()
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

        Task {
            // Re-setup handlers to capture updated state with fresh closure captures
            handlersConfigured = false
            await setupTTSHandlersAsync()
            // Clear restart flag so completion handler works normally when speech finishes
            await ttsService.clearRestartFlag()
            // Speak just the current sentence - completion handler will auto-advance
            speakCurrentSentence()
        }
    }

    private func stopReading() {
        isPlaying = false
        isPaused = false
        currentSentenceIndex = 0
        stopSleepTimer()
        sleepTimeRemaining = 0

        Task {
            await ttsService.stop()
        }
    }

    /// Jump to a specific sentence when user taps on it
    private func jumpToSentence(_ index: Int) {
        guard index >= 0 && index < sentences.count else { return }

        print("[DEBUG jumpToSentence] Jumping to sentence \(index), isPlaying=\(isPlaying), isPaused=\(isPaused)")

        // Visual feedback - briefly highlight the tapped sentence
        tappedSentenceIndex = index
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            tappedSentenceIndex = nil
        }

        let wasPlaying = isPlaying && !isPaused

        if wasPlaying {
            // Stop current speech and restart from the tapped sentence
            Task {
                await ttsService.stopForRestart()

                // Update state for the new position
                currentSentenceIndex = index

                // Re-setup handlers to capture the updated state with fresh closure captures
                handlersConfigured = false
                await setupTTSHandlersAsync()

                // Speak the tapped sentence - completion handler will auto-advance
                speakCurrentSentence()

                // Small delay then clear restart flag
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                await ttsService.clearRestartFlag()
            }
        } else {
            // Not playing - just update the position
            // When user presses play, it will start from this position
            currentSentenceIndex = index
            print("[DEBUG jumpToSentence] Updated position to \(index), will start from here on play")
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

        sleepTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if self.sleepTimeRemaining > 0 {
                self.sleepTimeRemaining -= 1

                if self.sleepTimeRemaining == 0 {
                    // Timer expired - pause the reading
                    timer.invalidate()
                    self.sleepTimer = nil
                    self.pauseReading()
                    // Reset selected duration so user can set it again
                    self.selectedSleepDuration = nil
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

        sleepTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if self.sleepTimeRemaining > 0 {
                self.sleepTimeRemaining -= 1

                if self.sleepTimeRemaining == 0 {
                    // Timer expired - pause the reading
                    timer.invalidate()
                    self.sleepTimer = nil
                    self.pauseReading()
                    // Reset selected duration so user can set it again
                    self.selectedSleepDuration = nil
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
