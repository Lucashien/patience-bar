import Foundation

enum EventType: String, Codable {
    case poke, charge, selfAdjust, recover
}

struct EventItem: Codable, Identifiable, Equatable {
    var id: String
    var type: EventType
    var actorId: String
    var targetId: String
    var delta: Double
    var action: ChargeAction?
    var createdAt: Date
}

/// 使用者能做的事。poke / charge 作用在對方，adjust / recover 作用在自己。
enum PatienceAction: Codable, Equatable {
    case poke
    case charge(ChargeAction)
    case adjust(Double)
    case recover
}

struct PendingAction: Codable, Identifiable, Equatable {
    var id = UUID()
    var action: PatienceAction
    var at: Date
}

struct CoupleSnapshot: Equatable {
    var meId: String
    var partnerId: String?
    var names: [String: String]
    var states: [String: PatienceState]
    var events: [EventItem]
    var inviteCode: String?
    var isLocal: Bool
    var avatars: [String: Data] = [:]

    var meName: String { names[meId] ?? "我" }
    var partnerName: String {
        guard let n = partnerId.flatMap({ names[$0] }), n != meName else { return "對方" }
        return n
    }
    var meAvatar: Data? { avatars[meId] }
    var partnerAvatar: Data? { partnerId.flatMap { avatars[$0] } }
    var meState: PatienceState? { states[meId] }
    var partnerState: PatienceState? { partnerId.flatMap { states[$0] } }
}
