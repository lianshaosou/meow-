import Foundation
import MeowDomain
import MeowLocation

public enum EncounterEligibilityReason: String, Sendable, Equatable {
    case eligible
    case noHomeConfigured
    case locationUncertain
    case insideHomeArea
    case cooldownActive
}

public struct EncounterEligibilityResult: Sendable, Equatable {
    public let isEligible: Bool
    public let reason: EncounterEligibilityReason
    public let currentRegionGeohash: String?

    public init(isEligible: Bool, reason: EncounterEligibilityReason, currentRegionGeohash: String?) {
        self.isEligible = isEligible
        self.reason = reason
        self.currentRegionGeohash = currentRegionGeohash
    }
}

public struct EncounterEligibilityService {
    private let classifier: HomeOutsideClassifier
    private let geohashEncoder: GeohashEncoder

    public init(
        classifier: HomeOutsideClassifier = HomeOutsideClassifier(),
        geohashEncoder: GeohashEncoder = GeohashEncoder()
    ) {
        self.classifier = classifier
        self.geohashEncoder = geohashEncoder
    }

    public func evaluate(
        currentLocation: Coordinate,
        horizontalAccuracyMeters: Double,
        activeHome: HomeRecord?,
        now: Date,
        lastEncounterAt: Date?,
        cooldownMinutes: Int,
        geohashPrecision: Int = 7
    ) -> EncounterEligibilityResult {
        guard let activeHome else {
            return EncounterEligibilityResult(
                isEligible: false,
                reason: .noHomeConfigured,
                currentRegionGeohash: nil
            )
        }

        let mode = classifier.classify(
            current: currentLocation,
            home: activeHome.area,
            horizontalAccuracyMeters: horizontalAccuracyMeters
        )

        switch mode {
        case .uncertain:
            return EncounterEligibilityResult(isEligible: false, reason: .locationUncertain, currentRegionGeohash: nil)
        case .home:
            return EncounterEligibilityResult(isEligible: false, reason: .insideHomeArea, currentRegionGeohash: nil)
        case .outside:
            break
        }

        if let lastEncounterAt {
            let cooldownSeconds = TimeInterval(max(0, cooldownMinutes) * 60)
            if now.timeIntervalSince(lastEncounterAt) < cooldownSeconds {
                return EncounterEligibilityResult(isEligible: false, reason: .cooldownActive, currentRegionGeohash: nil)
            }
        }

        let geohash = geohashEncoder.encode(currentLocation, precision: geohashPrecision).geohash
        return EncounterEligibilityResult(isEligible: true, reason: .eligible, currentRegionGeohash: geohash)
    }
}
