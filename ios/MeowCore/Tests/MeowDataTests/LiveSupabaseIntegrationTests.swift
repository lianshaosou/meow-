import Foundation
import Testing
@testable import MeowData
import MeowDomain

@Suite(.serialized)
struct LiveSupabaseIntegrationTests {
    @Test
    func liveAuthAndEncounterRpcRoundTrip() async throws {
        guard let live = LiveSupabaseTestConfig.fromEnvironment() else {
            return
        }

        let store = SupabaseSessionStore(storageKey: live.storageKeyPrefix + ".encounter", preferKeychain: false)
        let auth = SupabaseAuthService(config: live.config, sessionStore: store)
        let session = try await auth.signInWithEmail(email: live.email, password: live.password)
        defer {
            Task {
                await auth.signOut()
            }
        }

        #expect(session.provider == .email)

        let repository = SupabaseEncounterRepository(config: live.config, sessionStore: store)
        let result = try await repository.activateRegionAndRollEncounter(
            geohash: live.geohash,
            precision: live.geohash.count,
            countryCode: live.countryCode,
            densityHint: nil
        )

        #expect(result.regionGeohash == live.geohash)
    }

    @Test
    func liveNotificationLifecycleRoundTrip() async throws {
        guard let live = LiveSupabaseTestConfig.fromEnvironment() else {
            return
        }

        let store = SupabaseSessionStore(storageKey: live.storageKeyPrefix + ".notifications", preferKeychain: false)
        let auth = SupabaseAuthService(config: live.config, sessionStore: store)
        let session = try await auth.signInWithEmail(email: live.email, password: live.password)
        defer {
            Task {
                await auth.signOut()
            }
        }

        let notifications = SupabaseNotificationRepository(config: live.config, sessionStore: store)
        let runID = UUID().uuidString
        let draft = NotificationEventDraft(
            userID: session.userID,
            category: "integration_live_test",
            severity: .low,
            title: "live-test-\(runID)",
            body: "Live integration path validation",
            payload: ["run_id": runID],
            scheduledFor: Date().addingTimeInterval(-5)
        )
        try await notifications.scheduleNotification(draft)

        var claimedTarget: PendingNotificationDelivery?
        for _ in 0..<3 {
            let claimed = try await notifications.claimDueNotifications(batchSize: 100)
            if let match = claimed.first(where: { $0.payload["run_id"] == runID }) {
                claimedTarget = match
                break
            }
            try await Task.sleep(nanoseconds: 200_000_000)
        }

        #expect(claimedTarget != nil)
        if let claimedTarget {
            try await notifications.markDelivered(notificationID: claimedTarget.id)
        }
    }

    @Test
    func livePushBridgeTokenRegistrationRoundTrip() async throws {
        guard let live = LiveSupabaseTestConfig.fromEnvironment() else {
            return
        }

        let store = SupabaseSessionStore(storageKey: live.storageKeyPrefix + ".push", preferKeychain: false)
        let auth = SupabaseAuthService(config: live.config, sessionStore: store)
        _ = try await auth.signInWithEmail(email: live.email, password: live.password)
        defer {
            Task {
                await auth.signOut()
            }
        }

        let push = SupabasePushBridgeRepository(config: live.config, sessionStore: store)
        let token = "integration-live-\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
        try await push.registerDeviceToken(token: token, platform: "ios", environment: "sandbox")
    }
}

private struct LiveSupabaseTestConfig {
    let config: SupabaseConfig
    let email: String
    let password: String
    let geohash: String
    let countryCode: String?
    let storageKeyPrefix: String

    static func fromEnvironment(_ env: [String: String] = ProcessInfo.processInfo.environment) -> LiveSupabaseTestConfig? {
        guard env["MEOW_RUN_LIVE_SUPABASE_TESTS"] == "1" else {
            return nil
        }
        guard let url = env["SUPABASE_URL"],
              let anon = env["SUPABASE_ANON_KEY"],
              let email = env["SUPABASE_TEST_EMAIL"],
              let password = env["SUPABASE_TEST_PASSWORD"],
              url.isEmpty == false,
              anon.isEmpty == false,
              email.isEmpty == false,
              password.isEmpty == false,
              let parsedURL = URL(string: url) else {
            return nil
        }

        let geohash = env["SUPABASE_TEST_GEOHASH"]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let chosenGeohash = geohash.flatMap { $0.isEmpty ? nil : $0 } ?? "9q9hvum"
        let country = env["SUPABASE_TEST_COUNTRY_CODE"]?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return LiveSupabaseTestConfig(
            config: SupabaseConfig(url: parsedURL, anonKey: anon),
            email: email,
            password: password,
            geohash: chosenGeohash,
            countryCode: country,
            storageKeyPrefix: "test.live.\(UUID().uuidString)"
        )
    }
}
