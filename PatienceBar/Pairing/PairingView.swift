import SwiftUI

struct PairingView: View {
    @Environment(CoupleStore.self) private var store
    @State private var name = ""
    @State private var code = ""
    @State private var busy = false

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        ZStack {
            LinearGradient(colors: Weather.sunny.gradient, startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 64)).foregroundStyle(Weather.sunny.tint)
                        .padding(.top, 48)
                    Text("耐心條").font(.largeTitle.bold())
                    Text("讓藏在表面下的煩躁，被對方輕輕看見。")
                        .font(.subheadline).foregroundStyle(.secondary)

                    TextField("我的暱稱", text: $name)
                        .textFieldStyle(.roundedBorder).padding(.top, 12)

                    if FirebaseSupport.isConfigured {
                        remoteSection
                    } else {
                        Text("還沒放 GoogleService-Info.plist，雙機同步未啟用。先用本機模擬體驗。")
                            .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }

                    Button {
                        store.startLocal(name: trimmedName)
                    } label: {
                        Label("本機模擬（一支手機扮兩人）", systemImage: "iphone")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered).controlSize(.large)
                }
                .padding(.horizontal, 24)
            }
        }
        .disabled(busy)
    }

    private var remoteSection: some View {
        VStack(spacing: 12) {
            Button {
                run { await store.createRemote(name: trimmedName.isEmpty ? "我" : trimmedName) }
            } label: {
                Label("建立配對，產生邀請碼", systemImage: "heart.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).controlSize(.large)

            HStack {
                TextField("對方的邀請碼", text: $code)
                    .textInputAutocapitalization(.characters).autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                Button("加入") {
                    run { await store.joinRemote(code: code, name: trimmedName.isEmpty ? "我" : trimmedName) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).count != 12)
            }
        }
    }

    private func run(_ work: @escaping () async -> Void) {
        busy = true
        Task { await work(); busy = false }
    }
}
