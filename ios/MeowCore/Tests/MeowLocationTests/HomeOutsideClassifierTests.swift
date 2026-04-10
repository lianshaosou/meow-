import Testing
@testable import MeowLocation
import MeowDomain

@Test
func classifierReturnsHomeWhenInsideFuzzyRadius() {
    let home = HomeArea(center: Coordinate(latitude: 37.3317, longitude: -122.0301), radiusMeters: 80)
    let current = Coordinate(latitude: 37.33175, longitude: -122.0302)
    let classifier = HomeOutsideClassifier(driftToleranceMeters: 20, minimumConfidence: 0.6)

    let mode = classifier.classify(current: current, home: home, horizontalAccuracyMeters: 10)
    #expect(mode == .home)
}

@Test
func classifierReturnsUncertainWhenConfidenceTooLow() {
    let home = HomeArea(center: Coordinate(latitude: 37.3317, longitude: -122.0301), radiusMeters: 80)
    let current = Coordinate(latitude: 37.3400, longitude: -122.0400)
    let classifier = HomeOutsideClassifier(driftToleranceMeters: 20, minimumConfidence: 0.6)

    let mode = classifier.classify(current: current, home: home, horizontalAccuracyMeters: 120)
    #expect(mode == .uncertain)
}
