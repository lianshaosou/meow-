import Foundation
import Testing
@testable import MeowFeatures
import MeowDomain

@Test
func encounterIsEligibleWhenOutsideAndNoCooldown() {
    let service = EncounterEligibilityService()
    let now = Date(timeIntervalSince1970: 10_000)
    let home = HomeRecord(
        id: UUID(),
        userID: UUID(),
        label: "Home",
        area: HomeArea(center: Coordinate(latitude: 37.3317, longitude: -122.0301), radiusMeters: 80),
        geohashPrefix: "9q9",
        updatedAt: now
    )

    let result = service.evaluate(
        currentLocation: Coordinate(latitude: 37.3400, longitude: -122.0400),
        horizontalAccuracyMeters: 10,
        activeHome: home,
        now: now,
        lastEncounterAt: nil,
        cooldownMinutes: 15
    )

    #expect(result.isEligible)
    #expect(result.reason == .eligible)
    #expect(result.currentRegionGeohash != nil)
}

@Test
func encounterIsBlockedDuringCooldown() {
    let service = EncounterEligibilityService()
    let now = Date(timeIntervalSince1970: 10_000)
    let home = HomeRecord(
        id: UUID(),
        userID: UUID(),
        label: "Home",
        area: HomeArea(center: Coordinate(latitude: 37.3317, longitude: -122.0301), radiusMeters: 80),
        geohashPrefix: "9q9",
        updatedAt: now
    )

    let result = service.evaluate(
        currentLocation: Coordinate(latitude: 37.3400, longitude: -122.0400),
        horizontalAccuracyMeters: 10,
        activeHome: home,
        now: now,
        lastEncounterAt: now.addingTimeInterval(-300),
        cooldownMinutes: 15
    )

    #expect(result.isEligible == false)
    #expect(result.reason == .cooldownActive)
}
