import Foundation
import MeowDomain

public enum RepositoryError: Error, Equatable {
    case unauthorized
    case decoding
    case invalidResponse
    case server(String)
}

public actor SupabaseProfileRepository: ProfileRepository {
    private struct ProfileRow: Codable {
        let id: UUID
        let nickname: String
    }

    private let client: SupabaseHTTPClient

    public init(config: SupabaseConfig, sessionStore: SupabaseSessionStore) {
        self.client = SupabaseHTTPClient(config: config, sessionStore: sessionStore)
    }

    public func upsertProfile(_ profile: UserProfile) async throws {
        let rows = [ProfileRow(id: profile.id, nickname: profile.nickname)]
        let body = try JSONEncoder().encode(rows)

        do {
            _ = try await client.request(
                path: "/rest/v1/profiles",
                method: "POST",
                body: body,
                requiresAuth: true,
                extraHeaders: ["Prefer": "resolution=merge-duplicates"]
            )
        } catch let error as SupabaseHTTPError {
            throw map(error)
        }
    }

    public func profile(userID: UUID) async throws -> UserProfile? {
        let path = "/rest/v1/profiles?id=eq.\(userID.uuidString)&select=id,nickname&limit=1"

        let data: Data
        do {
            data = try await client.request(path: path, method: "GET", requiresAuth: true)
        } catch let error as SupabaseHTTPError {
            throw map(error)
        }

        let rows = try decode([ProfileRow].self, from: data)
        guard let row = rows.first else { return nil }
        return UserProfile(id: row.id, nickname: row.nickname)
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try SupabaseHTTPClient.jsonDecoder().decode(T.self, from: data)
        } catch {
            throw RepositoryError.decoding
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

public actor SupabaseHomeRepository: HomeRepository {
    private struct HomeRow: Codable {
        let id: UUID
        let user_id: UUID
        let label: String
        let center_lat: Double
        let center_lng: Double
        let radius_meters: Int
        let geohash_prefix: String
        let updated_at: Date
    }

    private struct HomePayload: Codable {
        let user_id: UUID
        let label: String
        let center_lat: Double
        let center_lng: Double
        let radius_meters: Int
        let geohash_prefix: String
        let is_active: Bool
    }

    private let client: SupabaseHTTPClient

    public init(config: SupabaseConfig, sessionStore: SupabaseSessionStore) {
        self.client = SupabaseHTTPClient(config: config, sessionStore: sessionStore)
    }

    public func upsertHome(userID: UUID, draft: HomeDraft, geohashPrefix: String) async throws -> HomeRecord {
        let payload = HomePayload(
            user_id: userID,
            label: draft.label,
            center_lat: draft.area.center.latitude,
            center_lng: draft.area.center.longitude,
            radius_meters: Int(draft.area.radiusMeters),
            geohash_prefix: geohashPrefix,
            is_active: true
        )

        if let existing = try await activeHome(userID: userID) {
            let body = try JSONEncoder().encode(payload)
            let path = "/rest/v1/homes?id=eq.\(existing.id.uuidString)&select=id,user_id,label,center_lat,center_lng,radius_meters,geohash_prefix,updated_at"

            let data: Data
            do {
                data = try await client.request(
                    path: path,
                    method: "PATCH",
                    body: body,
                    requiresAuth: true,
                    extraHeaders: ["Prefer": "return=representation"]
                )
            } catch let error as SupabaseHTTPError {
                throw map(error)
            }

            let rows = try decode([HomeRow].self, from: data)
            guard let row = rows.first else { throw RepositoryError.invalidResponse }
            return mapRow(row)
        }

        let body = try JSONEncoder().encode([payload])
        let data: Data
        do {
            data = try await client.request(
                path: "/rest/v1/homes?select=id,user_id,label,center_lat,center_lng,radius_meters,geohash_prefix,updated_at",
                method: "POST",
                body: body,
                requiresAuth: true,
                extraHeaders: ["Prefer": "return=representation"]
            )
        } catch let error as SupabaseHTTPError {
            throw map(error)
        }

        let rows = try decode([HomeRow].self, from: data)
        guard let row = rows.first else { throw RepositoryError.invalidResponse }
        return mapRow(row)
    }

    public func activeHome(userID: UUID) async throws -> HomeRecord? {
        let path = "/rest/v1/homes?user_id=eq.\(userID.uuidString)&is_active=eq.true&select=id,user_id,label,center_lat,center_lng,radius_meters,geohash_prefix,updated_at&order=updated_at.desc&limit=1"
        let data: Data
        do {
            data = try await client.request(path: path, method: "GET", requiresAuth: true)
        } catch let error as SupabaseHTTPError {
            throw map(error)
        }

        let rows = try decode([HomeRow].self, from: data)
        return rows.first.map(mapRow)
    }

    private func mapRow(_ row: HomeRow) -> HomeRecord {
        HomeRecord(
            id: row.id,
            userID: row.user_id,
            label: row.label,
            area: HomeArea(
                center: Coordinate(latitude: row.center_lat, longitude: row.center_lng),
                radiusMeters: Double(row.radius_meters)
            ),
            geohashPrefix: row.geohash_prefix,
            updatedAt: row.updated_at
        )
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try SupabaseHTTPClient.jsonDecoder().decode(T.self, from: data)
        } catch {
            throw RepositoryError.decoding
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

public actor SupabaseTimeSnapshotRepository: TimeSnapshotRepository {
    private struct TimeSnapshotPayload: Codable {
        let user_id: UUID
        let entity_type: String
        let entity_id: UUID?
        let real_world_timestamp: Date
        let simulation_timestamp: Date
        let care_cycle_timestamp: Date
    }

    private struct TimeSnapshotRow: Codable {
        let id: UUID
        let user_id: UUID
        let entity_type: String
        let entity_id: UUID?
        let real_world_timestamp: Date
        let simulation_timestamp: Date
        let care_cycle_timestamp: Date
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

    public func saveSnapshot(
        userID: UUID,
        entityType: String,
        entityID: UUID?,
        state: TimeState
    ) async throws -> TimeSnapshotRecord {
        let payload = TimeSnapshotPayload(
            user_id: userID,
            entity_type: entityType,
            entity_id: entityID,
            real_world_timestamp: state.realWorld,
            simulation_timestamp: state.simulation,
            care_cycle_timestamp: state.careCycle
        )
        let body = try encoder.encode([payload])

        let data: Data
        do {
            data = try await client.request(
                path: "/rest/v1/time_state_snapshots?select=id,user_id,entity_type,entity_id,real_world_timestamp,simulation_timestamp,care_cycle_timestamp,created_at",
                method: "POST",
                body: body,
                requiresAuth: true,
                extraHeaders: ["Prefer": "return=representation"]
            )
        } catch let error as SupabaseHTTPError {
            throw map(error)
        }

        let rows = try decode([TimeSnapshotRow].self, from: data)
        guard let row = rows.first else { throw RepositoryError.invalidResponse }
        return mapRow(row)
    }

    public func latestSnapshot(userID: UUID, entityType: String) async throws -> TimeSnapshotRecord? {
        let escapedType = entityType.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? entityType
        let path = "/rest/v1/time_state_snapshots?user_id=eq.\(userID.uuidString)&entity_type=eq.\(escapedType)&select=id,user_id,entity_type,entity_id,real_world_timestamp,simulation_timestamp,care_cycle_timestamp,created_at&order=real_world_timestamp.desc&limit=1"

        let data: Data
        do {
            data = try await client.request(path: path, method: "GET", requiresAuth: true)
        } catch let error as SupabaseHTTPError {
            throw map(error)
        }

        let rows = try decode([TimeSnapshotRow].self, from: data)
        return rows.first.map(mapRow)
    }

    private func mapRow(_ row: TimeSnapshotRow) -> TimeSnapshotRecord {
        TimeSnapshotRecord(
            id: row.id,
            userID: row.user_id,
            entityType: row.entity_type,
            entityID: row.entity_id,
            state: TimeState(
                realWorld: row.real_world_timestamp,
                simulation: row.simulation_timestamp,
                careCycle: row.care_cycle_timestamp
            ),
            createdAt: row.created_at
        )
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try SupabaseHTTPClient.jsonDecoder().decode(T.self, from: data)
        } catch {
            throw RepositoryError.decoding
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
