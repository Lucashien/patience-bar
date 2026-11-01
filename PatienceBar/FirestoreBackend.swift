import Foundation
#if canImport(FirebaseFirestore) && canImport(FirebaseAuth)
import FirebaseAuth
import FirebaseFirestore

/// Firestore 的欄位對應；放在 nonisolated 型別裡，transaction 的 closure 才能呼叫。
enum FirestoreCoding {
    static func stateDict(_ s: PatienceState) -> [String: Any] {
        var d: [String: Any] = [
            "base": s.base, "updatedAt": Timestamp(date: s.updatedAt), "dayKey": s.dayKey,
            "pokeLossToday": s.pokeLossToday, "chargeGainToday": s.chargeGainToday, "combo": s.combo,
        ]
        d["lastPokeAt"] = s.lastPokeAt.map { Timestamp(date: $0) } ?? NSNull()
        return d
    }

    static func parseState(_ d: [String: Any]) -> PatienceState? {
        guard let base = (d["base"] as? NSNumber)?.doubleValue,
              let updated = d["updatedAt"] as? Timestamp,
              let dayKey = d["dayKey"] as? String else { return nil }
        return PatienceState(
            base: base, updatedAt: updated.dateValue(), dayKey: dayKey,
            pokeLossToday: (d["pokeLossToday"] as? NSNumber)?.doubleValue ?? 0,
            chargeGainToday: (d["chargeGainToday"] as? NSNumber)?.doubleValue ?? 0,
            combo: (d["combo"] as? NSNumber)?.intValue ?? 0,
            lastPokeAt: (d["lastPokeAt"] as? Timestamp)?.dateValue())
    }

    static func eventDict(_ e: EventItem) -> [String: Any] {
        var d: [String: Any] = [
            "type": e.type.rawValue, "actorId": e.actorId, "targetId": e.targetId,
            "delta": e.delta, "createdAt": Timestamp(date: e.createdAt),
        ]
        if let a = e.action { d["action"] = a.rawValue }
        return d
    }

    static func parseEvent(id: String, _ d: [String: Any]) -> EventItem? {
        guard let t = (d["type"] as? String).flatMap(EventType.init(rawValue:)),
              let actor = d["actorId"] as? String, let target = d["targetId"] as? String,
              let ts = d["createdAt"] as? Timestamp else { return nil }
        return EventItem(id: id, type: t, actorId: actor, targetId: target,
                         delta: (d["delta"] as? NSNumber)?.doubleValue ?? 0,
                         action: (d["action"] as? String).flatMap(ChargeAction.init(rawValue:)),
                         createdAt: ts.dateValue())
    }
}

@MainActor
final class FirestoreBackend: CoupleBackend {
    let coupleId: String
    let viewerId: String
    private let db = Firestore.firestore()
    private var listeners: [ListenerRegistration] = []
    private var handler: (@MainActor (CoupleSnapshot) -> Void)?

    private var members: [String] = []
    private var inviteCode: String?
    private var names: [String: String] = [:]
    private var states: [String: PatienceState] = [:]
    private var avatars: [String: Data] = [:]
    private var events: [EventItem] = []

    private init(coupleId: String, viewerId: String) {
        self.coupleId = coupleId
        self.viewerId = viewerId
    }

    static func signIn() async throws -> String {
        if let u = Auth.auth().currentUser { return u.uid }
        return try await Auth.auth().signInAnonymously().user.uid
    }

    static func resume(coupleId: String) async throws -> FirestoreBackend {
        FirestoreBackend(coupleId: coupleId, viewerId: try await signIn())
    }

    static func create(name: String) async throws -> FirestoreBackend {
        let uid = try await signIn()
        let db = Firestore.firestore()
        let letters = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        // The unlisted document ID is the invitation capability (60 random bits).
        let code = String((0..<12).map { _ in letters.randomElement()! })
        let ref = db.collection("couples").document(code)
        try await ref.setData(["members": [uid], "inviteCode": code, "createdAt": FieldValue.serverTimestamp()])
        try await writeUser(ref: ref, uid: uid, name: name)
        return FirestoreBackend(coupleId: ref.documentID, viewerId: uid)
    }

    static func join(code: String, name: String) async throws -> FirestoreBackend {
        let uid = try await signIn()
        let db = Firestore.firestore()
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard normalized.count == 12,
              normalized.allSatisfy({ "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".contains($0) }) else {
            throw BackendError.badCode
        }
        let ref = db.collection("couples").document(normalized)
        do {
            // Rules atomically allow only the second member to add themselves.
            // No collection query or pre-membership read is needed.
            try await ref.updateData(["members": FieldValue.arrayUnion([uid])])
        } catch {
            let nsError = error as NSError
            if nsError.domain == FirestoreErrorDomain,
               [FirestoreErrorCode.permissionDenied.rawValue, FirestoreErrorCode.notFound.rawValue].contains(nsError.code) {
                throw BackendError.badCode
            }
            throw error
        }
        try await writeUser(ref: ref, uid: uid, name: name)
        return FirestoreBackend(coupleId: ref.documentID, viewerId: uid)
    }

    private static func writeUser(ref: DocumentReference, uid: String, name: String) async throws {
        var d = FirestoreCoding.stateDict(PatienceEngine.fresh(now: Date()))
        d["name"] = name
        try await ref.collection("users").document(uid).setData(d, merge: true)
    }

    var inviteCodeValue: String? { inviteCode }

    func observe(_ handler: @escaping @MainActor (CoupleSnapshot) -> Void) {
        self.handler = handler
        let couple = db.collection("couples").document(coupleId)

        listeners.append(couple.addSnapshotListener { [weak self] snap, _ in
            guard let d = snap?.data() else { return }
            let members = d["members"] as? [String] ?? []
            let code = d["inviteCode"] as? String
            Task { @MainActor in
                self?.members = members
                self?.inviteCode = code
                self?.emit()
            }
        })
        listeners.append(couple.collection("users").addSnapshotListener { [weak self] snap, _ in
            guard let docs = snap?.documents else { return }
            var names: [String: String] = [:]
            var states: [String: PatienceState] = [:]
            var avatars: [String: Data] = [:]
            for doc in docs {
                let d = doc.data()
                if let a = d["avatar"] as? Data { avatars[doc.documentID] = a }
                if let n = d["name"] as? String { names[doc.documentID] = n }
                if let s = FirestoreCoding.parseState(d) { states[doc.documentID] = s }
            }
            Task { @MainActor in
                self?.names = names
                self?.states = states
                self?.avatars = avatars
                self?.emit()
            }
        })
        listeners.append(couple.collection("events").order(by: "createdAt", descending: true).limit(to: 50)
            .addSnapshotListener { [weak self] snap, _ in
                guard let docs = snap?.documents else { return }
                let events = docs.compactMap { FirestoreCoding.parseEvent(id: $0.documentID, $0.data()) }
                Task { @MainActor in
                    self?.events = events
                    self?.emit()
                }
            })
    }

    func stop() {
        listeners.forEach { $0.remove() }
        listeners = []
        handler = nil
    }

    private func emit() {
        handler?(CoupleSnapshot(meId: viewerId, partnerId: members.first { $0 != viewerId },
                                names: names, states: states, events: events,
                                inviteCode: inviteCode, isLocal: false, avatars: avatars))
    }

    func setAvatar(_ data: Data?) async throws {
        let ref = db.collection("couples").document(coupleId).collection("users").document(viewerId)
        try await ref.setData(["avatar": data.map { $0 as Any } ?? FieldValue.delete()], merge: true)
    }

    func perform(_ action: PatienceAction) async throws {
        let partnerId = members.first { $0 != viewerId } ?? ""
        switch action {
        case .poke, .charge:
            if partnerId.isEmpty { throw BackendError.notPaired }
        default: break
        }
        let actorId = viewerId
        let couple = db.collection("couples").document(coupleId)
        let users = couple.collection("users")
        let events = couple.collection("events")

        _ = try await db.runTransaction { tx, errorPointer -> Any? in
            do {
                var current: [String: PatienceState] = [:]
                for id in [actorId, partnerId] where !id.isEmpty {
                    let doc = try tx.getDocument(users.document(id))
                    if let s = FirestoreCoding.parseState(doc.data() ?? [:]) { current[id] = s }
                }
                let r = ActionApplier.apply(action, actorId: actorId, partnerId: partnerId,
                                            states: current, now: Date())
                tx.setData(FirestoreCoding.stateDict(r.newState), forDocument: users.document(r.targetId), merge: true)
                tx.setData(FirestoreCoding.eventDict(r.event), forDocument: events.document(r.event.id))
                return nil
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }
    }
}
#endif
