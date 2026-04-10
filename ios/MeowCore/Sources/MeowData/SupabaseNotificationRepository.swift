import Foundation
import MeowDomain

public actor SupabaseNotificationRepository: NotificationRepository {
    private struct NotificationPayload: Encodable {
        let user_id: UUID
        let category: String
        let severity: String
        let title: String
        let body: String
        let payload: [String: String]
        let scheduled_for: Date
    }

    private struct PendingRow: Decodable {
        let id: UUID
        let user_id: UUID
        let category: String
        let severity: String
        let title: String
        let body: String
        let payload: [String: String]
        let scheduled_for: Date
    }

    private let client: SupabaseHTTPClient
    private let encoder: JSONEncoder

    public init(config: SupabaseConfig, sessionStore: SupabaseSessionStore, session: URLSession = .shared) {
        self.client = SupabaseHTTPClient(config: config, session: session, sessionStore: sessionStore)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    public func scheduleNotification(_ draft: NotificationEventDraft) async throws {
        let payload = NotificationPayload(
            user_id: draft.userID,
            category: draft.category,
            severity: draft.severity.rawValue,
            title: draft.title,
            body: draft.body,
            payload: draft.payload,
            scheduled_for: draft.scheduledFor
        )

        let body = try encoder.encode([payload])
        do {
            _ = try await client.request(
                path: "/rest/v1/notification_events",
                method: "POST",
                body: body,
                requiresAuth: true
            )
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

    public func claimDueNotifications(batchSize: Int) async throws -> [PendingNotificationDelivery] {
        let body = try JSONEncoder().encode(["input_batch_size": max(1, min(batchSize, 100))])
        let data: Data
        do {
            data = try await client.request(
                path: "/rest/v1/rpc/claim_due_notifications",
                method: "POST",
                body: body,
                requiresAuth: true
            )
        } catch let error as SupabaseHTTPError {
            throw map(error)
        }

        let rows: [PendingRow]
        do {
            rows = try SupabaseHTTPClient.jsonDecoder().decode([PendingRow].self, from: data)
        } catch {
            throw RepositoryError.decoding
        }

        return rows.compactMap { row in
            guard let severity = NotificationSeverity(rawValue: row.severity) else {
                return nil
            }
            return PendingNotificationDelivery(
                id: row.id,
                userID: row.user_id,
                category: row.category,
                severity: severity,
                title: row.title,
                body: row.body,
                payload: row.payload,
                scheduledFor: row.scheduled_for
            )
        }
    }

    public func markDelivered(notificationID: UUID) async throws {
        let body = try JSONEncoder().encode(["input_notification_id": notificationID.uuidString])
        do {
            _ = try await client.request(
                path: "/rest/v1/rpc/mark_notification_delivered",
                method: "POST",
                body: body,
                requiresAuth: true
            )
        } catch let error as SupabaseHTTPError {
            throw map(error)
        }
    }

    public func markFailed(notificationID: UUID, error: String) async throws {
        let body = try JSONEncoder().encode([
            "input_notification_id": notificationID.uuidString,
            "input_error": error
        ])
        do {
            _ = try await client.request(
                path: "/rest/v1/rpc/mark_notification_failed",
                method: "POST",
                body: body,
                requiresAuth: true
            )
        } catch let error as SupabaseHTTPError {
            throw map(error)
        }
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
