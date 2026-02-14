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
            return try await extractFromURL(url)
        }

        return try await extractFromURL(url)
    }

    /// Routes extraction based on URL type
    private func extractFromURL(_ url: URL) async throws -> (title: String, content: String) {
        // Use oEmbed API for Twitter/X URLs (they require JS to render)
        if isTwitterURL(url) {
            return try await extractFromTwitterOEmbed(url: url)
        }

        return try await fetchAndParse(url: url)
    }

    /// Checks if a URL is a Twitter/X post
    private func isTwitterURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host == "x.com" || host == "www.x.com"
            || host == "twitter.com" || host == "www.twitter.com"
            || host == "mobile.twitter.com" || host == "mobile.x.com"
    }

    /// Extracts tweet content using Twitter's oEmbed API
    private func extractFromTwitterOEmbed(url: URL) async throws -> (title: String, content: String) {
        guard var components = URLComponents(string: "https://publish.twitter.com/oembed") else {
            throw ArticleExtractorError.noContentFound
        }
        components.queryItems = [URLQueryItem(name: "url", value: url.absoluteString)]

        guard let oembedURL = components.url else {
            throw ArticleExtractorError.noContentFound
        }

        let data: Data
        do {
            let (responseData, response) = try await URLSession.shared.data(from: oembedURL)
            if let httpResponse = response as? HTTPURLResponse,
               !(200...299).contains(httpResponse.statusCode) {
                throw ArticleExtractorError.noContentFound
            }
            data = responseData
        } catch let error as ArticleExtractorError {
            throw error
        } catch {
            throw ArticleExtractorError.networkError(error)
        }

        // Parse oEmbed JSON
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let html = json["html"] as? String,
              let authorName = json["author_name"] as? String else {
            throw ArticleExtractorError.noContentFound
        }

        // Extract tweet text from the blockquote HTML
        let tweetText: String
        do {
            let doc = try SwiftSoup.parse(html)
            // The tweet text is in the <p> inside the <blockquote>
            if let paragraph = try doc.select("blockquote p").first() {
                tweetText = try paragraph.text()
            } else {
                tweetText = try doc.text()
            }
        } catch {
            throw ArticleExtractorError.parsingError(error)
        }

        if tweetText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ArticleExtractorError.noContentFound
        }

        let title = "@\(authorName)"
        return (title: title, content: tweetText)
    }

    /// Fetches HTML from URL and parses the content
    private func fetchAndParse(url: URL) async throws -> (title: String, content: String) {
        // Fetch HTML content
        let html: String
        do {
            var request = URLRequest(url: url)
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await URLSession.shared.data(for: request)

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

        // Final fallback: Extract from meta tags (handles JS-rendered pages like Twitter/X)
        let metaContent = extractFromMetaTags(document: document)
        if !metaContent.isEmpty {
            return metaContent
        }

        return ""
    }

    /// Extracts content from Open Graph and Twitter Card meta tags
    /// Used as a fallback for JS-rendered pages (e.g. Twitter/X, Facebook)
    private func extractFromMetaTags(document: Document) -> String {
        var parts: [String] = []

        // Try og:title or twitter:title for a heading
        let titleSelectors = [
            "meta[property='og:title']",
            "meta[name='twitter:title']"
        ]
        for selector in titleSelectors {
            if let element = try? document.select(selector).first(),
               let content = try? element.attr("content"),
               !content.isEmpty {
                parts.append(content)
                break
            }
        }

        // Try og:description or twitter:description for the body
        let descriptionSelectors = [
            "meta[property='og:description']",
            "meta[name='twitter:description']",
            "meta[name='description']"
        ]
        for selector in descriptionSelectors {
            if let element = try? document.select(selector).first(),
               let content = try? element.attr("content"),
               !content.isEmpty {
                parts.append(content)
                break
            }
        }

        let combined = parts.joined(separator: "\n\n")
        return combined.trimmingCharacters(in: .whitespacesAndNewlines)
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
