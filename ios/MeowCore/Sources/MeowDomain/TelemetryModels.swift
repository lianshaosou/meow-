import Foundation

public struct TelemetryEventDraft: Sendable, Equatable {
    public let userID: UUID
    public let eventName: String
    public let properties: [String: String]
    public let createdAt: Date

    public init(userID: UUID, eventName: String, properties: [String: String], createdAt: Date) {
        self.userID = userID
        self.eventName = eventName
        self.properties = properties
        self.createdAt = createdAt
    }
}
