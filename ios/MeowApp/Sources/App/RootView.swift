import SwiftUI
import MeowFeatures

struct RootView: View {
    @Binding var isAuthenticated: Bool
    @Binding var isOnboarded: Bool

    let authViewModel: AuthViewModel
    let onboardingViewModel: OnboardingViewModel
    let bootstrapService: AppBootstrapService
    let timelineOrchestrator: TimelineSimulationOrchestrator
    let exploreViewModel: ExploreViewModel
    let accountLinkViewModel: AccountLinkViewModel
    let accountProvidersViewModel: AccountProvidersViewModel
    let notificationDeliveryService: NotificationDeliveryService

    var body: some View {
        Group {
            if isAuthenticated == false {
                AuthScreen(viewModel: authViewModel) {
                    isAuthenticated = true
                }
            } else if isOnboarded == false {
                OnboardingScreen(userID: authViewModel.currentUserID ?? UUID(), viewModel: onboardingViewModel) {
                    isOnboarded = true
                }
            } else {
                NavigationStack {
                    ExploreScreen(userID: authViewModel.currentUserID ?? UUID(), viewModel: exploreViewModel)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                NavigationLink("Account") {
                                    AccountLinkScreen(
                                        viewModel: accountLinkViewModel,
                                        providersViewModel: accountProvidersViewModel
                                    )
                                }
                            }
                        }
                }
                .task {
                    if let userID = authViewModel.currentUserID,
                       let timeline = try? await bootstrapService.appDidBecomeActiveTimeline() {
                        await timelineOrchestrator.consume(userID: userID, timeline: timeline)
                    }
                    _ = await notificationDeliveryService.processDueNotifications()
                }
            }
        }
    }
}
