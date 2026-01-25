import Foundation
import SwiftData

@MainActor
class ArticleStore {
    private let modelContainer: ModelContainer
    private var modelContext: ModelContext

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.modelContext = modelContainer.mainContext
    }

    func save(article: Article) throws {
        modelContext.insert(article)
        try modelContext.save()
    }

    func delete(article: Article) throws {
        modelContext.delete(article)
        try modelContext.save()
    }

    func fetchAll() throws -> [Article] {
        let descriptor = FetchDescriptor<Article>(
            sortBy: [SortDescriptor(\.dateAdded, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchById(_ id: UUID) throws -> Article? {
        let descriptor = FetchDescriptor<Article>(
            predicate: #Predicate { article in
                article.id == id
            }
        )
        return try modelContext.fetch(descriptor).first
    }
}
