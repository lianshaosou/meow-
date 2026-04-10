import Foundation
import Testing
@testable import MeowFeatures
import MeowData
import MeowDomain

@Test
func remotePushDispatcherThrowsWhenNoTokenRegistered() async throws {
    let repo = InMemoryPushBridgeRepository()
    let dispatcher = RemotePushNotificationDispatcher(pushBridgeRepository: repo)

    let notification = PendingNotificationDelivery(
        id: UUID(),
        userID: UUID(),
        category: "encounter",
        severity: .medium,
        title: "A cat is nearby",
        body: "Body",
        payload: [:],
        scheduledFor: Date()
    )

    await #expect(throws: NotificationDispatchError.noRegisteredPushToken) {
        try await dispatcher.dispatch(notification)
    }
}

@Test
func fallbackDispatcherUsesSecondaryOnPrimaryFailure() async throws {
    let primary = ThrowingNotificationDispatcher()
    let fallback = CapturingNotificationDispatcher()
    let dispatcher = FallbackNotificationDispatcher(primary: primary, fallback: fallback)

    let notification = PendingNotificationDelivery(
        id: UUID(),
        userID: UUID(),
        category: "encounter",
        severity: .medium,
        title: "A cat is nearby",
        body: "Body",
        payload: [:],
        scheduledFor: Date()
    )

    try await dispatcher.dispatch(notification)
    let captured = await fallback.capturedCount()
    #expect(captured == 1)
}

private struct ThrowingNotificationDispatcher: NotificationDispatching {
    func dispatch(_ notification: PendingNotificationDelivery) async throws {
        _ = notification
        throw NotificationDispatchError.noRegisteredPushToken
    }
}

private actor CapturingNotificationDispatcher: NotificationDispatching {
    private var count = 0

    func dispatch(_ notification: PendingNotificationDelivery) async throws {
        _ = notification
        count += 1
    }

    func capturedCount() -> Int {
        count
    }
}
