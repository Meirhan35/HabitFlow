# HabitFlow — Native macOS Habit Management & Progress Tracking Application

HabitFlow is a native macOS desktop application built with **Swift**, **SwiftUI**, **Swift Charts**, **UserNotifications**, and offline local persistence.

## Architecture & Project Structure

```text
HabitFlow_macOS/
├── Package.swift
├── Sources/
│   └── HabitFlow/
│       ├── HabitFlowApp.swift                   # @main App entry point, WindowGroup, macOS menu commands
│       ├── Models/
│       │   └── Models.swift                     # 6 Measurement Types, Habit, TargetHistoryEntry, ProgressEntry, DailyNote, AppSettings
│       ├── Services/
│       │   └── HabitStore.swift                 # Calculation engine, Conditional Missed Days visibility, Weekly Goals, Smart Recovery, Timer, Notifications, Persistence
│       └── Views/
│           ├── MainWindowView.swift             # NavigationSplitView sidebar, Dark/Light/System palette, SmoothProgressBar
│           ├── DashboardView.swift              # Strict 5-part visual hierarchy + conditional Missed Days unlock
│           ├── HabitEditorAndMyHabitsView.swift # Dynamic 6-measurement-type modal & My Habits manager
│           ├── TodaysGoalsAndMissedView.swift   # Today's Goals, Weekly Goals, Missed & Unfinished + Smart Recovery
│           ├── CalendarAndStatisticsView.swift  # Monthly Calendar, 365-day GitHub Heatmap, Daily Notes, Swift Charts Statistics
│           └── SettingsView.swift               # Dark/Light/System theme, Accent color, Week start day, JSON Backup/Restore
└── Tests/
    └── HabitFlowTests/
        └── HabitFlowTests.swift                 # Unit test suite verifying all QA requirements
```

## Opening and Running on macOS

1. **In Xcode (macOS 14 Sonoma or later)**:
   - Open `Package.swift` directly in Xcode (`open Package.swift`), select the **HabitFlow** scheme and **My Mac** destination, and press **⌘R** to build and run.
   - Press **⌘U** to run the unit test suite (`HabitFlowTests`).
2. **Single-File Compilation**:
   - You can also inspect or compile the consolidated `HabitFlow.swift` file directly using `swiftc`.
