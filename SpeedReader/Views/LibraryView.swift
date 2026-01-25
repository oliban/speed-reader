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

    private var urlDomain: String {
        if let url = URL(string: article.url),
           let host = url.host {
            return host.replacingOccurrences(of: "www.", with: "")
        }
        return article.url
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: article.dateAdded)
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

                Text("0%")
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
