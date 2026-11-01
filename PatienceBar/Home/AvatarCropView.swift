import SwiftUI
import UIKit

struct CropTarget: Identifiable {
    let id = UUID()
    let image: UIImage
}

/// 自己選大頭貼要用的範圍：拖曳移動、兩指縮放，圓圈內就是最後的樣子。
struct AvatarCropView: View {
    let image: UIImage
    let onDone: (Data) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var zoom: CGFloat = 1
    @State private var pinch: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var drag: CGSize = .zero

    private let maxZoom: CGFloat = 5

    private func baseScale(_ v: CGFloat) -> CGFloat { v / min(image.size.width, image.size.height) }

    private func clamp(_ o: CGSize, v: CGFloat, zoom z: CGFloat) -> CGSize {
        let s = baseScale(v) * z
        let mx = max(0, (image.size.width * s - v) / 2)
        let my = max(0, (image.size.height * s - v) / 2)
        return CGSize(width: min(max(o.width, -mx), mx), height: min(max(o.height, -my), my))
    }

    private func liveZoom() -> CGFloat { min(max(zoom * pinch, 1), maxZoom) }

    private func liveOffset(v: CGFloat) -> CGSize {
        clamp(CGSize(width: offset.width + drag.width, height: offset.height + drag.height),
              v: v, zoom: liveZoom())
    }

    var body: some View {
        GeometryReader { geo in
            let v = min(geo.size.width - 48, 340)
            let s = baseScale(v) * liveZoom()
            let o = liveOffset(v: v)

            VStack(spacing: 20) {
                Text("調整大頭貼").font(.headline)
                    .padding(.top, 24)
                Spacer(minLength: 0)

                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .frame(width: image.size.width * s, height: image.size.height * s)
                        .offset(o)
                }
                .frame(width: v, height: v)
                .clipped()
                .overlay {
                    Rectangle().fill(.black.opacity(0.6))
                        .mask {
                            Rectangle().overlay { Circle().blendMode(.destinationOut) }
                                .compositingGroup()
                        }
                        .allowsHitTesting(false)
                }
                .overlay { Circle().stroke(.white.opacity(0.9), lineWidth: 2).allowsHitTesting(false) }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { drag = $0.translation }
                        .onEnded { g in
                            offset = clamp(CGSize(width: offset.width + g.translation.width,
                                                  height: offset.height + g.translation.height),
                                           v: v, zoom: zoom)
                            drag = .zero
                        }
                        .simultaneously(with:
                            MagnifyGesture()
                                .onChanged { pinch = $0.magnification }
                                .onEnded { g in
                                    zoom = min(max(zoom * g.magnification, 1), maxZoom)
                                    pinch = 1
                                    offset = clamp(offset, v: v, zoom: zoom)
                                })
                )

                Text("拖曳移動，兩指縮放").font(.footnote).opacity(0.7)
                Spacer(minLength: 0)

                HStack(spacing: 12) {
                    Button { dismiss() } label: {
                        Text("取消").frame(maxWidth: .infinity).frame(height: 48)
                            .overlay(Capsule().stroke(.white.opacity(0.8), lineWidth: 1.5))
                    }
                    Button {
                        let cropSize = v / s
                        let crop = CGRect(x: (image.size.width * s / 2 - v / 2 - o.width) / s,
                                          y: (image.size.height * s / 2 - v / 2 - o.height) / s,
                                          width: cropSize, height: cropSize)
                        if let jpeg = AvatarImage.render(image, crop: crop) { onDone(jpeg) }
                        dismiss()
                    } label: {
                        Text("完成").fontWeight(.bold).foregroundStyle(.black)
                            .frame(maxWidth: .infinity).frame(height: 48)
                            .background(Capsule().fill(.white))
                    }
                }
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
        }
        .foregroundStyle(.white)
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}
