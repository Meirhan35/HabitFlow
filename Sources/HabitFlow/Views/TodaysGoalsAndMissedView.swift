import SwiftUI

// MARK: - 1. Today's Goals & Weekly Goals Page (Section 10 & Section 11)

public struct TodaysGoalsView: View {
    @EnvironmentObject private var store: HabitStore

    public let palette: HabitFlowPalette
    public let onAddHabit: () -> Void

    public init(palette: HabitFlowPalette, onAddHabit: @escaping () -> Void) {
        self.palette = palette
        self.onAddHabit = onAddHabit
    }

    private var todayOverview: DailyProgressOverview {
        store.dailyProgressOverview(for: store.currentDateKey)
    }

    private var incompleteStatuses: [DailyHabitStatus] {
        todayOverview.scheduledStatuses.filter { $0.state == .notStarted }
    }

    private var partialStatuses: [DailyHabitStatus] {
        todayOverview.scheduledStatuses.filter { $0.state == .partial }
    }

    private var completedStatuses: [DailyHabitStatus] {
        todayOverview.scheduledStatuses.filter { $0.state == .completed }
    }

    private var weeklyProgressItems: [WeeklyHabitProgress] {
        store.weeklyHabitProgressList(for: store.currentDateKey)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Today's Goals & Weekly Targets")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(palette.primaryText)
                        Text("Detailed breakdown of remaining quantities, estimated time left, and weekly goal progress.")
                            .font(.system(size: 13))
                            .foregroundStyle(palette.secondaryText)
                    }
                    Spacer()
                    if todayOverview.totalEstimatedRemainingMinutes > 0 {
                        HStack(spacing: 6) {
                            Image(systemName: "hourglass")
                                .foregroundStyle(palette.accent)
                            Text("Est. \(todayOverview.totalEstimatedRemainingMinutes) min remaining today")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(palette.primaryText)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 9).fill(palette.cardBackground))
                    }
                }

                // KPI Summary Cards
                HStack(spacing: 14) {
                    goalStatCard(
                        title: "Completed Today",
                        value: "\(completedStatuses.count)",
                        subtitle: "Reached 100% target",
                        color: .green
                    )
                    goalStatCard(
                        title: "Partially Completed",
                        value: "\(partialStatuses.count)",
                        subtitle: "In progress today",
                        color: .orange
                    )
                    goalStatCard(
                        title: "Incomplete",
                        value: "\(incompleteStatuses.count)",
                        subtitle: "Not started yet",
                        color: palette.accent
                    )
                }

                // Remaining Quantities Breakdown (Section 10)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Remaining Quantities Today")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)

                    let unfinished = todayOverview.scheduledStatuses.filter { !$0.isCompleted }
                    if unfinished.isEmpty {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                            Text("Every scheduled habit for today is 100% complete!")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(palette.primaryText)
                            Spacer()
                        }
                        .padding(.vertical, 6)
                    } else {
                        ForEach(unfinished) { st in
                            HStack(spacing: 12) {
                                HabitIconBadge(icon: st.habit.icon, accent: palette.accent, isCompleted: false, size: 34)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(st.habit.name)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(palette.primaryText)
                                    Text(st.state.rawValue)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(st.state == .partial ? Color.orange : palette.secondaryText)
                                }

                                Spacer()

                                if st.habit.measurementType == .checkbox {
                                    Text("Not completed")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(palette.secondaryText)
                                } else {
                                    Text("\(NumberFormattingHelper.format(st.remainingAmount)) \(st.habit.unit) remaining")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(palette.accent)
                                }

                                Button {
                                    store.quickAdd(for: st.habit.id, on: store.currentDateKey)
                                } label: {
                                    Text(st.habit.measurementType == .checkbox ? "Complete" : "+\(NumberFormattingHelper.format(st.quickAddIncrement))")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(RoundedRectangle(cornerRadius: 7).fill(palette.accent))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
                .habitFlowCard(palette: palette, padding: 18)

                // Completed Habits Today
                if !completedStatuses.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Completed Today")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(palette.primaryText)

                        ForEach(completedStatuses) { st in
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text(st.habit.name)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(palette.primaryText)
                                Spacer()
                                Text(st.progressText)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.green)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .habitFlowCard(palette: palette, padding: 18)
                }

                // Section 11: Weekly Goals
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Weekly Goals (\(store.settings.weekStartDay.rawValue) Start)")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(palette.primaryText)
                            Text("Aggregated progress across the current 7-day week without double-counting.")
                                .font(.system(size: 12))
                                .foregroundStyle(palette.secondaryText)
                        }
                        Spacer()
                    }

                    ForEach(weeklyProgressItems) { wp in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(wp.habit.name)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(palette.primaryText)
                                Spacer()
                                Text("\(NumberFormattingHelper.format(wp.currentProgress)) / \(NumberFormattingHelper.format(wp.weeklyTarget)) \(wp.unitLabel) (\(Int(wp.completionPercentage))%)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(wp.isCompleted ? Color.green : palette.primaryText)
                            }

                            SmoothProgressBar(
                                fraction: wp.completionPercentage / 100.0,
                                accentColor: wp.isCompleted ? .green : palette.accent,
                                height: 7,
                                trackColor: palette.secondarySurface
                            )

                            HStack {
                                Text(wp.isCompleted ? "Weekly target achieved" : "\(NumberFormattingHelper.format(wp.remainingAmount)) \(wp.unitLabel) remaining this week")
                                    .font(.system(size: 11))
                                    .foregroundStyle(palette.secondaryText)
                                Spacer()
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(palette.secondarySurface.opacity(0.55))
                        )
                    }
                }
                .habitFlowCard(palette: palette, padding: 18)
            }
            .padding(32)
            .frame(maxWidth: 960, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private func goalStatCard(title: String, value: String, subtitle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.secondaryText)
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(palette.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .habitFlowCard(palette: palette, padding: 16)
    }
}

// MARK: - 2. Dedicated Missed & Unfinished Page + Smart Recovery (Section 12)

public struct MissedAndUnfinishedView: View {
    @EnvironmentObject private var store: HabitStore

    public let palette: HabitFlowPalette
    public let onEditHabit: (Habit) -> Void

    @State private var expandedDateKeys: Set<String> = []
    @State private var filterMode: String = "All Unfinished"

    public init(palette: HabitFlowPalette, onEditHabit: @escaping (Habit) -> Void) {
        self.palette = palette
        self.onEditHabit = onEditHabit
    }

    private var missedRecords: [MissedDayRecord] {
        store.allMissedDaysHistory(lookbackDays: 90)
    }

    private var recoverySuggestions: [SmartRecoverySuggestion] {
        store.smartRecoverySuggestions()
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Missed & Unfinished History")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(palette.primaryText)
                        Text("Accessible at any time. Historical missed tasks are never automatically added to today's goals.")
                            .font(.system(size: 13))
                            .foregroundStyle(palette.secondaryText)
                    }
                    Spacer()

                    Picker("Filter", selection: $filterMode) {
                        Text("All Unfinished").tag("All Unfinished")
                        Text("Partially Completed Only").tag("Partially Completed Only")
                        Text("Fully Missed Only").tag("Fully Missed Only")
                    }
                    .frame(width: 220)
                }

                // Smart Recovery Gentle Banner (Section 12)
                if !recoverySuggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "heart.text.square.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(palette.accent)
                            Text("Smart Recovery Suggestion")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(palette.primaryText)
                        }

                        ForEach(recoverySuggestions) { suggestion in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(suggestion.message)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(palette.primaryText)

                                HStack(spacing: 10) {
                                    Button("Continue Normal Target") {
                                        store.dismissRecoverySuggestion(for: suggestion.habit.id)
                                    }
                                    .buttonStyle(.bordered)

                                    if suggestion.habit.measurementType != .checkbox {
                                        Button("Temporarily Reduce to \(NumberFormattingHelper.format(suggestion.suggestedReducedTarget)) \(suggestion.habit.unit)") {
                                            store.applyTemporaryTargetReduction(for: suggestion)
                                        }
                                        .buttonStyle(.borderedProminent)
                                    }

                                    Button("Change Schedule...") {
                                        onEditHabit(suggestion.habit)
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(palette.secondarySurface)
                            )
                        }
                    }
                    .habitFlowCard(palette: palette, padding: 18)
                }

                // Historical Missed Days List
                if missedRecords.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.green)
                        Text("You're all caught up!")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(palette.primaryText)
                        Text("No missed or partially completed scheduled habits in your history.")
                            .font(.system(size: 13))
                            .foregroundStyle(palette.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 36)
                    .habitFlowCard(palette: palette)
                } else {
                    VStack(spacing: 12) {
                        ForEach(missedRecords) { record in
                            let filteredItems = record.missedOrPartialStatuses.filter { st in
                                if filterMode == "Partially Completed Only" { return st.state == .partial }
                                if filterMode == "Fully Missed Only" { return st.state == .notStarted }
                                return true
                            }

                            if !filteredItems.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Text(record.friendlyTitle)
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundStyle(palette.primaryText)

                                        Text("(\(record.dateKey))")
                                            .font(.system(size: 12))
                                            .foregroundStyle(palette.secondaryText)

                                        Spacer()

                                        Text("Day Completion: \(Int(record.completionPercentage))% • \(record.fullyMissedCount) missed, \(record.partialCount) partial")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(palette.secondaryText)
                                    }

                                    Divider()

                                    ForEach(filteredItems) { st in
                                        HStack(spacing: 12) {
                                            HabitIconBadge(
                                                icon: st.habit.icon,
                                                accent: st.state == .partial ? .orange : .red,
                                                isCompleted: false,
                                                size: 32
                                            )

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(st.habit.name)
                                                    .font(.system(size: 13, weight: .semibold))
                                                    .foregroundStyle(palette.primaryText)
                                                Text("Effective target on \(record.dateKey): \(NumberFormattingHelper.formatWithUnit(st.target, unit: st.habit.unit, measurementType: st.habit.measurementType))")
                                                    .font(.system(size: 11))
                                                    .foregroundStyle(palette.secondaryText)
                                            }

                                            Spacer()

                                            Text(st.state == .notStarted ? "Not completed" : st.progressText)
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundStyle(st.state == .partial ? Color.orange : Color.red.opacity(0.85))
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                                .habitFlowCard(palette: palette, padding: 16)
                            }
                        }
                    }
                }
            }
            .padding(32)
            .frame(maxWidth: 960, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}
