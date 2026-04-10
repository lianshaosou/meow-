import Foundation

public struct EncounterEventRecord: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let userID: UUID
    public let catID: UUID
    public let regionID: UUID
    public let happenedAt: Date

    public init(id: UUID, userID: UUID, catID: UUID, regionID: UUID, happenedAt: Date) {
        self.id = id
        self.userID = userID
        self.catID = catID
        self.regionID = regionID
        self.happenedAt = happenedAt
    }
}

public struct CatEncounterPreview: Sendable, Equatable {
    public let id: UUID
    public let internalName: String
    public let displayName: String?

    public init(id: UUID, internalName: String, displayName: String?) {
        self.id = id
        self.internalName = internalName
        self.displayName = displayName
    }
}

public struct RegionActivationRollResult: Sendable, Equatable {
    public let regionID: UUID
    public let regionGeohash: String
    public let countryCode: String?
    public let densityTier: String?
    public let regionState: String?
    public let wasReactivated: Bool?
    public let isNewRegion: Bool
    public let cooldownActive: Bool
    public let cooldownRemainingSeconds: Int
    public let encounterRolled: Bool
    public let encounterEventID: UUID?
    public let encounterHappenedAt: Date?
    public let catSource: String?
    public let familiarEncounterCount: Int?
    public let adjacentRoamUsed: Bool?
    public let cat: CatEncounterPreview?

    public init(
        regionID: UUID,
        regionGeohash: String,
        countryCode: String?,
        densityTier: String?,
        regionState: String? = nil,
        wasReactivated: Bool? = nil,
        isNewRegion: Bool,
        cooldownActive: Bool,
        cooldownRemainingSeconds: Int,
        encounterRolled: Bool,
        encounterEventID: UUID?,
        encounterHappenedAt: Date?,
        catSource: String? = nil,
        familiarEncounterCount: Int? = nil,
        adjacentRoamUsed: Bool? = nil,
        cat: CatEncounterPreview?
    ) {
        self.regionID = regionID
        self.regionGeohash = regionGeohash
        self.countryCode = countryCode
        self.densityTier = densityTier
        self.regionState = regionState
        self.wasReactivated = wasReactivated
        self.isNewRegion = isNewRegion
        self.cooldownActive = cooldownActive
        self.cooldownRemainingSeconds = cooldownRemainingSeconds
        self.encounterRolled = encounterRolled
        self.encounterEventID = encounterEventID
        self.encounterHappenedAt = encounterHappenedAt
        self.catSource = catSource
        self.familiarEncounterCount = familiarEncounterCount
        self.adjacentRoamUsed = adjacentRoamUsed
        self.cat = cat
    }
}
