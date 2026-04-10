import Foundation
import MeowDomain

public actor SupabaseTelemetryRepository: TelemetryRepository {
    private struct TelemetryPayload: Encodable {
        let user_id: UUID
        let event_name: String
        let properties: [String: String]
        let created_at: Date
    }

    private let client: SupabaseHTTPClient
    private let encoder: JSONEncoder

    public init(config: SupabaseConfig, sessionStore: SupabaseSessionStore) {
        self.client = SupabaseHTTPClient(config: config, sessionStore: sessionStore)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    public func track(_ draft: TelemetryEventDraft) async throws {
        let payload = TelemetryPayload(
            user_id: draft.userID,
            event_name: draft.eventName,
            properties: draft.properties,
            created_at: draft.createdAt
        )
        let body = try encoder.encode([payload])

        do {
            _ = try await client.request(path: "/rest/v1/app_telemetry_events", method: "POST", body: body, requiresAuth: true)
        } catch let error as SupabaseHTTPError {
            switch error {
            case .missingAuthToken:
                throw RepositoryError.unauthorized
            case .badResponse:
                throw RepositoryError.invalidResponse
            case .statusCode(let code, let message):
                if code == 401 || code == 403 { throw RepositoryError.unauthorized }
                throw RepositoryError.server(message)
            }
        }
    }
}
