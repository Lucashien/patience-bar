import SwiftUI

struct EventsView: View {
    @Environment(\.dismiss) private var dismiss
    let snap: CoupleSnapshot

    var body: some View {
        NavigationStack {
            List(snap.events) { e in
                VStack(alignment: .leading, spacing: 2) {
                    Text(Copy.eventText(e, viewerId: snap.meId, names: snap.names))
                    Text(e.createdAt, style: .relative).font(.caption).foregroundStyle(.secondary)
                }
            }
            .overlay { if snap.events.isEmpty { Text("今天還很平靜。").foregroundStyle(.secondary) } }
            .navigationTitle("最近發生的事")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
    }
}
