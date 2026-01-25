import Foundation
import SwiftData

@Model
final class ReadingProgress {
    var articleId: UUID
    var currentWordIndex: Int
    var totalWords: Int
    var mode: ReadingMode

    init(
        articleId: UUID,
        currentWordIndex: Int = 0,
        totalWords: Int = 0,
        mode: ReadingMode = .rsvp
    ) {
        self.articleId = articleId
        self.currentWordIndex = currentWordIndex
        self.totalWords = totalWords
        self.mode = mode
    }
}
