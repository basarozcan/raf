import Foundation

enum ShortenerProvider: String, CaseIterable, Identifiable, Codable {
    case tinyURL
    case bitly
    case dub
    case shlink
    case yourls

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .tinyURL: return "TinyURL"
        case .bitly: return "Bitly"
        case .dub: return "Dub.co"
        case .shlink: return "Shlink (self-hosted)"
        case .yourls: return "YOURLS (self-hosted)"
        }
    }

    var needsAPIKey: Bool { self != .tinyURL }
    var needsBaseURL: Bool { self == .shlink || self == .yourls }

    var apiKeyLabel: String {
        self == .yourls ? "Signature token" : "API key"
    }
}

struct ShortenerConfig {
    var provider: ShortenerProvider
    var apiKey: String
    var baseURL: String
}

enum ShortenerError: LocalizedError {
    case missingAPIKey(ShortenerProvider)
    case missingBaseURL(ShortenerProvider)
    case badResponse(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let provider):
            return "Add your \(provider.displayName) \(provider.apiKeyLabel.lowercased()) in Settings."
        case .missingBaseURL(let provider):
            return "Add your \(provider.displayName) server address in Settings."
        case .badResponse(let detail):
            return "Shortening failed: \(detail)"
        }
    }
}

enum URLShortener {
    static func shorten(_ url: URL, config: ShortenerConfig) async throws -> URL {
        let apiKey = config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseURL = config.baseURL
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        if config.provider.needsAPIKey, apiKey.isEmpty {
            throw ShortenerError.missingAPIKey(config.provider)
        }
        if config.provider.needsBaseURL, URL(string: baseURL)?.host == nil {
            throw ShortenerError.missingBaseURL(config.provider)
        }

        let long = url.absoluteString

        switch config.provider {
        case .tinyURL:
            let request = URLRequest(url: try makeURL("https://tinyurl.com/api-create.php?url=\(formEncode(long))"))
            let data = try await send(request)
            let text = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            return try parseShortURL(text)

        case .bitly:
            var request = URLRequest(url: try makeURL("https://api-ssl.bitly.com/v4/shorten"))
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            try setJSONBody(["long_url": long], on: &request)
            let data = try await send(request)
            return try parseShortURL(try jsonString("link", from: data))

        case .dub:
            var request = URLRequest(url: try makeURL("https://api.dub.co/links"))
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            try setJSONBody(["url": long], on: &request)
            let data = try await send(request)
            return try parseShortURL(try jsonString("shortLink", from: data))

        case .shlink:
            var request = URLRequest(url: try makeURL("\(baseURL)/rest/v3/short-urls"))
            request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
            try setJSONBody(["longUrl": long], on: &request)
            let data = try await send(request)
            return try parseShortURL(try jsonString("shortUrl", from: data))

        case .yourls:
            let query = "signature=\(formEncode(apiKey))&action=shorturl&format=json&url=\(formEncode(long))"
            let request = URLRequest(url: try makeURL("\(baseURL)/yourls-api.php?\(query)"))
            // YOURLS answers an already-shortened link with an error status
            // but still includes the existing short URL, so allow that through.
            let data = try await send(request, acceptErrorStatus: true)
            return try parseShortURL(try jsonString("shorturl", from: data))
        }
    }

    // MARK: Networking helpers

    private static func send(_ request: URLRequest, acceptErrorStatus: Bool = false) async throws -> Data {
        var request = request
        request.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ShortenerError.badResponse("no HTTP response")
        }
        if !(200..<300).contains(http.statusCode) && !acceptErrorStatus {
            let body = String(decoding: data.prefix(200), as: UTF8.self)
            throw ShortenerError.badResponse("HTTP \(http.statusCode) \(body)")
        }
        return data
    }

    private static func setJSONBody(_ body: [String: String], on request: inout URLRequest) throws {
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
    }

    private static func jsonString(_ key: String, from data: Data) throws -> String {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let value = object[key] as? String
        else {
            let body = String(decoding: data.prefix(200), as: UTF8.self)
            throw ShortenerError.badResponse("unexpected response \(body)")
        }
        return value
    }

    private static func parseShortURL(_ text: String) throws -> URL {
        guard let url = URL(string: text), url.scheme != nil else {
            throw ShortenerError.badResponse("unexpected response \(text.prefix(200))")
        }
        return url
    }

    private static func makeURL(_ string: String) throws -> URL {
        guard let url = URL(string: string) else {
            throw ShortenerError.badResponse("invalid address \(string)")
        }
        return url
    }

    /// Percent-encodes everything except unreserved characters, so a long
    /// URL's own "&", "=" and "?" survive as a single query value.
    private static func formEncode(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}
