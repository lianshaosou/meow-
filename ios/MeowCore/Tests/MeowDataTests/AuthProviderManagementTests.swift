import Testing
@testable import MeowData

@Test
func inMemoryAuthReportsLinkedProvidersAfterLinking() async throws {
    let auth = InMemoryAuthService()
    _ = try await auth.signInWithApple(identityToken: "token")
    _ = try await auth.linkEmailCredentialToCurrentUser(email: "meow@example.com", password: "password123")

    let providers = try await auth.linkedProviders()

    #expect(providers.contains(.apple))
    #expect(providers.contains(.email))
}

@Test
func inMemoryAuthCannotUnlinkLastProvider() async throws {
    let auth = InMemoryAuthService()
    _ = try await auth.signInWithApple(identityToken: "token")

    await #expect(throws: AuthError.cannotUnlinkLastProvider) {
        _ = try await auth.unlinkProvider(.apple)
    }
}

@Test
func inMemoryAuthCanUnlinkWhenMultipleProvidersExist() async throws {
    let auth = InMemoryAuthService()
    _ = try await auth.signInWithApple(identityToken: "token")
    _ = try await auth.linkEmailCredentialToCurrentUser(email: "meow@example.com", password: "password123")

    _ = try await auth.reauthenticateCurrentSession()
    let session = try await auth.unlinkProvider(.apple)
    let providers = try await auth.linkedProviders()

    #expect(session.provider == .email)
    #expect(providers == [.email])
}
