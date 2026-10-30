import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case weather, game

    var id: String { rawValue }

    var title: String {
        switch self {
        case .weather: "天氣窗"
        case .game: "遊戲血條"
        }
    }

    static let key = "theme"
    static let gameInk = Color(hex: 0x3B2A20)
    static let gameBackground = Color(hex: 0xFFE8A3)
    static let gameEmpty = Color(hex: 0xEDE3CC)
    static let gameGreen = Color(hex: 0x8DDB7A)
    static let gamePink = Color(hex: 0xFF9F8A)

    /// app 與小工具共用 App Group 的設定。
    static var current: AppTheme {
        get { AppTheme(rawValue: SharedCache.defaults.string(forKey: key) ?? "") ?? .weather }
        set { SharedCache.defaults.set(newValue.rawValue, forKey: key) }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

extension Weather {
    /// 遊戲主題的血條顏色。
    var gameFill: Color {
        switch self {
        case .sunny: Color(hex: 0x7BC96F)
        case .cloudy: Color(hex: 0xF2C94C)
        case .aboutToRain: Color(hex: 0xF29A4B)
        case .thunderstorm: Color(hex: 0xE5586B)
        }
    }
}

/// 分成 10 格的血條。
struct SegmentedBar: View {
    let value: Double
    var height: CGFloat = 14
    var fill: Color
    var empty: Color = AppTheme.gameEmpty
    var border: Color = AppTheme.gameInk
    var lineWidth: CGFloat = 2
    var gap: CGFloat = 3

    var body: some View {
        HStack(spacing: gap) {
            ForEach(0..<10, id: \.self) { i in
                let on = value >= Double(i + 1) * 10 - 5
                RoundedRectangle(cornerRadius: height / 3.2)
                    .fill(on ? fill : empty)
                    .overlay(RoundedRectangle(cornerRadius: height / 3.2).stroke(border, lineWidth: lineWidth))
                    .frame(height: height)
            }
        }
    }
}

struct DotsBackground: View {
    var spacing: CGFloat = 22

    var body: some View {
        Canvas { ctx, size in
            var y: CGFloat = spacing / 2
            while y < size.height {
                var x: CGFloat = spacing / 2
                while x < size.width {
                    ctx.fill(Path(ellipseIn: CGRect(x: x - 1.5, y: y - 1.5, width: 3, height: 3)),
                             with: .color(AppTheme.gameInk.opacity(0.13)))
                    x += spacing
                }
                y += spacing
            }
        }
        .background(AppTheme.gameBackground)
    }
}

/// 立體陰影用「墊在底下的實心形狀」做，不用 .shadow，免得文字也被複製一份。
struct GameSlab: View {
    var radius: CGFloat
    var depth: CGFloat
    var fill: Color = .white
    var ink: Color = AppTheme.gameInk
    var showsDepth = true

    var body: some View {
        ZStack {
            if showsDepth { RoundedRectangle(cornerRadius: radius).fill(ink).offset(y: depth) }
            RoundedRectangle(cornerRadius: radius).fill(fill)
        }
    }
}

extension View {
    /// 遊戲主題的白底粗框貼紙卡片。
    func gameCard(radius: CGFloat = 22, depth: CGFloat = 5) -> some View {
        self.background(GameSlab(radius: radius, depth: depth))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(AppTheme.gameInk, lineWidth: 3))
    }
}

struct GameButtonStyle: ButtonStyle {
    let fill: Color
    var small = false

    func makeBody(configuration: Configuration) -> some View {
        let r: CGFloat = small ? 14 : 20
        let depth: CGFloat = configuration.isPressed ? 1 : (small ? 3 : 5)
        configuration.label
            .font(.system(size: small ? 13 : 19, weight: .black, design: .rounded))
            .foregroundStyle(AppTheme.gameInk)
            .padding(.horizontal, small ? 12 : 0)
            .frame(maxWidth: small ? nil : .infinity)
            .frame(height: small ? 36 : 58)
            .background(GameSlab(radius: r, depth: depth, fill: fill))
            .overlay(RoundedRectangle(cornerRadius: r).stroke(AppTheme.gameInk, lineWidth: small ? 2.5 : 3))
            .offset(y: configuration.isPressed ? 4 : 0)
            .padding(.bottom, 5)
    }
}
