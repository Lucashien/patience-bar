import SwiftUI

extension Weather {
    var tint: Color {
        switch self {
        case .sunny: Color(red: 0.98, green: 0.74, blue: 0.20)
        case .cloudy: Color(red: 0.55, green: 0.66, blue: 0.80)
        case .aboutToRain: Color(red: 0.36, green: 0.50, blue: 0.78)
        case .thunderstorm: Color(red: 0.55, green: 0.38, blue: 0.80)
        }
    }

    /// 文字顏色固定，不跟系統深淺色走：雷雨背景較暗用白字，其餘用深色字。
    var ink: Color {
        self == .thunderstorm ? .white : Color(red: 0.13, green: 0.12, blue: 0.20)
    }

    var cardFill: Color {
        self == .thunderstorm ? .black.opacity(0.28) : .white.opacity(0.62)
    }

    var gradient: [Color] {
        switch self {
        case .sunny: [Color(red: 1.0, green: 0.92, blue: 0.70), Color(red: 1.0, green: 0.78, blue: 0.55)]
        case .cloudy: [Color(red: 0.86, green: 0.90, blue: 0.95), Color(red: 0.72, green: 0.80, blue: 0.90)]
        case .aboutToRain: [Color(red: 0.70, green: 0.76, blue: 0.88), Color(red: 0.50, green: 0.58, blue: 0.78)]
        case .thunderstorm: [Color(red: 0.45, green: 0.42, blue: 0.68), Color(red: 0.24, green: 0.22, blue: 0.42)]
        }
    }
}

struct PatienceBarView: View {
    let value: Double
    var height: CGFloat = 14
    var fill: Color? = nil
    var track: Color = .black.opacity(0.12)

    var body: some View {
        let weather = PatienceEngine.weather(for: value)
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule()
                    
                    .fill(fill ?? weather.tint)
                    .frame(width: max(height, geo.size.width * value / PatienceEngine.maxValue))
            }
        }
        .frame(height: height)
    }
}

/// 實心膠囊按鈕：底色用 ink，字用背景色，任何深淺色模式都看得清楚。
struct PillButtonStyle: ButtonStyle {
    let weather: Weather
    var prominent = true
    var outlined = false

    func makeBody(configuration: Configuration) -> some View {
        let fill = prominent ? weather.ink : weather.ink.opacity(0.14)
        let text = (prominent && !outlined) ? (weather == .thunderstorm ? Color(red: 0.2, green: 0.18, blue: 0.4) : .white) : weather.ink
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(text)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(outlined ? Color.clear : fill, in: Capsule())
            .overlay(Capsule().stroke(weather.ink, lineWidth: outlined ? 2 : 0))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
