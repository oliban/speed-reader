import Foundation
import AVFoundation

/// Errors that can occur during text-to-speech operations
enum TTSServiceError: LocalizedError {
    case synthesisFailure
    case invalidText

    var errorDescription: String? {
        switch self {
        case .synthesisFailure:
            return "Failed to synthesize speech."
        case .invalidText:
            return "Invalid or empty text provided."
        }
    }
}

/// Service for text-to-speech functionality using AVSpeechSynthesizer
actor TTSService {
    private let synthesizer: AVSpeechSynthesizer

    init() {
        self.synthesizer = AVSpeechSynthesizer()
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
}
