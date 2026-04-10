import SwiftUI
import MeowFeatures
import MeowData

#if canImport(UIKit)
import UIKit
#endif

@main
@MainActor
struct MeowApp: App {
    @State private var isAuthenticated = false
    @State private var isOnboarded = false

#if canImport(UIKit)
    @UIApplicationDelegateAdaptor(MeowAppDelegate.self) private var appDelegate
#endif

    private let dependencies = AppDependencies.make()

    var body: some Scene {
        WindowGroup {
            RootView(
                isAuthenticated: $isAuthenticated,
                isOnboarded: $isOnboarded,
                authViewModel: AuthViewModel(authService: dependencies.authService),
                onboardingViewModel: OnboardingViewModel(
                    profileRepository: dependencies.profileRepository,
                    homeRepository: dependencies.homeRepository
                ),
                bootstrapService: AppBootstrapService(
                    authService: dependencies.authService,
                    homeRepository: dependencies.homeRepository,
                    snapshotRepository: dependencies.snapshotRepository
                ),
                timelineOrchestrator: TimelineSimulationOrchestrator(
                    notificationRepository: dependencies.notificationRepository,
                    telemetryRepository: dependencies.telemetryRepository
                ),
                exploreViewModel: ExploreViewModel(
                    homeRepository: dependencies.homeRepository,
                    encounterRepository: dependencies.encounterRepository,
                    notificationRepository: dependencies.notificationRepository,
                    telemetryRepository: dependencies.telemetryRepository,
                    locationService: dependencies.locationService
                ),
                accountLinkViewModel: AccountLinkViewModel(
                    authService: dependencies.authService,
                    telemetryRepository: dependencies.telemetryRepository
                ),
                accountProvidersViewModel: AccountProvidersViewModel(
                    authService: dependencies.authService,
                    telemetryRepository: dependencies.telemetryRepository
                ),
                notificationDeliveryService: NotificationDeliveryService(
                    notificationRepository: dependencies.notificationRepository,
                    dispatcher: FallbackNotificationDispatcher(
                        primary: RemotePushNotificationDispatcher(pushBridgeRepository: dependencies.pushBridgeRepository),
                        fallback: LocalNotificationDispatcher()
                    )
                )
            )
            .task {
                await dependencies.pushTokenRegistrationService.requestPermissionAndRegister()
            }
#if canImport(UIKit)
            .onAppear {
                appDelegate.onDeviceToken = { token in
                    Task {
                        await dependencies.pushTokenRegistrationService.handleDeviceToken(token)
                    }
                }
            }
#endif
        }
    }
}

private struct AppDependencies {
    let authService: any AuthService
    let profileRepository: any ProfileRepository
    let homeRepository: any HomeRepository
    let snapshotRepository: any TimeSnapshotRepository
    let encounterRepository: any EncounterRepository
    let notificationRepository: any NotificationRepository
    let telemetryRepository: any TelemetryRepository
    let pushBridgeRepository: any PushBridgeRepository
    let pushTokenRegistrationService: PushTokenRegistrationService
    let locationService: LocationService

    @MainActor
    static func make() -> AppDependencies {
        if let config = try? SupabaseConfigLoader.load() {
            let sessionStore = SupabaseSessionStore()
            let authService = SupabaseAuthService(config: config, sessionStore: sessionStore)
            let pushBridgeRepository = SupabasePushBridgeRepository(config: config, sessionStore: sessionStore)
            return AppDependencies(
                authService: authService,
                profileRepository: SupabaseProfileRepository(config: config, sessionStore: sessionStore),
                homeRepository: SupabaseHomeRepository(config: config, sessionStore: sessionStore),
                snapshotRepository: SupabaseTimeSnapshotRepository(config: config, sessionStore: sessionStore),
                encounterRepository: SupabaseEncounterRepository(config: config, sessionStore: sessionStore),
                notificationRepository: SupabaseNotificationRepository(config: config, sessionStore: sessionStore),
                telemetryRepository: SupabaseTelemetryRepository(config: config, sessionStore: sessionStore),
                pushBridgeRepository: pushBridgeRepository,
                pushTokenRegistrationService: PushTokenRegistrationService(
                    pushBridgeRepository: pushBridgeRepository,
                    environment: "sandbox"
                ),
                locationService: AppleLocationService()
            )
        }

        let authService = InMemoryAuthService()
        let pushBridgeRepository = InMemoryPushBridgeRepository()
        return AppDependencies(
            authService: authService,
            profileRepository: InMemoryProfileRepository(),
            homeRepository: InMemoryHomeRepository(),
            snapshotRepository: InMemoryTimeSnapshotRepository(),
            encounterRepository: InMemoryEncounterRepository(),
            notificationRepository: InMemoryNotificationRepository(),
            telemetryRepository: InMemoryTelemetryRepository(),
            pushBridgeRepository: pushBridgeRepository,
            pushTokenRegistrationService: PushTokenRegistrationService(
                pushBridgeRepository: pushBridgeRepository,
                environment: "sandbox"
            ),
            locationService: AppleLocationService()
        )
    }
}
