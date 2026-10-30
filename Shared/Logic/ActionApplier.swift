import Foundation

struct ActionResult {
    var targetId: String
    var newState: PatienceState
    var event: EventItem
}

/// 把一個動作套用到狀態上；本機後端、Firestore transaction、小工具的樂觀更新都用它。
enum ActionApplier {
    /// 「我好了」每按一次回升的量。
    static let recoverStep = 10.0

    static func apply(_ action: PatienceAction, actorId: String, partnerId: String,
                      states: [String: PatienceState], now: Date,
                      calendar: Calendar = .current) -> ActionResult {
        func state(_ id: String) -> PatienceState {
            states[id] ?? PatienceEngine.fresh(now: now, calendar: calendar)
        }
        func event(_ type: EventType, target: String, delta: Double, action: ChargeAction? = nil) -> EventItem {
            EventItem(id: UUID().uuidString, type: type, actorId: actorId, targetId: target,
                      delta: delta, action: action, createdAt: now)
        }

        switch action {
        case .poke:
            let r = PatienceEngine.poke(state(partnerId), now: now, calendar: calendar)
            return ActionResult(targetId: partnerId, newState: r.state,
                                event: event(.poke, target: partnerId, delta: -r.applied))
        case .charge(let a):
            let r = PatienceEngine.charge(state(partnerId), action: a, now: now, calendar: calendar)
            return ActionResult(targetId: partnerId, newState: r.state,
                                event: event(.charge, target: partnerId, delta: r.applied, action: a))
        case .adjust(let d):
            let new = PatienceEngine.adjust(state(actorId), delta: d, now: now, calendar: calendar)
            return ActionResult(targetId: actorId, newState: new,
                                event: event(.selfAdjust, target: actorId, delta: d))
        case .recover:
            let before = PatienceEngine.current(state(actorId), now: now, calendar: calendar)
            let new = PatienceEngine.adjust(state(actorId), delta: recoverStep, now: now, calendar: calendar)
            return ActionResult(targetId: actorId, newState: new,
                                event: event(.recover, target: actorId, delta: new.base - before))
        }
    }
}
