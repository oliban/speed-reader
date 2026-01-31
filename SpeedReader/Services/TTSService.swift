import Foundation
import AVFoundation

/// Errors that can occur during text-to-speech operations
enum TTSServiceError: LocalizedError {
    case synthesisFailure
    case invalidText
    case audioSessionError

    var errorDescription: String? {
        switch self {
        case .synthesisFailure:
            return "Failed to synthesize speech."
        case .invalidText:
            return "Invalid or empty text provided."
        case .audioSessionError:
            return "Failed to configure audio session."
        }
    }
}

/// Service for text-to-speech functionality using AVSpeechSynthesizer
actor TTSService: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer: AVSpeechSynthesizer
    private let audioSession = AVAudioSession.sharedInstance()
    private var speechProgressHandler: ((NSRange) -> Void)?
    private var speechCompletionHandler: (() -> Void)?
    private var isRestarting: Bool = false  // Flag to suppress completion during speed change
    private var interruptionObserver: NSObjectProtocol?  // Store observer for cleanup

    override init() {
        self.synthesizer = AVSpeechSynthesizer()
        super.init()
        self.synthesizer.delegate = self
        setupAudioSession()
        setupInterruptionHandling()
    }

    /// Configures the audio session for background playback
    private func setupAudioSession() {
        do {
            // Configure for playback with mixWithOthers option
            try audioSession.setCategory(.playback, mode: .spokenAudio, options: [.mixWithOthers])
            try audioSession.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error.localizedDescription)")
        }
    }

    /// Sets up audio interruption handling
    private func setupInterruptionHandling() {
        // Store the observer so we can remove it during cleanup
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: audioSession,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let userInfo = notification.userInfo,
                  let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
                return
            }

            Task {
                await self.handleInterruption(type: type, userInfo: userInfo)
            }
        }
    }

    /// Handles audio interruptions (e.g., phone calls, other audio)
    private func handleInterruption(type: AVAudioSession.InterruptionType, userInfo: [AnyHashable: Any]) {
        switch type {
        case .began:
            // Interruption began - stop speech immediately
            // Using stopSpeaking instead of pauseSpeaking for immediate effect
            if synthesizer.isSpeaking {
                synthesizer.stopSpeaking(at: .immediate)
            }
        case .ended:
            // Interruption ended - optionally resume
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else {
                return
            }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                do {
                    try audioSession.setActive(true)
                    if synthesizer.isPaused {
                        synthesizer.continueSpeaking()
                    }
                } catch {
                    print("Failed to reactivate audio session: \(error.localizedDescription)")
                }
            }
        @unknown default:
            break
        }
    }

    /// Sets the handler to be called when speech progress updates
    /// - Parameter handler: Closure called with the current character range being spoken
    func setSpeechProgressHandler(_ handler: @escaping (NSRange) -> Void) {
        speechProgressHandler = handler
    }

    /// Sets the handler to be called when speech completes
    /// - Parameter handler: Closure called when speech finishes
    func setSpeechCompletionHandler(_ handler: @escaping () -> Void) {
        speechCompletionHandler = handler
    }

    /// Speaks the provided text using the specified speed multiplier
    /// - Parameters:
    ///   - text: The text to speak
    ///   - speedMultiplier: Speed multiplier (default 1.0). Applied to base rate of 0.5
    ///   - voiceId: Optional voice identifier to use for speech
    func speak(text: String, speedMultiplier: Double = 1.0, voiceId: String? = nil) throws {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TTSServiceError.invalidText
        }

        let utterance = AVSpeechUtterance(string: text)

        // Map speed multiplier to AVSpeechUtterance rate
        // Base rate is 0.5, multiply by speedMultiplier
        // AVSpeechUtterance rate range: AVSpeechUtteranceMinimumSpeechRate (0.0) to AVSpeechUtteranceMaximumSpeechRate (1.0)
        let baseRate: Float = 0.5
        let calculatedRate = baseRate * Float(speedMultiplier)
        utterance.rate = max(AVSpeechUtteranceMinimumSpeechRate, min(calculatedRate, AVSpeechUtteranceMaximumSpeechRate))

        // Set voice if specified
        if let voiceId = voiceId {
            utterance.voice = AVSpeechSynthesisVoice(identifier: voiceId)
        }

        print("[DEBUG TTSService.speak] Starting speech with rate=\(utterance.rate), isRestarting=\(isRestarting), hasProgressHandler=\(speechProgressHandler != nil)")
        synthesizer.speak(utterance)
    }

    /// Pauses speech synthesis immediately by stopping (pauseSpeaking has iOS limitations)
    /// Note: AVSpeechSynthesizer.pauseSpeaking(at: .immediate) does not actually pause immediately
    /// on iOS - it often waits for the current word/phrase to finish. Using stopSpeaking instead
    /// provides true immediate stopping. The caller must track position and restart on resume.
    func pause() {
        print("[DEBUG TTSService.pause] Stopping speech immediately (using stop, not pause)")
        synthesizer.stopSpeaking(at: .immediate)
    }

    /// Resumes paused speech synthesis
    /// Note: After using stop-based pause, this won't work - caller must restart speech from position
    func resume() {
        print("[DEBUG TTSService.resume] Attempting continueSpeaking")
        synthesizer.continueSpeaking()
    }

    /// Stops speech synthesis immediately
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    /// Cleans up all resources: removes observer and clears handlers
    /// Call this when the view disappears to prevent memory leaks
    func cleanup() {
        // Stop any ongoing speech
        synthesizer.stopSpeaking(at: .immediate)

        // Remove the interruption observer to prevent accumulation
        if let observer = interruptionObserver {
            NotificationCenter.default.removeObserver(observer)
            interruptionObserver = nil
        }

        // Clear handlers to break any retain cycles
        speechProgressHandler = nil
        speechCompletionHandler = nil
    }

    /// Stops speech synthesis and prepares for immediate restart (suppresses completion callback)
    func stopForRestart() {
        print("[DEBUG TTSService.stopForRestart] Setting isRestarting=true, current isSpeaking=\(synthesizer.isSpeaking)")
        isRestarting = true
        synthesizer.stopSpeaking(at: .immediate)
        print("[DEBUG TTSService.stopForRestart] After stop, isSpeaking=\(synthesizer.isSpeaking)")
    }

    /// Clears the restarting flag (call after speak() during a restart)
    func clearRestartFlag() {
        print("[DEBUG TTSService.clearRestartFlag] Setting isRestarting=false")
        isRestarting = false
    }

    /// Checks if the synthesizer is currently speaking
    var isSpeaking: Bool {
        synthesizer.isSpeaking
    }

    /// Checks if the synthesizer is currently paused
    var isPaused: Bool {
        synthesizer.isPaused
    }

    // MARK: - AVSpeechSynthesizerDelegate

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        Task {
            await self.handleSpeechProgress(characterRange)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task {
            await self.handleSpeechCompletion()
        }
    }

    private func handleSpeechProgress(_ characterRange: NSRange) {
        print("[DEBUG TTSService.handleSpeechProgress] range=\(characterRange), isRestarting=\(isRestarting)")
        // Call handler on main actor to ensure UI state updates happen on main thread
        if let handler = speechProgressHandler {
            Task { @MainActor in
                print("[DEBUG TTSService] Calling progress handler on MainActor")
                handler(characterRange)
            }
        }
    }

    private func handleSpeechCompletion() {
        print("[DEBUG TTSService.handleSpeechCompletion] isRestarting=\(isRestarting)")
        // Don't fire completion handler if we're in the middle of a restart (e.g., speed change)
        if isRestarting {
            print("[DEBUG TTSService.handleSpeechCompletion] Suppressing completion due to restart")
            return
        }
        print("[DEBUG TTSService.handleSpeechCompletion] Calling completion handler")
        // Call handler on main actor to ensure UI state updates happen on main thread
        if let handler = speechCompletionHandler {
            Task { @MainActor in
                print("[DEBUG TTSService] Calling completion handler on MainActor")
                handler()
            }
        }
    }
}
