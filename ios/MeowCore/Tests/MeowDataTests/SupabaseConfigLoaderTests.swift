import Foundation
import Testing
@testable import MeowData

@Test
func supabaseConfigLoaderParsesValidEnv() throws {
    let env = [
        "SUPABASE_URL": "https://example.supabase.co",
        "SUPABASE_ANON_KEY": "anon-key"
    ]

    let config = try SupabaseConfigLoader.load(from: env)
    #expect(config.url.absoluteString == "https://example.supabase.co")
    #expect(config.anonKey == "anon-key")
}

@Test
func supabaseConfigLoaderRejectsMissingURL() {
    let env = ["SUPABASE_ANON_KEY": "anon-key"]

    #expect(throws: SupabaseConfigError.missingURL) {
        _ = try SupabaseConfigLoader.load(from: env)
    }
}
