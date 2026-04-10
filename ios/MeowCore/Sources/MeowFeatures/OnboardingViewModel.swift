import Foundation
import MeowDomain
import MeowData
import MeowLocation

public enum OnboardingError: Error, Equatable {
    case missingNickname
    case nicknameTooShort
    case missingHomeLabel
    case invalidRadius
}

@MainActor
public final class OnboardingViewModel: ObservableObject {
    @Published public var nickname: String = ""
    @Published public var homeLabel: String = "Home"
    @Published public var homeLatitude: Double = 0
    @Published public var homeLongitude: Double = 0
    @Published public var homeRadiusMeters: Double = 80
    @Published public var isSaving: Bool = false
    @Published public var errorMessage: String?
    @Published public private(set) var isComplete: Bool = false

    private let profileRepository: ProfileRepository
    private let homeRepository: HomeRepository
    private let geohashEncoder: GeohashEncoder

    public init(
        profileRepository: ProfileRepository,
        homeRepository: HomeRepository,
        geohashEncoder: GeohashEncoder = GeohashEncoder()
    ) {
        self.profileRepository = profileRepository
        self.homeRepository = homeRepository
        self.geohashEncoder = geohashEncoder
    }

    public func complete(userID: UUID) async {
        errorMessage = nil

        do {
            try validate()
            isSaving = true
            defer { isSaving = false }

            let profile = UserProfile(id: userID, nickname: nickname.trimmingCharacters(in: .whitespacesAndNewlines))
            try await profileRepository.upsertProfile(profile)

            let center = Coordinate(latitude: homeLatitude, longitude: homeLongitude)
            let homeArea = HomeArea(center: center, radiusMeters: homeRadiusMeters)
            let draft = HomeDraft(label: homeLabel, area: homeArea)
            let geohashPrefix = geohashEncoder.encode(center, precision: 6).geohash
            _ = try await homeRepository.upsertHome(userID: userID, draft: draft, geohashPrefix: geohashPrefix)

            isComplete = true
        } catch let error as OnboardingError {
            isComplete = false
            errorMessage = Self.userMessage(for: error)
        } catch {
            isComplete = false
            errorMessage = "Could not save onboarding details. Please try again."
        }
    }

    private func validate() throws {
        let trimmedName = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty { throw OnboardingError.missingNickname }
        if trimmedName.count < 2 { throw OnboardingError.nicknameTooShort }

        if homeLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw OnboardingError.missingHomeLabel
        }

        if (20...500).contains(homeRadiusMeters) == false {
            throw OnboardingError.invalidRadius
        }
    }

    private static func userMessage(for error: OnboardingError) -> String {
        switch error {
        case .missingNickname:
            return "Add a nickname to continue."
        case .nicknameTooShort:
            return "Nickname must be at least 2 characters."
        case .missingHomeLabel:
            return "Give your home area a name."
        case .invalidRadius:
            return "Home radius must be between 20m and 500m."
        }
    }
}
