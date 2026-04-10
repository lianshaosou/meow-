import Foundation
import MeowDomain

public actor SupabaseEncounterRepository: EncounterRepository {
    private struct EncounterRow: Decodable {
        let id: UUID
        let user_id: UUID
        let cat_id: UUID
        let region_id: UUID
        let happened_at: Date
    }

    private struct ActivationPayload: Encodable {
        let input_geohash: String
        let input_precision: Int
        let input_country_code: String?
        let input_density_tier: String?
    }

    private struct ActivationResponse: Decodable {
        let region_id: UUID
        let region_geohash: String
        let country_code: String?
        let density_tier: String?
        let region_state: String?
        let was_reactivated: Bool?
        let is_new_region: Bool
        let cooldown_active: Bool
        let cooldown_remaining_seconds: Int
        let encounter_rolled: Bool
        let encounter_event_id: UUID?
        let encounter_happened_at: Date?
        let cat_source: String?
        let familiar_encounter_count: Int?
        let adjacent_roam_used: Bool?
        let cat_id: UUID?
        let cat_internal_name: String?
        let cat_display_name: String?
    }

    private let client: SupabaseHTTPClient

    public init(config: SupabaseConfig, sessionStore: SupabaseSessionStore, session: URLSession = .shared) {
        self.client = SupabaseHTTPClient(config: config, session: session, sessionStore: sessionStore)
    }

    public func latestEncounter(userID: UUID) async throws -> EncounterEventRecord? {
        let path = "/rest/v1/encounter_events?user_id=eq.\(userID.uuidString)&select=id,user_id,cat_id,region_id,happened_at&order=happened_at.desc&limit=1"
        let data: Data
        do {
            data = try await client.request(path: path, method: "GET", requiresAuth: true)
        } catch let error as SupabaseHTTPError {
            throw map(error)
        }

        let rows: [EncounterRow]
        do {
            rows = try SupabaseHTTPClient.jsonDecoder().decode([EncounterRow].self, from: data)
        } catch {
            throw RepositoryError.decoding
        }

        guard let row = rows.first else { return nil }
        return EncounterEventRecord(
            id: row.id,
            userID: row.user_id,
            catID: row.cat_id,
            regionID: row.region_id,
            happenedAt: row.happened_at
        )
    }

    public func activateRegionAndRollEncounter(
        geohash: String,
        precision: Int,
        countryCode: String?,
        densityHint: String?
    ) async throws -> RegionActivationRollResult {
        let payload = ActivationPayload(
            input_geohash: geohash,
            input_precision: precision,
            input_country_code: countryCode,
            input_density_tier: densityHint
        )
        let body = try JSONEncoder().encode(payload)

        let data: Data
        do {
            data = try await client.request(
                path: "/rest/v1/rpc/activate_region_and_roll_encounter",
                method: "POST",
                body: body,
                requiresAuth: true
            )
        } catch let error as SupabaseHTTPError {
            throw map(error)
        }

        let response: ActivationResponse
        do {
            response = try SupabaseHTTPClient.jsonDecoder().decode(ActivationResponse.self, from: data)
        } catch {
            throw RepositoryError.decoding
        }

        let catPreview: CatEncounterPreview?
        if let catID = response.cat_id, let internalName = response.cat_internal_name {
            catPreview = CatEncounterPreview(
                id: catID,
                internalName: internalName,
                displayName: response.cat_display_name
            )
        } else {
            catPreview = nil
        }

        return RegionActivationRollResult(
            regionID: response.region_id,
            regionGeohash: response.region_geohash,
            countryCode: response.country_code,
            densityTier: response.density_tier,
            regionState: response.region_state,
            wasReactivated: response.was_reactivated,
            isNewRegion: response.is_new_region,
            cooldownActive: response.cooldown_active,
            cooldownRemainingSeconds: response.cooldown_remaining_seconds,
            encounterRolled: response.encounter_rolled,
            encounterEventID: response.encounter_event_id,
            encounterHappenedAt: response.encounter_happened_at,
            catSource: response.cat_source,
            familiarEncounterCount: response.familiar_encounter_count,
            adjacentRoamUsed: response.adjacent_roam_used,
            cat: catPreview
        )
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
