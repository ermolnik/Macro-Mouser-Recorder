import Foundation

public struct Macro: Codable, Equatable, Identifiable {
    public let id: UUID
    public var name: String
    public let createdAt: Date
    public var updatedAt: Date
    public let events: [RecordedEvent]

    public var durationSeconds: Double { events.last?.t ?? 0 }
    public var eventCount: Int { events.count }

    public init(id: UUID, name: String, createdAt: Date, updatedAt: Date, events: [RecordedEvent]) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.events = events
    }
}
