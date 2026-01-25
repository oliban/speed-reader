import SwiftUI
import SwiftData

struct LibraryView: View {
    @Query(sort: \Article.lastRead, order: .reverse) private var articles: [Article]

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
                    List(articles) { article in
                        ArticleRowView(article: article)
                    }
                }
            }
            .navigationTitle("Library")
        }
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
