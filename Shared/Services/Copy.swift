import Foundation

/// 所有文案集中在這裡：第一人稱、說需求，不寫「你很煩」，也不顯示戰績。
enum Copy {
    static func statusLine(_ w: Weather) -> String {
        switch w {
        case .sunny: "我心情不錯"
        case .cloudy: "我有點煩了"
        case .aboutToRain: "我快沒耐心了"
        case .thunderstorm: "先讓我冷靜一下"
        }
    }

    static func chargeTitle(_ a: ChargeAction) -> String {
        switch a {
        case .kindWords: "說幾句好話"
        case .drink: "請喝飲料"
        case .hug: "抱一下"
        }
    }

    static func chargeSymbol(_ a: ChargeAction) -> String {
        switch a {
        case .kindWords: "bubble.left.fill"
        case .drink: "cup.and.saucer.fill"
        case .hug: "heart.fill"
        }
    }

    static func eventText(_ e: EventItem, viewerId: String, names: [String: String]) -> String {
        let actorIsMe = e.actorId == viewerId
        let actor = names[e.actorId] ?? "對方"
        let target = names[e.targetId] ?? "對方"
        let n = Int(abs(e.delta).rounded())

        switch e.type {
        case .poke:
            return actorIsMe ? "我戳了\(target)" : "\(actor)戳了我"
        case .charge:
            let gain = n > 0 ? "，耐心 +\(n)" : "，今天的充電已經滿了"
            switch (e.action ?? .kindWords, actorIsMe) {
            case (.kindWords, true): return "我跟\(target)說了幾句好話\(gain)"
            case (.kindWords, false): return "\(actor)跟我說了幾句好話\(gain)"
            case (.drink, true): return "我請\(target)喝飲料\(gain)"
            case (.drink, false): return "\(actor)請我喝飲料\(gain)"
            case (.hug, true): return "我抱了\(target)一下\(gain)"
            case (.hug, false): return "\(actor)抱了我一下\(gain)"
            }
        case .selfAdjust:
            return actorIsMe ? "我需要先喘口氣，耐心 −\(n)" : "\(actor)需要先喘口氣"
        case .recover:
            return actorIsMe ? "我好了，耐心 +\(n)" : "\(actor)好了"
        }
    }
}
