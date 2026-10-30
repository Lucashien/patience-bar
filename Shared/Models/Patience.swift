import Foundation

enum Weather: String, Codable, CaseIterable {
    case sunny, cloudy, aboutToRain, thunderstorm

    var symbol: String {
        switch self {
        case .sunny: "sun.max.fill"
        case .cloudy: "cloud.fill"
        case .aboutToRain: "cloud.drizzle.fill"
        case .thunderstorm: "cloud.bolt.rain.fill"
        }
    }
}

enum ChargeAction: String, Codable, CaseIterable, Identifiable {
    case kindWords, drink, hug

    var id: String { rawValue }

    var gain: Double {
        switch self {
        case .kindWords: 10
        case .drink: 20
        case .hug: 15
        }
    }
}

/// 一個人的耐心條。`base` 只是上次結算的值，顯示值要用 `PatienceEngine.current` 現算。
struct PatienceState: Codable, Equatable {
    var base: Double
    var updatedAt: Date
    var dayKey: String
    var pokeLossToday: Double
    var chargeGainToday: Double
    var combo: Int
    var lastPokeAt: Date?
}
