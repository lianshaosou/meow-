import Testing
@testable import MeowFeatures
import MeowData

@Test
@MainActor
func accountLinkShowsUnauthorizedWhenNotSignedIn() async {
    let telemetry = InMemoryTelemetryRepository()
    let vm = AccountLinkViewModel(
        authService: InMemoryAuthService(),
        telemetryRepository: telemetry
    )
    vm.email = "meow@example.com"
    vm.password = "password123"

    await vm.linkEmailToCurrentAccount()

    #expect(vm.errorMessage == "Sign in first before linking email.")
    let events = await telemetry.events()
    #expect(events.contains(where: { $0.eventName == "account_link_email_failed" }))
}

@Test
@MainActor
func accountLinkSucceedsAfterAppleSignIn() async throws {
    let auth = InMemoryAuthService()
    let telemetry = InMemoryTelemetryRepository()
    _ = try await auth.signInWithApple(identityToken: "apple-token")

    let vm = AccountLinkViewModel(
        authService: auth,
        telemetryRepository: telemetry
    )
    vm.email = "meow@example.com"
    vm.password = "password123"

    await vm.linkEmailToCurrentAccount()

    #expect(vm.message == "Email sign-in linked to this account.")
    #expect(vm.errorMessage == nil)
    let events = await telemetry.events()
    #expect(events.contains(where: { $0.eventName == "account_link_email_success" }))
}
