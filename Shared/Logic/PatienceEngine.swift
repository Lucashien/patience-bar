import Foundation

/// 耐心條規則：純函式、無 I/O，app 與 widget 共用。
enum PatienceEngine {
    static let maxValue = 100.0
    static let regenPerMinute = 0.5
    static let floorValue = 10.0
    static let pokeLossCap = 40.0
    static let chargeGainCap = 60.0
    static let comboWindow: TimeInterval = 30
    static let basePokeLoss = 3.0
    static let maxComboBonus = 5

    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    static func fresh(now: Date, calendar: Calendar = .current) -> PatienceState {
        PatienceState(base: maxValue, updatedAt: now, dayKey: dayKey(now, calendar: calendar),
                      pokeLossToday: 0, chargeGainToday: 0, combo: 0, lastPokeAt: nil)
    }

    /// 顯示值：base 加上經過時間的回升，上限 100；跨日則視為滿格。
    static func current(_ s: PatienceState, now: Date, calendar: Calendar = .current) -> Double {
        if s.dayKey != dayKey(now, calendar: calendar) { return maxValue }
        let minutes = max(0, now.timeIntervalSince(s.updatedAt)) / 60
        return min(maxValue, s.base + regenPerMinute * minutes)
    }

    static func weather(for value: Double) -> Weather {
        switch value {
        case 70...: .sunny
        case 40..<70: .cloudy
        case 15..<40: .aboutToRain
        default: .thunderstorm
        }
    }

    /// 把回升與跨日重設結算進 base，之後的變動都從這個結果出發。
    static func settled(_ s: PatienceState, now: Date, calendar: Calendar = .current) -> PatienceState {
        if s.dayKey != dayKey(now, calendar: calendar) { return fresh(now: now, calendar: calendar) }
        var out = s
        out.base = current(s, now: now, calendar: calendar)
        out.updatedAt = now
        return out
    }

    /// 被戳一下。回傳新狀態與實際扣掉的量（受連擊、每日上限、下限影響）。
    static func poke(_ s: PatienceState, now: Date, calendar: Calendar = .current) -> (state: PatienceState, applied: Double) {
        var out = settled(s, now: now, calendar: calendar)
        if let last = out.lastPokeAt, now.timeIntervalSince(last) <= comboWindow {
            out.combo += 1
        } else {
            out.combo = 0
        }
        let wanted = basePokeLoss + Double(min(out.combo, maxComboBonus))
        let applied = max(0, min(wanted, pokeLossCap - out.pokeLossToday, out.base - floorValue))
        out.base -= applied
        out.pokeLossToday += applied
        out.lastPokeAt = now
        return (out, applied)
    }

    /// 被充電。回傳新狀態與實際回升的量。
    static func charge(_ s: PatienceState, action: ChargeAction, now: Date, calendar: Calendar = .current) -> (state: PatienceState, applied: Double) {
        var out = settled(s, now: now, calendar: calendar)
        let applied = max(0, min(action.gain, chargeGainCap - out.chargeGainToday, maxValue - out.base))
        out.base += applied
        out.chargeGainToday += applied
        return (out, applied)
    }

    /// 自己調整（桌面小工具 −10、Siri「我好煩」），不計入戳的每日上限。
    static func adjust(_ s: PatienceState, delta: Double, now: Date, calendar: Calendar = .current) -> PatienceState {
        var out = settled(s, now: now, calendar: calendar)
        out.base = min(maxValue, max(0, out.base + delta))
        return out
    }

    /// 「我好了」：至少回到 minimum。
    static func recover(_ s: PatienceState, toAtLeast minimum: Double, now: Date, calendar: Calendar = .current) -> PatienceState {
        var out = settled(s, now: now, calendar: calendar)
        out.base = max(out.base, min(maxValue, minimum))
        return out
    }

    /// 今天還能被充電多少（跨日重設）。
    static func chargeRoom(_ s: PatienceState, now: Date, calendar: Calendar = .current) -> Double {
        let t = settled(s, now: now, calendar: calendar)
        return max(0, chargeGainCap - t.chargeGainToday)
    }
}
