import Foundation
import Testing
@testable import MeowFeatures
import MeowData
import MeowDomain

@Test
func bootstrapCreatesSnapshotWhenSessionExists() async throws {
    let auth = InMemoryAuthService(seedUserID: UUID())
    _ = try await auth.signInWithEmail(email: "meow@example.com", password: "12345678")
    let homes = InMemoryHomeRepository()
    let snapshots = InMemoryTimeSnapshotRepository()
    let service = AppBootstrapService(authService: auth, homeRepository: homes, snapshotRepository: snapshots)

    let result = try await service.appDidBecomeActive(now: Date(timeIntervalSince1970: 2_000))

    #expect(result.userID == (await auth.currentSession())?.userID)
    #expect(result.entityType == TimeEntityType.user)
}

@Test
func bootstrapTimelinePersistsHomeDomainWhenHomeExists() async throws {
    let userID = UUID()
    let auth = InMemoryAuthService(seedUserID: userID)
    _ = try await auth.signInWithApple(identityToken: "token")
    let homes = InMemoryHomeRepository()
    let home = try await homes.upsertHome(
        userID: userID,
        draft: HomeDraft(
            label: "Home",
            area: HomeArea(center: Coordinate(latitude: 37.0, longitude: -122.0), radiusMeters: 120)
        ),
        geohashPrefix: "9q9"
    )
    let snapshots = InMemoryTimeSnapshotRepository()
    let service = AppBootstrapService(authService: auth, homeRepository: homes, snapshotRepository: snapshots)

    let timeline = try await service.appDidBecomeActiveTimeline(now: Date(timeIntervalSince1970: 4_000))

    #expect(timeline.snapshotsByEntityType[TimeEntityType.user] != nil)
    #expect(timeline.snapshotsByEntityType[TimeEntityType.home]?.entityID == home.id)
    let homeSnapshot = try await snapshots.latestSnapshot(userID: userID, entityType: TimeEntityType.home)
    #expect(homeSnapshot?.entityID == home.id)
}

@Test
func bootstrapTimelineAdvancesUserAndHomeDomainsFromPreviousSnapshots() async throws {
    let userID = UUID()
    let start = Date(timeIntervalSince1970: 10_000)
    let end = Date(timeIntervalSince1970: 10_060)

    let auth = InMemoryAuthService(seedUserID: userID)
    _ = try await auth.signInWithEmail(email: "meow@example.com", password: "12345678")

    let homes = InMemoryHomeRepository()
    let home = try await homes.upsertHome(
        userID: userID,
        draft: HomeDraft(
            label: "Home",
            area: HomeArea(center: Coordinate(latitude: 35.0, longitude: 139.0), radiusMeters: 80)
        ),
        geohashPrefix: "xn7"
    )

    let snapshots = InMemoryTimeSnapshotRepository()
    _ = try await snapshots.saveSnapshot(
        userID: userID,
        entityType: TimeEntityType.user,
        entityID: userID,
        state: TimeState(realWorld: start, simulation: start, careCycle: start)
    )
    _ = try await snapshots.saveSnapshot(
        userID: userID,
        entityType: TimeEntityType.home,
        entityID: home.id,
        state: TimeState(realWorld: start, simulation: start, careCycle: start)
    )

    let service = AppBootstrapService(authService: auth, homeRepository: homes, snapshotRepository: snapshots)
    let timeline = try await service.appDidBecomeActiveTimeline(now: end)

    let userSnapshot = try #require(timeline.snapshotsByEntityType[TimeEntityType.user])
    let homeSnapshot = try #require(timeline.snapshotsByEntityType[TimeEntityType.home])
    let userDelta = try #require(timeline.advancesByEntityType[TimeEntityType.user])
    let homeDelta = try #require(timeline.advancesByEntityType[TimeEntityType.home])

    #expect(userSnapshot.state.realWorld == end)
    #expect(userSnapshot.state.careCycle == start.addingTimeInterval(60))
    #expect(userSnapshot.state.simulation == start.addingTimeInterval(300))
    #expect(homeSnapshot.state.realWorld == end)
    #expect(homeSnapshot.state.careCycle == start.addingTimeInterval(60))
    #expect(homeSnapshot.state.simulation == start.addingTimeInterval(300))
    #expect(userDelta.realElapsed == 60)
    #expect(userDelta.simulationElapsed == 300)
    #expect(homeDelta.realElapsed == 60)
}
