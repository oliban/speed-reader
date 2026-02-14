import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var articles: [Article]
    @Query private var allProgress: [ReadingProgress]

    @State private var articleToDelete: Article?
    @State private var showDeleteConfirmation = false
    @State private var searchText = ""
    @State private var selectedArticle: Article?
    @State private var showModeSelection = false
    @State private var navigateToRSVP = false
    @State private var navigateToTTS = false
    @State private var readingSummary = false
    @State private var listVisible = true

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

    /// Calculate progress value (0.0 to 1.0) for an article
    private func progressValue(for article: Article) -> Double {
        guard let progress = allProgress.first(where: { $0.articleId == article.id }),
              progress.totalWords > 0 else {
            return 0.0
        }
        return Double(progress.currentWordIndex) / Double(progress.totalWords)
    }

    var body: some View {
        NavigationStack {
            Group {
                if articles.isEmpty {
                    ContentUnavailableView {
                        Label("No Saved Articles", systemImage: "books.vertical")
                            .foregroundColor(.adaptivePrimaryText)
                    } description: {
                        Text("Articles you save will appear here")
                            .foregroundColor(.adaptiveSecondaryText)
                    }
                    .background(Color.adaptiveBackground)
                } else if filteredArticles.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                        .background(Color.adaptiveBackground)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(Array(filteredArticles.enumerated()), id: \.element.id) { index, article in
                                ArticleCard(
                                    article: article,
                                    progress: progressValue(for: article),
                                    index: index
                                )
                                .staggeredAppear(isVisible: listVisible, index: index)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedArticle = article
                                    showModeSelection = true
                                }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        articleToDelete = article
                                        showDeleteConfirmation = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                    }
                    .background(Color.adaptiveBackground)
                    .onAppear {
                        withAnimation {
                            listVisible = true
                        }
                    }
                }
            }
            .background(Color.adaptiveBackground)
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
            .sheet(isPresented: $showModeSelection) {
                ModeSelectionSheet(
                    article: selectedArticle,
                    onRSVPSelected: {
                        readingSummary = false
                        showModeSelection = false
                        navigateToRSVP = true
                    },
                    onTTSSelected: {
                        readingSummary = false
                        showModeSelection = false
                        navigateToTTS = true
                    },
                    onSummaryRSVPSelected: {
                        readingSummary = true
                        showModeSelection = false
                        navigateToRSVP = true
                    },
                    onSummaryTTSSelected: {
                        readingSummary = true
                        showModeSelection = false
                        navigateToTTS = true
                    }
                )
                .presentationDetents([.medium, .large])
            }
            .navigationDestination(isPresented: $navigateToRSVP) {
                if let article = selectedArticle {
                    RSVPReaderView(article: article, readingSummary: readingSummary)
                }
            }
            .navigationDestination(isPresented: $navigateToTTS) {
                if let article = selectedArticle {
                    TTSReaderView(article: article, readingSummary: readingSummary)
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

// MARK: - Preview

#Preview("Library - Empty") {
    LibraryView()
        .modelContainer(for: [Article.self, ReadingProgress.self], inMemory: true)
}

#Preview("Library - With Articles") {
    let container = try! ModelContainer(
        for: Article.self, ReadingProgress.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    // Add sample articles
    let articles = [
        Article(url: "https://example.com/1", title: "How to Build Better Habits", content: "Sample content..."),
        Article(url: "https://medium.com/2", title: "The Future of AI: What We Can Expect in 2025", content: "Sample content..."),
        Article(url: "https://news.ycombinator.com/3", title: "Understanding SwiftUI Performance", content: "Sample content...")
    ]

    for article in articles {
        container.mainContext.insert(article)
    }

    return LibraryView()
        .modelContainer(container)
}
