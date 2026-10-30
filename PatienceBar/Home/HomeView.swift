import SwiftUI

struct HomeView: View {
    @Environment(CoupleStore.self) private var store
    @State private var showEvents = false
    @State private var confirmLeave = false

    var body: some View {
        if let snap = store.snapshot {
            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                content(snap, now: ctx.date)
            }
        }
    }

    private func content(_ snap: CoupleSnapshot, now: Date) -> some View {
        let mine = snap.meState.map { PatienceEngine.current($0, now: now) } ?? 100
        let weather = PatienceEngine.weather(for: mine)
        let theme = store.theme
        let ink = theme == .game ? AppTheme.gameInk : weather.ink

        return ZStack {
            background(theme, weather).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    header(snap, theme: theme, weather: weather)

                    if let code = snap.inviteCode, snap.partnerId == nil {
                        waitingCard(code, theme: theme, weather: weather)
                    }

                    switch theme {
                    case .weather:
                        WeatherBody(snap: snap, now: now, weather: weather,
                                    onRecover: { store.perform(.recover) },
                                    onAdjust: { store.perform(.adjust(-10)) })
                    case .game:
                        GameBody(snap: snap, now: now, weather: weather,
                                 onRecover: { store.perform(.recover) },
                                 onAdjust: { store.perform(.adjust(-10)) })
                    }

                    recent(snap, theme: theme, weather: weather)
                }
                .padding(20)
            }
        }
        .foregroundStyle(ink)
        .tint(ink)
        .sheet(isPresented: $showEvents) { EventsView(snap: snap) }
        .confirmationDialog("要離開目前的配對嗎？", isPresented: $confirmLeave) {
            Button("離開", role: .destructive) { store.leave() }
        }
    }

    @ViewBuilder
    private func background(_ theme: AppTheme, _ weather: Weather) -> some View {
        switch theme {
        case .weather:
            LinearGradient(colors: weather.gradient, startPoint: .top, endPoint: .bottom)
                .animation(.easeInOut(duration: 0.8), value: weather)
        case .game:
            DotsBackground()
        }
    }

    private func header(_ snap: CoupleSnapshot, theme: AppTheme, weather: Weather) -> some View {
        @Bindable var store = store
        return HStack {
            Text("耐心條")
                .font(.system(size: theme == .game ? 30 : 22, weight: theme == .game ? .black : .bold, design: .rounded))
            Spacer()
            if snap.isLocal {
                Button { store.switchViewer() } label: {
                    Label("換成\(snap.partnerName)的視角", systemImage: "arrow.left.arrow.right")
                        .font(.footnote.weight(.semibold)).padding(.horizontal, 10)
                }
                .modifier(ViewerSwitchStyle(theme: theme, weather: weather))
                .fixedSize()
            }
            Menu {
                Picker("主題", selection: $store.theme) {
                    ForEach(AppTheme.allCases) { Text($0.title).tag($0) }
                }
                Divider()
                Button("離開配對", role: .destructive) { confirmLeave = true }
            } label: {
                Image(systemName: "ellipsis.circle").font(.title3)
            }
        }
    }

    private func waitingCard(_ code: String, theme: AppTheme, weather: Weather) -> some View {
        VStack(spacing: 6) {
            Text("把邀請碼給對方，等對方加入").font(.footnote)
            Text(code).font(.system(size: 30, weight: .bold, design: .monospaced))
                .lineLimit(1).minimumScaleFactor(0.6).textSelection(.enabled)
        }
        .frame(maxWidth: .infinity).padding()
        .themedCard(theme, weather)
    }

    private func recent(_ snap: CoupleSnapshot, theme: AppTheme, weather: Weather) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("最近發生的事").font(.headline)
                Spacer()
                Button("全部") { showEvents = true }.font(.footnote.weight(.semibold))
            }
            if snap.events.isEmpty {
                Text("今天還很平靜。").font(.subheadline).opacity(0.7)
            }
            ForEach(snap.events.prefix(4)) { e in
                Text(Copy.eventText(e, viewerId: snap.meId, names: snap.names))
                    .font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .themedCard(theme, weather)
    }
}

private struct ViewerSwitchStyle: ViewModifier {
    let theme: AppTheme
    let weather: Weather

    @ViewBuilder
    func body(content: Content) -> some View {
        if theme == .game {
            content.buttonStyle(GameButtonStyle(fill: .white, small: true))
        } else {
            content.buttonStyle(PillButtonStyle(weather: weather, prominent: false))
        }
    }
}

private extension View {
    @ViewBuilder
    func themedCard(_ theme: AppTheme, _ weather: Weather) -> some View {
        switch theme {
        case .weather:
            self.background(weather.cardFill, in: RoundedRectangle(cornerRadius: 20))
        case .game:
            self.gameCard(radius: 18, depth: 4)
        }
    }
}

// MARK: - 主題 A：天氣窗

private struct WeatherBody: View {
    let snap: CoupleSnapshot
    let now: Date
    let weather: Weather
    let onRecover: () -> Void
    let onAdjust: () -> Void

    var body: some View {
        let mine = snap.meState.map { PatienceEngine.current($0, now: now) } ?? 100
        let theirs = snap.partnerState.map { PatienceEngine.current($0, now: now) } ?? 100
        let theirWeather = PatienceEngine.weather(for: theirs)

        VStack(spacing: 16) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(RadialGradient(colors: [.white.opacity(0.75), .clear], center: .center,
                                             startRadius: 0, endRadius: 120))
                        .frame(width: 240, height: 240)
                    Image(systemName: weather.symbol)
                        .font(.system(size: 66))
                        .symbolRenderingMode(.multicolor)
                }
                .frame(height: 130)
                Text("\(Int(mine.rounded()))")
                    .font(.system(size: 92, weight: .black, design: .rounded))
                    .contentTransition(.numericText())
                Text(Copy.statusLine(weather)).font(.title3.weight(.bold))
            }

            PatienceBarView(value: mine, height: 18)
                .padding(.horizontal, 6)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: theirWeather.symbol).symbolRenderingMode(.multicolor)
                    Text(snap.partnerName).font(.subheadline.weight(.bold))
                    Spacer()
                    Text("\(Int(theirs.rounded()))").font(.title3.weight(.black))
                }
                PatienceBarView(value: theirs, height: 8)
                Text("「\(Copy.statusLine(theirWeather))」").font(.footnote).opacity(0.75)
            }
            .padding(16)
            .background(weather.cardFill, in: RoundedRectangle(cornerRadius: 22))

            VStack(spacing: 10) {
                Button(action: onRecover) { Label("我好了　+10", systemImage: "arrow.up") }
                    .buttonStyle(PillButtonStyle(weather: weather))
                Button(action: onAdjust) { Label("我有點煩　−10", systemImage: "arrow.down") }
                    .buttonStyle(PillButtonStyle(weather: weather, outlined: true))
            }
        }
    }
}

// MARK: - 主題 B：遊戲血條

private struct GameBody: View {
    let snap: CoupleSnapshot
    let now: Date
    let weather: Weather
    let onRecover: () -> Void
    let onAdjust: () -> Void

    var body: some View {
        let mine = snap.meState.map { PatienceEngine.current($0, now: now) } ?? 100
        let theirs = snap.partnerState.map { PatienceEngine.current($0, now: now) } ?? 100
        let theirWeather = PatienceEngine.weather(for: theirs)

        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(snap.partnerName).font(.system(size: 16, weight: .black, design: .rounded))
                    Text("「\(Copy.statusLine(theirWeather))」").font(.footnote.weight(.bold)).opacity(0.65)
                    Spacer()
                    Text("\(Int(theirs.rounded()))").font(.system(size: 20, weight: .black, design: .rounded))
                }
                SegmentedBar(value: theirs, height: 14, fill: theirWeather.gameFill, lineWidth: 2, gap: 3)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .gameCard(radius: 22, depth: 5)

            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle().fill(Color(hex: 0xFFD23F))
                        Circle().stroke(AppTheme.gameInk, lineWidth: 3)
                        Image(systemName: weather.symbol).font(.system(size: 22, weight: .bold))
                            .symbolRenderingMode(.monochrome)
                    }
                    .frame(width: 48, height: 48)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("我的耐心 HP").font(.footnote.weight(.bold)).opacity(0.65)
                        Text(Copy.statusLine(weather)).font(.system(size: 17, weight: .black, design: .rounded))
                    }
                    Spacer()
                    Text("\(Int(mine.rounded()))")
                        .font(.system(size: 56, weight: .black, design: .rounded))
                        .contentTransition(.numericText())
                }
                SegmentedBar(value: mine, height: 30, fill: weather.gameFill, lineWidth: 3, gap: 4)
            }
            .padding(16)
            .gameCard(radius: 26, depth: 7)

            VStack(spacing: 12) {
                Button(action: onRecover) { Text("▲　我好了　+10") }
                    .buttonStyle(GameButtonStyle(fill: AppTheme.gameGreen))
                Button(action: onAdjust) { Text("▼　我有點煩　−10") }
                    .buttonStyle(GameButtonStyle(fill: AppTheme.gamePink))
            }
            .padding(.top, 4)
        }
    }
}
