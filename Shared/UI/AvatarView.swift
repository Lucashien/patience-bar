import SwiftUI
import UIKit
import WidgetKit

/// 大頭貼的處理：使用者選好範圍後縮成小圖、壓成 JPEG（約 5–10 KB），
/// 這樣可以直接存在 Firestore 的使用者文件與 App Group 快取，不需要 Storage。
enum AvatarImage {
    static let side: CGFloat = 192

    /// 解碼、修正方向、縮到最長邊 1600，給裁切畫面用（避免大圖吃記憶體）。
    static func prepare(_ data: Data) -> UIImage? {
        guard let img = UIImage(data: data), img.size.width > 0, img.size.height > 0 else { return nil }
        let k = min(1, 1600 / max(img.size.width, img.size.height))
        let size = CGSize(width: (img.size.width * k).rounded(), height: (img.size.height * k).rounded())
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1
        fmt.opaque = true
        return UIGraphicsImageRenderer(size: size, format: fmt).image { _ in
            img.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    /// 把 `crop`（以圖片像素為單位的正方形）畫成 side×side 的 JPEG。
    static func render(_ img: UIImage, crop: CGRect) -> Data? {
        guard crop.width > 0 else { return nil }
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1
        fmt.opaque = true
        let k = side / crop.width
        let out = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: fmt).image { _ in
            img.draw(in: CGRect(x: -crop.minX * k, y: -crop.minY * k,
                                width: img.size.width * k, height: img.size.height * k))
        }
        return out.jpegData(compressionQuality: 0.75)
    }

    private static let cache = NSCache<NSData, UIImage>()

    static func image(from data: Data) -> UIImage? {
        let key = data as NSData
        if let hit = cache.object(forKey: key) { return hit }
        guard let img = UIImage(data: data) else { return nil }
        cache.setObject(img, forKey: key)
        return img
    }
}

/// 圓形大頭貼；沒有照片時顯示名字的第一個字。文字顏色吃外層的 foregroundStyle。
struct AvatarView: View {
    let data: Data?
    let name: String
    var size: CGFloat = 40
    var ring: Color = .clear
    var lineWidth: CGFloat = 0

    var body: some View {
        Group {
            if let data, let img = AvatarImage.image(from: data) {
                Image(uiImage: img)
                    .resizable()
                    .widgetAccentedRenderingMode(.fullColor)
                    .scaledToFill()
            } else {
                ZStack {
                    Circle().fill(Color.white.opacity(0.65))
                    Text(String(name.prefix(1)))
                        .font(.system(size: size * 0.45, weight: .black, design: .rounded))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(ring, lineWidth: lineWidth))
    }
}
