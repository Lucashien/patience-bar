import AppIntents


struct AdjustIntent: AppIntent {
    static var title: LocalizedStringResource = "耐心 −10"
    static var openAppWhenRun = false
    func perform() async throws -> some IntentResult {
        await PendingActions.submit(.adjust(-10))
        return .result()
    }
}

struct IAmAnnoyedIntent: AppIntent {
    static var title: LocalizedStringResource = "我好煩"
    static var openAppWhenRun = false
    func perform() async throws -> some IntentResult {
        await PendingActions.submit(.adjust(-15))
        return .result()
    }
}

struct IAmOkIntent: AppIntent {
    static var title: LocalizedStringResource = "我好了"
    static var openAppWhenRun = false
    func perform() async throws -> some IntentResult {
        await PendingActions.submit(.recover)
        return .result()
    }
}
