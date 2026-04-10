import Foundation
import MeowDomain

public enum PresenceMode: Equatable {
    case home
    case outside
    case uncertain
}

public struct HomeOutsideClassifier {
    public let driftToleranceMeters: Double
    public let minimumConfidence: Double

    public init(driftToleranceMeters: Double = 20, minimumConfidence: Double = 0.6) {
        self.driftToleranceMeters = driftToleranceMeters
        self.minimumConfidence = minimumConfidence
    }

    public func classify(
        current: Coordinate,
        home: HomeArea,
        horizontalAccuracyMeters: Double
    ) -> PresenceMode {
        guard horizontalAccuracyMeters >= 0 else {
            return .uncertain
        }

        let confidence = confidenceScore(horizontalAccuracyMeters: horizontalAccuracyMeters)
        guard confidence >= minimumConfidence else {
            return .uncertain
        }

        let distance = GeoMath.distanceMeters(from: current, to: home.center)
        let effectiveRadius = home.radiusMeters + driftToleranceMeters + horizontalAccuracyMeters
        return distance <= effectiveRadius ? .home : .outside
    }

    private func confidenceScore(horizontalAccuracyMeters: Double) -> Double {
        switch horizontalAccuracyMeters {
        case 0..<15:
            return 1.0
        case 15..<30:
            return 0.85
        case 30..<60:
            return 0.7
        case 60..<100:
            return 0.55
        default:
            return 0.35
        }
    }
}
