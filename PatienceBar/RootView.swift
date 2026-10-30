import SwiftUI

struct RootView: View {
    @Environment(CoupleStore.self) private var store

    var body: some View {
        Group {
            if store.snapshot != nil {
                HomeView()
            } else if store.isRestoring {
                ProgressView("連線中…")
            } else {
                PairingView()
            }
        }
        .alert("出了點狀況", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } })) {
            Button("好") {}
        } message: {
            Text(store.errorMessage ?? "")
        }
    }
}
