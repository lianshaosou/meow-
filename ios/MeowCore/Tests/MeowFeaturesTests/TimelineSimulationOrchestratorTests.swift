import Foundation
import Testing
@testable import MeowFeatures
import MeowData
import MeowDomain
import MeowSimulation

@Test
func timelineOrchestratorSchedulesCareCheckAndTelemetryForLongHomeElapsed() async throws {
    let userID = UUID()
    let notifications = InMemoryNotificationRepository()
    let telemetry = InMemoryTelemetryRepository()
    let orchestrator = TimelineSimulationOrchestrator(
        notificationRepository: notifications,
        telemetryRepository: telemetry,
        careCheckThresholdSeconds: 60,
        regionIdleThresholdSeconds: 120
    )

    let update = makeTimelineUpdate(
        userID: userID,
        advances: [
            TimeEntityType.user: SimulationAdvance(realElapsed: 10, simulationElapsed: 50, careCycleElapsed: 10),
            TimeEntityType.home: SimulationAdvance(realElapsed: 7_200, simulationElapsed: 36_000, careCycleElapsed: 7_200)
        ]
    )

    await orchestrator.consume(userID: userID, timeline: update, now: Date(timeIntervalSince1970: 20_000))

    let scheduled = await notifications.scheduledDrafts()
    #expect(scheduled.contains(where: { $0.category == "care_cycle_due" }))

    let events = await telemetry.events()
    #expect(events.contains(where: { $0.eventName == "timeline_user_advanced" }))
    #expect(events.contains(where: { $0.eventName == "timeline_home_care_due" }))
    #expect(events.contains(where: { $0.eventName == "timeline_region_dormancy_candidate" }))
}

@Test
func timelineOrchestratorNoHomeAdvanceSkipsCareAndDormancySignals() async {
    let userID = UUID()
    let notifications = InMemoryNotificationRepository()
    let telemetry = InMemoryTelemetryRepository()
    let orchestrator = TimelineSimulationOrchestrator(
        notificationRepository: notifications,
        telemetryRepository: telemetry,
        careCheckThresholdSeconds: 60,
        regionIdleThresholdSeconds: 120
    )

    let update = makeTimelineUpdate(
        userID: userID,
        advances: [
            TimeEntityType.user: SimulationAdvance(realElapsed: 5, simulationElapsed: 25, careCycleElapsed: 5)
        ]
    )

    await orchestrator.consume(userID: userID, timeline: update, now: Date(timeIntervalSince1970: 21_000))

    let scheduled = await notifications.scheduledDrafts()
    #expect(scheduled.isEmpty)

    let events = await telemetry.events()
    #expect(events.contains(where: { $0.eventName == "timeline_user_advanced" }))
    #expect(events.contains(where: { $0.eventName == "timeline_home_care_due" }) == false)
    #expect(events.contains(where: { $0.eventName == "timeline_region_dormancy_candidate" }) == false)
}

private func makeTimelineUpdate(
    userID: UUID,
    advances: [String: SimulationAdvance]
) -> AppBootstrapService.BootstrapTimelineUpdate {
    let now = Date(timeIntervalSince1970: 10_000)
    var snapshotsByType: [String: TimeSnapshotRecord] = [:]

    for (entityType, _) in advances {
        snapshotsByType[entityType] = TimeSnapshotRecord(
            id: UUID(),
            userID: userID,
            entityType: entityType,
            entityID: UUID(),
            state: TimeState(realWorld: now, simulation: now, careCycle: now),
            createdAt: now
        )
    }

    let userSnapshot = snapshotsByType[TimeEntityType.user]
        ?? TimeSnapshotRecord(
            id: UUID(),
            userID: userID,
            entityType: TimeEntityType.user,
            entityID: userID,
            state: TimeState(realWorld: now, simulation: now, careCycle: now),
            createdAt: now
        )

    return AppBootstrapService.BootstrapTimelineUpdate(
        userSnapshot: userSnapshot,
        snapshotsByEntityType: snapshotsByType,
        advancesByEntityType: advances
    )
}
