import Testing
@testable import MeowFeatures
import MeowData
import MeowDomain
import Foundation

@Test
@MainActor
func accountProvidersRefreshLoadsLinkedProviders() async throws {
    let auth = InMemoryAuthService()
    let telemetry = InMemoryTelemetryRepository()
    _ = try await auth.signInWithApple(identityToken: "token")
    _ = try await auth.linkEmailCredentialToCurrentUser(email: "meow@example.com", password: "password123")

    let vm = AccountProvidersViewModel(authService: auth, telemetryRepository: telemetry)
    await vm.refresh()

    #expect(vm.linkedProviders.count == 2)
}

@Test
@MainActor
func unlinkSetsReauthPromptWhenFreshnessWindowExpired() async {
    let auth = ReauthRequiredAuthService()
    let telemetry = InMemoryTelemetryRepository()
    let vm = AccountProvidersViewModel(authService: auth, telemetryRepository: telemetry)

    await vm.refresh()
    vm.selectedProviderForUnlink = .apple
    await vm.unlinkSelectedProvider()

    #expect(vm.shouldPromptReauthentication)
    #expect(vm.errorMessage == "Please re-authenticate before unlinking providers.")
    let eventNames = await telemetry.events().map(\.eventName)
    #expect(eventNames.contains("provider_unlink_reauth_prompted"))
}

@Test
@MainActor
func reauthenticateAndRetryUnlinkCompletesFlow() async {
    let auth = ReauthRequiredAuthService()
    let telemetry = InMemoryTelemetryRepository()
    let vm = AccountProvidersViewModel(authService: auth, telemetryRepository: telemetry)

    await vm.refresh()
    vm.selectedProviderForUnlink = .apple
    await vm.unlinkSelectedProvider()
    await vm.reauthenticateAndRetryUnlink()

    #expect(vm.shouldPromptReauthentication == false)
    #expect(vm.errorMessage == nil)
    #expect(vm.statusMessage == "Re-authentication successful. Apple was unlinked.")
    #expect(vm.linkedProviders == [.email])
    #expect(await auth.unlinkCallCount() == 2)
    #expect(await auth.reauthenticateCallCount() == 1)
    let eventNames = await telemetry.events().map(\.eventName)
    #expect(eventNames.contains("provider_reauth_success"))
    #expect(eventNames.contains("provider_unlink_success"))
}

private actor ReauthRequiredAuthService: AuthService {
    private let userID = UUID()
    private var session: AuthSession
    private var providers: Set<AuthProviderKind> = [.apple, .email]
    private var hasRecentReauthentication = false
    private var unlinkCalls = 0
    private var reauthCalls = 0

    init() {
        session = AuthSession(userID: userID, provider: .apple, createdAt: Date.distantPast)
    }

    func currentSession() async -> AuthSession? { session }

    func signInWithEmail(email: String, password: String) async throws -> AuthSession {
        throw AuthError.operationNotSupported
    }

    func signInWithApple(identityToken: String) async throws -> AuthSession {
        throw AuthError.operationNotSupported
    }

    func linkEmailCredentialToCurrentUser(email: String, password: String) async throws -> AuthSession {
        throw AuthError.operationNotSupported
    }

    func linkedProviders() async throws -> [AuthProviderKind] {
        providers.sorted { $0.rawValue < $1.rawValue }
    }

    func reauthenticateCurrentSession() async throws -> AuthSession {
        reauthCalls += 1
        hasRecentReauthentication = true
        session = AuthSession(userID: userID, provider: session.provider, createdAt: Date())
        return session
    }

    func unlinkProvider(_ provider: AuthProviderKind) async throws -> AuthSession {
        unlinkCalls += 1
        guard providers.contains(provider) else {
            throw AuthError.providerNotLinked
        }
        if hasRecentReauthentication == false {
            throw AuthError.reauthenticationRequired
        }
        providers.remove(provider)
        if session.provider == provider, let fallback = providers.first {
            session = AuthSession(userID: userID, provider: fallback, createdAt: Date())
        }
        return session
    }

    func signOut() async {
        providers = []
    }

    func unlinkCallCount() async -> Int { unlinkCalls }
    func reauthenticateCallCount() async -> Int { reauthCalls }
}
