import Foundation
import MeowData
import MeowDomain

@MainActor
public final class AccountProvidersViewModel: ObservableObject {
    @Published public private(set) var linkedProviders: [AuthProviderKind] = []
    @Published public var selectedProviderForUnlink: AuthProviderKind?
    @Published public var shouldPromptReauthentication: Bool = false
    @Published public var statusMessage: String?
    @Published public var errorMessage: String?
    @Published public var isLoading: Bool = false

    private let authService: AuthService
    private let telemetryRepository: TelemetryRepository
    private var pendingProviderForUnlinkRetry: AuthProviderKind?

    public init(authService: AuthService, telemetryRepository: TelemetryRepository) {
        self.authService = authService
        self.telemetryRepository = telemetryRepository
    }

    public func refresh() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        do {
            linkedProviders = try await authService.linkedProviders()
            if linkedProviders.contains(where: { $0 == selectedProviderForUnlink }) == false {
                selectedProviderForUnlink = linkedProviders.first
            }
        } catch let error as AuthError {
            errorMessage = Self.userMessage(for: error)
        } catch {
            errorMessage = "Could not load linked providers."
        }
    }

    public func reauthenticate() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        do {
            _ = try await authService.reauthenticateCurrentSession()
            shouldPromptReauthentication = false
            pendingProviderForUnlinkRetry = nil
            statusMessage = "Re-authentication successful."
            await trackEvent("provider_reauth_success", properties: [:])
        } catch let error as AuthError {
            await trackEvent("provider_reauth_failed", properties: ["reason": String(describing: error)])
            errorMessage = Self.userMessage(for: error)
        } catch {
            await trackEvent("provider_reauth_failed", properties: ["reason": "unknown"])
            errorMessage = "Could not re-authenticate right now."
        }
    }

    public func unlinkSelectedProvider() async {
        guard let provider = selectedProviderForUnlink else { return }
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        statusMessage = nil
        shouldPromptReauthentication = false

        do {
            await trackEvent("provider_unlink_attempt", properties: ["provider": provider.rawValue])
            _ = try await authService.unlinkProvider(provider)
            statusMessage = "\(provider.displayName) was unlinked."
            linkedProviders = try await authService.linkedProviders()
            selectedProviderForUnlink = linkedProviders.first
            await trackEvent("provider_unlink_success", properties: ["provider": provider.rawValue])
        } catch let error as AuthError {
            if error == .reauthenticationRequired {
                pendingProviderForUnlinkRetry = provider
                shouldPromptReauthentication = true
                await trackEvent("provider_unlink_reauth_prompted", properties: ["provider": provider.rawValue])
            } else {
                await trackEvent(
                    "provider_unlink_failed",
                    properties: ["provider": provider.rawValue, "reason": String(describing: error)]
                )
            }
            errorMessage = Self.userMessage(for: error)
        } catch {
            await trackEvent("provider_unlink_failed", properties: ["provider": provider.rawValue, "reason": "unknown"])
            errorMessage = "Could not unlink provider right now."
        }
    }

    public func reauthenticateAndRetryUnlink() async {
        guard let provider = pendingProviderForUnlinkRetry ?? selectedProviderForUnlink else { return }
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        statusMessage = nil
        shouldPromptReauthentication = false

        do {
            _ = try await authService.reauthenticateCurrentSession()
            await trackEvent("provider_reauth_success", properties: ["source": "unlink_retry"])
            _ = try await authService.unlinkProvider(provider)
            statusMessage = "Re-authentication successful. \(provider.displayName) was unlinked."
            linkedProviders = try await authService.linkedProviders()
            selectedProviderForUnlink = linkedProviders.first
            pendingProviderForUnlinkRetry = nil
            await trackEvent("provider_unlink_success", properties: ["provider": provider.rawValue, "source": "retry"])
        } catch let error as AuthError {
            if error == .reauthenticationRequired {
                pendingProviderForUnlinkRetry = provider
                shouldPromptReauthentication = true
                await trackEvent(
                    "provider_unlink_reauth_prompted",
                    properties: ["provider": provider.rawValue, "source": "retry"]
                )
            } else {
                await trackEvent(
                    "provider_unlink_failed",
                    properties: ["provider": provider.rawValue, "reason": String(describing: error), "source": "retry"]
                )
            }
            errorMessage = Self.userMessage(for: error)
        } catch {
            await trackEvent("provider_unlink_failed", properties: ["provider": provider.rawValue, "reason": "unknown", "source": "retry"])
            errorMessage = "Could not complete provider unlink right now."
        }
    }

    public var canAttemptUnlink: Bool {
        linkedProviders.count > 1 && selectedProviderForUnlink != nil
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
            return "Sign in first before changing providers."
        case .reauthenticationRequired:
            return "Please re-authenticate before unlinking providers."
        case .cannotUnlinkLastProvider:
            return "You cannot unlink your last sign-in method."
        case .providerNotLinked:
            return "That provider is not linked to this account."
        case .operationNotSupported:
            return "Provider unlink is not supported by backend yet."
        case .server(let message):
            return message
        }
    }

    private func trackEvent(_ name: String, properties: [String: String]) async {
        let userID = await authService.currentSession()?.userID ?? UUID()
        try? await telemetryRepository.track(
            TelemetryEventDraft(userID: userID, eventName: name, properties: properties, createdAt: Date())
        )
    }
}

private extension AuthProviderKind {
    var displayName: String {
        switch self {
        case .apple: return "Apple"
        case .email: return "Email"
        }
    }
}
