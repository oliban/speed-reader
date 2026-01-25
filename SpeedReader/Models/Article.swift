import Foundation
import SwiftData

@Model
final class Article {
    var id: UUID
    var url: String
    var title: String
    var content: String
    var dateAdded: Date
    var lastRead: Date?

    init(
        id: UUID = UUID(),
        url: String,
        title: String,
        content: String,
        dateAdded: Date = Date(),
        lastRead: Date? = nil
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.content = content
        self.dateAdded = dateAdded
        self.lastRead = lastRead
    }
}
