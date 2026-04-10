import Foundation

#if canImport(CoreLocation)
import CoreLocation
#endif

public struct LocationReading: Sendable, Equatable {
    public let latitude: Double
    public let longitude: Double
    public let horizontalAccuracyMeters: Double
    public let timestamp: Date

    public init(latitude: Double, longitude: Double, horizontalAccuracyMeters: Double, timestamp: Date) {
        self.latitude = latitude
        self.longitude = longitude
        self.horizontalAccuracyMeters = horizontalAccuracyMeters
        self.timestamp = timestamp
    }
}

@MainActor
public protocol LocationService: AnyObject {
    func start()
    func stop()
    func latestReading() -> LocationReading?
    func statusText() -> String
}

@MainActor
public final class InMemoryLocationService: LocationService {
    private var reading: LocationReading?

    public init(initialReading: LocationReading? = nil) {
        self.reading = initialReading
    }

    public func start() {}
    public func stop() {}
    public func latestReading() -> LocationReading? { reading }
    public func statusText() -> String { reading == nil ? "No live location" : "Live location ready" }

    public func update(reading: LocationReading?) {
        self.reading = reading
    }
}

#if canImport(CoreLocation)
@MainActor
public final class AppleLocationService: NSObject, LocationService, @preconcurrency CLLocationManagerDelegate {
    private let manager: CLLocationManager
    private var reading: LocationReading?
    private var latestStatus: String = "Location not started"

    public override init() {
        self.manager = CLLocationManager()
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 10
    }

    public func start() {
        switch manager.authorizationStatus {
        case .notDetermined:
            latestStatus = "Requesting location permission"
            manager.requestWhenInUseAuthorization()
            manager.startUpdatingLocation()
        case .restricted, .denied:
            latestStatus = "Location access denied"
        case .authorizedAlways, .authorizedWhenInUse:
            latestStatus = "Getting live location"
            manager.startUpdatingLocation()
        @unknown default:
            latestStatus = "Unknown location status"
        }
    }

    public func stop() {
        manager.stopUpdatingLocation()
    }

    public func latestReading() -> LocationReading? {
        reading
    }

    public func statusText() -> String {
        latestStatus
    }

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .notDetermined:
            latestStatus = "Location permission not determined"
        case .restricted, .denied:
            latestStatus = "Location access denied"
        case .authorizedAlways, .authorizedWhenInUse:
            latestStatus = "Location access granted"
            manager.startUpdatingLocation()
        @unknown default:
            latestStatus = "Unknown location status"
        }
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        reading = LocationReading(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            horizontalAccuracyMeters: location.horizontalAccuracy,
            timestamp: location.timestamp
        )
        latestStatus = "Live location updated"
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        latestStatus = "Location error: \(error.localizedDescription)"
    }
}
#else
@MainActor
public final class AppleLocationService: LocationService {
    public init() {}
    public func start() {}
    public func stop() {}
    public func latestReading() -> LocationReading? { nil }
    public func statusText() -> String { "Location unavailable on this platform" }
}
#endif
