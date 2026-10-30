import Foundation

/// 單機模擬：同一台手機裡有「我」和「對方」兩個人，可切換視角。沒有 Firebase 也能完整 demo。
@MainActor
final class LocalBackend: CoupleBackend {
    private struct Store: Codable {
        var names: [String: String]
        var states: [String: PatienceState]
        var events: [EventItem]
        var viewer: String
    }

    static let meId = "me"
    static let herId = "partner"
    private static let key = "local.couple"

    private var data: Store
    private var handler: (@MainActor (CoupleSnapshot) -> Void)?

    var viewerId: String { data.viewer }

    static func hasSavedData() -> Bool {
        SharedCache.defaults.data(forKey: key) != nil
    }

    static func wipe() {
        SharedCache.defaults.removeObject(forKey: key)
    }

    init(myName: String?) {
        if let raw = SharedCache.defaults.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode(Store.self, from: raw) {
            data = saved
        } else {
            let now = Date()
            data = Store(names: [Self.meId: myName ?? "我", Self.herId: "對方"],
                        states: [Self.meId: PatienceEngine.fresh(now: now),
                                 Self.herId: PatienceEngine.fresh(now: now)],
                        events: [], viewer: Self.meId)
            persist()
        }
    }

    private var partnerOfViewer: String { data.viewer == Self.meId ? Self.herId : Self.meId }

    func switchViewer() {
        data.viewer = partnerOfViewer
        persist()
        emit()
    }

    func observe(_ handler: @escaping @MainActor (CoupleSnapshot) -> Void) {
        self.handler = handler
        emit()
    }

    func stop() { handler = nil }

    func perform(_ action: PatienceAction) async throws {
        let r = ActionApplier.apply(action, actorId: data.viewer, partnerId: partnerOfViewer,
                                    states: data.states, now: Date())
        data.states[r.targetId] = r.newState
        data.events.insert(r.event, at: 0)
        data.events = Array(data.events.prefix(50))
        persist()
        emit()
    }

    private func persist() {
        if let raw = try? JSONEncoder().encode(data) {
            SharedCache.defaults.set(raw, forKey: Self.key)
        }
    }

    private func emit() {
        handler?(CoupleSnapshot(meId: data.viewer, partnerId: partnerOfViewer, names: data.names,
                                states: data.states, events: data.events, inviteCode: nil, isLocal: true))
    }
}
