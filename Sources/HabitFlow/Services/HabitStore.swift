import Foundation
import SwiftUI
import Combine
import UserNotifications

// MARK: - 1. Computed Daily Status & Summaries

public enum HabitCompletionState: String, Codable, Equatable {
    case notStarted = "Not completed"
    case partial = "Partially completed"
    case completed = "Completed"
}

public struct DailyHabitStatus: Identifiable, Equatable {
    public var id: UUID { habit.id }
    public let habit: Habit
    public let dateKey: String
    public let target: Double
    public let quickAddIncrement: Double
    public let completedAmount: Double
    public let remainingAmount: Double
    public let progressFraction: Double
    public let state: HabitCompletionState
    public let entries: [ProgressEntry]
    public let estimatedRemainingMinutes: Int

    public var isCompleted: Bool {
        state == .completed
    }

    public var progressText: String {
        if habit.measurementType == .checkbox {
            return isCompleted ? "Completed" : "Not completed"
        }
        let currentStr = NumberFormattingHelper.format(completedAmount)
        let targetStr = NumberFormattingHelper.format(target)
        if habit.unit.isEmpty {
            return "\(currentStr) / \(targetStr)"
        }
        return "\(currentStr) / \(targetStr) \(habit.unit)"
    }

    public var remainingSummaryText: String {
        if isCompleted { return "Completed" }
        if habit.measurementType == .checkbox {
            return "\(habit.name) — Not completed"
        }
        let remStr = NumberFormattingHelper.format(remainingAmount)
        if habit.unit.isEmpty {
            return "\(remStr) of \(habit.name.lowercased())"
        }
        return "\(remStr) \(habit.unit) of \(habit.name.lowercased())"
    }
}

public struct DailyProgressOverview: Equatable {
    public let dateKey: String
    public let scheduledStatuses: [DailyHabitStatus]
    public let completedCount: Int
    public let partialCount: Int
    public let incompleteCount: Int
    public let totalScheduledCount: Int
    public let completionPercentage: Double
    public let allScheduledCompleted: Bool
    public let totalEstimatedRemainingMinutes: Int

    public var progressFraction: Double {
        completionPercentage / 100.0
    }
}

public struct MissedDayRecord: Identifiable, Equatable {
    public var id: String { dateKey }
    public let dateKey: String
    public let friendlyTitle: String
    public let missedOrPartialStatuses: [DailyHabitStatus]
    public let allScheduledStatuses: [DailyHabitStatus]
    public let completionPercentage: Double

    public var fullyMissedCount: Int {
        missedOrPartialStatuses.filter { $0.state == .notStarted }.count
    }

    public var partialCount: Int {
        missedOrPartialStatuses.filter { $0.state == .partial }.count
    }
}

public struct WeeklyHabitProgress: Identifiable, Equatable {
    public var id: UUID { habit.id }
    public let habit: Habit
    public let weekDateKeys: [String]
    public let weeklyTarget: Double
    public let currentProgress: Double
    public let remainingAmount: Double
    public let completionPercentage: Double
    public let isCompleted: Bool
    public let unitLabel: String
}

public struct SmartRecoverySuggestion: Identifiable, Equatable {
    public var id: UUID { habit.id }
    public let habit: Habit
    public let consecutiveMissedDays: Int
    public let suggestedReducedTarget: Double
    public var message: String {
        "You missed your \(habit.name.lowercased()) habit for \(consecutiveMissedDays) days. Would you like to continue with your normal target or adjust it?"
    }
}

public enum AnalyticsTimeRange: String, CaseIterable, Identifiable {
    case days7 = "7 Days"
    case days30 = "30 Days"
    case days90 = "90 Days"
    case days365 = "365 Days"
    case allTime = "All Time"

    public var id: String { rawValue }

    public var dayCount: Int? {
        switch self {
        case .days7: return 7
        case .days30: return 30
        case .days90: return 90
        case .days365: return 365
        case .allTime: return nil
        }
    }
}

public struct DailyCompletionPoint: Identifiable, Equatable {
    public var id: String { dateKey }
    public let dateKey: String
    public let date: Date
    public let percentage: Double
    public let completedCount: Int
    public let scheduledCount: Int
}

public struct HabitConsistencyMetric: Identifiable, Equatable {
    public var id: UUID { habit.id }
    public let habit: Habit
    public let scheduledDays: Int
    public let completedDays: Int
    public let partialDays: Int
    public let missedDays: Int
    public let completionRate: Double
    public let currentStreak: Int
    public let longestStreak: Int
    public let totalAccumulatedAmount: Double
}

public struct GlobalStatisticsSummary: Equatable {
    public let dailyCompletionRate: Double
    public let weeklyCompletionRate: Double
    public let monthlyCompletionRate: Double
    public let rangeCompletionRate: Double
    public let totalCompletedHabitInstances: Int
    public let totalTrackedMinutes: Double
    public let totalDistanceKilometers: Double
    public let totalRepetitions: Double
    public let currentOverallStreak: Int
    public let longestOverallStreak: Int
    public let mostConsistentHabits: [HabitConsistencyMetric]
    public let habitsNeedingAttention: [HabitConsistencyMetric]
    public let dailyTrendPoints: [DailyCompletionPoint]
}

// MARK: - 2. Active Duration Timer Service

@MainActor
public final class ActiveHabitTimerManager: ObservableObject {
    @Published public private(set) var activeHabitId: UUID?
    @Published public private(set) var elapsedSeconds: Int = 0
    @Published public private(set) var isRunning: Bool = false

    private var timerCancellable: AnyCancellable?
    private var lastTickDate: Date?

    public init() {}

    public func startOrResume(for habitId: UUID) {
        if activeHabitId != habitId {
            activeHabitId = habitId
            elapsedSeconds = 0
        }
        isRunning = true
        lastTickDate = Date()
        timerCancellable?.cancel()
        timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, self.isRunning else { return }
                self.elapsedSeconds += 1
            }
    }

    public func pause() {
        isRunning = false
        timerCancellable?.cancel()
    }

    public func stopAndCommit(into store: HabitStore) {
        guard let habitId = activeHabitId, elapsedSeconds > 0 else {
            reset()
            return
        }
        guard let habit = store.habits.first(where: { $0.id == habitId }) else {
            reset()
            return
        }
        let amountInHabitUnit: Double
        if habit.unit.lowercased().contains("hour") {
            amountInHabitUnit = max(0.05, (Double(elapsedSeconds) / 3600.0 * 100).rounded() / 100)
        } else {
            amountInHabitUnit = max(1.0, (Double(elapsedSeconds) / 60.0 * 10).rounded() / 10)
        }
        store.addProgressEntry(
            for: habitId,
            dateKey: store.currentDateKey,
            amount: amountInHabitUnit,
            label: "Timer Session (\(formattedElapsed))",
            note: "Logged via built-in duration timer"
        )
        reset()
    }

    public func reset() {
        isRunning = false
        timerCancellable?.cancel()
        activeHabitId = nil
        elapsedSeconds = 0
    }

    public var formattedElapsed: String {
        let mins = elapsedSeconds / 60
        let secs = elapsedSeconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

// MARK: - 3. Local Notification Scheduler (macOS UserNotifications)

public final class HabitNotificationScheduler {
    public static let shared = HabitNotificationScheduler()

    private init() {}

    /// UNUserNotificationCenter.current() throws an NSInternalInconsistencyException on macOS
    /// if the process is launched as a bare SwiftPM executable rather than a signed .app bundle.
    private var isRunningInsideAppBundle: Bool {
        guard let bundleId = Bundle.main.bundleIdentifier, !bundleId.isEmpty else {
            return false
        }
        return Bundle.main.bundleURL.pathExtension == "app"
    }

    public func requestAuthorizationIfNeeded(completion: ((Bool) -> Void)? = nil) {
        guard isRunningInsideAppBundle else {
            DispatchQueue.main.async {
                completion?(false)
            }
            return
        }
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                completion?(granted)
            }
        }
    }

    public func syncNotifications(for habits: [Habit], globallyEnabled: Bool) {
        guard isRunningInsideAppBundle else { return }
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        guard globallyEnabled else { return }

        for habit in habits where !habit.isPaused && !habit.isArchived && habit.reminderEnabled {
            for weekday in habit.scheduledWeekdays {
                var dateComponents = DateComponents()
                dateComponents.weekday = weekday.rawValue
                dateComponents.hour = habit.reminderHour
                dateComponents.minute = habit.reminderMinute

                let content = UNMutableNotificationContent()
                content.title = "HabitFlow Reminder: \(habit.name)"
                if habit.measurementType == .checkbox {
                    content.body = "Time to complete your daily goal: \(habit.name)."
                } else {
                    content.body = "Daily target: \(NumberFormattingHelper.format(habit.dailyTarget)) \(habit.unit). Stay consistent!"
                }
                content.sound = .default

                let identifier = "habitflow.reminder.\(habit.id.uuidString).weekday.\(weekday.rawValue)"
                let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                center.add(request, withCompletionHandler: nil)
            }
        }
    }
}

// MARK: - 4. HabitStore (Persistence + Calculation Engine + Automatic Rollover)

@MainActor
public final class HabitStore: ObservableObject {
    @Published public var settings: AppSettings {
        didSet { saveStateImmediately() }
    }
    @Published public var habits: [Habit] {
        didSet { saveStateImmediately() }
    }
    @Published public var progressEntries: [ProgressEntry] {
        didSet { saveStateImmediately() }
    }
    @Published public var dailyNotes: [DailyNote] {
        didSet { saveStateImmediately() }
    }

    /// Current active local date key ("YYYY-MM-DD"). Automatically updates on midnight or system clock/timezone change.
    @Published public var currentDateKey: String
    @Published public var selectedCalendarDateKey: String
    @Published public var lastFeedbackBanner: String?

    private let storageURL: URL
    private var calendar: Calendar
    private var dayCheckCancellable: AnyCancellable?
    private var isSuppressingSave = false

    public init(storageFileURL: URL? = nil, calendar: Calendar = .current, seedSampleDataIfEmpty: Bool = true) {
        self.calendar = calendar
        let resolvedToday = DateKeyHelper.todayKey(calendar: calendar)
        self.currentDateKey = resolvedToday
        self.selectedCalendarDateKey = resolvedToday

        if let customURL = storageFileURL {
            self.storageURL = customURL
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory())
            let folder = appSupport.appendingPathComponent("HabitFlow", isDirectory: true)
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            self.storageURL = folder.appendingPathComponent("habitflow_store_v1.json")
        }

        self.settings = AppSettings()
        self.habits = []
        self.progressEntries = []
        self.dailyNotes = []

        if !loadStateFromDisk() && seedSampleDataIfEmpty {
            seedDefaultShowcaseData(referenceTodayKey: resolvedToday)
            saveStateImmediately()
        }

        setupAutomaticDayRolloverMonitor()
    }

    // MARK: - Automatic Daily Tracking & Rollover

    private func setupAutomaticDayRolloverMonitor() {
        dayCheckCancellable = Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.verifyCurrentDayAndTimezone()
            }

        NotificationCenter.default.addObserver(
            forName: .NSCalendarDayChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.verifyCurrentDayAndTimezone()
            }
        }

        NotificationCenter.default.addObserver(
            forName: .NSSystemTimeZoneDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.calendar = Calendar.current
                self?.verifyCurrentDayAndTimezone()
            }
        }
    }

    public func verifyCurrentDayAndTimezone() {
        let latestToday = DateKeyHelper.todayKey(calendar: calendar)
        if latestToday != currentDateKey {
            let wasViewingToday = (selectedCalendarDateKey == currentDateKey)
            currentDateKey = latestToday
            if wasViewingToday {
                selectedCalendarDateKey = latestToday
            }
        }
    }

    // MARK: - Local Persistence & Backup / Restore

    public func saveStateImmediately() {
        guard !isSuppressingSave else { return }
        let payload = HabitFlowBackupDocument(
            schemaVersion: 1,
            exportedAt: Date(),
            settings: settings,
            habits: habits,
            progressEntries: progressEntries,
            dailyNotes: dailyNotes
        )
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(payload)
            try data.write(to: storageURL, options: [.atomic])
        } catch {
            print("HabitFlow persistence save error: \(error)")
        }
    }

    @discardableResult
    public func loadStateFromDisk() -> Bool {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return false }
        do {
            let data = try Data(contentsOf: storageURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let doc = try decoder.decode(HabitFlowBackupDocument.self, from: data)
            isSuppressingSave = true
            self.settings = doc.settings
            self.habits = doc.habits
            self.progressEntries = doc.progressEntries
            self.dailyNotes = doc.dailyNotes
            isSuppressingSave = false
            return true
        } catch {
            isSuppressingSave = false
            print("HabitFlow persistence load error: \(error)")
            return false
        }
    }

    public func exportBackupJSONData() throws -> Data {
        let payload = HabitFlowBackupDocument(
            schemaVersion: 1,
            exportedAt: Date(),
            settings: settings,
            habits: habits,
            progressEntries: progressEntries,
            dailyNotes: dailyNotes
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(payload)
    }

    public func importBackupJSONData(_ data: Data) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let doc = try decoder.decode(HabitFlowBackupDocument.self, from: data)
        isSuppressingSave = true
        self.settings = doc.settings
        self.habits = doc.habits
        self.progressEntries = doc.progressEntries
        self.dailyNotes = doc.dailyNotes
        isSuppressingSave = false
        saveStateImmediately()
        HabitNotificationScheduler.shared.syncNotifications(for: habits, globallyEnabled: settings.notificationsEnabled)
    }

    // MARK: - Habit CRUD & Target History Preservation

    public func addHabit(_ habit: Habit) {
        habits.append(habit)
        if !settings.allCategories.contains(habit.category) {
            settings.customCategories.append(habit.category)
        }
        HabitNotificationScheduler.shared.syncNotifications(for: habits, globallyEnabled: settings.notificationsEnabled)
    }

    public func updateHabit(_ updated: Habit, effectiveDateKey: String? = nil) {
        guard let idx = habits.firstIndex(where: { $0.id == updated.id }) else { return }
        var copy = updated
        let effKey = effectiveDateKey ?? currentDateKey

        // Record effective-dated target change so historical completion percentages never get overwritten
        let snapshot = TargetHistoryEntry(
            effectiveDateKey: effKey,
            dailyTarget: copy.measurementType == .checkbox ? 1.0 : copy.dailyTarget,
            weeklyTarget: copy.weeklyTarget,
            quickAddIncrement: copy.measurementType == .checkbox ? 1.0 : copy.quickAddIncrement,
            frequency: copy.frequency,
            scheduledWeekdays: copy.scheduledWeekdays
        )
        if let existingIdx = copy.targetHistory.firstIndex(where: { $0.effectiveDateKey == effKey }) {
            copy.targetHistory[existingIdx] = snapshot
        } else {
            copy.targetHistory.append(snapshot)
            copy.targetHistory.sort { $0.effectiveDateKey < $1.effectiveDateKey }
        }

        habits[idx] = copy
        if !settings.allCategories.contains(copy.category) {
            settings.customCategories.append(copy.category)
        }
        HabitNotificationScheduler.shared.syncNotifications(for: habits, globallyEnabled: settings.notificationsEnabled)
    }

    public func togglePauseHabit(_ habitId: UUID) {
        guard let idx = habits.firstIndex(where: { $0.id == habitId }) else { return }
        habits[idx].isPaused.toggle()
        HabitNotificationScheduler.shared.syncNotifications(for: habits, globallyEnabled: settings.notificationsEnabled)
    }

    /// Archives a habit to hide it from active lists while preserving 100% of historical records, or permanently deletes if confirmed.
    public func deleteHabit(_ habitId: UUID, deleteHistoricalRecords: Bool = false) {
        if deleteHistoricalRecords {
            habits.removeAll { $0.id == habitId }
            progressEntries.removeAll { $0.habitId == habitId }
        } else {
            guard let idx = habits.firstIndex(where: { $0.id == habitId }) else { return }
            habits[idx].isArchived = true
            habits[idx].isPaused = true
        }
        HabitNotificationScheduler.shared.syncNotifications(for: habits, globallyEnabled: settings.notificationsEnabled)
    }

    // MARK: - Instant Quick-Add, Decrease, & Multi-Entry Management

    public func quickAdd(for habitId: UUID, on dateKey: String? = nil) {
        let targetDateKey = dateKey ?? currentDateKey
        guard let habit = habits.first(where: { $0.id == habitId }) else { return }
        let snapshot = habit.effectiveSnapshot(for: targetDateKey)

        if habit.measurementType == .checkbox {
            let current = totalCompleted(for: habitId, on: targetDateKey)
            if current >= 1.0 {
                // Toggle off for checkbox
                progressEntries.removeAll { $0.habitId == habitId && $0.dateKey == targetDateKey }
            } else {
                let entry = ProgressEntry(
                    habitId: habitId,
                    dateKey: targetDateKey,
                    timestamp: Date(),
                    amount: 1.0,
                    label: timeOfDayLabel()
                )
                progressEntries.append(entry)
            }
        } else {
            let increment = snapshot.quickAddIncrement
            let entry = ProgressEntry(
                habitId: habitId,
                dateKey: targetDateKey,
                timestamp: Date(),
                amount: increment,
                label: timeOfDayLabel()
            )
            progressEntries.append(entry)
        }
    }

    public func quickDecrease(for habitId: UUID, on dateKey: String? = nil) {
        let targetDateKey = dateKey ?? currentDateKey
        guard let habit = habits.first(where: { $0.id == habitId }) else { return }
        let snapshot = habit.effectiveSnapshot(for: targetDateKey)
        let currentTotal = totalCompleted(for: habitId, on: targetDateKey)
        guard currentTotal > 0 else { return }

        if habit.measurementType == .checkbox {
            progressEntries.removeAll { $0.habitId == habitId && $0.dateKey == targetDateKey }
            return
        }

        let decrement = min(currentTotal, snapshot.quickAddIncrement)
        var remainingToSubtract = decrement

        // Subtract from the most recent entries on that day without ever allowing negative progress
        let dayEntryIndices = progressEntries.indices
            .filter { progressEntries[$0].habitId == habitId && progressEntries[$0].dateKey == targetDateKey }
            .sorted { progressEntries[$0].timestamp > progressEntries[$1].timestamp }

        var indicesToRemove: [Int] = []
        for idx in dayEntryIndices {
            guard remainingToSubtract > 0.0001 else { break }
            let entryAmount = progressEntries[idx].amount
            if entryAmount <= remainingToSubtract + 0.0001 {
                remainingToSubtract -= entryAmount
                indicesToRemove.append(idx)
            } else {
                progressEntries[idx].amount = max(0, ((entryAmount - remainingToSubtract) * 100).rounded() / 100)
                remainingToSubtract = 0
            }
        }

        for idx in indicesToRemove.sorted(by: >) {
            progressEntries.remove(at: idx)
        }
    }

    public func addProgressEntry(
        for habitId: UUID,
        dateKey: String,
        amount: Double,
        label: String,
        note: String? = nil
    ) {
        guard amount > 0 else { return }
        let entry = ProgressEntry(
            habitId: habitId,
            dateKey: dateKey,
            timestamp: Date(),
            amount: amount,
            label: label.isEmpty ? timeOfDayLabel() : label,
            note: note
        )
        progressEntries.append(entry)
    }

    public func updateProgressEntry(_ updated: ProgressEntry) {
        guard let idx = progressEntries.firstIndex(where: { $0.id == updated.id }) else { return }
        if updated.amount <= 0 {
            progressEntries.remove(at: idx)
        } else {
            progressEntries[idx] = updated
        }
    }

    public func deleteProgressEntry(_ entryId: UUID) {
        progressEntries.removeAll { $0.id == entryId }
    }

    public func totalCompleted(for habitId: UUID, on dateKey: String) -> Double {
        let sum = progressEntries
            .filter { $0.habitId == habitId && $0.dateKey == dateKey }
            .reduce(0.0) { $0 + $1.amount }
        return max(0.0, (sum * 100).rounded() / 100)
    }

    public func entries(for habitId: UUID, on dateKey: String) -> [ProgressEntry] {
        progressEntries
            .filter { $0.habitId == habitId && $0.dateKey == dateKey }
            .sorted { $0.timestamp < $1.timestamp }
    }

    // MARK: - Daily Status & Progress Overview Calculation

    public func status(for habit: Habit, on dateKey: String) -> DailyHabitStatus {
        let snapshot = habit.effectiveSnapshot(for: dateKey)
        let target = habit.measurementType == .checkbox ? 1.0 : max(0.01, snapshot.dailyTarget)
        let dayEntries = entries(for: habit.id, on: dateKey)
        let completed = dayEntries.reduce(0.0) { $0 + $1.amount }
        let roundedCompleted = max(0.0, (completed * 100).rounded() / 100)
        let remaining = max(target - roundedCompleted, 0.0)
        let fraction = min(max(roundedCompleted / target, 0.0), 1.0)

        let state: HabitCompletionState
        if roundedCompleted + 0.0001 >= target {
            state = .completed
        } else if roundedCompleted > 0.0001 {
            state = .partial
        } else {
            state = .notStarted
        }

        let estimatedRemainingMinutes: Int = {
            guard state != .completed else { return 0 }
            if habit.measurementType == .duration {
                if habit.unit.lowercased().contains("hour") {
                    return Int((remaining * 60.0).rounded())
                }
                return Int(remaining.rounded())
            }
            if let est = habit.estimatedDurationMinutes {
                return Int((Double(est) * (1.0 - fraction)).rounded())
            }
            return 0
        }()

        return DailyHabitStatus(
            habit: habit,
            dateKey: dateKey,
            target: target,
            quickAddIncrement: snapshot.quickAddIncrement,
            completedAmount: roundedCompleted,
            remainingAmount: (remaining * 100).rounded() / 100,
            progressFraction: fraction,
            state: state,
            entries: dayEntries,
            estimatedRemainingMinutes: estimatedRemainingMinutes
        )
    }

    public func dailyProgressOverview(for dateKey: String) -> DailyProgressOverview {
        let isEvaluatingToday = (dateKey == currentDateKey)
        let scheduledHabits = habits.filter { habit in
            guard !habit.isArchived else { return false }
            if isEvaluatingToday && habit.isPaused { return false }
            if habit.isPaused && dateKey >= currentDateKey { return false }
            return habit.isScheduled(on: dateKey, calendar: calendar)
        }

        let statuses = scheduledHabits.map { status(for: $0, on: dateKey) }
        let completedCount = statuses.filter { $0.state == .completed }.count
        let partialCount = statuses.filter { $0.state == .partial }.count
        let incompleteCount = statuses.filter { $0.state == .notStarted }.count
        let totalCount = statuses.count

        let percentage: Double = {
            guard totalCount > 0 else { return 0.0 }
            let sumFractions = statuses.reduce(0.0) { $0 + $1.progressFraction }
            return ((sumFractions / Double(totalCount)) * 100.0).rounded()
        }()

        // Rule: Missed Days unlocks ONLY when EVERY scheduled active habit for today has reached 100% of its target.
        // Partially completed habits block visibility. Empty schedule does not unlock unless at least 1 scheduled habit is completed.
        let allCompleted = totalCount > 0 && completedCount == totalCount && partialCount == 0 && incompleteCount == 0
        let totalRemainingMinutes = statuses.reduce(0) { $0 + $1.estimatedRemainingMinutes }

        return DailyProgressOverview(
            dateKey: dateKey,
            scheduledStatuses: statuses,
            completedCount: completedCount,
            partialCount: partialCount,
            incompleteCount: incompleteCount,
            totalScheduledCount: totalCount,
            completionPercentage: percentage,
            allScheduledCompleted: allCompleted,
            totalEstimatedRemainingMinutes: totalRemainingMinutes
        )
    }

    /// Strict Conditional Visibility Rule (Section 5):
    /// True ONLY AFTER ALL of today's scheduled active habits have reached 100% of their target.
    /// Immediately becomes false if any habit is unchecked or reduced below target.
    public var isMissedDaysUnlockedOnDashboard: Bool {
        let todayOverview = dailyProgressOverview(for: currentDateKey)
        return todayOverview.allScheduledCompleted
    }

    // MARK: - Missed Days & Historical Unfinished Records (Section 5 & Section 12)

    public func allMissedDaysHistory(lookbackDays: Int = 90) -> [MissedDayRecord] {
        let earliestHabitCreation = habits.map(\.createdAtDateKey).min() ?? currentDateKey
        let lookbackStart = DateKeyHelper.addingDays(-lookbackDays, to: currentDateKey, calendar: calendar)
        let startKey = max(earliestHabitCreation, lookbackStart)
        let yesterdayKey = DateKeyHelper.addingDays(-1, to: currentDateKey, calendar: calendar)
        guard startKey <= yesterdayKey else { return [] }

        let candidateDates = DateKeyHelper.daysBetween(startKey: startKey, endKey: yesterdayKey, calendar: calendar).reversed()
        var records: [MissedDayRecord] = []

        for dateKey in candidateDates {
            let scheduledHabits = habits.filter { habit in
                !habit.isArchived && !habit.isPaused && habit.isScheduled(on: dateKey, calendar: calendar)
            }
            guard !scheduledHabits.isEmpty else { continue }

            let statuses = scheduledHabits.map { status(for: $0, on: dateKey) }
            let unfinished = statuses.filter { $0.state != .completed }
            guard !unfinished.isEmpty else { continue }

            let sumFractions = statuses.reduce(0.0) { $0 + $1.progressFraction }
            let pct = ((sumFractions / Double(statuses.count)) * 100.0).rounded()

            records.append(
                MissedDayRecord(
                    dateKey: dateKey,
                    friendlyTitle: DateKeyHelper.friendlyDateTitle(for: dateKey, relativeTo: currentDateKey, calendar: calendar),
                    missedOrPartialStatuses: unfinished,
                    allScheduledStatuses: statuses,
                    completionPercentage: pct
                )
            )
        }
        return records
    }

    /// Returns only the latest 3 missed days for the Dashboard Missed Days section.
    public var dashboardLatestThreeMissedDays: [MissedDayRecord] {
        Array(allMissedDaysHistory(lookbackDays: 60).prefix(3))
    }

    // MARK: - Smart Recovery Suggestions (Section 12)

    public func smartRecoverySuggestions() -> [SmartRecoverySuggestion] {
        let dismissedToday = Set(settings.dismissedRecoveryHabitIdsForDate[currentDateKey] ?? [])
        var suggestions: [SmartRecoverySuggestion] = []

        for habit in habits where !habit.isArchived && !habit.isPaused {
            guard !dismissedToday.contains(habit.id) else { continue }
            var consecutiveMissed = 0
            var cursor = DateKeyHelper.addingDays(-1, to: currentDateKey, calendar: calendar)
            var checkedScheduledDays = 0

            while cursor >= habit.createdAtDateKey && checkedScheduledDays < 14 {
                if habit.isScheduled(on: cursor, calendar: calendar) {
                    checkedScheduledDays += 1
                    let st = status(for: habit, on: cursor)
                    if st.state != .completed {
                        consecutiveMissed += 1
                    } else {
                        break
                    }
                }
                cursor = DateKeyHelper.addingDays(-1, to: cursor, calendar: calendar)
            }

            if consecutiveMissed >= 3 {
                let reduced = habit.measurementType == .checkbox
                    ? 1.0
                    : max(habit.quickAddIncrement, ((habit.dailyTarget * 0.7) * 10).rounded() / 10)
                suggestions.append(
                    SmartRecoverySuggestion(
                        habit: habit,
                        consecutiveMissedDays: consecutiveMissed,
                        suggestedReducedTarget: reduced
                    )
                )
            }
        }
        return suggestions
    }

    public func dismissRecoverySuggestion(for habitId: UUID) {
        var list = settings.dismissedRecoveryHabitIdsForDate[currentDateKey] ?? []
        if !list.contains(habitId) {
            list.append(habitId)
            settings.dismissedRecoveryHabitIdsForDate[currentDateKey] = list
        }
    }

    public func applyTemporaryTargetReduction(for suggestion: SmartRecoverySuggestion) {
        var updated = suggestion.habit
        if updated.measurementType != .checkbox {
            updated.dailyTarget = suggestion.suggestedReducedTarget
        } else {
            updated.frequency = .weekdays
            updated.scheduledWeekdays = [.monday, .wednesday, .friday]
        }
        updateHabit(updated, effectiveDateKey: currentDateKey)
        dismissRecoverySuggestion(for: suggestion.habit.id)
    }

    // MARK: - Weekly Goals Engine (Section 11)

    public func weeklyHabitProgressList(for referenceDateKey: String? = nil) -> [WeeklyHabitProgress] {
        let refKey = referenceDateKey ?? currentDateKey
        let weekKeys = DateKeyHelper.weekDateKeys(containing: refKey, weekStart: settings.weekStartDay, calendar: calendar)

        return habits.filter { !$0.isArchived && !$0.isPaused }.map { habit in
            let snapshot = habit.effectiveSnapshot(for: refKey)
            let scheduledDaysInWeek = weekKeys.filter { habit.isScheduled(on: $0, calendar: calendar) }.count
            let resolvedWeeklyTarget: Double = {
                if let explicitWeekly = snapshot.weeklyTarget, explicitWeekly > 0 {
                    return explicitWeekly
                }
                return snapshot.dailyTarget * Double(max(1, scheduledDaysInWeek))
            }()

            // Sum unique daily entries across the week (never double-counting)
            let weekCompleted = weekKeys.reduce(0.0) { acc, dayKey in
                if habit.measurementType == .checkbox {
                    return acc + (totalCompleted(for: habit.id, on: dayKey) >= 1.0 ? 1.0 : 0.0)
                } else {
                    return acc + totalCompleted(for: habit.id, on: dayKey)
                }
            }

            let roundedCurrent = (weekCompleted * 100).rounded() / 100
            let remaining = max(resolvedWeeklyTarget - roundedCurrent, 0.0)
            let pct = resolvedWeeklyTarget > 0
                ? min(100.0, ((roundedCurrent / resolvedWeeklyTarget) * 100.0).rounded())
                : 0.0
            let unitLabel = habit.measurementType == .checkbox ? "sessions" : habit.unit

            return WeeklyHabitProgress(
                habit: habit,
                weekDateKeys: weekKeys,
                weeklyTarget: resolvedWeeklyTarget,
                currentProgress: roundedCurrent,
                remainingAmount: (remaining * 100).rounded() / 100,
                completionPercentage: pct,
                isCompleted: roundedCurrent + 0.0001 >= resolvedWeeklyTarget,
                unitLabel: unitLabel
            )
        }
    }

    // MARK: - Daily Notes Management (Section 16)

    public func dailyNote(for dateKey: String) -> DailyNote {
        if let existing = dailyNotes.first(where: { $0.dateKey == dateKey }) {
            return existing
        }
        return DailyNote(dateKey: dateKey)
    }

    public func saveDailyNote(_ note: DailyNote) {
        var updated = note
        updated.updatedAt = Date()
        if let idx = dailyNotes.firstIndex(where: { $0.dateKey == note.dateKey }) {
            if updated.isEmpty {
                dailyNotes.remove(at: idx)
            } else {
                dailyNotes[idx] = updated
            }
        } else if !updated.isEmpty {
            dailyNotes.append(updated)
        }
    }

    // MARK: - Calendar & 365-Day GitHub Heatmap (Section 14)

    public func heatmapDaysLast365() -> [DailyCompletionPoint] {
        let startKey = DateKeyHelper.addingDays(-364, to: currentDateKey, calendar: calendar)
        let keys = DateKeyHelper.daysBetween(startKey: startKey, endKey: currentDateKey, calendar: calendar)
        return keys.compactMap { key in
            guard let d = DateKeyHelper.date(from: key, calendar: calendar) else { return nil }
            let ov = dailyProgressOverview(for: key)
            return DailyCompletionPoint(
                dateKey: key,
                date: d,
                percentage: ov.completionPercentage,
                completedCount: ov.completedCount,
                scheduledCount: ov.totalScheduledCount
            )
        }
    }

    // MARK: - Statistics & Analytics Engine (Section 15)

    public func calculateStatistics(for range: AnalyticsTimeRange) -> GlobalStatisticsSummary {
        let earliestKey = habits.map(\.createdAtDateKey).min() ?? DateKeyHelper.addingDays(-30, to: currentDateKey, calendar: calendar)
        let startKey: String = {
            if let days = range.dayCount {
                let candidate = DateKeyHelper.addingDays(-(days - 1), to: currentDateKey, calendar: calendar)
                return max(earliestKey, candidate)
            }
            return earliestKey
        }()

        let dateKeys = DateKeyHelper.daysBetween(startKey: startKey, endKey: currentDateKey, calendar: calendar)
        var trendPoints: [DailyCompletionPoint] = []
        var totalCompletedInstances = 0

        for key in dateKeys {
            guard let d = DateKeyHelper.date(from: key, calendar: calendar) else { continue }
            let ov = dailyProgressOverview(for: key)
            totalCompletedInstances += ov.completedCount
            trendPoints.append(
                DailyCompletionPoint(
                    dateKey: key,
                    date: d,
                    percentage: ov.completionPercentage,
                    completedCount: ov.completedCount,
                    scheduledCount: ov.totalScheduledCount
                )
            )
        }

        let scheduledTrendPoints = trendPoints.filter { $0.scheduledCount > 0 }
        let rangeRate: Double = {
            guard !scheduledTrendPoints.isEmpty else { return 0 }
            let sum = scheduledTrendPoints.reduce(0.0) { $0 + $1.percentage }
            return (sum / Double(scheduledTrendPoints.count)).rounded()
        }()

        let todayRate = dailyProgressOverview(for: currentDateKey).completionPercentage

        // Weekly rate (last 7 days)
        let weekStartKey = DateKeyHelper.addingDays(-6, to: currentDateKey, calendar: calendar)
        let weekKeys = DateKeyHelper.daysBetween(startKey: max(earliestKey, weekStartKey), endKey: currentDateKey, calendar: calendar)
        let weekOverviews = weekKeys.map { dailyProgressOverview(for: $0) }.filter { $0.totalScheduledCount > 0 }
        let weeklyRate: Double = weekOverviews.isEmpty ? 0 : (weekOverviews.reduce(0.0) { $0 + $1.completionPercentage } / Double(weekOverviews.count)).rounded()

        // Monthly rate (last 30 days)
        let monthStartKey = DateKeyHelper.addingDays(-29, to: currentDateKey, calendar: calendar)
        let monthKeys = DateKeyHelper.daysBetween(startKey: max(earliestKey, monthStartKey), endKey: currentDateKey, calendar: calendar)
        let monthOverviews = monthKeys.map { dailyProgressOverview(for: $0) }.filter { $0.totalScheduledCount > 0 }
        let monthlyRate: Double = monthOverviews.isEmpty ? 0 : (monthOverviews.reduce(0.0) { $0 + $1.completionPercentage } / Double(monthOverviews.count)).rounded()

        // Unit-isolated totals (Never combine incompatible units)
        var totalMinutes = 0.0
        var totalKilometers = 0.0
        var totalReps = 0.0

        let habitsById = Dictionary(uniqueKeysWithValues: habits.map { ($0.id, $0) })
        for entry in progressEntries where entry.dateKey >= startKey && entry.dateKey <= currentDateKey {
            guard let habit = habitsById[entry.habitId] else { continue }
            switch habit.measurementType {
            case .duration:
                if habit.unit.lowercased().contains("hour") {
                    totalMinutes += entry.amount * 60.0
                } else {
                    totalMinutes += entry.amount
                }
            case .distance:
                if habit.unit.lowercased() == "meters" || habit.unit.lowercased() == "m" {
                    totalKilometers += entry.amount / 1000.0
                } else {
                    totalKilometers += entry.amount
                }
            case .counter:
                totalReps += entry.amount
            default:
                break
            }
        }

        // Per-habit consistency metrics
        let habitMetrics: [HabitConsistencyMetric] = habits.filter { !$0.isArchived }.map { habit in
            calculateHabitMetric(for: habit, startKey: startKey, endKey: currentDateKey)
        }

        let sortedByConsistency = habitMetrics.sorted { $0.completionRate > $1.completionRate }
        let mostConsistent = Array(sortedByConsistency.filter { $0.completionRate >= 60 }.prefix(4))
        let needingAttention = Array(habitMetrics.sorted { $0.completionRate < $1.completionRate }.filter { $0.completionRate < 85 }.prefix(4))

        // Overall streaks (days where all scheduled habits were 100% completed)
        let allDaysFromCreation = DateKeyHelper.daysBetween(startKey: earliestKey, endKey: currentDateKey, calendar: calendar)
        var currentStreak = 0
        var longestStreak = 0
        var runningStreak = 0

        for key in allDaysFromCreation {
            let ov = dailyProgressOverview(for: key)
            guard ov.totalScheduledCount > 0 else { continue }
            if ov.allScheduledCompleted {
                runningStreak += 1
                longestStreak = max(longestStreak, runningStreak)
            } else if key != currentDateKey {
                runningStreak = 0
            }
        }
        currentStreak = runningStreak

        return GlobalStatisticsSummary(
            dailyCompletionRate: todayRate,
            weeklyCompletionRate: weeklyRate,
            monthlyCompletionRate: monthlyRate,
            rangeCompletionRate: rangeRate,
            totalCompletedHabitInstances: totalCompletedInstances,
            totalTrackedMinutes: (totalMinutes * 10).rounded() / 10,
            totalDistanceKilometers: (totalKilometers * 100).rounded() / 100,
            totalRepetitions: totalReps.rounded(),
            currentOverallStreak: currentStreak,
            longestOverallStreak: longestStreak,
            mostConsistentHabits: mostConsistent,
            habitsNeedingAttention: needingAttention,
            dailyTrendPoints: trendPoints
        )
    }

    public func calculateHabitMetric(for habit: Habit, startKey: String, endKey: String) -> HabitConsistencyMetric {
        let effectiveStart = max(startKey, habit.createdAtDateKey)
        let keys = DateKeyHelper.daysBetween(startKey: effectiveStart, endKey: endKey, calendar: calendar)
        var scheduled = 0
        var completed = 0
        var partial = 0
        var missed = 0
        var accumulated = 0.0

        for key in keys {
            let dayTotal = totalCompleted(for: habit.id, on: key)
            accumulated += dayTotal
            guard habit.isScheduled(on: key, calendar: calendar) else { continue }
            scheduled += 1
            let st = status(for: habit, on: key)
            switch st.state {
            case .completed: completed += 1
            case .partial: partial += 1
            case .notStarted: missed += 1
            }
        }

        let rate = scheduled > 0 ? ((Double(completed) / Double(scheduled)) * 100.0).rounded() : 0.0

        // Calculate streaks across entire habit lifetime
        let allKeys = DateKeyHelper.daysBetween(startKey: habit.createdAtDateKey, endKey: currentDateKey, calendar: calendar)
        var longest = 0
        var running = 0
        for key in allKeys {
            guard habit.isScheduled(on: key, calendar: calendar) else { continue }
            let st = status(for: habit, on: key)
            if st.isCompleted {
                running += 1
                longest = max(longest, running)
            } else if key != currentDateKey {
                running = 0
            }
        }

        return HabitConsistencyMetric(
            habit: habit,
            scheduledDays: scheduled,
            completedDays: completed,
            partialDays: partial,
            missedDays: missed,
            completionRate: rate,
            currentStreak: running,
            longestStreak: longest,
            totalAccumulatedAmount: (accumulated * 100).rounded() / 100
        )
    }

    // MARK: - Default Showcase Seed Data

    private func timeOfDayLabel(for date: Date = Date()) -> String {
        let hour = calendar.component(.hour, from: date)
        if hour < 12 { return "Morning" }
        if hour < 17 { return "Afternoon" }
        return "Evening"
    }

    public func seedDefaultShowcaseData(referenceTodayKey: String) {
        let createdStartKey = DateKeyHelper.addingDays(-14, to: referenceTodayKey, calendar: calendar)

        // All 6 measurement types represented with realistic daily & weekly targets
        let readingHabit = Habit(
            name: "Reading",
            habitDescription: "Deep technical & non-fiction reading session",
            icon: "book.fill",
            category: DefaultCategory.education.rawValue,
            measurementType: .duration,
            unit: "minutes",
            dailyTarget: 60,
            weeklyTarget: 360,
            quickAddIncrement: 5,
            frequency: .daily,
            reminderEnabled: true,
            reminderHour: 20,
            reminderMinute: 0,
            estimatedDurationMinutes: 60,
            createdAtDateKey: createdStartKey,
            targetHistory: [
                TargetHistoryEntry(
                    effectiveDateKey: createdStartKey,
                    dailyTarget: 30,
                    weeklyTarget: 210,
                    quickAddIncrement: 5,
                    frequency: .daily,
                    scheduledWeekdays: Set(Weekday.allCases)
                ),
                TargetHistoryEntry(
                    effectiveDateKey: referenceTodayKey,
                    dailyTarget: 60,
                    weeklyTarget: 360,
                    quickAddIncrement: 5,
                    frequency: .daily,
                    scheduledWeekdays: Set(Weekday.allCases)
                )
            ]
        )

        let runningHabit = Habit(
            name: "Running",
            habitDescription: "Outdoor aerobic pace training",
            icon: "figure.run",
            category: DefaultCategory.fitness.rawValue,
            measurementType: .distance,
            unit: "km",
            dailyTarget: 5.0,
            weeklyTarget: 25.0,
            quickAddIncrement: 0.5,
            frequency: .daily,
            reminderEnabled: true,
            reminderHour: 7,
            reminderMinute: 0,
            estimatedDurationMinutes: 30,
            createdAtDateKey: createdStartKey
        )

        let waterHabit = Habit(
            name: "Drink Water",
            habitDescription: "Stay hydrated throughout the workday",
            icon: "drop.fill",
            category: DefaultCategory.health.rawValue,
            measurementType: .quantity,
            unit: "glasses",
            dailyTarget: 6,
            weeklyTarget: 42,
            quickAddIncrement: 1,
            frequency: .daily,
            reminderEnabled: false,
            estimatedDurationMinutes: 5,
            createdAtDateKey: createdStartKey
        )

        let lectureHabit = Habit(
            name: "Attend Lecture",
            habitDescription: "Complete daily university lecture & take structured notes",
            icon: "graduationcap.fill",
            category: DefaultCategory.education.rawValue,
            measurementType: .checkbox,
            unit: "completion",
            dailyTarget: 1,
            weeklyTarget: 5,
            quickAddIncrement: 1,
            frequency: .daily,
            reminderEnabled: true,
            reminderHour: 10,
            reminderMinute: 0,
            estimatedDurationMinutes: 45,
            createdAtDateKey: createdStartKey
        )

        let pushupsHabit = Habit(
            name: "Push-ups",
            habitDescription: "Upper body strength sets",
            icon: "flame.fill",
            category: DefaultCategory.fitness.rawValue,
            measurementType: .counter,
            unit: "reps",
            dailyTarget: 20,
            weeklyTarget: 140,
            quickAddIncrement: 5,
            frequency: .daily,
            reminderEnabled: false,
            estimatedDurationMinutes: 10,
            createdAtDateKey: createdStartKey
        )

        let quranHabit = Habit(
            name: "Quran Reflection",
            habitDescription: "Daily mindful reading with custom page unit",
            icon: "sparkles",
            category: DefaultCategory.religion.rawValue,
            measurementType: .customUnit,
            unit: "pages",
            dailyTarget: 2,
            weeklyTarget: 14,
            quickAddIncrement: 1,
            frequency: .daily,
            reminderEnabled: true,
            reminderHour: 6,
            reminderMinute: 30,
            estimatedDurationMinutes: 15,
            createdAtDateKey: createdStartKey
        )

        self.habits = [readingHabit, runningHabit, waterHabit, lectureHabit, pushupsHabit, quranHabit]

        var seededEntries: [ProgressEntry] = []

        // Seed today's entries matching the prompt's clean dashboard examples:
        // Reading: 35 / 60 minutes (Morning 15m + Afternoon 20m)
        seededEntries.append(ProgressEntry(habitId: readingHabit.id, dateKey: referenceTodayKey, amount: 15, label: "Morning"))
        seededEntries.append(ProgressEntry(habitId: readingHabit.id, dateKey: referenceTodayKey, amount: 20, label: "Afternoon"))

        // Running: 3.5 / 5 km (Morning 2.0 km + Afternoon 1.5 km)
        seededEntries.append(ProgressEntry(habitId: runningHabit.id, dateKey: referenceTodayKey, amount: 2.0, label: "Morning"))
        seededEntries.append(ProgressEntry(habitId: runningHabit.id, dateKey: referenceTodayKey, amount: 1.5, label: "Evening"))

        // Drink Water: 4 / 6 glasses
        seededEntries.append(ProgressEntry(habitId: waterHabit.id, dateKey: referenceTodayKey, amount: 2, label: "Morning"))
        seededEntries.append(ProgressEntry(habitId: waterHabit.id, dateKey: referenceTodayKey, amount: 2, label: "Afternoon"))

        // Push-ups: 20 / 20 reps (Completed today)
        seededEntries.append(ProgressEntry(habitId: pushupsHabit.id, dateKey: referenceTodayKey, amount: 20, label: "Morning"))

        // Quran Reflection: 2 / 2 pages (Completed today)
        seededEntries.append(ProgressEntry(habitId: quranHabit.id, dateKey: referenceTodayKey, amount: 2, label: "Morning"))

        // Attend Lecture: Not completed yet today (so user can see Today's Remaining Goals and test completing today's habits to unlock Missed Days)

        // Seed Yesterday (-1 day): Reading 20/30 min (partial), Running not completed, others completed
        let dayMinus1 = DateKeyHelper.addingDays(-1, to: referenceTodayKey, calendar: calendar)
        seededEntries.append(ProgressEntry(habitId: readingHabit.id, dateKey: dayMinus1, amount: 20, label: "Evening"))
        seededEntries.append(ProgressEntry(habitId: waterHabit.id, dateKey: dayMinus1, amount: 6, label: "All Day"))
        seededEntries.append(ProgressEntry(habitId: lectureHabit.id, dateKey: dayMinus1, amount: 1, label: "Morning"))
        seededEntries.append(ProgressEntry(habitId: pushupsHabit.id, dateKey: dayMinus1, amount: 20, label: "Morning"))
        seededEntries.append(ProgressEntry(habitId: quranHabit.id, dateKey: dayMinus1, amount: 2, label: "Morning"))

        // Seed -2 days: Reading not completed, Water 3/6 glasses (partial), Running 5/5 km
        let dayMinus2 = DateKeyHelper.addingDays(-2, to: referenceTodayKey, calendar: calendar)
        seededEntries.append(ProgressEntry(habitId: runningHabit.id, dateKey: dayMinus2, amount: 5.0, label: "Morning"))
        seededEntries.append(ProgressEntry(habitId: waterHabit.id, dateKey: dayMinus2, amount: 3, label: "Afternoon"))
        seededEntries.append(ProgressEntry(habitId: lectureHabit.id, dateKey: dayMinus2, amount: 1, label: "Morning"))
        seededEntries.append(ProgressEntry(habitId: pushupsHabit.id, dateKey: dayMinus2, amount: 20, label: "Morning"))
        seededEntries.append(ProgressEntry(habitId: quranHabit.id, dateKey: dayMinus2, amount: 2, label: "Morning"))

        // Seed -3 days: Reading 15/30 min (partial -> 3 days of unfinished reading triggers Smart Recovery suggestion!), others completed
        let dayMinus3 = DateKeyHelper.addingDays(-3, to: referenceTodayKey, calendar: calendar)
        seededEntries.append(ProgressEntry(habitId: readingHabit.id, dateKey: dayMinus3, amount: 15, label: "Evening"))
        seededEntries.append(ProgressEntry(habitId: runningHabit.id, dateKey: dayMinus3, amount: 5.0, label: "Morning"))
        seededEntries.append(ProgressEntry(habitId: waterHabit.id, dateKey: dayMinus3, amount: 6, label: "All Day"))
        seededEntries.append(ProgressEntry(habitId: lectureHabit.id, dateKey: dayMinus3, amount: 1, label: "Morning"))
        seededEntries.append(ProgressEntry(habitId: pushupsHabit.id, dateKey: dayMinus3, amount: 20, label: "Morning"))
        seededEntries.append(ProgressEntry(habitId: quranHabit.id, dateKey: dayMinus3, amount: 2, label: "Morning"))

        // Seed days -4 through -12 as mostly 100% completed for realistic streaks & heatmap
        for offset in 4...12 {
            let dKey = DateKeyHelper.addingDays(-offset, to: referenceTodayKey, calendar: calendar)
            seededEntries.append(ProgressEntry(habitId: readingHabit.id, dateKey: dKey, amount: 30, label: "Evening"))
            seededEntries.append(ProgressEntry(habitId: runningHabit.id, dateKey: dKey, amount: 5.0, label: "Morning"))
            seededEntries.append(ProgressEntry(habitId: waterHabit.id, dateKey: dKey, amount: 6, label: "All Day"))
            seededEntries.append(ProgressEntry(habitId: lectureHabit.id, dateKey: dKey, amount: 1, label: "Morning"))
            seededEntries.append(ProgressEntry(habitId: pushupsHabit.id, dateKey: dKey, amount: 20, label: "Morning"))
            seededEntries.append(ProgressEntry(habitId: quranHabit.id, dateKey: dKey, amount: 2, label: "Morning"))
        }

        self.progressEntries = seededEntries

        self.dailyNotes = [
            DailyNote(
                dateKey: referenceTodayKey,
                wentWell: "Completed morning run split and push-ups before 8 AM.",
                wasDifficult: "Afternoon schedule was packed; still have 25 minutes of reading left.",
                improveTomorrow: "Finish reading session right after dinner.",
                freeformNote: "Feeling energized and focused."
            ),
            DailyNote(
                dateKey: dayMinus1,
                wentWell: "Hydration and lecture notes stayed on track.",
                wasDifficult: "Rainy evening cut outdoor running short.",
                improveTomorrow: "Run in the morning instead of waiting until evening.",
                freeformNote: ""
            )
        ]
    }
}
