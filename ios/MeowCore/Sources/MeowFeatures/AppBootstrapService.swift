import Foundation
import MeowData
import MeowDomain
import MeowSimulation

public struct AppBootstrapService {
    public struct BootstrapTimelineUpdate: Sendable {
        public let userSnapshot: TimeSnapshotRecord
        public let snapshotsByEntityType: [String: TimeSnapshotRecord]
        public let advancesByEntityType: [String: SimulationAdvance]

        public var allSnapshots: [TimeSnapshotRecord] {
            Array(snapshotsByEntityType.values)
        }
    }

    public enum BootstrapError: Error {
        case missingSession
        case invalidTimelineProgression(entityType: String)
    }

    private let authService: AuthService
    private let homeRepository: HomeRepository
    private let snapshotRepository: TimeSnapshotRepository
    private let clock: SimulationClock

    public init(
        authService: AuthService,
        homeRepository: HomeRepository,
        snapshotRepository: TimeSnapshotRepository,
        clock: SimulationClock = SimulationClock()
    ) {
        self.authService = authService
        self.homeRepository = homeRepository
        self.snapshotRepository = snapshotRepository
        self.clock = clock
    }

    public func appDidBecomeActive(now: Date = Date()) async throws -> TimeSnapshotRecord {
        try await appDidBecomeActiveTimeline(now: now).userSnapshot
    }

    public func appDidBecomeActiveTimeline(now: Date = Date()) async throws -> BootstrapTimelineUpdate {
        guard let session = await authService.currentSession() else {
            throw BootstrapError.missingSession
        }

        var targets: [(entityType: String, entityID: UUID?)] = [
            (entityType: TimeEntityType.user, entityID: session.userID)
        ]
        if let home = try await homeRepository.activeHome(userID: session.userID) {
            targets.append((entityType: TimeEntityType.home, entityID: home.id))
        }

        var snapshotsByEntityType: [String: TimeSnapshotRecord] = [:]
        var advancesByEntityType: [String: SimulationAdvance] = [:]

        for target in targets {
            let previous = try await snapshotRepository.latestSnapshot(userID: session.userID, entityType: target.entityType)?.state
                ?? TimeState(realWorld: now, simulation: now, careCycle: now)

            let normalizedPrevious = normalizePreviousState(previous, now: now)
            let advanced = clock.advance(from: normalizedPrevious, to: now)
            guard isValidProgression(from: normalizedPrevious, to: advanced.next) else {
                throw BootstrapError.invalidTimelineProgression(entityType: target.entityType)
            }

            let saved = try await snapshotRepository.saveSnapshot(
                userID: session.userID,
                entityType: target.entityType,
                entityID: target.entityID,
                state: advanced.next
            )
            snapshotsByEntityType[target.entityType] = saved
            advancesByEntityType[target.entityType] = advanced.delta
        }

        guard let userSnapshot = snapshotsByEntityType[TimeEntityType.user] else {
            throw BootstrapError.invalidTimelineProgression(entityType: TimeEntityType.user)
        }

        return BootstrapTimelineUpdate(
            userSnapshot: userSnapshot,
            snapshotsByEntityType: snapshotsByEntityType,
            advancesByEntityType: advancesByEntityType
        )
    }

    private func normalizePreviousState(_ state: TimeState, now: Date) -> TimeState {
        guard state.realWorld > now else {
            return state
        }

        return TimeState(
            realWorld: now,
            simulation: state.simulation,
            careCycle: state.careCycle
        )
    }

    private func isValidProgression(from previous: TimeState, to next: TimeState) -> Bool {
        next.realWorld >= previous.realWorld
            && next.simulation >= previous.simulation
            && next.careCycle >= previous.careCycle
    }
}
