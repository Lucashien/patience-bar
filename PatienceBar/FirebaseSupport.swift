import Foundation
#if canImport(FirebaseCore)
import FirebaseCore
#endif

enum FirebaseSupport {
    nonisolated(unsafe) private static var didConfigure = false

    /// 有放 GoogleService-Info.plist 才會啟用雙機同步。
    static var isConfigured: Bool {
        #if canImport(FirebaseCore)
        Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil
        #else
        false
        #endif
    }

    static func configureIfPossible() {
        #if canImport(FirebaseCore)
        if isConfigured, !didConfigure {
            FirebaseApp.configure()
            didConfigure = true
        }
        #endif
    }
}
