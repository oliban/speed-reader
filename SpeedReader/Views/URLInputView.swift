import SwiftUI
import SwiftData

struct URLInputView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var urlText: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showSuccessAlert: Bool = false
    @State private var extractedTitle: String = ""

    private let extractor = ArticleExtractor()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // Icon and description
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 60))
                        .foregroundStyle(.blue)

                    Text("Enter URL to read")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text("Paste or type a web article URL to extract and read it")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // URL Input field with paste button
                VStack(spacing: 16) {
                    HStack(spacing: 8) {
                        TextField("https://example.com/article", text: $urlText)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .disabled(isLoading)

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
                    .padding(.horizontal)

                    // Fetch button
                    Button {
                        Task {
                            await fetchArticle()
                        }
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                            } else {
                                Image(systemName: "arrow.down.doc")
                            }
                            Text(isLoading ? "Extracting..." : "Extract Article")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                    .padding(.horizontal)
                }

                // Error message display
                if let errorMessage = errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }

                Spacer()
                Spacer()
            }
            .navigationTitle("Home")
            .alert("Article Saved", isPresented: $showSuccessAlert) {
                Button("OK", role: .cancel) {
                    // Clear the input after successful save
                    urlText = ""
                }
            } message: {
                Text("\"\(extractedTitle)\" has been saved to your library.")
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

            // Show success message
            extractedTitle = title
            showSuccessAlert = true

        } catch let error as ArticleExtractorError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
        }
    }
}

#Preview {
    URLInputView()
        .modelContainer(for: Article.self, inMemory: true)
}
