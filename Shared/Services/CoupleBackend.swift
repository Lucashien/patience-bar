import Foundation

@MainActor
protocol CoupleBackend: AnyObject {
    var viewerId: String { get }
    /// 開始監聽；立即與之後每次變動都會呼叫 handler。
    func observe(_ handler: @escaping @MainActor (CoupleSnapshot) -> Void)
    func stop()
    func perform(_ action: PatienceAction) async throws
}

enum BackendError: LocalizedError {
    case notPaired, badCode, coupleFull

    var errorDescription: String? {
        switch self {
        case .notPaired: "對方還沒加入"
        case .badCode: "邀請碼無效，或這組配對已經滿員"
        case .coupleFull: "這組邀請碼已經配對完成"
        }
    }
}
