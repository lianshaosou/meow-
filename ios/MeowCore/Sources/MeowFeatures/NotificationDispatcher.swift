import Foundation
import MeowData
import MeowDomain

#if canImport(UserNotifications)
@preconcurrency import UserNotifications
#endif

public protocol NotificationDispatching {
    func dispatch(_ notification: PendingNotificationDelivery) async throws
}

public struct NoopNotificationDispatcher: NotificationDispatching {
    public init() {}

    public func dispatch(_ notification: PendingNotificationDelivery) async throws {
        _ = notification
    }
}

public struct RemotePushNotificationDispatcher: NotificationDispatching {
    private let pushBridgeRepository: PushBridgeRepository

    public init(pushBridgeRepository: PushBridgeRepository) {
        self.pushBridgeRepository = pushBridgeRepository
    }

    public func dispatch(_ notification: PendingNotificationDelivery) async throws {
        let enqueued = try await pushBridgeRepository.enqueueRemoteDelivery(notificationID: notification.id)
        if enqueued <= 0 {
            throw NotificationDispatchError.noRegisteredPushToken
        }
    }
}

public struct FallbackNotificationDispatcher: NotificationDispatching {
    private let primary: NotificationDispatching
    private let fallback: NotificationDispatching

    public init(primary: NotificationDispatching, fallback: NotificationDispatching) {
        self.primary = primary
        self.fallback = fallback
    }

    public func dispatch(_ notification: PendingNotificationDelivery) async throws {
        do {
            try await primary.dispatch(notification)
        } catch {
            try await fallback.dispatch(notification)
        }
    }
}

#if canImport(UserNotifications)
public struct LocalNotificationDispatcher: NotificationDispatching {
    private let center: UNUserNotificationCenter

    public init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    public func dispatch(_ notification: PendingNotificationDelivery) async throws {
        try await ensureAuthorizationIfNeeded()

        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        content.userInfo = notification.payload.reduce(into: [AnyHashable: Any]()) { partial, pair in
            partial[pair.key] = pair.value
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: notification.id.uuidString,
            content: content,
            trigger: trigger
        )

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            center.add(request) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func ensureAuthorizationIfNeeded() async throws {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return
        case .notDetermined:
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            if granted == false {
                throw NotificationDispatchError.permissionDenied
            }
        case .denied:
            throw NotificationDispatchError.permissionDenied
        @unknown default:
            throw NotificationDispatchError.permissionDenied
        }
    }
}
#endif

public enum NotificationDispatchError: Error, Equatable {
    case permissionDenied
    case noRegisteredPushToken
}
