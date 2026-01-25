import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Article.lastRead, order: .reverse) private var articles: [Article]
    @Query private var allProgress: [ReadingProgress]

    @State private var articleToDelete: Article?
    @State private var showDeleteConfirmation = false
    @State private var searchText = ""

    private var filteredArticles: [Article] {
        if searchText.isEmpty {
            return articles
        }
        let lowercasedSearch = searchText.lowercased()
        return articles.filter { article in
            article.title.lowercased().contains(lowercasedSearch) ||
            article.url.lowercased().contains(lowercasedSearch)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if articles.isEmpty {
                    ContentUnavailableView {
                        Label("No Saved Articles", systemImage: "books.vertical")
                    } description: {
                        Text("Articles you save will appear here")
                    }
                } else if filteredArticles.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List {
                        ForEach(filteredArticles) { article in
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
            .searchable(text: $searchText, prompt: "Search articles")
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

            HStack(spacing: 8) {
                Image(systemName: "link")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(urlDomain)
                    .font(.body)
                    .foregroundStyle(.secondary)

                Spacer()

                Label(progressPercentage, systemImage: "book.pages")
                    .font(.body)
                    .foregroundStyle(Color.accentColor)
                    .labelStyle(.titleAndIcon)
            }

            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text("Added: \(formattedDate)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(article.title), \(urlDomain), \(progressPercentage) complete, added \(formattedDate)")
    }
}

#Preview {
    LibraryView()
        .modelContainer(for: Article.self, inMemory: true)
}
