import Foundation

public struct SupabaseConfig: Sendable, Equatable {
    public let url: URL
    public let anonKey: String

    public init(url: URL, anonKey: String) {
        self.url = url
        self.anonKey = anonKey
    }
}

public enum SupabaseConfigError: Error, Equatable {
    case missingURL
    case invalidURL
    case missingAnonKey
}

public enum SupabaseConfigLoader {
    public static func load(from env: [String: String] = ProcessInfo.processInfo.environment) throws -> SupabaseConfig {
        guard let urlString = env["SUPABASE_URL"], urlString.isEmpty == false else {
            throw SupabaseConfigError.missingURL
        }
        guard let url = URL(string: urlString) else {
            throw SupabaseConfigError.invalidURL
        }
        guard let anonKey = env["SUPABASE_ANON_KEY"], anonKey.isEmpty == false else {
            throw SupabaseConfigError.missingAnonKey
        }
        return SupabaseConfig(url: url, anonKey: anonKey)
    }
}
