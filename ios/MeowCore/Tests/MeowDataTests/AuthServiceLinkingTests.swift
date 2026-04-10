import Foundation
import Testing
@testable import MeowData

@Test
func inMemoryAuthServiceLinksEmailToCurrentUser() async throws {
    let auth = InMemoryAuthService(seedUserID: UUID())
    let initial = try await auth.signInWithApple(identityToken: "apple-token")

    let linked = try await auth.linkEmailCredentialToCurrentUser(email: "meow@example.com", password: "password123")

    #expect(linked.userID == initial.userID)
    #expect(linked.provider == .email)
}

@Test
func inMemoryAuthServiceRejectsLinkWithoutSession() async {
    let auth = InMemoryAuthService(seedUserID: UUID())

    await #expect(throws: AuthError.unauthorized) {
        _ = try await auth.linkEmailCredentialToCurrentUser(email: "meow@example.com", password: "password123")
    }
}
