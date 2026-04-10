import Foundation
import Testing
@testable import MeowFeatures
import MeowData
import MeowDomain

@Test
@MainActor
func exploreShowsHomeRequirementWhenNoHomeConfigured() async {
    let vm = ExploreViewModel(
        homeRepository: InMemoryHomeRepository(),
        encounterRepository: InMemoryEncounterRepository(),
        notificationRepository: InMemoryNotificationRepository(),
        telemetryRepository: InMemoryTelemetryRepository(),
        locationService: InMemoryLocationService()
    )
    vm.useLiveLocation = false

    await vm.checkNearbyCats(userID: UUID())

    #expect(vm.statusMessage == "Set your home area first.")
}

@Test
@MainActor
func exploreReportsEncounterWhenEligible() async throws {
    let userID = UUID()
    let homes = InMemoryHomeRepository()
    _ = try await homes.upsertHome(
        userID: userID,
        draft: HomeDraft(
            label: "Home",
            area: HomeArea(center: Coordinate(latitude: 37.3317, longitude: -122.0301), radiusMeters: 80)
        ),
        geohashPrefix: "9q9"
    )
    let telemetry = InMemoryTelemetryRepository()

    let vm = ExploreViewModel(
        homeRepository: homes,
        encounterRepository: InMemoryEncounterRepository(),
        notificationRepository: InMemoryNotificationRepository(),
        telemetryRepository: telemetry,
        locationService: InMemoryLocationService()
    )

    vm.useLiveLocation = false
    vm.latitude = 37.3400
    vm.longitude = -122.0400
    vm.horizontalAccuracyMeters = 10

    await vm.checkNearbyCats(userID: userID)

    #expect(vm.encounterMessage != nil)
    let successEvent = await telemetry.events().first(where: { $0.eventName == "encounter_success" })
    #expect(successEvent != nil)
    #expect(successEvent?.properties["cat_source"] == "new_local")
    #expect(successEvent?.properties["familiar_encounter_count"] == "0")
    #expect(successEvent?.properties["adjacent_roam_used"] == "false")
    #expect(successEvent?.properties["region_state"] == "active")
    #expect(successEvent?.properties["was_reactivated"] == "false")
}

@Test
@MainActor
func exploreRefreshHomeContextLoadsHomeAreaForMapDebug() async throws {
    let userID = UUID()
    let homes = InMemoryHomeRepository()
    _ = try await homes.upsertHome(
        userID: userID,
        draft: HomeDraft(
            label: "Home",
            area: HomeArea(center: Coordinate(latitude: 35.6895, longitude: 139.6917), radiusMeters: 90)
        ),
        geohashPrefix: "xn7"
    )

    let vm = ExploreViewModel(
        homeRepository: homes,
        encounterRepository: InMemoryEncounterRepository(),
        notificationRepository: InMemoryNotificationRepository(),
        telemetryRepository: InMemoryTelemetryRepository(),
        locationService: InMemoryLocationService()
    )

    await vm.refreshHomeContext(userID: userID)

    #expect(vm.activeHomeArea?.center.latitude == 35.6895)
    #expect(vm.activeHomeArea?.center.longitude == 139.6917)
    #expect(vm.activeHomeArea?.radiusMeters == 90)
}

@Test
@MainActor
func exploreTracksEncounterEcologyTelemetryContext() async throws {
    let userID = UUID()
    let homes = InMemoryHomeRepository()
    _ = try await homes.upsertHome(
        userID: userID,
        draft: HomeDraft(
            label: "Home",
            area: HomeArea(center: Coordinate(latitude: 37.3317, longitude: -122.0301), radiusMeters: 80)
        ),
        geohashPrefix: "9q9"
    )
    let telemetry = InMemoryTelemetryRepository()
    let catID = UUID()

    let vm = ExploreViewModel(
        homeRepository: homes,
        encounterRepository: StubEncounterRepository(
            result: RegionActivationRollResult(
                regionID: UUID(),
                regionGeohash: "9q9hvum",
                countryCode: "JP",
                densityTier: "city",
                regionState: "active",
                wasReactivated: true,
                isNewRegion: false,
                cooldownActive: false,
                cooldownRemainingSeconds: 0,
                encounterRolled: true,
                encounterEventID: UUID(),
                encounterHappenedAt: Date(),
                catSource: "familiar_adjacent_roam",
                familiarEncounterCount: 4,
                adjacentRoamUsed: true,
                cat: CatEncounterPreview(id: catID, internalName: "Stray-test", displayName: "Nori")
            )
        ),
        notificationRepository: InMemoryNotificationRepository(),
        telemetryRepository: telemetry,
        locationService: InMemoryLocationService()
    )

    vm.useLiveLocation = false
    vm.latitude = 37.3400
    vm.longitude = -122.0400
    vm.horizontalAccuracyMeters = 10

    await vm.checkNearbyCats(userID: userID)

    let event = await telemetry.events().first(where: { $0.eventName == "encounter_success" })
    #expect(event != nil)
    #expect(event?.properties["cat_source"] == "familiar_adjacent_roam")
    #expect(event?.properties["familiar_encounter_count"] == "4")
    #expect(event?.properties["adjacent_roam_used"] == "true")
    #expect(event?.properties["region_state"] == "active")
    #expect(event?.properties["was_reactivated"] == "true")
    #expect(event?.properties["cat_id"] == catID.uuidString)
}

private actor StubEncounterRepository: EncounterRepository {
    private let result: RegionActivationRollResult

    init(result: RegionActivationRollResult) {
        self.result = result
    }

    func latestEncounter(userID: UUID) async throws -> EncounterEventRecord? {
        _ = userID
        return nil
    }

    func activateRegionAndRollEncounter(
        geohash: String,
        precision: Int,
        countryCode: String?,
        densityHint: String?
    ) async throws -> RegionActivationRollResult {
        _ = geohash
        _ = precision
        _ = countryCode
        _ = densityHint
        return result
    }
}
