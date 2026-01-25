import Foundation

/// Represents tokenized text with word-to-paragraph mappings
struct TokenizedText {
    /// Array of individual words extracted from the text
    let words: [String]

    /// Array mapping each word index to its paragraph index
    let paragraphIndices: [Int]

    /// Array of paragraph strings
    let paragraphs: [String]
}

/// Service for tokenizing text into words and managing paragraph context
actor TextTokenizer {

    /// Tokenizes text into words and builds paragraph mappings
    /// - Parameter text: The text to tokenize
    /// - Returns: TokenizedText containing words, paragraph indices, and paragraphs
    func tokenize(_ text: String) -> TokenizedText {
        // Split text into paragraphs (separated by double newlines or single newlines)
        let paragraphs = text.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        // Build words array and paragraph mappings
        var allWords: [String] = []
        var paragraphIndices: [Int] = []

        for (paragraphIndex, paragraph) in paragraphs.enumerated() {
            let words = paragraph.components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }

            for word in words {
                allWords.append(word)
                paragraphIndices.append(paragraphIndex)
            }
        }

        return TokenizedText(
            words: allWords,
            paragraphIndices: paragraphIndices,
            paragraphs: paragraphs
        )
    }

    /// Builds paragraph data mapping words to their containing paragraphs
    /// - Parameter tokenizedText: The tokenized text to process
    /// - Returns: Dictionary mapping word indices to paragraph information
    func buildParagraphsData(from tokenizedText: TokenizedText) -> [Int: (paragraphIndex: Int, paragraph: String)] {
        var paragraphsData: [Int: (paragraphIndex: Int, paragraph: String)] = [:]

        for (wordIndex, paragraphIndex) in tokenizedText.paragraphIndices.enumerated() {
            let paragraph = tokenizedText.paragraphs[paragraphIndex]
            paragraphsData[wordIndex] = (paragraphIndex: paragraphIndex, paragraph: paragraph)
        }

        return paragraphsData
    }

    /// Calculates the base delay in milliseconds for a given WPM (words per minute)
    /// - Parameter wpm: Words per minute reading speed
    /// - Returns: Delay in milliseconds per word
    func getDelay(wpm: Int) -> Double {
        return 60000.0 / Double(wpm)
    }

    /// Calculates the delay multiplier based on punctuation at the end of a word
    /// - Parameter word: The word to check for punctuation
    /// - Returns: Multiplier value (1.5x for .!?, 1.2x for ,:;, 1.0x otherwise)
    func getDelayMultiplier(for word: String) -> Double {
        guard let lastChar = word.last else {
            return 1.0
        }

        switch lastChar {
        case ".", "!", "?":
            return 1.5
        case ",", ":", ";":
            return 1.2
        default:
            return 1.0
        }
    }
}
