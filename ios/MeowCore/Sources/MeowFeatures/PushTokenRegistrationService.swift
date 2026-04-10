import Foundation
import MeowData

#if canImport(UIKit) && canImport(UserNotifications)
import UIKit
@preconcurrency import UserNotifications

@MainActor
public final class PushTokenRegistrationService {
    private let pushBridgeRepository: PushBridgeRepository
    private let environment: String

    public init(pushBridgeRepository: PushBridgeRepository, environment: String) {
        self.pushBridgeRepository = pushBridgeRepository
        self.environment = environment
    }

    public func requestPermissionAndRegister() async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            if granted {
                UIApplication.shared.registerForRemoteNotifications()
            }
        } catch {
            // Best effort flow; app continues with local-only fallback.
        }
    }

    public func handleDeviceToken(_ tokenData: Data) async {
        let token = tokenData.map { String(format: "%02.2hhx", $0) }.joined()
        if token.isEmpty { return }

        try? await pushBridgeRepository.registerDeviceToken(
            token: token,
            platform: "ios",
            environment: environment
        )
    }
}

#else
@MainActor
public final class PushTokenRegistrationService {
    public init(pushBridgeRepository: PushBridgeRepository, environment: String) {
        _ = pushBridgeRepository
        _ = environment
    }

    public func requestPermissionAndRegister() async {}
    public func handleDeviceToken(_ tokenData: Data) async { _ = tokenData }
}
#endif
