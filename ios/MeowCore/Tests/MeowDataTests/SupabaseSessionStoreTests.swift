import Foundation
import Testing
@testable import MeowData
import MeowDomain

@Test
func sessionStorePersistsAcrossInstances() async {
    let suiteName = "meow.tests.session.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    let storageKey = "session"

    let session = AuthSession(userID: UUID(), provider: .email, createdAt: Date(timeIntervalSince1970: 1_000))

    let first = SupabaseSessionStore(userDefaults: defaults, storageKey: storageKey, preferKeychain: false)
    await first.set(.init(authSession: session, accessToken: "abc", refreshToken: "def"))

    let second = SupabaseSessionStore(userDefaults: defaults, storageKey: storageKey, preferKeychain: false)
    let restored = await second.current()

    #expect(restored?.authSession == session)
    #expect(restored?.accessToken == "abc")
    #expect(restored?.refreshToken == "def")

    await second.clear()
    defaults.removePersistentDomain(forName: suiteName)
}
