import SwiftUI
import SwiftData

struct URLInputView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var urlText: String = "https://babuschk.in/posts/2026-01-25-life-on-claude-nine.html"
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showModeSelection: Bool = false
    @State private var extractedArticle: Article?
    @State private var navigateToRSVP: Bool = false
    @State private var navigateToTTS: Bool = false

    private let extractor = ArticleExtractor()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // Icon and description
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 60))
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)

                    Text("Enter URL to read")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Text("Paste or type a web article URL to extract and read it")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }

                // URL Input field with paste button
                VStack(spacing: 16) {
                    HStack(spacing: 8) {
                        TextField("https://example.com/article", text: $urlText)
                            .font(.body)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .disabled(isLoading)
                            .accessibilityLabel("Article URL")

                        Button {
                            pasteFromClipboard()
                        } label: {
                            Image(systemName: "doc.on.clipboard")
                                .font(.title3)
                        }
                        .buttonStyle(.bordered)
                        .disabled(isLoading)
                        .accessibilityLabel("Paste from clipboard")
                    }
                    .padding(.horizontal, 16)

                    // Fetch button
                    Button {
                        Task {
                            await fetchArticle()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                            } else {
                                Image(systemName: "arrow.down.doc")
                            }
                            Text(isLoading ? "Extracting..." : "Extract Article")
                                .font(.body)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                    .padding(.horizontal, 16)
                    .accessibilityLabel(isLoading ? "Extracting article" : "Extract article")
                }

                // Error message display
                if let errorMessage = errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .accessibilityHidden(true)
                        Text(errorMessage)
                            .font(.body)
                            .foregroundStyle(.red)
                    }
                    .padding(16)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal, 16)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Error: \(errorMessage)")
                }

                Spacer()
                Spacer()
            }
            .navigationTitle("Home")
            .sheet(isPresented: $showModeSelection) {
                ModeSelectionSheet(
                    article: extractedArticle,
                    onRSVPSelected: {
                        showModeSelection = false
                        navigateToRSVP = true
                    },
                    onTTSSelected: {
                        showModeSelection = false
                        navigateToTTS = true
                    }
                )
                .presentationDetents([.medium])
            }
            .navigationDestination(isPresented: $navigateToRSVP) {
                if let article = extractedArticle {
                    RSVPReaderView(article: article)
                }
            }
            .navigationDestination(isPresented: $navigateToTTS) {
                if let article = extractedArticle {
                    TTSReaderView(article: article)
                }
            }
        }
    }

    /// Pastes URL from system clipboard
    private func pasteFromClipboard() {
        if let pastedString = UIPasteboard.general.string {
            urlText = pastedString.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    /// Fetches and extracts article content from the entered URL
    @MainActor
    private func fetchArticle() async {
        // Clear previous error
        errorMessage = nil

        // Validate input
        let trimmedURL = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty else {
            errorMessage = "Please enter a URL"
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            // Extract article content
            let (title, content) = try await extractor.extract(from: trimmedURL)

            // Normalize URL for storage
            let normalizedURL: String
            if trimmedURL.lowercased().hasPrefix("http://") || trimmedURL.lowercased().hasPrefix("https://") {
                normalizedURL = trimmedURL
            } else {
                normalizedURL = "https://\(trimmedURL)"
            }

            // Create and save article to SwiftData
            let article = Article(
                url: normalizedURL,
                title: title,
                content: content
            )
            modelContext.insert(article)

            // Store the extracted article and show mode selection
            extractedArticle = article
            showModeSelection = true

        } catch let error as ArticleExtractorError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
        }
    }
}

/// Sheet for selecting reading mode after article extraction
struct ModeSelectionSheet: View {
    let article: Article?
    let onRSVPSelected: () -> Void
    let onTTSSelected: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "book.pages")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)

                Text("Choose Reading Mode")
                    .font(.title2)
                    .fontWeight(.semibold)

                if let article = article {
                    Text(article.title)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal)
                }
            }
            .padding(.top, 24)

            // Mode selection buttons
            VStack(spacing: 16) {
                Button(action: onRSVPSelected) {
                    HStack {
                        Image(systemName: "text.word.spacing")
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("RSVP Reader")
                                .font(.headline)
                            Text("Rapid Serial Visual Presentation")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)

                Button(action: onTTSSelected) {
                    HStack {
                        Image(systemName: "speaker.wave.2")
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("TTS Reader")
                                .font(.headline)
                            Text("Text-to-Speech with highlighting")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)

            Spacer()
        }
    }
}

#Preview {
    URLInputView()
        .modelContainer(for: Article.self, inMemory: true)
}

#Preview("Mode Selection Sheet") {
    ModeSelectionSheet(
        article: Article(
            url: "https://example.com",
            title: "Sample Article Title",
            content: "Sample content"
        ),
        onRSVPSelected: {},
        onTTSSelected: {}
    )
}
