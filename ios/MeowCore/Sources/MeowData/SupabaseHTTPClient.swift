import Foundation

enum SupabaseHTTPError: Error, Equatable {
    case missingAuthToken
    case badResponse
    case statusCode(Int, String)
}

struct SupabaseHTTPClient {
    let config: SupabaseConfig
    let session: URLSession
    let sessionStore: SupabaseSessionStore

    init(config: SupabaseConfig, session: URLSession = .shared, sessionStore: SupabaseSessionStore) {
        self.config = config
        self.session = session
        self.sessionStore = sessionStore
    }

    func request(
        path: String,
        method: String,
        body: Data? = nil,
        requiresAuth: Bool,
        extraHeaders: [String: String] = [:]
    ) async throws -> Data {
        let url = config.url.appending(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")

        if requiresAuth {
            guard let token = await sessionStore.current()?.accessToken else {
                throw SupabaseHTTPError.missingAuthToken
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        for (key, value) in extraHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseHTTPError.badResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? ""
            throw SupabaseHTTPError.statusCode(httpResponse.statusCode, message)
        }
        return data
    }

    static func jsonDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            let withFractional = ISO8601DateFormatter()
            withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = withFractional.date(from: value) {
                return date
            }

            let plain = ISO8601DateFormatter()
            plain.formatOptions = [.withInternetDateTime]
            if let date = plain.date(from: value) {
                return date
            }

            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(value)")
        }
        return decoder
    }
}
