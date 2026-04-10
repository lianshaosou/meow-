import Foundation
import Testing
@testable import MeowSimulation
import MeowDomain

@Test
func simulationClockAppliesFiveXToLongTermDomain() {
    let start = Date(timeIntervalSince1970: 1_000)
    let end = Date(timeIntervalSince1970: 1_060)

    let initial = TimeState(realWorld: start, simulation: start, careCycle: start)
    let clock = SimulationClock()
    let result = clock.advance(from: initial, to: end)

    #expect(result.delta.realElapsed == 60)
    #expect(result.delta.careCycleElapsed == 60)
    #expect(result.delta.simulationElapsed == 300)
}
