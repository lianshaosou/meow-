import Foundation

public struct TimeState: Sendable, Equatable {
    public var realWorld: Date
    public var simulation: Date
    public var careCycle: Date

    public init(realWorld: Date, simulation: Date, careCycle: Date) {
        self.realWorld = realWorld
        self.simulation = simulation
        self.careCycle = careCycle
    }
}

public enum SimulationSpeed {
    public static let longTermMultiplier: Double = 5.0
}

public enum TimeEntityType {
    public static let user = "user"
    public static let home = "home"
}
