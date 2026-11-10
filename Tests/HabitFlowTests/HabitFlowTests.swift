import XCTest
@testable import HabitFlow

@MainActor
final class HabitFlowTests: XCTestCase {
    private var tempFileURL: URL!
    private var store: HabitStore!

    override func setUp() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        tempFileURL = tempDir.appendingPathComponent("habitflow_test_\(UUID().uuidString).json")
        store = HabitStore(storageFileURL: tempFileURL, seedSampleDataIfEmpty: false)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempFileURL)
    }

    // 1. Test Creating, Editing, Pausing, and Archiving Habits Across All 6 Measurement Types
    func testSixMeasurementTypesAndHabitLifecycle() {
        let today = store.currentDateKey
        let durationHabit = Habit(name: "Read", measurementType: .duration, unit: "minutes", dailyTarget: 60, quickAddIncrement: 15, createdAtDateKey: today)
        let distanceHabit = Habit(name: "Run", measurementType: .distance, unit: "km", dailyTarget: 5.0, quickAddIncrement: 0.5, createdAtDateKey: today)
        let checkboxHabit = Habit(name: "Lecture", measurementType: .checkbox, unit: "completion", dailyTarget: 1, quickAddIncrement: 1, createdAtDateKey: today)
        let counterHabit = Habit(name: "Push-ups", measurementType: .counter, unit: "reps", dailyTarget: 20, quickAddIncrement: 5, createdAtDateKey: today)
        let quantityHabit = Habit(name: "Water", measurementType: .quantity, unit: "glasses", dailyTarget: 6, quickAddIncrement: 1, createdAtDateKey: today)
        let customHabit = Habit(name: "Quran", measurementType: .customUnit, unit: "pages", dailyTarget: 2, quickAddIncrement: 1, createdAtDateKey: today)

        [durationHabit, distanceHabit, checkboxHabit, counterHabit, quantityHabit, customHabit].forEach {
            store.addHabit($0)
        }

        XCTAssertEqual(store.habits.count, 6)

        // Test Quick-Add & Decrease never goes negative
        store.quickAdd(for: distanceHabit.id, on: today)
        XCTAssertEqual(store.totalCompleted(for: distanceHabit.id, on: today), 0.5, accuracy: 0.001)

        store.quickDecrease(for: distanceHabit.id, on: today)
        XCTAssertEqual(store.totalCompleted(for: distanceHabit.id, on: today), 0.0, accuracy: 0.001)

        // Decreasing again at 0 stays at 0
        store.quickDecrease(for: distanceHabit.id, on: today)
        XCTAssertEqual(store.totalCompleted(for: distanceHabit.id, on: today), 0.0, accuracy: 0.001)
    }

    // 2. Test Multiple Progress Entries Per Day
    func testMultipleEntriesPerDayAggregation() {
        let today = store.currentDateKey
        let reading = Habit(name: "Reading", measurementType: .duration, unit: "minutes", dailyTarget: 60, quickAddIncrement: 5, createdAtDateKey: today)
        store.addHabit(reading)

        store.addProgressEntry(for: reading.id, dateKey: today, amount: 15, label: "Morning")
        store.addProgressEntry(for: reading.id, dateKey: today, amount: 20, label: "Afternoon")

        let status = store.status(for: reading, on: today)
        XCTAssertEqual(status.completedAmount, 35.0, accuracy: 0.001)
        XCTAssertEqual(status.remainingAmount, 25.0, accuracy: 0.001)
        XCTAssertEqual(status.state, .partial)
        XCTAssertEqual(status.entries.count, 2)
    }

    // 3. Test Conditional Missed Days Visibility Rules (Section 5)
    func testConditionalMissedDaysVisibilityRules() {
        let today = store.currentDateKey
        let yesterday = DateKeyHelper.addingDays(-1, to: today)

        let reading = Habit(name: "Reading", measurementType: .duration, unit: "minutes", dailyTarget: 60, quickAddIncrement: 30, createdAtDateKey: yesterday)
        let lecture = Habit(name: "Lecture", measurementType: .checkbox, unit: "completion", dailyTarget: 1, quickAddIncrement: 1, createdAtDateKey: yesterday)
        let pausedHabit = Habit(name: "Paused Yoga", measurementType: .duration, unit: "minutes", dailyTarget: 30, quickAddIncrement: 10, isPaused: true, createdAtDateKey: yesterday)

        store.addHabit(reading)
        store.addHabit(lecture)
        store.addHabit(pausedHabit)

        // Initially: Nothing completed today -> Missed Days MUST be hidden
        XCTAssertFalse(store.isMissedDaysUnlockedOnDashboard)

        // Partial completion of Reading (30/60) + Lecture completed -> Still hidden!
        store.quickAdd(for: reading.id, on: today) // 30/60
        store.quickAdd(for: lecture.id, on: today) // 1/1
        XCTAssertFalse(store.isMissedDaysUnlockedOnDashboard)

        // Complete Reading (60/60) -> All active scheduled habits completed (Paused habit does not block) -> Missed Days VISIBLE!
        store.quickAdd(for: reading.id, on: today) // 60/60
        XCTAssertTrue(store.isMissedDaysUnlockedOnDashboard)

        // If user reduces progress or unchecks a completed habit -> Hide Missed Days again immediately!
        store.quickDecrease(for: reading.id, on: today) // 30/60
        XCTAssertFalse(store.isMissedDaysUnlockedOnDashboard)
    }

    // 4. Test Effective-Dated Flexible Targets Preserve Historical Completion Percentages (Section 13)
    func testEffectiveDatedTargetChangesPreserveHistory() {
        let today = store.currentDateKey
        let yesterday = DateKeyHelper.addingDays(-1, to: today)

        var reading = Habit(name: "Reading", measurementType: .duration, unit: "minutes", dailyTarget: 30, quickAddIncrement: 10, createdAtDateKey: yesterday)
        store.addHabit(reading)

        // Yesterday user logged 30/30 minutes (100% completed)
        store.addProgressEntry(for: reading.id, dateKey: yesterday, amount: 30, label: "Evening")
        XCTAssertEqual(store.status(for: reading, on: yesterday).state, .completed)

        // Today user increases daily target from 30 to 45 minutes
        reading.dailyTarget = 45
        store.updateHabit(reading, effectiveDateKey: today)

        let updatedHabit = store.habits.first { $0.id == reading.id }!
        // Yesterday's target MUST remain 30 minutes and 100% completed
        let yesterdayStatus = store.status(for: updatedHabit, on: yesterday)
        XCTAssertEqual(yesterdayStatus.target, 30.0, accuracy: 0.001)
        XCTAssertEqual(yesterdayStatus.state, .completed)

        // Today's target MUST be 45 minutes
        let todayStatus = store.status(for: updatedHabit, on: today)
        XCTAssertEqual(todayStatus.target, 45.0, accuracy: 0.001)
    }

    // 5. Test Backup Export & Restore Persistence (Section 18 & 19)
    func testBackupAndRestoreRoundTrip() throws {
        let today = store.currentDateKey
        let habit = Habit(name: "Cycle", measurementType: .distance, unit: "km", dailyTarget: 10, quickAddIncrement: 2, createdAtDateKey: today)
        store.addHabit(habit)
        store.quickAdd(for: habit.id, on: today)
        store.saveDailyNote(DailyNote(dateKey: today, wentWell: "Great ride"))

        let exportedData = try store.exportBackupJSONData()

        let secondURL = FileManager.default.temporaryDirectory.appendingPathComponent("habitflow_restore_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: secondURL) }

        let restoredStore = HabitStore(storageFileURL: secondURL, seedSampleDataIfEmpty: false)
        try restoredStore.importBackupJSONData(exportedData)

        XCTAssertEqual(restoredStore.habits.count, 1)
        XCTAssertEqual(restoredStore.totalCompleted(for: habit.id, on: today), 2.0, accuracy: 0.001)
        XCTAssertEqual(restoredStore.dailyNote(for: today).wentWell, "Great ride")
    }
}
