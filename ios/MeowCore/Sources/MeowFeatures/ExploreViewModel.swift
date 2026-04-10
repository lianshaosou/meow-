import Foundation
import MeowData
import MeowDomain

@MainActor
public final class ExploreViewModel: ObservableObject {
    @Published public var latitude: Double = 37.3400
    @Published public var longitude: Double = -122.0400
    @Published public var horizontalAccuracyMeters: Double = 12
    @Published public var useLiveLocation: Bool = true
    @Published public private(set) var activeHomeArea: HomeArea?
    @Published public private(set) var locationStatus: String = "Location not started"
    @Published public var statusMessage: String?
    @Published public var encounterMessage: String?
    @Published public var isLoading: Bool = false

    private let homeRepository: HomeRepository
    private let encounterRepository: EncounterRepository
    private let notificationRepository: NotificationRepository
    private let telemetryRepository: TelemetryRepository
    private let locationService: LocationService
    private let eligibilityService: EncounterEligibilityService

    public init(
        homeRepository: HomeRepository,
        encounterRepository: EncounterRepository,
        notificationRepository: NotificationRepository,
        telemetryRepository: TelemetryRepository,
        locationService: LocationService,
        eligibilityService: EncounterEligibilityService = EncounterEligibilityService()
    ) {
        self.homeRepository = homeRepository
        self.encounterRepository = encounterRepository
        self.notificationRepository = notificationRepository
        self.telemetryRepository = telemetryRepository
        self.locationService = locationService
        self.eligibilityService = eligibilityService
    }

    public func onAppear() {
        if useLiveLocation {
            locationService.start()
        }
        locationStatus = locationService.statusText()
    }

    public func onDisappear() {
        locationService.stop()
    }

    public func refreshHomeContext(userID: UUID) async {
        do {
            activeHomeArea = try await homeRepository.activeHome(userID: userID)?.area
        } catch {
            activeHomeArea = nil
        }
    }

    public func checkNearbyCats(userID: UUID) async {
        isLoading = true
        defer { isLoading = false }

        statusMessage = nil
        encounterMessage = nil

        do {
            let home = try await homeRepository.activeHome(userID: userID)
            activeHomeArea = home?.area
            let lastEncounter = try await encounterRepository.latestEncounter(userID: userID)
            let now = Date()

            if useLiveLocation {
                locationService.start()
                locationStatus = locationService.statusText()
                guard let reading = locationService.latestReading() else {
                    statusMessage = "Waiting for a precise live location fix."
                    try? await telemetryRepository.track(
                        TelemetryEventDraft(
                            userID: userID,
                            eventName: "explore_live_location_pending",
                            properties: ["status": locationStatus],
                            createdAt: now
                        )
                    )
                    return
                }
                latitude = reading.latitude
                longitude = reading.longitude
                horizontalAccuracyMeters = reading.horizontalAccuracyMeters
            }

            let eligibility = eligibilityService.evaluate(
                currentLocation: Coordinate(latitude: latitude, longitude: longitude),
                horizontalAccuracyMeters: horizontalAccuracyMeters,
                activeHome: home,
                now: now,
                lastEncounterAt: lastEncounter?.happenedAt,
                cooldownMinutes: 15
            )

            guard eligibility.isEligible, let geohash = eligibility.currentRegionGeohash else {
                statusMessage = Self.message(for: eligibility.reason)
                try? await telemetryRepository.track(
                    TelemetryEventDraft(
                        userID: userID,
                        eventName: "encounter_eligibility_blocked",
                        properties: ["reason": eligibility.reason.rawValue],
                        createdAt: now
                    )
                )
                return
            }

            let result = try await encounterRepository.activateRegionAndRollEncounter(
                geohash: geohash,
                precision: 7,
                countryCode: Locale.current.region?.identifier,
                densityHint: nil
            )

            if result.cooldownActive {
                let mins = max(1, result.cooldownRemainingSeconds / 60)
                statusMessage = "Encounter cooldown active. Try again in about \(mins)m."
                try? await telemetryRepository.track(
                    TelemetryEventDraft(
                        userID: userID,
                        eventName: "encounter_cooldown_active",
                        properties: ["remaining_minutes": String(mins)],
                        createdAt: now
                    )
                )
                return
            }

            if result.encounterRolled, let cat = result.cat {
                let name = cat.displayName ?? cat.internalName
                encounterMessage = "You found \(name) nearby in \(result.regionGeohash)!"
                statusMessage = result.isNewRegion ? "New region initialized." : "Region active."
                try await notificationRepository.scheduleNotification(
                    NotificationEventDraft(
                        userID: userID,
                        category: "encounter",
                        severity: .medium,
                        title: "A cat is nearby",
                        body: "\(name) was spotted near \(result.regionGeohash).",
                        payload: [
                            "cat_id": cat.id.uuidString,
                            "region_geohash": result.regionGeohash
                        ],
                        scheduledFor: now
                    )
                )
                try? await telemetryRepository.track(
                    TelemetryEventDraft(
                        userID: userID,
                        eventName: "encounter_success",
                        properties: encounterTelemetryProperties(
                            for: result,
                            catID: cat.id,
                            base: [
                            "cat_id": cat.id.uuidString,
                            "region_geohash": result.regionGeohash
                            ]
                        ),
                        createdAt: now
                    )
                )
            } else {
                statusMessage = "No cats visible right now. Keep walking and try again."
                try? await telemetryRepository.track(
                    TelemetryEventDraft(
                        userID: userID,
                        eventName: "encounter_roll_empty",
                        properties: encounterTelemetryProperties(
                            for: result,
                            catID: nil,
                            base: ["region_geohash": result.regionGeohash]
                        ),
                        createdAt: now
                    )
                )
            }
        } catch {
            statusMessage = "Could not check nearby cats right now."
            try? await telemetryRepository.track(
                TelemetryEventDraft(
                    userID: userID,
                    eventName: "encounter_check_error",
                    properties: [:],
                    createdAt: Date()
                )
            )
        }
    }

    private static func message(for reason: EncounterEligibilityReason) -> String {
        switch reason {
        case .eligible:
            return "Ready to check nearby cats."
        case .noHomeConfigured:
            return "Set your home area first."
        case .locationUncertain:
            return "Location accuracy is too low. Move to open sky and retry."
        case .insideHomeArea:
            return "You are in home mode. Go outside your home area to find strays."
        case .cooldownActive:
            return "Encounter cooldown is active."
        }
    }

    private func encounterTelemetryProperties(
        for result: RegionActivationRollResult,
        catID: UUID?,
        base: [String: String]
    ) -> [String: String] {
        var properties = base
        if let catID {
            properties["cat_id"] = catID.uuidString
        }
        if let source = result.catSource {
            properties["cat_source"] = source
        }
        if let familiarity = result.familiarEncounterCount {
            properties["familiar_encounter_count"] = String(familiarity)
        }
        if let adjacentRoamUsed = result.adjacentRoamUsed {
            properties["adjacent_roam_used"] = adjacentRoamUsed ? "true" : "false"
        }
        if let regionState = result.regionState {
            properties["region_state"] = regionState
        }
        if let wasReactivated = result.wasReactivated {
            properties["was_reactivated"] = wasReactivated ? "true" : "false"
        }
        return properties
    }
}
