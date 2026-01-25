import Foundation
import SwiftSoup

/// Errors that can occur during article extraction
enum ArticleExtractorError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case parsingError(Error)
    case noContentFound

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL. Please enter a valid web address."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .parsingError(let error):
            return "Failed to parse content: \(error.localizedDescription)"
        case .noContentFound:
            return "Could not find article content on this page."
        }
    }
}

/// Service for extracting article content from web pages
actor ArticleExtractor {

    /// Extracts article content from a URL
    /// - Parameter urlString: The URL string to extract from
    /// - Returns: A tuple containing the title and cleaned content
    func extract(from urlString: String) async throws -> (title: String, content: String) {
        // Validate and create URL
        guard let url = URL(string: urlString), url.scheme != nil else {
            // Try adding https:// if no scheme
            guard let url = URL(string: "https://\(urlString)"), url.host != nil else {
                throw ArticleExtractorError.invalidURL
            }
            return try await fetchAndParse(url: url)
        }

        return try await fetchAndParse(url: url)
    }

    /// Fetches HTML from URL and parses the content
    private func fetchAndParse(url: URL) async throws -> (title: String, content: String) {
        // Fetch HTML content
        let html: String
        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            // Check for valid HTTP response
            if let httpResponse = response as? HTTPURLResponse,
               !(200...299).contains(httpResponse.statusCode) {
                throw ArticleExtractorError.networkError(
                    NSError(domain: "HTTP", code: httpResponse.statusCode,
                           userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"])
                )
            }

            // Try to decode with detected encoding, fallback to UTF-8
            if let htmlString = String(data: data, encoding: .utf8) {
                html = htmlString
            } else if let htmlString = String(data: data, encoding: .isoLatin1) {
                html = htmlString
            } else {
                throw ArticleExtractorError.parsingError(
                    NSError(domain: "Encoding", code: 0,
                           userInfo: [NSLocalizedDescriptionKey: "Could not decode page content"])
                )
            }
        } catch let error as ArticleExtractorError {
            throw error
        } catch {
            throw ArticleExtractorError.networkError(error)
        }

        // Parse HTML
        let document: Document
        do {
            document = try SwiftSoup.parse(html)
        } catch {
            throw ArticleExtractorError.parsingError(error)
        }

        // Extract title
        let title = extractTitle(from: document)

        // Remove unwanted elements before extraction
        stripUnwantedElements(from: document)

        // Extract main content
        let content = try extractContent(from: document)

        if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ArticleExtractorError.noContentFound
        }

        return (title: title, content: content)
    }

    /// Extracts the title from the document
    private func extractTitle(from document: Document) -> String {
        // Try <title> tag first
        if let titleElement = try? document.select("title").first(),
           let titleText = try? titleElement.text(),
           !titleText.isEmpty {
            // Clean up common title patterns (e.g., "Article Title | Site Name")
            let cleanedTitle = titleText
                .components(separatedBy: CharacterSet(charactersIn: "|—–-"))
                .first?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? titleText
            return cleanedTitle
        }

        // Fallback to <h1>
        if let h1Element = try? document.select("h1").first(),
           let h1Text = try? h1Element.text(),
           !h1Text.isEmpty {
            return h1Text
        }

        return "Untitled Article"
    }

    /// Strips unwanted elements from the document
    private func stripUnwantedElements(from document: Document) {
        // Remove unwanted tags
        let unwantedTags = ["script", "style", "nav", "header", "footer", "aside", "noscript", "iframe", "form"]
        for tag in unwantedTags {
            try? document.select(tag).remove()
        }

        // Remove elements with classes/ids containing unwanted patterns
        let unwantedPatterns = ["ad", "sidebar", "comment", "related", "share", "social", "newsletter", "popup", "modal", "banner", "promo", "sponsor"]

        for pattern in unwantedPatterns {
            // Remove by class containing pattern
            try? document.select("[class*=\(pattern)]").remove()
            // Remove by id containing pattern
            try? document.select("[id*=\(pattern)]").remove()
        }

        // Remove hidden elements
        try? document.select("[hidden]").remove()
        try? document.select("[style*='display:none']").remove()
        try? document.select("[style*='display: none']").remove()
        try? document.select("[aria-hidden='true']").remove()
    }

    /// Extracts the main content from the document using priority-based selection
    private func extractContent(from document: Document) throws -> String {
        // Priority 1: <article> tag
        if let articleElement = try? document.select("article").first(),
           let content = extractTextContent(from: articleElement),
           isSubstantialContent(content) {
            return content
        }

        // Priority 2: [role="main"] or <main> tag
        if let mainElement = try? document.select("[role='main'], main").first(),
           let content = extractTextContent(from: mainElement),
           isSubstantialContent(content) {
            return content
        }

        // Priority 3: Common content class names
        let contentSelectors = [
            ".post-content",
            ".article-content",
            ".entry-content",
            ".content-body",
            ".article-body",
            ".post-body",
            ".story-body",
            "[itemprop='articleBody']"
        ]

        for selector in contentSelectors {
            if let element = try? document.select(selector).first(),
               let content = extractTextContent(from: element),
               isSubstantialContent(content) {
                return content
            }
        }

        // Priority 4: Fallback - find largest text-heavy div
        return findLargestTextContent(in: document)
    }

    /// Extracts and cleans text content from an element
    private func extractTextContent(from element: Element) -> String? {
        do {
            // Get paragraphs and headings for structured content
            let paragraphs = try element.select("p, h1, h2, h3, h4, h5, h6")

            if paragraphs.isEmpty() {
                // Fallback to all text if no paragraphs
                return cleanText(try element.text())
            }

            var contentParts: [String] = []

            for paragraph in paragraphs {
                let text = try paragraph.text()
                let cleaned = cleanText(text)
                if !cleaned.isEmpty {
                    contentParts.append(cleaned)
                }
            }

            return contentParts.joined(separator: "\n\n")
        } catch {
            return nil
        }
    }

    /// Finds the largest text-heavy container as a fallback
    private func findLargestTextContent(in document: Document) -> String {
        var bestContent = ""
        var maxLength = 0

        // Look for divs with substantial text
        if let divs = try? document.select("div") {
            for div in divs {
                if let content = extractTextContent(from: div),
                   content.count > maxLength,
                   isSubstantialContent(content) {
                    maxLength = content.count
                    bestContent = content
                }
            }
        }

        // If no good div found, try body
        if bestContent.isEmpty,
           let body = try? document.body(),
           let content = extractTextContent(from: body) {
            return content
        }

        return bestContent
    }

    /// Checks if content is substantial enough to be article content
    private func isSubstantialContent(_ content: String) -> Bool {
        // Require at least 100 characters and multiple words
        let wordCount = content.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
        return content.count >= 100 && wordCount >= 20
    }

    /// Cleans and normalizes text content
    private func cleanText(_ text: String) -> String {
        var cleaned = text

        // Normalize whitespace - replace multiple spaces/tabs with single space
        cleaned = cleaned.replacingOccurrences(
            of: "[ \\t]+",
            with: " ",
            options: .regularExpression
        )

        // Normalize line breaks
        cleaned = cleaned.replacingOccurrences(
            of: "\\n{3,}",
            with: "\n\n",
            options: .regularExpression
        )

        // Trim each line
        cleaned = cleaned.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: "\n")

        // Final trim
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned
    }
}
