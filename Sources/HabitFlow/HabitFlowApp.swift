import SwiftUI
import AppKit
import CoreText

@main
public struct HabitFlowApp: App {
    @AppStorage("interfaceLanguage") private var interfaceLanguage = "en"
    @StateObject private var store = HabitStore()
    @StateObject private var timerManager = ActiveHabitTimerManager()
    @StateObject private var assistantHistory = AssistantChatStore()

    public init() {
        for name in ["Inter", "CormorantGaramond", "CormorantGaramond-Italic"] {
            if let url = Bundle.module.url(forResource: name, withExtension: "ttf") {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
        // Ensure bare SwiftPM executable shows in the Dock and brings its window to front
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    public var body: some Scene {
        WindowGroup("HabitFlow") {
            MainWindowView()
                .environment(\.locale, L10n.locale)
                .environmentObject(store)
                .environmentObject(timerManager)
                .environmentObject(assistantHistory)
                .frame(minWidth: 820, minHeight: 680)
                .onChange(of: interfaceLanguage) { _, _ in
                    HabitNotificationScheduler.shared.syncNotifications(for: store.habits, globallyEnabled: store.settings.notificationsEnabled)
                }
                .onAppear {
                    DispatchQueue.main.async {
                        for window in NSApplication.shared.windows {
                            window.titlebarAppearsTransparent = true
                            window.titleVisibility = .hidden
                            window.styleMask.insert(.fullSizeContentView)
                            window.toolbar = nil
                            if let widthArgument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--preview-width=") }),
                               let width = Double(widthArgument.replacingOccurrences(of: "--preview-width=", with: "")) {
                                window.setContentSize(NSSize(width: width, height: 800))
                                window.center()
                            }
                        }
                    }
                    store.verifyCurrentDayAndTimezone()
                    if store.settings.notificationsEnabled {
                        HabitNotificationScheduler.shared.requestAuthorizationIfNeeded { _ in
                            HabitNotificationScheduler.shared.syncNotifications(
                                for: store.habits,
                                globallyEnabled: store.settings.notificationsEnabled
                            )
                        }
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandMenu(L10n.tr("Habits")) {
                Button(L10n.tr("Quick Add First Unfinished Habit")) {
                    let todayOv = store.dailyProgressOverview(for: store.currentDateKey)
                    if let firstUnfinished = todayOv.scheduledStatuses.first(where: { !$0.isCompleted }) {
                        store.quickAdd(for: firstUnfinished.habit.id, on: store.currentDateKey)
                    }
                }
                .keyboardShortcut("=", modifiers: [.command])

                Divider()

                Button(L10n.tr("Switch to Dark Mode")) {
                    store.settings.appearanceMode = .dark
                }
                Button(L10n.tr("Switch to Light Mode")) {
                    store.settings.appearanceMode = .light
                }
                Button(L10n.tr("Use System Appearance")) {
                    store.settings.appearanceMode = .system
                }
            }
        }
    }
}
