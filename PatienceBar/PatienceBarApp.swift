import SwiftUI

@main
struct PatienceBarApp: App {
    @State private var store: CoupleStore
    @Environment(\.scenePhase) private var scenePhase

    init() {
        FirebaseSupport.configureIfPossible()
        _store = State(initialValue: CoupleStore.shared)
        PendingActions.flush = { await CoupleStore.shared.drainPending() }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { Task { await store.drainPending() } }
                }
        }
    }
}
