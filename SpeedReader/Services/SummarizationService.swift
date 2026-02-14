import Foundation

#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26, *)
actor SummarizationService {
    private let instructions = """
        You are a concise article summarizer. Given an article's text, produce a clear \
        summary of 2-3 short paragraphs that captures the key points. Write in plain prose, \
        no bullet points or headings. Keep it under 200 words.
        """

    func summarize(_ content: String) async throws -> String {
        let session = LanguageModelSession(instructions: instructions)
        // The on-device model has limited context; truncate very long articles
        let truncated = String(content.prefix(12_000))
        let response = try await session.respond(to: truncated)
        return response.content
    }
}
#endif

/// Checks whether on-device summarization is available at runtime.
enum SummarizationAvailability {
    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            return true
        }
        #endif
        return false
    }
}
