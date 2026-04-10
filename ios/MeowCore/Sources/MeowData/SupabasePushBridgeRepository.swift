import Foundation

public actor SupabasePushBridgeRepository: PushBridgeRepository {
    private let client: SupabaseHTTPClient

    public init(config: SupabaseConfig, sessionStore: SupabaseSessionStore, session: URLSession = .shared) {
        self.client = SupabaseHTTPClient(config: config, session: session, sessionStore: sessionStore)
    }

    public func registerDeviceToken(token: String, platform: String, environment: String) async throws {
        let body = try JSONEncoder().encode([
            "input_token": token,
            "input_platform": platform,
            "input_environment": environment
        ])

        do {
            _ = try await client.request(
                path: "/rest/v1/rpc/register_push_device_token",
                method: "POST",
                body: body,
                requiresAuth: true
            )
        } catch let error as SupabaseHTTPError {
            throw map(error)
        }
    }

    public func enqueueRemoteDelivery(notificationID: UUID) async throws -> Int {
        let body = try JSONEncoder().encode(["input_notification_id": notificationID.uuidString])
        let data: Data
        do {
            data = try await client.request(
                path: "/rest/v1/rpc/enqueue_notification_push",
                method: "POST",
                body: body,
                requiresAuth: true
            )
        } catch let error as SupabaseHTTPError {
            throw map(error)
        }

        if let value = try? JSONDecoder().decode(Int.self, from: data) {
            return value
        }
        if let stringValue = String(data: data, encoding: .utf8),
           let intValue = Int(stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return intValue
        }
        throw RepositoryError.decoding
    }

    private func map(_ error: SupabaseHTTPError) -> RepositoryError {
        switch error {
        case .missingAuthToken:
            return .unauthorized
        case .badResponse:
            return .invalidResponse
        case .statusCode(let code, let message):
            if code == 401 || code == 403 { return .unauthorized }
            return .server(message)
        }
    }
}
