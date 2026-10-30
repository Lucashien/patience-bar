import XCTest
@testable import PatienceBar

final class PatienceEngineTests: XCTestCase {
    var cal = Calendar(identifier: .gregorian)
    let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUp() {
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
    }

    private func fresh(base: Double = 100) -> PatienceState {
        var s = PatienceEngine.fresh(now: t0, calendar: cal)
        s.base = base
        return s
    }

    func testWeatherThresholds() {
        XCTAssertEqual(PatienceEngine.weather(for: 100), .sunny)
        XCTAssertEqual(PatienceEngine.weather(for: 70), .sunny)
        XCTAssertEqual(PatienceEngine.weather(for: 69.9), .cloudy)
        XCTAssertEqual(PatienceEngine.weather(for: 40), .cloudy)
        XCTAssertEqual(PatienceEngine.weather(for: 39.9), .aboutToRain)
        XCTAssertEqual(PatienceEngine.weather(for: 15), .aboutToRain)
        XCTAssertEqual(PatienceEngine.weather(for: 14.9), .thunderstorm)
    }

    func testRegenOverTimeCapsAtMax() {
        let s = fresh(base: 50)
        XCTAssertEqual(PatienceEngine.current(s, now: t0.addingTimeInterval(20 * 60), calendar: cal), 60, accuracy: 0.001)
        XCTAssertEqual(PatienceEngine.current(s, now: t0.addingTimeInterval(600 * 60), calendar: cal), 100, accuracy: 0.001)
    }

    func testNewDayResetsToFull() {
        var s = fresh(base: 12)
        s.pokeLossToday = 30
        let tomorrow = t0.addingTimeInterval(24 * 3600)
        XCTAssertEqual(PatienceEngine.current(s, now: tomorrow, calendar: cal), 100)
        let settled = PatienceEngine.settled(s, now: tomorrow, calendar: cal)
        XCTAssertEqual(settled.pokeLossToday, 0)
        XCTAssertEqual(settled.base, 100)
    }

    func testPokeComboEscalatesThenResets() {
        var s = fresh()
        var losses: [Double] = []
        for i in 0..<4 {
            let r = PatienceEngine.poke(s, now: t0.addingTimeInterval(Double(i) * 5), calendar: cal)
            s = r.state
            losses.append(r.applied)
        }
        XCTAssertEqual(losses, [3, 4, 5, 6])
        let later = PatienceEngine.poke(s, now: t0.addingTimeInterval(200), calendar: cal)
        XCTAssertEqual(later.applied, 3)
        XCTAssertEqual(later.state.combo, 0)
    }

    func testComboBonusIsCapped() {
        var s = fresh()
        var last = 0.0
        for i in 0..<9 {
            s.pokeLossToday = 0
            s.base = 100
            let r = PatienceEngine.poke(s, now: t0.addingTimeInterval(Double(i)), calendar: cal)
            s = r.state
            last = r.applied
        }
        XCTAssertEqual(last, 8)
    }

    func testDailyPokeCap() {
        var s = fresh()
        s.pokeLossToday = 38
        let r = PatienceEngine.poke(s, now: t0, calendar: cal)
        XCTAssertEqual(r.applied, 2)
        XCTAssertEqual(PatienceEngine.poke(r.state, now: t0.addingTimeInterval(100), calendar: cal).applied, 0)
    }

    func testPokeNeverGoesBelowFloor() {
        let r = PatienceEngine.poke(fresh(base: 11), now: t0, calendar: cal)
        XCTAssertEqual(r.state.base, 10)
        XCTAssertEqual(PatienceEngine.poke(r.state, now: t0.addingTimeInterval(1), calendar: cal).applied, 0.0083, accuracy: 0.001)
    }

    func testChargeRespectsDailyCapAndMax() {
        var s = fresh(base: 20)
        s.chargeGainToday = 50
        let r = PatienceEngine.charge(s, action: .drink, now: t0, calendar: cal)
        XCTAssertEqual(r.applied, 10)
        XCTAssertEqual(r.state.base, 30)
        let full = PatienceEngine.charge(fresh(base: 95), action: .drink, now: t0, calendar: cal)
        XCTAssertEqual(full.applied, 5)
    }

    func testSelfAdjustAndRecover() {
        let s = PatienceEngine.adjust(fresh(), delta: -15, now: t0, calendar: cal)
        XCTAssertEqual(s.base, 85)
        XCTAssertEqual(s.pokeLossToday, 0)
        let low = PatienceEngine.adjust(fresh(base: 5), delta: -10, now: t0, calendar: cal)
        XCTAssertEqual(low.base, 0)
        let ok = PatienceEngine.recover(low, toAtLeast: 70, now: t0, calendar: cal)
        XCTAssertEqual(ok.base, 70)
    }
}
