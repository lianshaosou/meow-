import Foundation

public enum NotificationSeverity: String, Sendable {
    case low
    case medium
    case high
    case critical
}

public struct NotificationEventDraft: Sendable, Equatable {
    public let userID: UUID
    public let category: String
    public let severity: NotificationSeverity
    public let title: String
    public let body: String
    public let payload: [String: String]
    public let scheduledFor: Date

    public init(
        userID: UUID,
        category: String,
        severity: NotificationSeverity,
        title: String,
        body: String,
        payload: [String: String],
        scheduledFor: Date
    ) {
        self.userID = userID
        self.category = category
        self.severity = severity
        self.title = title
        self.body = body
        self.payload = payload
        self.scheduledFor = scheduledFor
    }
}

public struct PendingNotificationDelivery: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let userID: UUID
    public let category: String
    public let severity: NotificationSeverity
    public let title: String
    public let body: String
    public let payload: [String: String]
    public let scheduledFor: Date

    public init(
        id: UUID,
        userID: UUID,
        category: String,
        severity: NotificationSeverity,
        title: String,
        body: String,
        payload: [String: String],
        scheduledFor: Date
    ) {
        self.id = id
        self.userID = userID
        self.category = category
        self.severity = severity
        self.title = title
        self.body = body
        self.payload = payload
        self.scheduledFor = scheduledFor
    }
}
