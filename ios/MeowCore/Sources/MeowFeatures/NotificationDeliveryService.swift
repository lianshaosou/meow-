import Foundation
import MeowData
import MeowDomain

public actor NotificationDeliveryService {
    private let notificationRepository: NotificationRepository
    private let dispatcher: NotificationDispatching

    public init(
        notificationRepository: NotificationRepository,
        dispatcher: NotificationDispatching = NoopNotificationDispatcher()
    ) {
        self.notificationRepository = notificationRepository
        self.dispatcher = dispatcher
    }

    @discardableResult
    public func processDueNotifications(batchSize: Int = 20) async -> Int {
        let claimed: [PendingNotificationDelivery]
        do {
            claimed = try await notificationRepository.claimDueNotifications(batchSize: batchSize)
        } catch {
            return 0
        }

        var delivered = 0
        for notification in claimed {
            do {
                try await deliver(notification)
                try await notificationRepository.markDelivered(notificationID: notification.id)
                delivered += 1
            } catch {
                try? await notificationRepository.markFailed(
                    notificationID: notification.id,
                    error: String(describing: error)
                )
            }
        }
        return delivered
    }

    private func deliver(_ notification: PendingNotificationDelivery) async throws {
        try await dispatcher.dispatch(notification)
    }
}
