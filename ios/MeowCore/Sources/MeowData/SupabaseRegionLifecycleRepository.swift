import Foundation

public actor SupabaseRegionLifecycleRepository: RegionLifecycleRepository {
    private struct MarkDormantPayload: Encodable {
        let input_idle_hours: Int
        let input_batch_size: Int
        let input_reason: String
        let input_retention_days: Int?
    }

    private struct MarkArchivedPayload: Encodable {
        let input_batch_size: Int
        let input_reason: String
    }

    private let client: SupabaseHTTPClient

    public init(config: SupabaseConfig, sessionStore: SupabaseSessionStore, session: URLSession = .shared) {
        self.client = SupabaseHTTPClient(config: config, session: session, sessionStore: sessionStore)
    }

    public func markStaleRegionsDormant(
        idleHours: Int,
        batchSize: Int,
        reason: String,
        retentionDays: Int?
    ) async throws -> Int {
        let payload = MarkDormantPayload(
            input_idle_hours: idleHours,
            input_batch_size: batchSize,
            input_reason: reason,
            input_retention_days: retentionDays
        )
        let body = try JSONEncoder().encode(payload)

        let data: Data
        do {
            data = try await client.request(
                path: "/rest/v1/rpc/mark_stale_regions_dormant",
                method: "POST",
                body: body,
                requiresAuth: true
            )
        } catch let error as SupabaseHTTPError {
            throw map(error)
        }

        return parseCount(data)
    }

    public func markExpiredDormantRegionsArchived(
        batchSize: Int,
        reason: String
    ) async throws -> Int {
        let payload = MarkArchivedPayload(input_batch_size: batchSize, input_reason: reason)
        let body = try JSONEncoder().encode(payload)

        let data: Data
        do {
            data = try await client.request(
                path: "/rest/v1/rpc/mark_expired_dormant_regions_archived",
                method: "POST",
                body: body,
                requiresAuth: true
            )
        } catch let error as SupabaseHTTPError {
            throw map(error)
        }

        return parseCount(data)
    }

    private func parseCount(_ data: Data) -> Int {
        if let value = try? JSONDecoder().decode(Int.self, from: data) {
            return value
        }

        if let text = String(data: data, encoding: .utf8), let value = Int(text.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return value
        }

        return 0
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
