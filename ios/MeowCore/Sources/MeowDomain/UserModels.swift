import Foundation

public enum AuthProviderKind: String, Sendable, Codable {
    case apple
    case email
}

public struct UserProfile: Sendable, Equatable, Identifiable {
    public let id: UUID
    public var nickname: String

    public init(id: UUID, nickname: String) {
        self.id = id
        self.nickname = nickname
    }
}

public struct HomeDraft: Sendable, Equatable {
    public var label: String
    public var area: HomeArea

    public init(label: String, area: HomeArea) {
        self.label = label
        self.area = area
    }
}

public struct HomeRecord: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let userID: UUID
    public var label: String
    public var area: HomeArea
    public var geohashPrefix: String
    public var updatedAt: Date

    public init(
        id: UUID,
        userID: UUID,
        label: String,
        area: HomeArea,
        geohashPrefix: String,
        updatedAt: Date
    ) {
        self.id = id
        self.userID = userID
        self.label = label
        self.area = area
        self.geohashPrefix = geohashPrefix
        self.updatedAt = updatedAt
    }
}

public struct TimeSnapshotRecord: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let userID: UUID
    public let entityType: String
    public let entityID: UUID?
    public let state: TimeState
    public let createdAt: Date

    public init(
        id: UUID,
        userID: UUID,
        entityType: String,
        entityID: UUID?,
        state: TimeState,
        createdAt: Date
    ) {
        self.id = id
        self.userID = userID
        self.entityType = entityType
        self.entityID = entityID
        self.state = state
        self.createdAt = createdAt
    }
}
