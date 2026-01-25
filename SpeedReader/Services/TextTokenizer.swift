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

/// Represents a word split into parts for RSVP display
struct RSVPWord {
    /// The part of the word before the focus letter
    let leftPart: String

    /// The focus letter (middle character)
    let focusLetter: String

    /// The part of the word after the focus letter
    let rightPart: String
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

    /// Calculates the focus index (middle character position) for a word
    /// - Parameter word: The word to calculate the focus index for
    /// - Returns: The index of the focus letter (floor of word.count / 2)
    func getFocusIndex(for word: String) -> Int {
        return word.count / 2
    }

    /// Splits a word into left part, focus letter, and right part for RSVP display
    /// - Parameter word: The word to split
    /// - Returns: RSVPWord containing the three parts
    func splitWord(_ word: String) -> RSVPWord {
        let focusIndex = getFocusIndex(for: word)
        let characters = Array(word)

        let leftPart = String(characters[..<focusIndex])
        let focusLetter = String(characters[focusIndex])
        let rightPart = String(characters[(focusIndex + 1)...])

        return RSVPWord(
            leftPart: leftPart,
            focusLetter: focusLetter,
            rightPart: rightPart
        )
    }
}
