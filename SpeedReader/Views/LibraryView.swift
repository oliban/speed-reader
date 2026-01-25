import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Article.lastRead, order: .reverse) private var articles: [Article]
    @Query private var allProgress: [ReadingProgress]

    @State private var articleToDelete: Article?
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            Group {
                if articles.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "books.vertical")
                            .font(.system(size: 60))
                            .foregroundStyle(.gray)
                        Text("No saved articles")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Articles you save will appear here")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    List {
                        ForEach(articles) { article in
                            ArticleRowView(article: article)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        articleToDelete = article
                                        showDeleteConfirmation = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }
            .navigationTitle("Library")
            .alert("Delete Article?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    articleToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let article = articleToDelete {
                        deleteArticle(article)
                    }
                    articleToDelete = nil
                }
            } message: {
                if let article = articleToDelete {
                    Text("Are you sure you want to delete \"\(article.title)\"? This action cannot be undone.")
                }
            }
        }
    }

    private func deleteArticle(_ article: Article) {
        // Delete associated reading progress
        let articleId = article.id
        let progressToDelete = allProgress.filter { $0.articleId == articleId }
        for progress in progressToDelete {
            modelContext.delete(progress)
        }

        // Delete the article
        modelContext.delete(article)
    }
}

struct ArticleRowView: View {
    let article: Article
    @Query private var allProgress: [ReadingProgress]

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    init(article: Article) {
        self.article = article
        let articleId = article.id
        _allProgress = Query(filter: #Predicate<ReadingProgress> { progress in
            progress.articleId == articleId
        })
    }

    private var urlDomain: String {
        if let url = URL(string: article.url),
           let host = url.host {
            return host.replacingOccurrences(of: "www.", with: "")
        }
        return article.url
    }

    private var formattedDate: String {
        Self.dateFormatter.string(from: article.dateAdded)
    }

    private var progressPercentage: String {
        guard let progress = allProgress.first,
              progress.totalWords > 0 else {
            return "0%"
        }
        let percentage = (Double(progress.currentWordIndex) / Double(progress.totalWords)) * 100
        return "\(Int(percentage))%"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(article.title)
                .font(.headline)
                .lineLimit(2)

            HStack {
                Text(urlDomain)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                Text(progressPercentage)
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }

            Text("Added: \(formattedDate)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    LibraryView()
        .modelContainer(for: Article.self, inMemory: true)
}
