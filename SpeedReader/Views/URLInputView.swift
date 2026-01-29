//
//  URLInputView.swift
//  SpeedReader
//
//  "The Portal" - Hyperfocus Noir design
//

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
            ZStack {
                // Background
                Color.adaptiveBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Push content to upper third with dramatic negative space
                    Spacer()
                        .frame(height: 80)

                    // Editorial header section
                    VStack(spacing: 16) {
                        // Overline
                        Text("SPEEDREADER")
                            .srOverlineStyle()
                            .foregroundColor(.adaptiveSecondaryText)

                        // Dramatic headline
                        Text("Paste a URL to begin")
                            .srHeadlineStyle()
                            .foregroundColor(.adaptivePrimaryText)

                        // Red underline accent
                        Rectangle()
                            .fill(Color.signalRed)
                            .frame(width: 60, height: 2)
                    }
                    .padding(.bottom, 48)

                    // URL Input section
                    VStack(spacing: 20) {
                        // URL text field with paste button
                        HStack(spacing: 12) {
                            SRTextField(
                                placeholder: "https://example.com/article",
                                text: $urlText
                            )
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .disabled(isLoading)
                            .accessibilityLabel("Article URL")

                            // Paste button
                            Button {
                                pasteFromClipboard()
                            } label: {
                                Image(systemName: "doc.on.clipboard")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.adaptiveSecondaryText)
                                    .frame(width: 48, height: 48)
                                    .background(Color.adaptiveSecondary)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.adaptiveBorder, lineWidth: 1)
                                    )
                                    .cornerRadius(8)
                            }
                            .disabled(isLoading)
                            .accessibilityLabel("Paste from clipboard")
                        }
                        .padding(.horizontal, 24)

                        // Fetch button
                        SRPrimaryButton(
                            title: isLoading ? "Extracting..." : "Extract Article",
                            action: {
                                Task {
                                    await fetchArticle()
                                }
                            },
                            isLoading: isLoading,
                            isDisabled: urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        )
                        .padding(.horizontal, 24)
                        .accessibilityLabel(isLoading ? "Extracting article" : "Extract article")
                    }

                    // Error message display
                    if let errorMessage = errorMessage {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.signalRed)
                                .accessibilityHidden(true)
                            Text(errorMessage)
                                .font(.srBody)
                                .foregroundColor(.signalRed)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.adaptiveCard)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.signalRed.opacity(0.5), lineWidth: 1)
                        )
                        .cornerRadius(8)
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Error: \(errorMessage)")
                    }

                    Spacer()
                }
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.adaptiveBackground, for: .navigationBar)
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
                .presentationBackground(Color.adaptiveBackground)
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
        ZStack {
            Color.adaptiveBackground
                .ignoresSafeArea()

            VStack(spacing: 32) {
                // Header
                VStack(spacing: 16) {
                    // Overline
                    Text("Reading Mode")
                        .srOverlineStyle()
                        .foregroundColor(.adaptiveSecondaryText)

                    // Headline
                    Text("Choose Your Path")
                        .srHeadlineStyle()
                        .foregroundColor(.adaptivePrimaryText)

                    // Red underline accent
                    Rectangle()
                        .fill(Color.signalRed)
                        .frame(width: 40, height: 2)

                    if let article = article {
                        Text(article.title)
                            .font(.srBody)
                            .foregroundColor(.adaptiveSecondaryText)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                    }
                }
                .padding(.top, 32)

                // Mode selection buttons
                VStack(spacing: 16) {
                    // RSVP Button
                    Button(action: onRSVPSelected) {
                        HStack(spacing: 16) {
                            Image(systemName: "text.word.spacing")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(.adaptiveAccent)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("RSVP READER")
                                    .font(.system(size: 13, weight: .semibold))
                                    .tracking(0.1 * 13)
                                    .foregroundColor(.adaptivePrimaryText)

                                Text("Rapid Serial Visual Presentation")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(.adaptiveSecondaryText)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.adaptiveSecondaryText)
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity)
                        .background(Color.adaptiveCard)
                        .overlay(
                            RoundedRectangle(cornerRadius: 0)
                                .stroke(Color.adaptiveBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)

                    // TTS Button
                    Button(action: onTTSSelected) {
                        HStack(spacing: 16) {
                            Image(systemName: "speaker.wave.2")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(.iceBlue)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("TTS READER")
                                    .font(.system(size: 13, weight: .semibold))
                                    .tracking(0.1 * 13)
                                    .foregroundColor(.adaptivePrimaryText)

                                Text("Text-to-Speech with highlighting")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(.adaptiveSecondaryText)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.adaptiveSecondaryText)
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity)
                        .background(Color.adaptiveCard)
                        .overlay(
                            RoundedRectangle(cornerRadius: 0)
                                .stroke(Color.adaptiveBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)

                Spacer()
            }
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

#Preview("Dark Mode") {
    URLInputView()
        .modelContainer(for: Article.self, inMemory: true)
        .preferredColorScheme(.dark)
}

#Preview("Light Mode") {
    URLInputView()
        .modelContainer(for: Article.self, inMemory: true)
        .preferredColorScheme(.light)
}
