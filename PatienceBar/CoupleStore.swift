import Foundation
import Observation
import WidgetKit

@MainActor
@Observable
final class CoupleStore {
    static let shared = CoupleStore()

    private(set) var snapshot: CoupleSnapshot?
    private(set) var isRestoring = false
    var errorMessage: String?
    var theme: AppTheme = AppTheme.current {
        didSet {
            AppTheme.current = theme
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private var backend: CoupleBackend?
    private let sessionKey = "session"

    private struct Session: Codable {
        var kind: String          // "local" | "remote"
        var coupleId: String?
    }

    var isLocal: Bool { backend is LocalBackend }

    init() {
        restore()
    }

    // MARK: Session

    private func restore() {
        guard let raw = SharedCache.defaults.data(forKey: sessionKey),
              let s = try? JSONDecoder().decode(Session.self, from: raw) else { return }
        if s.kind == "local" {
            attach(LocalBackend(myName: nil))
        } else if let id = s.coupleId {
            #if canImport(FirebaseFirestore) && canImport(FirebaseAuth)
            if FirebaseSupport.isConfigured {
                isRestoring = true
                Task {
                    defer { isRestoring = false }
                    do { attach(try await FirestoreBackend.resume(coupleId: id)) }
                    catch { errorMessage = error.localizedDescription }
                }
            }
            #endif
        }
    }

    private func save(_ s: Session) {
        if let raw = try? JSONEncoder().encode(s) { SharedCache.defaults.set(raw, forKey: sessionKey) }
    }

    private func attach(_ b: CoupleBackend) {
        backend?.stop()
        backend = b
        b.observe { [weak self] snap in self?.apply(snap) }
    }

    private func apply(_ snap: CoupleSnapshot) {
        snapshot = snap
        SharedCache.save(from: snap)
    }

    // MARK: Pairing

    func startLocal(name: String) {
        LocalBackend.wipe()
        save(Session(kind: "local", coupleId: nil))
        attach(LocalBackend(myName: name.isEmpty ? nil : name))
    }

    func createRemote(name: String) async {
        #if canImport(FirebaseFirestore) && canImport(FirebaseAuth)
        do {
            let b = try await FirestoreBackend.create(name: name)
            save(Session(kind: "remote", coupleId: b.coupleId))
            attach(b)
        } catch { errorMessage = error.localizedDescription }
        #endif
    }

    func joinRemote(code: String, name: String) async {
        #if canImport(FirebaseFirestore) && canImport(FirebaseAuth)
        do {
            let b = try await FirestoreBackend.join(code: code, name: name)
            save(Session(kind: "remote", coupleId: b.coupleId))
            attach(b)
        } catch { errorMessage = error.localizedDescription }
        #endif
    }

    func leave() {
        backend?.stop()
        backend = nil
        snapshot = nil
        SharedCache.defaults.removeObject(forKey: sessionKey)
        LocalBackend.wipe()
        SharedCache.clear()
    }

    func switchViewer() {
        (backend as? LocalBackend)?.switchViewer()
    }

    // MARK: Actions

    func perform(_ action: PatienceAction) {
        guard let backend else { return }
        Task {
            do { try await backend.perform(action) }
            catch { errorMessage = error.localizedDescription }
        }
    }

    /// 小工具 / Siri 排進佇列的動作，在 app 取得機會時送出。
    func drainPending() async {
        guard let backend else { return }
        for p in SharedCache.takePending() {
            try? await backend.perform(p.action)
        }
    }
}
