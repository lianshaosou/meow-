import Foundation
import MeowDomain

public struct SimulationAdvance: Sendable, Equatable {
    public let realElapsed: TimeInterval
    public let simulationElapsed: TimeInterval
    public let careCycleElapsed: TimeInterval

    public init(realElapsed: TimeInterval, simulationElapsed: TimeInterval, careCycleElapsed: TimeInterval) {
        self.realElapsed = realElapsed
        self.simulationElapsed = simulationElapsed
        self.careCycleElapsed = careCycleElapsed
    }
}

public struct SimulationClock {
    public init() {}

    public func advance(from previous: TimeState, to now: Date) -> (next: TimeState, delta: SimulationAdvance) {
        let realElapsed = max(0, now.timeIntervalSince(previous.realWorld))
        let simulationElapsed = realElapsed * SimulationSpeed.longTermMultiplier
        let careCycleElapsed = realElapsed

        let nextState = TimeState(
            realWorld: now,
            simulation: previous.simulation.addingTimeInterval(simulationElapsed),
            careCycle: previous.careCycle.addingTimeInterval(careCycleElapsed)
        )

        return (
            next: nextState,
            delta: SimulationAdvance(
                realElapsed: realElapsed,
                simulationElapsed: simulationElapsed,
                careCycleElapsed: careCycleElapsed
            )
        )
    }
}
