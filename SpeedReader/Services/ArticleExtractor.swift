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

        // Extract main content using text density analysis
        let content = extractContent(from: document)

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
        let unwantedTags = ["script", "style", "nav", "footer", "aside", "noscript", "iframe", "form"]
        for tag in unwantedTags {
            _ = try? document.select(tag).remove()
        }

        // Remove elements with classes/ids containing unwanted patterns
        // Conservative list to avoid removing legitimate content
        let unwantedPatterns = ["sidebar", "comment", "newsletter", "popup", "modal", "promo", "sponsor"]

        for pattern in unwantedPatterns {
            _ = try? document.select("[class*=\(pattern)]").remove()
            _ = try? document.select("[id*=\(pattern)]").remove()
        }

        // Remove hidden elements
        _ = try? document.select("[hidden]").remove()
        _ = try? document.select("[style*='display:none']").remove()
        _ = try? document.select("[style*='display: none']").remove()
        _ = try? document.select("[aria-hidden='true']").remove()
    }

    /// Extracts the main content using text density analysis (primary method)
    private func extractContent(from document: Document) -> String {
        // Primary method: Text density analysis
        let content = findBestContentByDensity(in: document)
        if isSubstantialContent(content) {
            return content
        }

        // Fallback: Try known selectors if density analysis fails
        let contentSelectors = [
            "article", "main", "[role='main']",
            ".gh-content", ".post-content", ".article-content",
            ".entry-content", ".content-body", ".article-body",
            ".prose", ".markdown-body", "[itemprop='articleBody']"
        ]

        for selector in contentSelectors {
            if let element = try? document.select(selector).first(),
               let content = extractTextContent(from: element),
               isSubstantialContent(content) {
                return content
            }
        }

        return ""
    }

    /// Finds the best content container using text density scoring
    private func findBestContentByDensity(in document: Document) -> String {
        var bestContent = ""
        var bestScore: Double = 0

        // Check all potential content containers
        let containerSelectors = ["article", "main", "section", "div"]

        for selector in containerSelectors {
            guard let elements = try? document.select(selector) else { continue }

            for element in elements {
                let score = calculateContentScore(for: element)
                if score > bestScore,
                   let content = extractTextContent(from: element),
                   isSubstantialContent(content) {
                    bestScore = score
                    bestContent = content
                }
            }
        }

        return bestContent
    }

    /// Calculates a content quality score for an element based on text density
    private func calculateContentScore(for element: Element) -> Double {
        do {
            let text = try element.text()
            let textLength = Double(text.count)

            // Count paragraphs (good indicator of article content)
            let paragraphs = try element.select("p")
            let paragraphCount = Double(paragraphs.size())

            // Count links (high link density = navigation, not content)
            let links = try element.select("a")
            let linkText = try links.text()
            let linkTextLength = Double(linkText.count)

            // Calculate link density (0 to 1, lower is better)
            let linkDensity = textLength > 0 ? linkTextLength / textLength : 1.0

            // Score formula:
            // - Reward text length (log scale)
            // - Reward paragraph count
            // - Penalize high link density
            let lengthScore = textLength > 0 ? log(textLength) : 0
            let paragraphScore = paragraphCount * 10
            let linkPenalty = linkDensity * 50

            return max(0, lengthScore + paragraphScore - linkPenalty)
        } catch {
            return 0
        }
    }

    /// Extracts and cleans text content from an element
    private func extractTextContent(from element: Element) -> String? {
        do {
            // Get paragraphs and headings for structured content
            let paragraphs = try element.select("p, h1, h2, h3, h4, h5, h6")

            if paragraphs.isEmpty() {
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

    /// Checks if content is substantial enough to be article content
    private func isSubstantialContent(_ content: String) -> Bool {
        let wordCount = content.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
        return content.count >= 100 && wordCount >= 20
    }

    /// Cleans and normalizes text content
    private func cleanText(_ text: String) -> String {
        var cleaned = text

        // Normalize whitespace
        cleaned = cleaned.replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)

        // Normalize line breaks
        cleaned = cleaned.replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)

        // Trim each line
        cleaned = cleaned.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: "\n")

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
