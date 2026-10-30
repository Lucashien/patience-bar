import Foundation
import WidgetKit

/// 主 app、小工具、Siri 之間靠 App Group 共用的快照與待送動作佇列。
struct SharedSnapshot: Codable {
    var meId: String
    var partnerId: String?
    var names: [String: String]
    var states: [String: PatienceState]
    var pending: [PendingAction]
}

enum SharedCache {
    static let groupId = "group.com.lucashsien.patiencebar"
    static let key = "shared.snapshot"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: groupId) ?? .standard
    }

    static func load() -> SharedSnapshot? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(SharedSnapshot.self, from: data)
    }

    private static func store(_ s: SharedSnapshot) {
        if let data = try? JSONEncoder().encode(s) { defaults.set(data, forKey: key) }
    }

    /// 主 app 收到最新資料時呼叫；保留尚未送出的 pending。
    static func save(from snap: CoupleSnapshot) {
        let pending = load()?.pending ?? []
        store(SharedSnapshot(meId: snap.meId, partnerId: snap.partnerId,
                             names: snap.names, states: snap.states, pending: pending))
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func clear() {
        defaults.removeObject(forKey: key)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// 小工具 / Siri 觸發：先樂觀更新快照讓畫面立刻有反應，再排進佇列等主 app 送出。
    static func enqueue(_ action: PatienceAction, now: Date = Date()) {
        guard var s = load() else { return }
        let r = ActionApplier.apply(action, actorId: s.meId, partnerId: s.partnerId ?? "",
                                    states: s.states, now: now)
        s.states[r.targetId] = r.newState
        s.pending.append(PendingAction(action: action, at: now))
        store(s)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func takePending() -> [PendingAction] {
        guard var s = load() else { return [] }
        let p = s.pending
        s.pending = []
        store(s)
        return p
    }
}

enum PendingActions {
    /// 主 app 啟動時掛上；在小工具進程裡是 nil。
    nonisolated(unsafe) static var flush: (() async -> Void)?

    static func submit(_ action: PatienceAction) async {
        SharedCache.enqueue(action)
        await flush?()
    }
}
