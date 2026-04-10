import Testing
@testable import MeowLocation
import MeowDomain

@Test
func geohashEncoderReturnsExpectedLength() {
    let encoder = GeohashEncoder()
    let hash = encoder.encode(Coordinate(latitude: 37.3317, longitude: -122.0301), precision: 8)
    #expect(hash.geohash.count == 8)
    #expect(hash.precision == 8)
}
