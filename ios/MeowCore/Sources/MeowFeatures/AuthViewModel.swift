import Foundation
import MeowData

@MainActor
public final class AuthViewModel: ObservableObject {
    @Published public var email: String = ""
    @Published public var password: String = ""
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?
    @Published public private(set) var isAuthenticated: Bool = false
    @Published public private(set) var currentUserID: UUID?

    private let authService: AuthService

    public init(authService: AuthService) {
        self.authService = authService
    }

    public func restoreSession() async {
        let session = await authService.currentSession()
        isAuthenticated = (session != nil)
        currentUserID = session?.userID
    }

    public func signInWithEmail() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let session = try await authService.signInWithEmail(email: email, password: password)
            isAuthenticated = true
            currentUserID = session.userID
        } catch let error as AuthError {
            isAuthenticated = false
            currentUserID = nil
            errorMessage = Self.userMessage(for: error)
        } catch {
            isAuthenticated = false
            currentUserID = nil
            errorMessage = "Could not sign in right now. Please try again."
        }
    }

    public func signInWithApple(identityToken: String) async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let session = try await authService.signInWithApple(identityToken: identityToken)
            isAuthenticated = true
            currentUserID = session.userID
        } catch let error as AuthError {
            isAuthenticated = false
            currentUserID = nil
            errorMessage = Self.userMessage(for: error)
        } catch {
            isAuthenticated = false
            currentUserID = nil
            errorMessage = "Could not sign in right now. Please try again."
        }
    }

    public func signOut() async {
        await authService.signOut()
        isAuthenticated = false
        currentUserID = nil
    }

    private static func userMessage(for error: AuthError) -> String {
        switch error {
        case .invalidEmail:
            return "Enter a valid email address."
        case .weakPassword:
            return "Password must be at least 8 characters."
        case .invalidAppleToken:
            return "Apple sign-in failed. Please retry."
        case .unauthorized:
            return "You are not authorized for this action."
        case .reauthenticationRequired:
            return "Please re-authenticate and try again."
        case .cannotUnlinkLastProvider:
            return "At least one sign-in method must remain linked."
        case .providerNotLinked:
            return "This provider is not linked to your account."
        case .operationNotSupported:
            return "This action is not supported right now."
        case .server(let message):
            return message
        }
    }
}
