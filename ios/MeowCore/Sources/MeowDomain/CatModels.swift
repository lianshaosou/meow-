import Foundation

public enum CatStatus: String, Sendable {
    case stray
    case pet
    case shelter
}

public enum CatOwnershipState: String, Sendable {
    case unowned
    case owned
    case deceased
}

public struct CatEntity: Sendable, Equatable, Identifiable {
    public let id: UUID
    public var internalName: String
    public var displayName: String?
    public var status: CatStatus
    public var ownershipState: CatOwnershipState
    public var originRegionGeohash: String
    public var currentRegionGeohash: String
    public var isAlive: Bool
    public var isCastrated: Bool
    public var isMicrochipped: Bool
    public var bornAt: Date?
    public var spawnedAt: Date
    public var diedAt: Date?

    public init(
        id: UUID,
        internalName: String,
        displayName: String? = nil,
        status: CatStatus,
        ownershipState: CatOwnershipState,
        originRegionGeohash: String,
        currentRegionGeohash: String,
        isAlive: Bool,
        isCastrated: Bool,
        isMicrochipped: Bool,
        bornAt: Date?,
        spawnedAt: Date,
        diedAt: Date?
    ) {
        self.id = id
        self.internalName = internalName
        self.displayName = displayName
        self.status = status
        self.ownershipState = ownershipState
        self.originRegionGeohash = originRegionGeohash
        self.currentRegionGeohash = currentRegionGeohash
        self.isAlive = isAlive
        self.isCastrated = isCastrated
        self.isMicrochipped = isMicrochipped
        self.bornAt = bornAt
        self.spawnedAt = spawnedAt
        self.diedAt = diedAt
    }
}
