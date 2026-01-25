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
        NotificationCenter.default.addObserver(
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
            // Interruption began - pause speech
            if synthesizer.isSpeaking {
                synthesizer.pauseSpeaking(at: .word)
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

        synthesizer.speak(utterance)
    }

    /// Pauses speech synthesis
    func pause() {
        synthesizer.pauseSpeaking(at: .word)
    }

    /// Resumes paused speech synthesis
    func resume() {
        synthesizer.continueSpeaking()
    }

    /// Stops speech synthesis immediately
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
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
        Task { @MainActor in
            await self.handleSpeechProgress(characterRange)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            await self.handleSpeechCompletion()
        }
    }

    private func handleSpeechProgress(_ characterRange: NSRange) {
        speechProgressHandler?(characterRange)
    }

    private func handleSpeechCompletion() {
        speechCompletionHandler?()
    }
}
