import SwiftUI
import WidgetKit
import AppIntents

struct PatienceEntry: TimelineEntry {
    let date: Date
    let snapshot: SharedSnapshot?
}

struct PatienceProvider: TimelineProvider {
    func placeholder(in context: Context) -> PatienceEntry { PatienceEntry(date: .now, snapshot: nil) }

    func getSnapshot(in context: Context, completion: @escaping (PatienceEntry) -> Void) {
        completion(PatienceEntry(date: .now, snapshot: SharedCache.load()))
    }

    /// 顯示值由時間現算，所以預先排一小時、每 5 分鐘一筆，回升會自己看得到。
    func getTimeline(in context: Context, completion: @escaping (Timeline<PatienceEntry>) -> Void) {
        let snap = SharedCache.load()
        let entries = (0...12).map { i in
            PatienceEntry(date: Date().addingTimeInterval(Double(i) * 300), snapshot: snap)
        }
        completion(Timeline(entries: entries, policy: .after(Date().addingTimeInterval(3600))))
    }
}

/// 一列：天氣圖示 + 名字 + 數字 + 血條。染色 / 玻璃模式下系統會抹掉顏色，
/// 所以改用「粗細、透明度」區分，並用 widgetAccentable 讓圖示與血條吃到強調色。
struct MiniBar: View {
    let title: String
    let state: PatienceState?
    let date: Date
    var prominent = false
    var quote: String? = nil
    var avatar: Data? = nil

    @Environment(\.widgetRenderingMode) private var mode

    var body: some View {
        let value = state.map { PatienceEngine.current($0, now: date) } ?? 100
        let weather = PatienceEngine.weather(for: value)
        let full = mode == .fullColor
        let ink = full ? weather.ink : Color.primary
        let fill: Color = full ? weather.tint : .primary

        VStack(alignment: .leading, spacing: prominent ? 6 : 4) {
            HStack(spacing: 6) {
                if let avatar {
                    AvatarView(data: avatar, name: title, size: prominent ? 30 : 22,
                               ring: full ? .white : .clear, lineWidth: full ? 1.5 : 0)
                } else {
                    Image(systemName: weather.symbol)
                        .font(.system(size: prominent ? 18 : 14, weight: .semibold))
                        .symbolRenderingMode(full ? .multicolor : .monochrome)
                        .widgetAccentable()
                }
                Text(title)
                    .font(.system(size: prominent ? 15 : 12, weight: .semibold, design: .rounded))
                    .opacity(prominent ? 1 : 0.75)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text("\(Int(value.rounded()))")
                    .font(.system(size: prominent ? 26 : 16, weight: .bold, design: .rounded).monospacedDigit())
                    .contentTransition(.numericText())
            }
            PatienceBarView(value: value, height: prominent ? 12 : 7, fill: fill,
                            track: ink.opacity(0.18))
                .widgetAccentable()
            if let quote {
                Text("「\(quote)」").font(.system(size: 11, weight: .medium)).opacity(0.7).lineLimit(1)
            }
        }
        .foregroundStyle(ink)
    }
}

struct WidgetActionButton: View {
    let title: String
    let symbol: String
    let weather: Weather
    var outlined = false
    @Environment(\.widgetRenderingMode) private var mode

    var body: some View {
        let full = mode == .fullColor
        Label(title, systemImage: symbol)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .foregroundStyle(outlined || !full ? (full ? weather.ink : Color.primary) : (weather == .thunderstorm ? Color(red: 0.2, green: 0.18, blue: 0.4) : .white))
            .background(outlined ? Color.clear : (full ? weather.ink : Color.primary.opacity(0.18)), in: Capsule())
            .overlay(Capsule().stroke(full ? weather.ink : Color.primary, lineWidth: outlined ? 2 : 0))
    }
}

struct PatienceWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var mode
    let entry: PatienceEntry

    var body: some View {
        if let s = entry.snapshot {
            let mine = s.states[s.meId]
            let theirs = s.partnerId.flatMap { s.states[$0] }
            let partnerName = s.partnerId.flatMap { s.names[$0] } ?? "對方"
            let myValue = mine.map { PatienceEngine.current($0, now: entry.date) } ?? 100
            let weather = PatienceEngine.weather(for: myValue)

            if AppTheme.current == .game {
                gameLayout(partnerName: partnerName, mine: mine, theirs: theirs, weather: weather)
            } else {
                weatherLayout(partnerName: partnerName, mine: mine, theirs: theirs, weather: weather)
            }
        } else {
            VStack(spacing: 6) {
                Image(systemName: "sun.max.fill").font(.title).foregroundStyle(Weather.sunny.tint)
                Text("打開耐心條完成配對").font(.caption)
            }
        }
    }

    private var myAvatar: Data? { entry.snapshot.flatMap { $0.avatars?[$0.meId] } }
    private var theirAvatar: Data? {
        entry.snapshot.flatMap { s in s.partnerId.flatMap { s.avatars?[$0] } }
    }

    // MARK: 天氣窗

    private func weatherLayout(partnerName: String, mine: PatienceState?, theirs: PatienceState?, weather: Weather) -> some View {
        Group {
            if family == .systemMedium {
                HStack(spacing: 16) {
                    bars(partnerName: partnerName, mine: mine, theirs: theirs, weather: weather)
                    VStack(spacing: 8) {
                        Button(intent: IAmOkIntent()) {
                            WidgetActionButton(title: "我好了", symbol: "arrow.up", weather: weather)
                        }
                        Button(intent: AdjustIntent()) {
                            WidgetActionButton(title: "有點煩", symbol: "arrow.down", weather: weather, outlined: true)
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(width: 110)
                }
            } else {
                bars(partnerName: partnerName, mine: mine, theirs: theirs, weather: weather)
            }
        }
    }

    private func bars(partnerName: String, mine: PatienceState?, theirs: PatienceState?, weather: Weather) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            MiniBar(title: partnerName, state: theirs, date: entry.date, avatar: theirAvatar)
            MiniBar(title: "我", state: mine, date: entry.date, prominent: true,
                    quote: family == .systemSmall ? nil : Copy.statusLine(weather), avatar: myAvatar)
        }
        .frame(maxHeight: .infinity, alignment: .center)
    }

    // MARK: 遊戲血條

    private func gameLayout(partnerName: String, mine: PatienceState?, theirs: PatienceState?, weather: Weather) -> some View {
        let full = mode == .fullColor
        let myValue = mine.map { PatienceEngine.current($0, now: entry.date) } ?? 100
        let theirValue = theirs.map { PatienceEngine.current($0, now: entry.date) } ?? 100
        let theirFill = full ? PatienceEngine.weather(for: theirValue).gameFill : Color.primary
        let myFill = full ? weather.gameFill : Color.primary
        let ink = full ? AppTheme.gameInk : Color.primary
        let cardBG = full ? Color.white : Color.primary.opacity(0.12)

        let cards = VStack(spacing: 8) {
            VStack(spacing: 4) {
                HStack(spacing: 5) {
                    if let a = theirAvatar {
                        AvatarView(data: a, name: partnerName, size: 16, ring: ink, lineWidth: 1.5)
                    }
                    Text(partnerName).font(.system(size: 11, weight: .black, design: .rounded))
                    Spacer()
                    Text("\(Int(theirValue.rounded()))").font(.system(size: 11, weight: .black, design: .rounded))
                }
                SegmentedBar(value: theirValue, height: 7, fill: theirFill, empty: full ? AppTheme.gameEmpty : .clear,
                             border: ink, lineWidth: 1.5, gap: 2)
            }
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(cardBG, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(ink, lineWidth: 2.5))

            VStack(spacing: 5) {
                HStack(alignment: .center, spacing: 5) {
                    if let a = myAvatar {
                        AvatarView(data: a, name: "我", size: 24, ring: ink, lineWidth: 2)
                    }
                    Text("我").font(.system(size: 12, weight: .black, design: .rounded))
                    Spacer()
                    Text("\(Int(myValue.rounded()))").font(.system(size: 30, weight: .black, design: .rounded))
                }
                SegmentedBar(value: myValue, height: family == .systemSmall ? 12 : 11, fill: myFill,
                             empty: full ? AppTheme.gameEmpty : .clear, border: ink, lineWidth: 1.5, gap: 2)
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(GameSlab(radius: 16, depth: 3, fill: cardBG, ink: ink, showsDepth: full))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(ink, lineWidth: 3))
        }
        .foregroundStyle(ink)

        return Group {
            if family == .systemMedium {
                HStack(spacing: 12) {
                    cards
                    VStack(spacing: 10) {
                        Button(intent: IAmOkIntent()) {
                            GameWidgetButton(title: "▲ 我好了", fill: full ? AppTheme.gameGreen : .clear)
                        }
                        Button(intent: AdjustIntent()) {
                            GameWidgetButton(title: "▼ 有點煩", fill: full ? AppTheme.gamePink : .clear)
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(width: 104)
                }
            } else {
                cards
            }
        }
    }
}

struct GameWidgetButton: View {
    let title: String
    let fill: Color
    @Environment(\.widgetRenderingMode) private var mode

    var body: some View {
        let ink = mode == .fullColor ? AppTheme.gameInk : Color.primary
        Text(title)
            .font(.system(size: 14, weight: .black, design: .rounded))
            .foregroundStyle(ink)
            .frame(maxWidth: .infinity).frame(height: 44)
            .background(GameSlab(radius: 14, depth: 3, fill: fill, ink: ink, showsDepth: mode == .fullColor))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(ink, lineWidth: 3))
    }
}

struct PatienceWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PatienceWidget", provider: PatienceProvider()) { entry in
            PatienceWidgetView(entry: entry)
                .containerBackground(for: .widget) { background(entry) }
        }
        .configurationDisplayName("耐心條")
        .description("同時看到我和對方的耐心。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }

    @ViewBuilder
    private func background(_ entry: PatienceEntry) -> some View {
        if AppTheme.current == .game {
            DotsBackground(spacing: 18)
        } else {
            let value = entry.snapshot.flatMap { s in
                s.states[s.meId].map { PatienceEngine.current($0, now: entry.date) }
            } ?? 100
            LinearGradient(colors: PatienceEngine.weather(for: value).gradient, startPoint: .top, endPoint: .bottom)
        }
    }
}

@main
struct PatienceWidgetBundle: WidgetBundle {
    var body: some Widget { PatienceWidget() }
}
