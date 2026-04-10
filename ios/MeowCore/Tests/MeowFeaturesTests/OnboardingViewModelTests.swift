import Foundation
import Testing
@testable import MeowFeatures
import MeowData

@Test
@MainActor
func onboardingCompletesAndStoresHome() async {
    let userID = UUID()
    let profiles = InMemoryProfileRepository()
    let homes = InMemoryHomeRepository()
    let vm = OnboardingViewModel(profileRepository: profiles, homeRepository: homes)

    vm.nickname = "Lian"
    vm.homeLabel = "Apartment"
    vm.homeLatitude = 37.3317
    vm.homeLongitude = -122.0301
    vm.homeRadiusMeters = 80

    await vm.complete(userID: userID)

    #expect(vm.isComplete)
    let home = try? await homes.activeHome(userID: userID)
    #expect(home != nil)
    #expect(home?.geohashPrefix.count == 6)
}

@Test
@MainActor
func onboardingRejectsInvalidRadius() async {
    let vm = OnboardingViewModel(
        profileRepository: InMemoryProfileRepository(),
        homeRepository: InMemoryHomeRepository()
    )

    vm.nickname = "ok"
    vm.homeLabel = "Home"
    vm.homeLatitude = 1
    vm.homeLongitude = 1
    vm.homeRadiusMeters = 5

    await vm.complete(userID: UUID())

    #expect(vm.isComplete == false)
    #expect(vm.errorMessage == "Home radius must be between 20m and 500m.")
}
