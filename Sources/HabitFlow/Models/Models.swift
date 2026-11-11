import Foundation
import SwiftUI

// MARK: - 1. Six Habit Measurement Types

public enum MeasurementType: String, Codable, CaseIterable, Identifiable {
    case duration = "Duration"
    case distance = "Distance"
    case checkbox = "Checkbox"
    case counter = "Counter"
    case quantity = "Quantity"
    case customUnit = "Custom Unit"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .duration: return "timer"
        case .distance: return "figure.run"
        case .checkbox: return "checkmark.square.fill"
        case .counter: return "number.square.fill"
        case .quantity: return "drop.fill"
        case .customUnit: return "slider.horizontal.3"
        }
    }

    public var description: String {
        switch self {
        case .duration: return "Track time spent on an activity (minutes or hours) with manual entry or built-in timer."
        case .distance: return "Track physical distance (kilometers or meters) with decimal precision."
        case .checkbox: return "Simple completed or not completed daily tracking."
        case .counter: return "Track repetitions or occurrences (push-ups, words, exercises)."
        case .quantity: return "Track a specific amount with custom quantity units (glasses, pages, servings)."
        case .customUnit: return "Define your own custom unit name and numerical target."
        }
    }

    public var defaultUnits: [String] {
        switch self {
        case .duration: return ["minutes", "hours"]
        case .distance: return ["km", "meters"]
        case .checkbox: return ["completion"]
        case .counter: return ["reps", "times", "items"]
        case .quantity: return ["glasses", "pages", "servings", "cups"]
        case .customUnit: return ["sessions", "pages", "words", "assignments"]
        }
    }

    public var isNumerical: Bool {
        self != .checkbox
    }
}

// MARK: - 2. Categories & Frequency

public enum DefaultCategory: String, Codable, CaseIterable, Identifiable {
    case education = "Education"
    case fitness = "Fitness"
    case health = "Health"
    case religion = "Religion"
    case personalDevelopment = "Personal Development"
    case productivity = "Productivity"
    case other = "Other"

    public var id: String { rawValue }

    public var sfSymbol: String {
        switch self {
        case .education: return "book.closed.fill"
        case .fitness: return "figure.walk"
        case .health: return "heart.fill"
        case .religion: return "sparkles"
        case .personalDevelopment: return "brain.head.profile"
        case .productivity: return "bolt.fill"
        case .other: return "square.grid.2x2.fill"
        }
    }
}

public enum HabitFrequency: String, Codable, CaseIterable, Identifiable {
    case daily = "Every Day"
    case weekdays = "Weekdays (Mon–Fri)"
    case weekends = "Weekends (Sat–Sun)"
    case customDays = "Selected Weekdays"

    public var id: String { rawValue }
}

/// ISO-style weekday representation (1 = Sunday ... 7 = Saturday to match Calendar.Component.weekday)
public enum Weekday: Int, Codable, CaseIterable, Identifiable, Comparable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    public var id: Int { rawValue }

    public var shortName: String {
        switch self {
        case .sunday: return "Sun"
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        }
    }

    public var singleLetter: String {
        switch self {
        case .sunday: return "S"
        case .monday: return "M"
        case .tuesday: return "T"
        case .wednesday: return "W"
        case .thursday: return "T"
        case .friday: return "F"
        case .saturday: return "S"
        }
    }

    public static func < (lhs: Weekday, rhs: Weekday) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public static func ordered(startingOn weekStart: WeekStartDay) -> [Weekday] {
        switch weekStart {
        case .monday:
            return [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
        case .sunday:
            return [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
        }
    }
}

// MARK: - 3. Flexible Target History (Effective-Dated Targets)

public struct TargetHistoryEntry: Codable, Identifiable, Equatable, Hashable {
    public var id: UUID
    /// Format "YYYY-MM-DD" representing the date from which this target is effective (inclusive).
    public var effectiveDateKey: String
    public var dailyTarget: Double
    public var weeklyTarget: Double?
    public var quickAddIncrement: Double
    public var frequency: HabitFrequency
    public var scheduledWeekdays: Set<Weekday>

    public init(
        id: UUID = UUID(),
        effectiveDateKey: String,
        dailyTarget: Double,
        weeklyTarget: Double? = nil,
        quickAddIncrement: Double,
        frequency: HabitFrequency,
        scheduledWeekdays: Set<Weekday>
    ) {
        self.id = id
        self.effectiveDateKey = effectiveDateKey
        self.dailyTarget = dailyTarget
        self.weeklyTarget = weeklyTarget
        self.quickAddIncrement = quickAddIncrement
        self.frequency = frequency
        self.scheduledWeekdays = scheduledWeekdays
    }
}

// MARK: - 4. Progress Entry (Multiple Entries per Day)

public struct ProgressEntry: Codable, Identifiable, Equatable, Hashable {
    public var id: UUID
    public var habitId: UUID
    /// Normalized local date key "YYYY-MM-DD"
    public var dateKey: String
    public var timestamp: Date
    public var amount: Double
    public var label: String // e.g., "Morning", "Afternoon", "Evening", "Quick Add", "Timer Session"
    public var note: String?

    public init(
        id: UUID = UUID(),
        habitId: UUID,
        dateKey: String,
        timestamp: Date = Date(),
        amount: Double,
        label: String = "Quick Add",
        note: String? = nil
    ) {
        self.id = id
        self.habitId = habitId
        self.dateKey = dateKey
        self.timestamp = timestamp
        self.amount = amount
        self.label = label
        self.note = note
    }
}

// MARK: - 5. Habit Model

public struct Habit: Codable, Identifiable, Equatable, Hashable {
    public var id: UUID
    public var name: String
    public var habitDescription: String
    public var icon: String // SF Symbol or Emoji
    public var category: String
    public var measurementType: MeasurementType
    public var unit: String
    public var dailyTarget: Double
    public var weeklyTarget: Double?
    public var quickAddIncrement: Double
    public var frequency: HabitFrequency
    public var scheduledWeekdays: Set<Weekday>
    public var reminderEnabled: Bool
    public var reminderHour: Int
    public var reminderMinute: Int
    public var estimatedDurationMinutes: Int?
    public var isPaused: Bool
    public var isArchived: Bool
    public var createdAtDateKey: String
    public var targetHistory: [TargetHistoryEntry]

    public init(
        id: UUID = UUID(),
        name: String,
        habitDescription: String = "",
        icon: String = "star.fill",
        category: String = DefaultCategory.personalDevelopment.rawValue,
        measurementType: MeasurementType,
        unit: String,
        dailyTarget: Double,
        weeklyTarget: Double? = nil,
        quickAddIncrement: Double = 1.0,
        frequency: HabitFrequency = .daily,
        scheduledWeekdays: Set<Weekday> = Set(Weekday.allCases),
        reminderEnabled: Bool = false,
        reminderHour: Int = 20,
        reminderMinute: Int = 0,
        estimatedDurationMinutes: Int? = nil,
        isPaused: Bool = false,
        isArchived: Bool = false,
        createdAtDateKey: String = DateKeyHelper.todayKey(),
        targetHistory: [TargetHistoryEntry] = []
    ) {
        self.id = id
        self.name = name
        self.habitDescription = habitDescription
        self.icon = icon
        self.category = category
        self.measurementType = measurementType
        self.unit = unit
        let resolvedTarget = measurementType == .checkbox ? 1.0 : max(0.1, dailyTarget)
        self.dailyTarget = resolvedTarget
        self.weeklyTarget = weeklyTarget
        self.quickAddIncrement = measurementType == .checkbox ? 1.0 : max(0.01, quickAddIncrement)
        self.frequency = frequency
        let resolvedDays: Set<Weekday> = {
            switch frequency {
            case .daily: return Set(Weekday.allCases)
            case .weekdays: return [.monday, .tuesday, .wednesday, .thursday, .friday]
            case .weekends: return [.saturday, .sunday]
            case .customDays: return scheduledWeekdays.isEmpty ? Set(Weekday.allCases) : scheduledWeekdays
            }
        }()
        self.scheduledWeekdays = resolvedDays
        self.reminderEnabled = reminderEnabled
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
        self.estimatedDurationMinutes = estimatedDurationMinutes
        self.isPaused = isPaused
        self.isArchived = isArchived
        self.createdAtDateKey = createdAtDateKey

        if targetHistory.isEmpty {
            self.targetHistory = [
                TargetHistoryEntry(
                    effectiveDateKey: createdAtDateKey,
                    dailyTarget: resolvedTarget,
                    weeklyTarget: weeklyTarget,
                    quickAddIncrement: self.quickAddIncrement,
                    frequency: frequency,
                    scheduledWeekdays: resolvedDays
                )
            ]
        } else {
            self.targetHistory = targetHistory
        }
    }

    /// Returns the effective target snapshot for any historical or current date key ("YYYY-MM-DD").
    public func effectiveSnapshot(for dateKey: String) -> TargetHistoryEntry {
        let sorted = targetHistory.sorted { $0.effectiveDateKey < $1.effectiveDateKey }
        if let match = sorted.last(where: { $0.effectiveDateKey <= dateKey }) {
            return match
        }
        if let first = sorted.first {
            return first
        }
        return TargetHistoryEntry(
            effectiveDateKey: createdAtDateKey,
            dailyTarget: dailyTarget,
            weeklyTarget: weeklyTarget,
            quickAddIncrement: quickAddIncrement,
            frequency: frequency,
            scheduledWeekdays: scheduledWeekdays
        )
    }

    /// Checks whether this habit was scheduled on the given dateKey.
    public func isScheduled(on dateKey: String, calendar: Calendar = .current) -> Bool {
        if isArchived { return false }
        if dateKey < createdAtDateKey { return false }
        guard let date = DateKeyHelper.date(from: dateKey, calendar: calendar) else { return false }
        let weekdayInt = calendar.component(.weekday, from: date)
        guard let weekday = Weekday(rawValue: weekdayInt) else { return false }
        let snapshot = effectiveSnapshot(for: dateKey)
        switch snapshot.frequency {
        case .daily:
            return true
        case .weekdays:
            return [.monday, .tuesday, .wednesday, .thursday, .friday].contains(weekday)
        case .weekends:
            return [.saturday, .sunday].contains(weekday)
        case .customDays:
            return snapshot.scheduledWeekdays.contains(weekday)
        }
    }

    public var reminderTimeFormatted: String {
        String(format: "%02d:%02d", reminderHour, reminderMinute)
    }
}

// MARK: - 6. Daily Note Model

public struct DailyNote: Codable, Identifiable, Equatable, Hashable {
    public var id: UUID
    public var dateKey: String
    public var wentWell: String
    public var wasDifficult: String
    public var improveTomorrow: String
    public var freeformNote: String
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        dateKey: String,
        wentWell: String = "",
        wasDifficult: String = "",
        improveTomorrow: String = "",
        freeformNote: String = "",
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.dateKey = dateKey
        self.wentWell = wentWell
        self.wasDifficult = wasDifficult
        self.improveTomorrow = improveTomorrow
        self.freeformNote = freeformNote
        self.updatedAt = updatedAt
    }

    public var isEmpty: Bool {
        wentWell.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        wasDifficult.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        improveTomorrow.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        freeformNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - 7. Appearance & App Settings

public enum AppAppearanceMode: String, Codable, CaseIterable, Identifiable {
    case dark = "Dark Mode"
    case light = "Light Mode"
    case system = "System Appearance"

    public var id: String { rawValue }

    public var colorScheme: ColorScheme? {
        switch self {
        case .dark: return .dark
        case .light: return .light
        case .system: return nil
        }
    }
}

public enum AccentThemeColor: String, Codable, CaseIterable, Identifiable {
    case orange = "Orange"
    case indigo = "Indigo"
    case emerald = "Emerald"
    case sky = "Sky Blue"
    case amber = "Amber"
    case rose = "Rose"
    case violet = "Violet"
    case teal = "Teal"

    public var id: String { rawValue }

    public static var allCases: [AccentThemeColor] { [.orange] }

    public var color: Color {
        Color(red: 252.0 / 255, green: 115.0 / 255, blue: 77.0 / 255)
    }
}

public enum WeekStartDay: String, Codable, CaseIterable, Identifiable {
    case monday = "Monday"
    case sunday = "Sunday"

    public var id: String { rawValue }

    public var calendarFirstWeekday: Int {
        switch self {
        case .sunday: return 1
        case .monday: return 2
        }
    }
}

public struct AppSettings: Codable, Equatable {
    public var appearanceMode: AppAppearanceMode
    public var accentColor: AccentThemeColor
    public var weekStartDay: WeekStartDay
    public var defaultFrequency: HabitFrequency
    public var notificationsEnabled: Bool
    public var showDecreaseButtonsOnDashboard: Bool
    public var showMotivationalGreeting: Bool
    public var customCategories: [String]
    public var dismissedRecoveryHabitIdsForDate: [String: [UUID]]

    public init(
        appearanceMode: AppAppearanceMode = .system,
        accentColor: AccentThemeColor = .orange,
        weekStartDay: WeekStartDay = .monday,
        defaultFrequency: HabitFrequency = .daily,
        notificationsEnabled: Bool = true,
        showDecreaseButtonsOnDashboard: Bool = true,
        showMotivationalGreeting: Bool = true,
        customCategories: [String] = [],
        dismissedRecoveryHabitIdsForDate: [String: [UUID]] = [:]
    ) {
        self.appearanceMode = appearanceMode
        self.accentColor = accentColor
        self.weekStartDay = weekStartDay
        self.defaultFrequency = defaultFrequency
        self.notificationsEnabled = notificationsEnabled
        self.showDecreaseButtonsOnDashboard = showDecreaseButtonsOnDashboard
        self.showMotivationalGreeting = showMotivationalGreeting
        self.customCategories = customCategories
        self.dismissedRecoveryHabitIdsForDate = dismissedRecoveryHabitIdsForDate
    }

    public var allCategories: [String] {
        let defaults = DefaultCategory.allCases.map(\.rawValue)
        let extras = customCategories.filter { !defaults.contains($0) }
        return defaults + extras
    }
}

// MARK: - 8. Full Backup Payload

public struct HabitFlowBackupDocument: Codable {
    public var schemaVersion: Int
    public var exportedAt: Date
    public var settings: AppSettings
    public var habits: [Habit]
    public var progressEntries: [ProgressEntry]
    public var dailyNotes: [DailyNote]
    public var goals: [SavedGoal]?

    public init(
        schemaVersion: Int = 1,
        exportedAt: Date = Date(),
        settings: AppSettings,
        habits: [Habit],
        progressEntries: [ProgressEntry],
        dailyNotes: [DailyNote],
        goals: [SavedGoal]? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.settings = settings
        self.habits = habits
        self.progressEntries = progressEntries
        self.dailyNotes = dailyNotes
        self.goals = goals
    }
}

// MARK: - 9. Date & Number Formatting Utilities

public enum DateKeyHelper {
    private static let formatter: DateFormatter = {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()

    public static func dateKey(from date: Date, calendar: Calendar = .current) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        guard let y = comps.year, let m = comps.month, let d = comps.day else {
            return formatter.string(from: date)
        }
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    public static func todayKey(calendar: Calendar = .current) -> String {
        dateKey(from: Date(), calendar: calendar)
    }

    public static func date(from dateKey: String, calendar: Calendar = .current) -> Date? {
        let parts = dateKey.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var comps = DateComponents()
        comps.year = parts[0]
        comps.month = parts[1]
        comps.day = parts[2]
        comps.hour = 12 // Noon avoids DST boundary edge cases
        return calendar.date(from: comps)
    }

    public static func addingDays(_ days: Int, to dateKey: String, calendar: Calendar = .current) -> String {
        guard let baseDate = date(from: dateKey, calendar: calendar),
              let shifted = calendar.date(byAdding: .day, value: days, to: baseDate) else {
            return dateKey
        }
        return self.dateKey(from: shifted, calendar: calendar)
    }

    public static func friendlyDateTitle(for dateKey: String, relativeTo todayKey: String, calendar: Calendar = .current) -> String {
        guard let targetDate = date(from: dateKey, calendar: calendar) else { return dateKey }
        let df = DateFormatter()
        df.locale = L10n.locale
        df.setLocalizedDateFormatFromTemplate("MMMM d")
        let monthDay = df.string(from: targetDate)

        if dateKey == todayKey {
            return "Today — \(monthDay)"
        } else if dateKey == addingDays(-1, to: todayKey, calendar: calendar) {
            return "Yesterday — \(monthDay)"
        } else {
            let fullDf = DateFormatter()
        fullDf.locale = L10n.locale
            fullDf.setLocalizedDateFormatFromTemplate("EEEE MMMM d")
            return fullDf.string(from: targetDate)
        }
    }

    public static func weekDateKeys(containing dateKey: String, weekStart: WeekStartDay, calendar: Calendar = .current) -> [String] {
        guard let refDate = date(from: dateKey, calendar: calendar) else { return [dateKey] }
        let weekday = calendar.component(.weekday, from: refDate) // 1 = Sun ... 7 = Sat
        let firstWeekday = weekStart.calendarFirstWeekday
        let diff = (weekday - firstWeekday + 7) % 7
        guard let startOfWeek = calendar.date(byAdding: .day, value: -diff, to: refDate) else { return [dateKey] }
        return (0..<7).compactMap { offset in
            guard let d = calendar.date(byAdding: .day, value: offset, to: startOfWeek) else { return nil }
            return self.dateKey(from: d, calendar: calendar)
        }
    }

    public static func daysBetween(startKey: String, endKey: String, calendar: Calendar = .current) -> [String] {
        guard startKey <= endKey else { return [] }
        var result: [String] = []
        var cursor = startKey
        while cursor <= endKey {
            result.append(cursor)
            let next = addingDays(1, to: cursor, calendar: calendar)
            if next == cursor { break }
            cursor = next
        }
        return result
    }
}

public enum NumberFormattingHelper {
    public static func format(_ value: Double) -> String {
        let rounded = (value * 100).rounded() / 100
        if abs(rounded.truncatingRemainder(dividingBy: 1)) < 0.001 {
            return String(Int(rounded))
        } else if abs((rounded * 10).truncatingRemainder(dividingBy: 1)) < 0.001 {
            return String(format: "%.1f", rounded)
        } else {
            return String(format: "%.2f", rounded)
        }
    }

    public static func formatWithUnit(_ value: Double, unit: String, measurementType: MeasurementType) -> String {
        if measurementType == .checkbox {
            return value >= 1.0 ? "Completed" : "Not completed"
        }
        let numStr = format(value)
        if unit.isEmpty { return numStr }
        return "\(numStr) \(unit)"
    }
}
