import Foundation
import MeowData
import MeowDomain

@MainActor
public final class AccountLinkViewModel: ObservableObject {
    @Published public var email: String = ""
    @Published public var password: String = ""
    @Published public var isLoading: Bool = false
    @Published public var message: String?
    @Published public var errorMessage: String?

    private let authService: AuthService
    private let telemetryRepository: TelemetryRepository

    public init(authService: AuthService, telemetryRepository: TelemetryRepository) {
        self.authService = authService
        self.telemetryRepository = telemetryRepository
    }

    public func linkEmailToCurrentAccount() async {
        isLoading = true
        errorMessage = nil
        message = nil
        defer { isLoading = false }

        do {
            let session = try await authService.linkEmailCredentialToCurrentUser(email: email, password: password)
            message = "Email sign-in linked to this account."
            try? await telemetryRepository.track(
                TelemetryEventDraft(
                    userID: session.userID,
                    eventName: "account_link_email_success",
                    properties: [:],
                    createdAt: Date()
                )
            )
        } catch let error as AuthError {
            errorMessage = Self.userMessage(for: error)
            try? await telemetryRepository.track(
                TelemetryEventDraft(
                    userID: UUID(),
                    eventName: "account_link_email_failed",
                    properties: ["reason": String(describing: error)],
                    createdAt: Date()
                )
            )
        } catch {
            errorMessage = "Could not link email right now. Please try again."
            try? await telemetryRepository.track(
                TelemetryEventDraft(
                    userID: UUID(),
                    eventName: "account_link_email_failed",
                    properties: ["reason": "unknown"],
                    createdAt: Date()
                )
            )
        }
    }

    private static func userMessage(for error: AuthError) -> String {
        switch error {
        case .invalidEmail:
            return "Enter a valid email address."
        case .weakPassword:
            return "Password must be at least 8 characters."
        case .invalidAppleToken:
            return "Apple sign-in token is invalid."
        case .unauthorized:
            return "Sign in first before linking email."
        case .reauthenticationRequired:
            return "Please re-authenticate before changing sign-in methods."
        case .cannotUnlinkLastProvider:
            return "At least one sign-in method must remain linked."
        case .providerNotLinked:
            return "That provider is not linked to this account."
        case .operationNotSupported:
            return "This provider operation is not supported yet."
        case .server(let message):
            return message
        }
    }
}
