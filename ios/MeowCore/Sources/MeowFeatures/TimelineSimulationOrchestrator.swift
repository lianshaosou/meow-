import Foundation
import MeowData
import MeowDomain

public actor TimelineSimulationOrchestrator {
    private let notificationRepository: NotificationRepository
    private let telemetryRepository: TelemetryRepository
    private let careCheckThresholdSeconds: TimeInterval
    private let regionIdleThresholdSeconds: TimeInterval

    public init(
        notificationRepository: NotificationRepository,
        telemetryRepository: TelemetryRepository,
        careCheckThresholdSeconds: TimeInterval = 4 * 60 * 60,
        regionIdleThresholdSeconds: TimeInterval = 72 * 60 * 60
    ) {
        self.notificationRepository = notificationRepository
        self.telemetryRepository = telemetryRepository
        self.careCheckThresholdSeconds = careCheckThresholdSeconds
        self.regionIdleThresholdSeconds = regionIdleThresholdSeconds
    }

    public func consume(
        userID: UUID,
        timeline: AppBootstrapService.BootstrapTimelineUpdate,
        now: Date = Date()
    ) async {
        if let userAdvance = timeline.advancesByEntityType[TimeEntityType.user] {
            try? await telemetryRepository.track(
                TelemetryEventDraft(
                    userID: userID,
                    eventName: "timeline_user_advanced",
                    properties: [
                        "real_elapsed_seconds": String(Int(userAdvance.realElapsed)),
                        "simulation_elapsed_seconds": String(Int(userAdvance.simulationElapsed)),
                        "care_cycle_elapsed_seconds": String(Int(userAdvance.careCycleElapsed))
                    ],
                    createdAt: now
                )
            )
        }

        guard let homeAdvance = timeline.advancesByEntityType[TimeEntityType.home] else {
            return
        }

        if homeAdvance.careCycleElapsed >= careCheckThresholdSeconds {
            let elapsedHours = max(1, Int(homeAdvance.careCycleElapsed / 3600))
            try? await notificationRepository.scheduleNotification(
                NotificationEventDraft(
                    userID: userID,
                    category: "care_cycle_due",
                    severity: .low,
                    title: "Home care check due",
                    body: "It has been about \(elapsedHours)h since the last home care cycle update.",
                    payload: [
                        "elapsed_hours": String(elapsedHours),
                        "entity_type": TimeEntityType.home
                    ],
                    scheduledFor: now
                )
            )

            try? await telemetryRepository.track(
                TelemetryEventDraft(
                    userID: userID,
                    eventName: "timeline_home_care_due",
                    properties: [
                        "elapsed_hours": String(elapsedHours)
                    ],
                    createdAt: now
                )
            )
        }

        if homeAdvance.realElapsed >= regionIdleThresholdSeconds {
            let idleHours = Int(homeAdvance.realElapsed / 3600)
            try? await telemetryRepository.track(
                TelemetryEventDraft(
                    userID: userID,
                    eventName: "timeline_region_dormancy_candidate",
                    properties: [
                        "idle_hours": String(idleHours)
                    ],
                    createdAt: now
                )
            )
        }
    }
}
