import Foundation

public struct Coordinate: Sendable, Equatable {
    public let latitude: Double
    public let longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

public struct HomeArea: Sendable, Equatable {
    public let center: Coordinate
    public let radiusMeters: Double

    public init(center: Coordinate, radiusMeters: Double) {
        self.center = center
        self.radiusMeters = radiusMeters
    }
}

public struct RegionCell: Sendable, Equatable {
    public let geohash: String
    public let precision: Int

    public init(geohash: String, precision: Int) {
        self.geohash = geohash
        self.precision = precision
    }
}
