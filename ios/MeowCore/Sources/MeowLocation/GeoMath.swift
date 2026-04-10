import Foundation
import MeowDomain

public enum GeoMath {
    public static func distanceMeters(from a: Coordinate, to b: Coordinate) -> Double {
        let earthRadiusMeters = 6_371_000.0
        let lat1 = a.latitude * .pi / 180
        let lon1 = a.longitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let lon2 = b.longitude * .pi / 180

        let dLat = lat2 - lat1
        let dLon = lon2 - lon1

        let h = sin(dLat / 2) * sin(dLat / 2) +
            cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(h), sqrt(max(0, 1 - h)))
        return earthRadiusMeters * c
    }
}
