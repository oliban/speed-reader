//
//  ArticleCard.swift
//  SpeedReader
//
//  A library card component for the Hyperfocus Noir design.
//

import SwiftUI

struct ArticleCard: View {
    let article: Article
    let progress: Double // 0.0 to 1.0
    let index: Int // for stagger animation

    @Environment(\.colorScheme) private var colorScheme

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: article.dateAdded)
    }

    private var domain: String {
        guard let url = URL(string: article.url),
              let host = url.host else {
            return article.url
        }
        // Remove www. prefix if present
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    private var progressPercentage: Int {
        Int(progress * 100)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title
            Text(article.title)
                .font(.system(size: 17, weight: .semibold, design: .default))
                .foregroundColor(.adaptivePrimaryText)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            // Summary preview (if available)
            if let summary = article.summary {
                Text(summary)
                    .font(.system(size: 13, weight: .regular, design: .default))
                    .foregroundColor(.adaptiveSecondaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            Spacer()
                .frame(height: 4)

            // Metadata: domain and date
            HStack(spacing: 6) {
                Text("\(domain) \u{00B7} \(formattedDate)")
                    .font(.system(size: 13, weight: .regular, design: .default))
                    .foregroundColor(.ash)
                    .lineLimit(1)

                if article.summary != nil {
                    Text("\u{00B7}")
                        .font(.system(size: 13))
                        .foregroundColor(.ash)
                    Image(systemName: "sparkles")
                        .font(.system(size: 11))
                        .foregroundColor(.electricAmber)
                }
            }

            // Progress bar with percentage
            HStack(spacing: 8) {
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background track
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.smoke)
                            .frame(height: 2)

                        // Progress fill
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.signalRed)
                            .frame(width: geometry.size.width * CGFloat(progress), height: 2)
                    }
                }
                .frame(height: 2)

                // Percentage text
                Text("\(progressPercentage)%")
                    .font(.system(size: 13, weight: .regular, design: .default))
                    .foregroundColor(.ash)
                    .frame(width: 36, alignment: .trailing)
            }
        }
        .padding(16)
        .background(Color.adaptiveCard)
        .cornerRadius(12)
        .shadow(
            color: colorScheme == .light ? Color.black.opacity(0.08) : Color.clear,
            radius: 8,
            x: 0,
            y: 2
        )
    }
}

// MARK: - Preview

#Preview("Article Card - Light Mode") {
    let sampleArticle = Article(
        url: "https://www.example.com/article/how-to-read-faster",
        title: "How to Read Faster: A Comprehensive Guide to Speed Reading Techniques",
        content: "Sample content here..."
    )

    return VStack(spacing: 16) {
        ArticleCard(article: sampleArticle, progress: 0.42, index: 0)
        ArticleCard(article: sampleArticle, progress: 0.0, index: 1)
        ArticleCard(article: sampleArticle, progress: 1.0, index: 2)
    }
    .padding()
    .background(Color.paper)
    .preferredColorScheme(.light)
}

#Preview("Article Card - Dark Mode") {
    let sampleArticle = Article(
        url: "https://www.example.com/article/how-to-read-faster",
        title: "How to Read Faster: A Comprehensive Guide to Speed Reading Techniques",
        content: "Sample content here..."
    )

    return VStack(spacing: 16) {
        ArticleCard(article: sampleArticle, progress: 0.42, index: 0)
        ArticleCard(article: sampleArticle, progress: 0.0, index: 1)
        ArticleCard(article: sampleArticle, progress: 1.0, index: 2)
    }
    .padding()
    .background(Color.voidBlack)
    .preferredColorScheme(.dark)
}

#Preview("Article Card - Stagger Animation") {
    struct StaggerPreview: View {
        @State private var isVisible = false

        var body: some View {
            let sampleArticles = [
                Article(url: "https://example.com/1", title: "First Article Title", content: ""),
                Article(url: "https://medium.com/2", title: "Second Article with a Longer Title That Might Wrap", content: ""),
                Article(url: "https://news.ycombinator.com/3", title: "Third Article", content: "")
            ]

            VStack(spacing: 16) {
                ForEach(Array(sampleArticles.enumerated()), id: \.element.id) { index, article in
                    ArticleCard(article: article, progress: Double(index) * 0.3, index: index)
                        .staggeredAppear(isVisible: isVisible, index: index)
                }
            }
            .padding()
            .background(Color.adaptiveBackground)
            .onAppear {
                withAnimation {
                    isVisible = true
                }
            }
        }
    }

    return StaggerPreview()
}
