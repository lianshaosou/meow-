import Foundation
import Testing
@testable import MeowData
import MeowDomain

@Suite(.serialized)
struct SupabaseIntegrationPathTests {
    @Test
    func supabaseEncounterRepositoryActivatesRegionWithCountryContext() async throws {
        let session = makeMockSession()
        let config = SupabaseConfig(url: URL(string: "https://example.supabase.co")!, anonKey: "anon")
        let store = SupabaseSessionStore(storageKey: "test.encounter.session", preferKeychain: false)
        await store.set(
            .init(
                authSession: AuthSession(userID: UUID(), provider: .email, createdAt: Date()),
                accessToken: "token",
                refreshToken: "refresh"
            )
        )
        MockURLProtocol.handler = { request in
            #expect(request.url?.path == "/rest/v1/rpc/activate_region_and_roll_encounter")
            #expect(request.httpMethod == "POST")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer token")

            let bodyData = requestBodyData(from: request)
            let body = (try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any]) ?? [:]
            #expect(body["input_geohash"] as? String == "9q9hvum")
            #expect(body["input_country_code"] as? String == "JP")
            #expect(body["input_density_tier"] as? String == "city")

            let responseBody: [String: Any] = [
                "region_id": "7afdb4d7-4822-4975-89c8-fc6717ffca2d",
                "region_geohash": "9q9hvum",
                "country_code": "JP",
                "density_tier": "city",
                "region_state": "active",
                "was_reactivated": false,
                "is_new_region": true,
                "cooldown_active": false,
                "cooldown_remaining_seconds": 0,
                "encounter_rolled": true,
                "encounter_event_id": "22032dd4-b3cc-44b0-93d2-9ada475f13f1",
                "encounter_happened_at": "2026-04-05T21:00:00Z",
                "cat_source": "familiar_local",
                "familiar_encounter_count": 2,
                "adjacent_roam_used": false,
                "cat_id": "65d78c1f-bda4-41c3-abfe-dd24953cf13f",
                "cat_internal_name": "Stray-aaaa1111",
                "cat_display_name": NSNull()
            ]
            let data = (try? JSONSerialization.data(withJSONObject: responseBody)) ?? Data("{}".utf8)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, data)
        }
        defer { MockURLProtocol.handler = nil }

        let repository = SupabaseEncounterRepository(config: config, sessionStore: store, session: session)
        let result = try await repository.activateRegionAndRollEncounter(
            geohash: "9q9hvum",
            precision: 7,
            countryCode: "JP",
            densityHint: "city"
        )

        #expect(result.regionGeohash == "9q9hvum")
        #expect(result.countryCode == "JP")
        #expect(result.densityTier == "city")
        #expect(result.regionState == "active")
        #expect(result.wasReactivated == false)
        #expect(result.encounterRolled)
        #expect(result.catSource == "familiar_local")
        #expect(result.familiarEncounterCount == 2)
        #expect(result.adjacentRoamUsed == false)
        #expect(result.cat?.internalName == "Stray-aaaa1111")
    }

    @Test
    func supabaseEncounterRepositoryMapsReactivationAndAdjacentRoamMetadata() async throws {
        let session = makeMockSession()
        let config = SupabaseConfig(url: URL(string: "https://example.supabase.co")!, anonKey: "anon")
        let store = SupabaseSessionStore(storageKey: "test.encounter.metadata.session", preferKeychain: false)
        await store.set(
            .init(
                authSession: AuthSession(userID: UUID(), provider: .email, createdAt: Date()),
                accessToken: "token",
                refreshToken: "refresh"
            )
        )

        MockURLProtocol.handler = { request in
            #expect(request.url?.path == "/rest/v1/rpc/activate_region_and_roll_encounter")
            let responseBody: [String: Any] = [
                "region_id": "5f9b3a64-8795-4e19-a7e7-4afb34ec2db7",
                "region_geohash": "xn774c",
                "country_code": "JP",
                "density_tier": "city",
                "region_state": "active",
                "was_reactivated": true,
                "is_new_region": false,
                "cooldown_active": false,
                "cooldown_remaining_seconds": 0,
                "encounter_rolled": true,
                "encounter_event_id": "8b067e89-cb95-42f0-ac88-a9122cf3f272",
                "encounter_happened_at": "2026-04-09T10:00:00Z",
                "cat_source": "familiar_adjacent_roam",
                "familiar_encounter_count": 6,
                "adjacent_roam_used": true,
                "cat_id": "19ea9406-c4ec-4a63-87db-b5ea2539e082",
                "cat_internal_name": "Stray-bbbb2222",
                "cat_display_name": "Momo"
            ]
            let data = (try? JSONSerialization.data(withJSONObject: responseBody)) ?? Data("{}".utf8)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, data)
        }
        defer { MockURLProtocol.handler = nil }

        let repository = SupabaseEncounterRepository(config: config, sessionStore: store, session: session)
        let result = try await repository.activateRegionAndRollEncounter(
            geohash: "xn774c",
            precision: 6,
            countryCode: "JP",
            densityHint: "city"
        )

        #expect(result.regionState == "active")
        #expect(result.wasReactivated == true)
        #expect(result.catSource == "familiar_adjacent_roam")
        #expect(result.familiarEncounterCount == 6)
        #expect(result.adjacentRoamUsed == true)
        #expect(result.cat?.displayName == "Momo")
    }

    @Test
    func supabaseAuthServiceUnlinksProviderWithIdentityDelete() async throws {
        let session = makeMockSession()
        let config = SupabaseConfig(url: URL(string: "https://example.supabase.co")!, anonKey: "anon")
        let store = SupabaseSessionStore(storageKey: "test.auth.unlink.session", preferKeychain: false)
        let userID = UUID()
        await store.set(
            .init(
                authSession: AuthSession(userID: userID, provider: .apple, createdAt: Date()),
                accessToken: "token",
                refreshToken: "refresh"
            )
        )

        var calledPaths: [String] = []
        MockURLProtocol.handler = { request in
            let path = request.url?.path ?? ""
            calledPaths.append(path)

            if path == "/auth/v1/user" {
                let data = """
                {
                  "identities": [
                    {"identity_id": "apple-id-1", "provider": "apple"},
                    {"identity_id": "email-id-1", "provider": "email"}
                  ]
                }
                """.data(using: .utf8)!
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, data)
            }

            if path == "/auth/v1/user/identities/apple-id-1" {
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, Data("{}".utf8))
            }

            throw NSError(domain: "unexpected-path", code: 1)
        }
        defer { MockURLProtocol.handler = nil }

        let auth = SupabaseAuthService(config: config, sessionStore: store, session: session)
        let sessionAfter = try await auth.unlinkProvider(.apple)
        let currentSessionProvider = await store.current()?.authSession.provider

        #expect(calledPaths.contains("/auth/v1/user"))
        #expect(calledPaths.contains("/auth/v1/user/identities/apple-id-1"))
        #expect(sessionAfter.provider == .email)
        #expect(currentSessionProvider == .email)
    }

    @Test
    func supabaseNotificationRepositoryClaimsAndMarksDelivered() async throws {
        let session = makeMockSession()
        let config = SupabaseConfig(url: URL(string: "https://example.supabase.co")!, anonKey: "anon")
        let store = SupabaseSessionStore(storageKey: "test.notifications.session", preferKeychain: false)
        let userID = UUID()
        await store.set(
            .init(
                authSession: AuthSession(userID: userID, provider: .email, createdAt: Date()),
                accessToken: "token",
                refreshToken: "refresh"
            )
        )

        var paths: [String] = []
        MockURLProtocol.handler = { request in
            let path = request.url?.path ?? ""
            paths.append(path)

            if path == "/rest/v1/rpc/claim_due_notifications" {
                let data = """
                [
                  {
                    "id": "22032dd4-b3cc-44b0-93d2-9ada475f13f1",
                    "user_id": "\(userID.uuidString)",
                    "category": "encounter",
                    "severity": "medium",
                    "title": "A cat is nearby",
                    "body": "A stray was spotted.",
                    "payload": {"cat_id": "abc"},
                    "scheduled_for": "2026-04-05T21:00:00Z"
                  }
                ]
                """.data(using: .utf8)!
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, data)
            }

            if path == "/rest/v1/rpc/mark_notification_delivered" {
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, Data("{}".utf8))
            }

            throw NSError(domain: "unexpected-path", code: 1)
        }
        defer { MockURLProtocol.handler = nil }

        let repository = SupabaseNotificationRepository(config: config, sessionStore: store, session: session)
        let claimed = try await repository.claimDueNotifications(batchSize: 5)
        #expect(claimed.count == 1)
        #expect(claimed.first?.category == "encounter")

        if let id = claimed.first?.id {
            try await repository.markDelivered(notificationID: id)
        }

        #expect(paths.contains("/rest/v1/rpc/claim_due_notifications"))
        #expect(paths.contains("/rest/v1/rpc/mark_notification_delivered"))
    }

    @Test
    func supabasePushBridgeRegistersTokenAndEnqueuesRemoteDelivery() async throws {
        let session = makeMockSession()
        let config = SupabaseConfig(url: URL(string: "https://example.supabase.co")!, anonKey: "anon")
        let store = SupabaseSessionStore(storageKey: "test.pushbridge.session", preferKeychain: false)
        await store.set(
            .init(
                authSession: AuthSession(userID: UUID(), provider: .email, createdAt: Date()),
                accessToken: "token",
                refreshToken: "refresh"
            )
        )

        var called: [String] = []
        MockURLProtocol.handler = { request in
            let path = request.url?.path ?? ""
            called.append(path)

            if path == "/rest/v1/rpc/register_push_device_token" {
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, Data("\"af9b312b-e5f7-44ab-b96e-2fa9c6eeacaf\"".utf8))
            }

            if path == "/rest/v1/rpc/enqueue_notification_push" {
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, Data("2".utf8))
            }

            throw NSError(domain: "unexpected-path", code: 1)
        }
        defer { MockURLProtocol.handler = nil }

        let repo = SupabasePushBridgeRepository(config: config, sessionStore: store, session: session)
        try await repo.registerDeviceToken(token: "abcdef", platform: "ios", environment: "sandbox")
        let enqueued = try await repo.enqueueRemoteDelivery(notificationID: UUID())

        #expect(enqueued == 2)
        #expect(called.contains("/rest/v1/rpc/register_push_device_token"))
        #expect(called.contains("/rest/v1/rpc/enqueue_notification_push"))
    }

    @Test
    func supabaseRegionLifecycleRepositoryCallsDormancyTransitionRpcs() async throws {
        let session = makeMockSession()
        let config = SupabaseConfig(url: URL(string: "https://example.supabase.co")!, anonKey: "anon")
        let store = SupabaseSessionStore(storageKey: "test.region.lifecycle.session", preferKeychain: false)
        await store.set(
            .init(
                authSession: AuthSession(userID: UUID(), provider: .email, createdAt: Date()),
                accessToken: "token",
                refreshToken: "refresh"
            )
        )

        var called: [String] = []
        MockURLProtocol.handler = { request in
            let path = request.url?.path ?? ""
            called.append(path)

            if path == "/rest/v1/rpc/mark_stale_regions_dormant" {
                let bodyData = requestBodyData(from: request)
                let body = (try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any]) ?? [:]
                #expect(body["input_idle_hours"] as? Int == 72)
                #expect(body["input_batch_size"] as? Int == 200)
                #expect(body["input_reason"] as? String == "idle_timeout")
                #expect(body["input_retention_days"] as? Int == 30)

                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, Data("3".utf8))
            }

            if path == "/rest/v1/rpc/mark_expired_dormant_regions_archived" {
                let bodyData = requestBodyData(from: request)
                let body = (try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any]) ?? [:]
                #expect(body["input_batch_size"] as? Int == 100)
                #expect(body["input_reason"] as? String == "retention_elapsed")

                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, Data("2".utf8))
            }

            throw NSError(domain: "unexpected-path", code: 1)
        }
        defer { MockURLProtocol.handler = nil }

        let repository = SupabaseRegionLifecycleRepository(config: config, sessionStore: store, session: session)
        let dormant = try await repository.markStaleRegionsDormant(
            idleHours: 72,
            batchSize: 200,
            reason: "idle_timeout",
            retentionDays: 30
        )
        let archived = try await repository.markExpiredDormantRegionsArchived(
            batchSize: 100,
            reason: "retention_elapsed"
        )

        #expect(dormant == 3)
        #expect(archived == 2)
        #expect(called.contains("/rest/v1/rpc/mark_stale_regions_dormant"))
        #expect(called.contains("/rest/v1/rpc/mark_expired_dormant_regions_archived"))
    }
}

private func requestBodyData(from request: URLRequest) -> Data {
    if let body = request.httpBody {
        return body
    }
    guard let stream = request.httpBodyStream else {
        return Data()
    }

    stream.open()
    defer { stream.close() }

    var data = Data()
    let bufferSize = 1024
    var buffer = [UInt8](repeating: 0, count: bufferSize)
    while stream.hasBytesAvailable {
        let readCount = stream.read(&buffer, maxLength: bufferSize)
        if readCount <= 0 { break }
        data.append(buffer, count: readCount)
    }
    return data
}
