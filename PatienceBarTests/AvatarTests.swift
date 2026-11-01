import XCTest
import UIKit
@testable import PatienceBar

final class AvatarImageTests: XCTestCase {
    /// 左半紅、右半藍的圖，用來驗證裁切範圍有沒有選對。
    private func splitImage(width: CGFloat = 400, height: CGFloat = 200) -> UIImage {
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: fmt).image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: width / 2, height: height))
            UIColor.blue.setFill()
            ctx.fill(CGRect(x: width / 2, y: 0, width: width / 2, height: height))
        }
    }

    /// 取圖片正中央像素的 RGB。
    private func centerPixel(_ data: Data) -> (r: Int, g: Int, b: Int)? {
        guard let cg = UIImage(data: data)?.cgImage else { return nil }
        var px = [UInt8](repeating: 0, count: 4)
        guard let ctx = CGContext(data: &px, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let w = CGFloat(cg.width), h = CGFloat(cg.height)
        ctx.draw(cg, in: CGRect(x: -w / 2, y: -h / 2, width: w, height: h))
        return (Int(px[0]), Int(px[1]), Int(px[2]))
    }

    func testPrepareRejectsGarbage() {
        XCTAssertNil(AvatarImage.prepare(Data([0x00, 0x01, 0x02])))
        XCTAssertNil(AvatarImage.prepare(Data()))
    }

    func testPrepareDownscalesLargeImages() throws {
        let big = splitImage(width: 4000, height: 3000)
        let prepared = try XCTUnwrap(AvatarImage.prepare(try XCTUnwrap(big.pngData())))
        XCTAssertEqual(max(prepared.size.width, prepared.size.height), 1600, accuracy: 1)
        XCTAssertEqual(prepared.size.width / prepared.size.height, 4.0 / 3.0, accuracy: 0.01)
    }

    func testPrepareKeepsSmallImagesAtOriginalSize() throws {
        let small = splitImage(width: 400, height: 200)
        let prepared = try XCTUnwrap(AvatarImage.prepare(try XCTUnwrap(small.pngData())))
        XCTAssertEqual(prepared.size, CGSize(width: 400, height: 200))
    }

    func testRenderProducesFixedSizeSmallJPEG() throws {
        let data = try XCTUnwrap(AvatarImage.render(splitImage(), crop: CGRect(x: 0, y: 0, width: 200, height: 200)))
        let out = try XCTUnwrap(UIImage(data: data))
        XCTAssertEqual(out.size.width * out.scale, AvatarImage.side)
        XCTAssertEqual(out.size.height * out.scale, AvatarImage.side)
        XCTAssertLessThan(data.count, 30_000, "要夠小才放得進 Firestore 文件與 App Group 快取")
    }

    func testRenderPicksTheChosenRegion() throws {
        let img = splitImage()
        let left = try XCTUnwrap(centerPixel(try XCTUnwrap(AvatarImage.render(img, crop: CGRect(x: 0, y: 0, width: 200, height: 200)))))
        XCTAssertGreaterThan(left.r, 200)
        XCTAssertLessThan(left.b, 60)

        let right = try XCTUnwrap(centerPixel(try XCTUnwrap(AvatarImage.render(img, crop: CGRect(x: 200, y: 0, width: 200, height: 200)))))
        XCTAssertGreaterThan(right.b, 200)
        XCTAssertLessThan(right.r, 60)
    }

    func testRenderZoomedCropStaysInsideOneColor() throws {
        // 放大到只剩右下角 50×50，整張都該是藍色。
        let data = try XCTUnwrap(AvatarImage.render(splitImage(), crop: CGRect(x: 300, y: 100, width: 50, height: 50)))
        let c = try XCTUnwrap(centerPixel(data))
        XCTAssertGreaterThan(c.b, 200)
    }

    func testRenderRejectsEmptyCrop() {
        XCTAssertNil(AvatarImage.render(splitImage(), crop: CGRect(x: 0, y: 0, width: 0, height: 0)))
    }

    func testDecodeCacheReturnsSameInstanceForSameBytes() throws {
        let data = try XCTUnwrap(AvatarImage.render(splitImage(), crop: CGRect(x: 0, y: 0, width: 200, height: 200)))
        let a = try XCTUnwrap(AvatarImage.image(from: data))
        let b = try XCTUnwrap(AvatarImage.image(from: Data(data)))
        XCTAssertTrue(a === b)
        XCTAssertNil(AvatarImage.image(from: Data([1, 2, 3])))
    }
}

@MainActor
final class AvatarStorageTests: XCTestCase {
    private let jpegA = Data([0xFF, 0xD8, 0xAA])
    private let jpegB = Data([0xFF, 0xD8, 0xBB])

    override func setUp() {
        LocalBackend.wipe()
        SharedCache.clear()
    }

    override func tearDown() {
        LocalBackend.wipe()
        SharedCache.clear()
    }

    private func latest(_ b: LocalBackend) -> () -> CoupleSnapshot? {
        var snap: CoupleSnapshot?
        b.observe { snap = $0 }
        return { snap }
    }

    func testSnapshotAccessors() {
        let s = CoupleSnapshot(meId: "me", partnerId: "her", names: [:], states: [:], events: [],
                               inviteCode: nil, isLocal: true, avatars: ["me": jpegA, "her": jpegB])
        XCTAssertEqual(s.meAvatar, jpegA)
        XCTAssertEqual(s.partnerAvatar, jpegB)

        let alone = CoupleSnapshot(meId: "me", partnerId: nil, names: [:], states: [:], events: [],
                                   inviteCode: "X", isLocal: false, avatars: ["me": jpegA])
        XCTAssertEqual(alone.meAvatar, jpegA)
        XCTAssertNil(alone.partnerAvatar)
    }

    func testLocalBackendSetsAndRemovesOwnAvatar() async throws {
        let b = LocalBackend(myName: "阿明")
        let snap = latest(b)
        XCTAssertNil(snap()?.meAvatar)

        try await b.setAvatar(jpegA)
        XCTAssertEqual(snap()?.meAvatar, jpegA)
        XCTAssertNil(snap()?.partnerAvatar)

        try await b.setAvatar(nil)
        XCTAssertNil(snap()?.meAvatar)
    }

    func testLocalBackendKeepsAvatarsPerPerson() async throws {
        let b = LocalBackend(myName: "阿明")
        let snap = latest(b)
        try await b.setAvatar(jpegA)

        b.switchViewer()
        XCTAssertNil(snap()?.meAvatar, "換視角後，「我」是另一個人，不該看到原本那張")
        XCTAssertEqual(snap()?.partnerAvatar, jpegA)

        try await b.setAvatar(jpegB)
        XCTAssertEqual(snap()?.meAvatar, jpegB)
        XCTAssertEqual(snap()?.partnerAvatar, jpegA)
    }

    func testLocalBackendPersistsAvatarAcrossLaunches() async throws {
        try await LocalBackend(myName: "阿明").setAvatar(jpegA)
        let reopened = LocalBackend(myName: nil)
        let snap = latest(reopened)
        XCTAssertEqual(snap()?.meAvatar, jpegA)
    }

    func testSharedCacheCarriesAvatarsToWidget() {
        let s = CoupleSnapshot(meId: "me", partnerId: "her", names: ["me": "我", "her": "她"],
                               states: ["me": PatienceEngine.fresh(now: Date()),
                                        "her": PatienceEngine.fresh(now: Date())],
                               events: [], inviteCode: nil, isLocal: true,
                               avatars: ["me": jpegA, "her": jpegB])
        SharedCache.save(from: s)
        let loaded = SharedCache.load()
        XCTAssertEqual(loaded?.avatars?["me"], jpegA)
        XCTAssertEqual(loaded?.avatars?["her"], jpegB)
    }

    func testSharedCacheKeepsAvatarsWhenWidgetEnqueuesAction() {
        let s = CoupleSnapshot(meId: "me", partnerId: "her", names: [:],
                               states: ["me": PatienceEngine.fresh(now: Date()),
                                        "her": PatienceEngine.fresh(now: Date())],
                               events: [], inviteCode: nil, isLocal: true, avatars: ["me": jpegA])
        SharedCache.save(from: s)
        SharedCache.enqueue(.adjust(-10))
        XCTAssertEqual(SharedCache.load()?.avatars?["me"], jpegA)
        XCTAssertEqual(SharedCache.load()?.pending.count, 1)
    }

    func testOldCacheWithoutAvatarsStillDecodes() throws {
        let old = SharedSnapshot(meId: "me", partnerId: nil, names: [:], states: [:], pending: [], avatars: nil)
        let raw = try JSONEncoder().encode(old)
        XCTAssertFalse(String(decoding: raw, as: UTF8.self).contains("avatars"))
        let decoded = try JSONDecoder().decode(SharedSnapshot.self, from: raw)
        XCTAssertNil(decoded.avatars)
    }
}
