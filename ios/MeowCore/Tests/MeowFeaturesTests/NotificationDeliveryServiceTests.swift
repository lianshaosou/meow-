import Foundation
import Testing
@testable import MeowFeatures
import MeowData
import MeowDomain

@Test
func notificationDeliveryServiceProcessesDueNotifications() async throws {
    let repo = InMemoryNotificationRepository()
    try await repo.scheduleNotification(
        NotificationEventDraft(
            userID: UUID(),
            category: "encounter",
            severity: .medium,
            title: "A cat is nearby",
            body: "A stray was spotted nearby.",
            payload: [:],
            scheduledFor: Date().addingTimeInterval(-10)
        )
    )

    let service = NotificationDeliveryService(notificationRepository: repo)
    let delivered = await service.processDueNotifications(batchSize: 10)

    #expect(delivered == 1)
    let remaining = try await repo.claimDueNotifications(batchSize: 10)
    #expect(remaining.isEmpty)
}

@Test
func notificationDeliveryServiceMarksFailedWhenDispatcherThrows() async throws {
    let repo = InMemoryNotificationRepository()
    try await repo.scheduleNotification(
        NotificationEventDraft(
            userID: UUID(),
            category: "encounter",
            severity: .medium,
            title: "A cat is nearby",
            body: "A stray was spotted nearby.",
            payload: [:],
            scheduledFor: Date().addingTimeInterval(-10)
        )
    )

    let service = NotificationDeliveryService(
        notificationRepository: repo,
        dispatcher: ThrowingDispatcher()
    )
    let delivered = await service.processDueNotifications(batchSize: 10)

    #expect(delivered == 0)
    let remaining = try await repo.claimDueNotifications(batchSize: 10)
    #expect(remaining.count == 1)
}

private struct ThrowingDispatcher: NotificationDispatching {
    func dispatch(_ notification: PendingNotificationDelivery) async throws {
        _ = notification
        throw NotificationDispatchError.permissionDenied
    }
}
