import AppIntents

struct PatienceShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: IAmAnnoyedIntent(),
                    phrases: ["在\(.applicationName)說我好煩", "\(.applicationName)我好煩"],
                    shortTitle: "我好煩", systemImageName: "cloud.drizzle.fill")
        AppShortcut(intent: IAmOkIntent(),
                    phrases: ["在\(.applicationName)說我好了", "\(.applicationName)我好了"],
                    shortTitle: "我好了", systemImageName: "sun.max.fill")
    }
}
