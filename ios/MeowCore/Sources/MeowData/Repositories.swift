import Foundation
import MeowDomain

public protocol ProfileRepository: Sendable {
    func upsertProfile(_ profile: UserProfile) async throws
    func profile(userID: UUID) async throws -> UserProfile?
}

public protocol HomeRepository: Sendable {
    func upsertHome(userID: UUID, draft: HomeDraft, geohashPrefix: String) async throws -> HomeRecord
    func activeHome(userID: UUID) async throws -> HomeRecord?
}

public protocol TimeSnapshotRepository: Sendable {
    func saveSnapshot(
        userID: UUID,
        entityType: String,
        entityID: UUID?,
        state: TimeState
    ) async throws -> TimeSnapshotRecord
    func latestSnapshot(userID: UUID, entityType: String) async throws -> TimeSnapshotRecord?
}

public protocol EncounterRepository: Sendable {
    func latestEncounter(userID: UUID) async throws -> EncounterEventRecord?
    func activateRegionAndRollEncounter(
        geohash: String,
        precision: Int,
        countryCode: String?,
        densityHint: String?
    ) async throws -> RegionActivationRollResult
}

public protocol RegionLifecycleRepository: Sendable {
    func markStaleRegionsDormant(
        idleHours: Int,
        batchSize: Int,
        reason: String,
        retentionDays: Int?
    ) async throws -> Int

    func markExpiredDormantRegionsArchived(
        batchSize: Int,
        reason: String
    ) async throws -> Int
}

public protocol NotificationRepository: Sendable {
    func scheduleNotification(_ draft: NotificationEventDraft) async throws
    func claimDueNotifications(batchSize: Int) async throws -> [PendingNotificationDelivery]
    func markDelivered(notificationID: UUID) async throws
    func markFailed(notificationID: UUID, error: String) async throws
}

public protocol TelemetryRepository: Sendable {
    func track(_ draft: TelemetryEventDraft) async throws
}

public protocol PushBridgeRepository: Sendable {
    func registerDeviceToken(token: String, platform: String, environment: String) async throws
    func enqueueRemoteDelivery(notificationID: UUID) async throws -> Int
}

public actor InMemoryProfileRepository: ProfileRepository {
    private var storage: [UUID: UserProfile] = [:]

    public init() {}

    public func upsertProfile(_ profile: UserProfile) async throws {
        storage[profile.id] = profile
    }

    public func profile(userID: UUID) async throws -> UserProfile? {
        storage[userID]
    }
}

public actor InMemoryHomeRepository: HomeRepository {
    private var storage: [UUID: HomeRecord] = [:]

    public init() {}

    public func upsertHome(userID: UUID, draft: HomeDraft, geohashPrefix: String) async throws -> HomeRecord {
        if let existing = storage[userID] {
            let updated = HomeRecord(
                id: existing.id,
                userID: userID,
                label: draft.label,
                area: draft.area,
                geohashPrefix: geohashPrefix,
                updatedAt: Date()
            )
            storage[userID] = updated
            return updated
        }

        let record = HomeRecord(
            id: UUID(),
            userID: userID,
            label: draft.label,
            area: draft.area,
            geohashPrefix: geohashPrefix,
            updatedAt: Date()
        )
        storage[userID] = record
        return record
    }

    public func activeHome(userID: UUID) async throws -> HomeRecord? {
        storage[userID]
    }
}

public actor InMemoryTimeSnapshotRepository: TimeSnapshotRepository {
    private var storage: [String: TimeSnapshotRecord] = [:]

    public init() {}

    public func saveSnapshot(
        userID: UUID,
        entityType: String,
        entityID: UUID?,
        state: TimeState
    ) async throws -> TimeSnapshotRecord {
        let key = cacheKey(userID: userID, entityType: entityType)
        let record = TimeSnapshotRecord(
            id: UUID(),
            userID: userID,
            entityType: entityType,
            entityID: entityID,
            state: state,
            createdAt: Date()
        )
        storage[key] = record
        return record
    }

    public func latestSnapshot(userID: UUID, entityType: String) async throws -> TimeSnapshotRecord? {
        storage[cacheKey(userID: userID, entityType: entityType)]
    }

    private func cacheKey(userID: UUID, entityType: String) -> String {
        "\(userID.uuidString)::\(entityType)"
    }
}

public actor InMemoryEncounterRepository: EncounterRepository {
    private var latest: EncounterEventRecord?

    public init() {}

    public func latestEncounter(userID: UUID) async throws -> EncounterEventRecord? {
        latest
    }

    public func activateRegionAndRollEncounter(
        geohash: String,
        precision: Int,
        countryCode: String?,
        densityHint: String?
    ) async throws -> RegionActivationRollResult {
        let now = Date()
        let userID = UUID()
        let regionID = UUID()
        let catID = UUID()
        let event = EncounterEventRecord(
            id: UUID(),
            userID: userID,
            catID: catID,
            regionID: regionID,
            happenedAt: now
        )
        latest = event

        return RegionActivationRollResult(
            regionID: regionID,
            regionGeohash: geohash,
            countryCode: countryCode,
            densityTier: densityHint ?? "suburban",
            regionState: "active",
            wasReactivated: false,
            isNewRegion: true,
            cooldownActive: false,
            cooldownRemainingSeconds: 0,
            encounterRolled: true,
            encounterEventID: event.id,
            encounterHappenedAt: event.happenedAt,
            catSource: "new_local",
            familiarEncounterCount: 0,
            adjacentRoamUsed: false,
            cat: CatEncounterPreview(id: catID, internalName: "Stray-Demo", displayName: nil)
        )
    }
}

public actor InMemoryRegionLifecycleRepository: RegionLifecycleRepository {
    private(set) var staleDormantMarked: Int = 0
    private(set) var expiredArchivedMarked: Int = 0

    public init() {}

    public func markStaleRegionsDormant(
        idleHours: Int,
        batchSize: Int,
        reason: String,
        retentionDays: Int?
    ) async throws -> Int {
        _ = idleHours
        _ = batchSize
        _ = reason
        _ = retentionDays
        staleDormantMarked += 1
        return staleDormantMarked
    }

    public func markExpiredDormantRegionsArchived(
        batchSize: Int,
        reason: String
    ) async throws -> Int {
        _ = batchSize
        _ = reason
        expiredArchivedMarked += 1
        return expiredArchivedMarked
    }
}

public actor InMemoryNotificationRepository: NotificationRepository {
    private var scheduled: [NotificationEventDraft] = []
    private var pending: [PendingNotificationDelivery] = []

    public init() {}

    public func scheduleNotification(_ draft: NotificationEventDraft) async throws {
        scheduled.append(draft)
        pending.append(
            PendingNotificationDelivery(
                id: UUID(),
                userID: draft.userID,
                category: draft.category,
                severity: draft.severity,
                title: draft.title,
                body: draft.body,
                payload: draft.payload,
                scheduledFor: draft.scheduledFor
            )
        )
    }

    public func claimDueNotifications(batchSize: Int) async throws -> [PendingNotificationDelivery] {
        let due = pending
            .filter { $0.scheduledFor <= Date() }
            .prefix(max(1, batchSize))
        return Array(due)
    }

    public func markDelivered(notificationID: UUID) async throws {
        pending.removeAll { $0.id == notificationID }
    }

    public func markFailed(notificationID: UUID, error: String) async throws {
        // Keep failed notifications in queue for future retries.
        _ = error
    }

    public func scheduledDrafts() -> [NotificationEventDraft] {
        scheduled
    }
}

public actor InMemoryTelemetryRepository: TelemetryRepository {
    private var trackedEvents: [TelemetryEventDraft] = []

    public init() {}

    public func track(_ draft: TelemetryEventDraft) async throws {
        trackedEvents.append(draft)
    }

    public func events() -> [TelemetryEventDraft] {
        trackedEvents
    }
}

public actor InMemoryPushBridgeRepository: PushBridgeRepository {
    private var tokens: Set<String> = []
    private var enqueued: [UUID: Int] = [:]

    public init() {}

    public func registerDeviceToken(token: String, platform: String, environment: String) async throws {
        _ = platform
        _ = environment
        tokens.insert(token)
    }

    public func enqueueRemoteDelivery(notificationID: UUID) async throws -> Int {
        let count = tokens.isEmpty ? 0 : tokens.count
        enqueued[notificationID] = count
        return count
    }

    public func registeredTokenCount() -> Int {
        tokens.count
    }
}
