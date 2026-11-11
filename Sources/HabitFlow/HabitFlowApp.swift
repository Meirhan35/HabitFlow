import SwiftUI
import AppKit

@main
public struct HabitFlowApp: App {
    @StateObject private var store = HabitStore()
    @StateObject private var timerManager = ActiveHabitTimerManager()
    @StateObject private var assistantHistory = AssistantChatStore()

    public init() {
        // Ensure bare SwiftPM executable shows in the Dock and brings its window to front
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    public var body: some Scene {
        WindowGroup("HabitFlow") {
            MainWindowView()
                .environmentObject(store)
                .environmentObject(timerManager)
                .environmentObject(assistantHistory)
                .frame(minWidth: 980, minHeight: 680)
                .onAppear {
                    DispatchQueue.main.async {
                        for window in NSApplication.shared.windows {
                            window.titlebarAppearsTransparent = true
                            window.titleVisibility = .hidden
                            window.styleMask.insert(.fullSizeContentView)
                            window.toolbar = nil
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
            CommandMenu("Habits") {
                Button("Quick Add First Unfinished Habit") {
                    let todayOv = store.dailyProgressOverview(for: store.currentDateKey)
                    if let firstUnfinished = todayOv.scheduledStatuses.first(where: { !$0.isCompleted }) {
                        store.quickAdd(for: firstUnfinished.habit.id, on: store.currentDateKey)
                    }
                }
                .keyboardShortcut("=", modifiers: [.command])

                Divider()

                Button("Switch to Dark Mode") {
                    store.settings.appearanceMode = .dark
                }
                Button("Switch to Light Mode") {
                    store.settings.appearanceMode = .light
                }
                Button("Use System Appearance") {
                    store.settings.appearanceMode = .system
                }
            }
        }
    }
}
