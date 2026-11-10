import SwiftUI
import Charts

// MARK: - 1. Calendar, 365-Day GitHub Heatmap, & Daily Notes Page (Section 14 & Section 16)

public struct CalendarHistoryView: View {
    @EnvironmentObject private var store: HabitStore

    public let palette: HabitFlowPalette

    @State private var displayedMonthDate: Date = Date()
    @State private var selectedDateKey: String = DateKeyHelper.todayKey()
    @State private var draftNote: DailyNote = DailyNote(dateKey: DateKeyHelper.todayKey())
    @State private var noteSavedFeedback: Bool = false

    public init(palette: HabitFlowPalette) {
        self.palette = palette
    }

    private var selectedDayOverview: DailyProgressOverview {
        store.dailyProgressOverview(for: selectedDateKey)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Calendar & Activity Heatmap")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(palette.primaryText)
                        Text("Inspect daily completion records, browse the 365-day consistency heatmap, and capture daily notes.")
                            .font(.system(size: 13))
                            .foregroundStyle(palette.secondaryText)
                    }
                    Spacer()

                    Button("Jump to Today") {
                        displayedMonthDate = DateKeyHelper.date(from: store.currentDateKey) ?? Date()
                        selectDateKey(store.currentDateKey)
                    }
                    .buttonStyle(.bordered)
                }

                // GitHub-style 365-Day Activity Heatmap (Section 14)
                heatmapSectionCard

                // Split Monthly Grid + Selected Day Details & Daily Notes
                HStack(alignment: .top, spacing: 20) {
                    monthlyCalendarCard
                        .frame(maxWidth: 440)

                    VStack(alignment: .leading, spacing: 18) {
                        selectedDayDetailsCard
                        dailyNotesCard
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(32)
            .frame(maxWidth: 1020, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .onAppear {
            selectDateKey(store.selectedCalendarDateKey)
            if let d = DateKeyHelper.date(from: store.selectedCalendarDateKey) {
                displayedMonthDate = d
            }
        }
    }

    private func selectDateKey(_ key: String) {
        selectedDateKey = key
        store.selectedCalendarDateKey = key
        draftNote = store.dailyNote(for: key)
        noteSavedFeedback = false
    }

    // MARK: - 365-Day GitHub Activity Heatmap

    private var heatmapSectionCard: some View {
        let points = store.heatmapDaysLast365()
        let weeks = stride(from: 0, to: points.count, by: 7).map { idx in
            Array(points[idx..<min(idx + 7, points.count)])
        }

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Last 365 Days Activity Heatmap")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.primaryText)
                Spacer()
                HStack(spacing: 4) {
                    Text("Less")
                        .font(.system(size: 10))
                        .foregroundStyle(palette.secondaryText)
                    ForEach([0.0, 25.0, 55.0, 85.0, 100.0], id: \.self) { level in
                        RoundedRectangle(cornerRadius: 2.5)
                            .fill(heatmapColor(for: level, scheduledCount: 1))
                            .frame(width: 10, height: 10)
                    }
                    Text("More")
                        .font(.system(size: 10))
                        .foregroundStyle(palette.secondaryText)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 3) {
                    ForEach(weeks.indices, id: \.self) { weekIdx in
                        VStack(spacing: 3) {
                            ForEach(weeks[weekIdx]) { pt in
                                RoundedRectangle(cornerRadius: 2.5)
                                    .fill(heatmapColor(for: pt.percentage, scheduledCount: pt.scheduledCount))
                                    .frame(width: 11, height: 11)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 2.5)
                                            .strokeBorder(selectedDateKey == pt.dateKey ? Color.white : Color.clear, lineWidth: 1.2)
                                    )
                                    .onTapGesture {
                                        selectDateKey(pt.dateKey)
                                    }
                                    .help("\(pt.dateKey): \(Int(pt.percentage))% (\(pt.completedCount)/\(pt.scheduledCount) habits)")
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .habitFlowCard(palette: palette, padding: 16)
    }

    private func heatmapColor(for percentage: Double, scheduledCount: Int) -> Color {
        if scheduledCount == 0 {
            return palette.secondarySurface.opacity(0.45) // Unscheduled days are never counted as missed
        }
        if percentage <= 0 {
            return palette.secondarySurface
        } else if percentage < 40 {
            return palette.accent.opacity(0.32)
        } else if percentage < 75 {
            return palette.accent.opacity(0.58)
        } else if percentage < 100 {
            return palette.accent.opacity(0.82)
        } else {
            return palette.accent
        }
    }

    // MARK: - Monthly Calendar Grid

    private var monthlyCalendarCard: some View {
        let cal = Calendar.current
        let monthTitle: String = {
            let df = DateFormatter()
            df.dateFormat = "MMMM yyyy"
            return df.string(from: displayedMonthDate)
        }()

        let daysInMonthGrid = buildMonthGridDates(for: displayedMonthDate)
        let orderedWeekdays = Weekday.ordered(startingOn: store.settings.weekStartDay)

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(monthTitle)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.primaryText)

                Spacer()

                HStack(spacing: 6) {
                    Button {
                        if let prev = cal.date(byAdding: .month, value: -1, to: displayedMonthDate) {
                            displayedMonthDate = prev
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .frame(width: 26, height: 26)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        if let next = cal.date(byAdding: .month, value: 1, to: displayedMonthDate) {
                            displayedMonthDate = next
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .frame(width: 26, height: 26)
                    }
                    .buttonStyle(.bordered)
                }
            }

            // Weekday Header Row
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(orderedWeekdays) { wd in
                    Text(wd.shortName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(palette.secondaryText)
                        .frame(maxWidth: .infinity)
                }

                ForEach(daysInMonthGrid.indices, id: \.self) { idx in
                    if let dKey = daysInMonthGrid[idx] {
                        calendarDayCell(for: dKey)
                    } else {
                        Color.clear
                            .frame(height: 44)
                    }
                }
            }
        }
        .habitFlowCard(palette: palette, padding: 18)
    }

    private func calendarDayCell(for dateKey: String) -> some View {
        let isSelected = (dateKey == selectedDateKey)
        let isToday = (dateKey == store.currentDateKey)
        let dayNum = Int(dateKey.suffix(2)) ?? 1
        let ov = store.dailyProgressOverview(for: dateKey)
        let hasNote = store.dailyNotes.contains { $0.dateKey == dateKey && !$0.isEmpty }

        return Button {
            selectDateKey(dateKey)
        } label: {
            VStack(spacing: 3) {
                HStack(spacing: 2) {
                    Text("\(dayNum)")
                        .font(.system(size: 12, weight: isSelected || isToday ? .bold : .medium))
                        .foregroundStyle(isSelected ? .white : palette.primaryText)
                    if hasNote {
                        Circle()
                            .fill(isSelected ? .white : palette.accent)
                            .frame(width: 4, height: 4)
                    }
                }

                if dateKey <= store.currentDateKey && ov.totalScheduledCount > 0 {
                    Text("\(Int(ov.completionPercentage))%")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(
                            isSelected
                                ? .white.opacity(0.9)
                                : (ov.allScheduledCompleted ? Color.green : palette.secondaryText)
                        )
                } else {
                    Text(" ")
                        .font(.system(size: 9))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        isSelected
                            ? palette.accent
                            : (isToday ? palette.accent.opacity(0.15) : palette.secondarySurface.opacity(0.55))
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func buildMonthGridDates(for monthDate: Date) -> [String?] {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: monthDate)
        guard let firstOfMonth = cal.date(from: comps),
              let range = cal.range(of: .day, in: .month, for: firstOfMonth) else {
            return []
        }

        let firstWeekdayOfMonth = cal.component(.weekday, from: firstOfMonth)
        let weekStart = store.settings.weekStartDay.calendarFirstWeekday
        let leadingEmptyCount = (firstWeekdayOfMonth - weekStart + 7) % 7

        var cells: [String?] = Array(repeating: nil, count: leadingEmptyCount)
        let year = comps.year ?? 2026
        let month = comps.month ?? 1

        for day in range {
            cells.append(String(format: "%04d-%02d-%02d", year, month, day))
        }
        return cells
    }

    // MARK: - Selected Day Detailed History

    private var selectedDayDetailsCard: some View {
        let ov = selectedDayOverview
        let title = DateKeyHelper.friendlyDateTitle(for: selectedDateKey, relativeTo: store.currentDateKey)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)
                    Text("\(ov.completedCount) completed • \(ov.partialCount) partial • \(ov.incompleteCount) missed (\(Int(ov.completionPercentage))%)")
                        .font(.system(size: 12))
                        .foregroundStyle(palette.secondaryText)
                }
                Spacer()
            }

            Divider()

            if ov.scheduledStatuses.isEmpty {
                Text("No habits were scheduled on this date.")
                    .font(.system(size: 13))
                    .foregroundStyle(palette.secondaryText)
            } else {
                ForEach(ov.scheduledStatuses) { st in
                    HStack(spacing: 10) {
                        HabitIconBadge(icon: st.habit.icon, accent: palette.accent, isCompleted: st.isCompleted, size: 30)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(st.habit.name)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(palette.primaryText)
                            Text(st.progressText)
                                .font(.system(size: 11))
                                .foregroundStyle(palette.secondaryText)
                        }
                        Spacer()
                        Text(st.state.rawValue)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(
                                st.state == .completed ? Color.green : (st.state == .partial ? Color.orange : palette.secondaryText)
                            )
                    }
                    .padding(.vertical, 3)
                }
            }
        }
        .habitFlowCard(palette: palette, padding: 18)
    }

    // MARK: - Optional Daily Notes Card (Section 16)

    private var dailyNotesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Daily Notes (\(selectedDateKey))", systemImage: "note.text")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.primaryText)
                Spacer()
                if noteSavedFeedback {
                    Text("Saved")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.green)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("What went well today?")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.secondaryText)
                TextField("Highlights or wins...", text: $draftNote.wentWell)
                    .textFieldStyle(.roundedBorder)

                Text("What was difficult?")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.secondaryText)
                TextField("Obstacles or distractions...", text: $draftNote.wasDifficult)
                    .textFieldStyle(.roundedBorder)

                Text("What would I improve tomorrow?")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.secondaryText)
                TextField("One concrete adjustment for tomorrow...", text: $draftNote.improveTomorrow)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Spacer()
                Button("Save Daily Note") {
                    draftNote.dateKey = selectedDateKey
                    store.saveDailyNote(draftNote)
                    noteSavedFeedback = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .habitFlowCard(palette: palette, padding: 18)
    }
}

// MARK: - 2. Statistics & Analytics Page + Per-Habit Detailed Analytics Modal (Section 15)

public struct StatisticsAnalyticsView: View {
    @EnvironmentObject private var store: HabitStore

    public let palette: HabitFlowPalette
    public let onSelectHabitDetail: (Habit) -> Void

    @State private var selectedRange: AnalyticsTimeRange = .days30

    public init(palette: HabitFlowPalette, onSelectHabitDetail: @escaping (Habit) -> Void) {
        self.palette = palette
        self.onSelectHabitDetail = onSelectHabitDetail
    }

    private var summary: GlobalStatisticsSummary {
        store.calculateStatistics(for: selectedRange)
    }

    public var body: some View {
        let stats = summary

        return ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header & Date Filters (7d, 30d, 90d, 365d, All time)
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Statistics & Analytics")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(palette.primaryText)
                        Text("Long-term consistency, unit-isolated totals, streaks, and per-habit insights.")
                            .font(.system(size: 13))
                            .foregroundStyle(palette.secondaryText)
                    }
                    Spacer()

                    Picker("Date Range", selection: $selectedRange) {
                        ForEach(AnalyticsTimeRange.allCases) { r in
                            Text(r.rawValue).tag(r)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 360)
                }

                // Completion Rate Cards (Daily, Weekly, Monthly, Streaks)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 4), spacing: 14) {
                    metricCard(title: "Daily Rate (Today)", value: "\(Int(stats.dailyCompletionRate))%", subtitle: "Today's scheduled habits", color: palette.accent)
                    metricCard(title: "Weekly Rate (7d)", value: "\(Int(stats.weeklyCompletionRate))%", subtitle: "Rolling 7-day average", color: .green)
                    metricCard(title: "Monthly Rate (30d)", value: "\(Int(stats.monthlyCompletionRate))%", subtitle: "Rolling 30-day average", color: .cyan)
                    metricCard(title: "Overall Streak", value: "\(stats.currentOverallStreak)d", subtitle: "Longest: \(stats.longestOverallStreak) days", color: .orange)
                }

                // Unit-Isolated Cumulative Totals (Never combining incompatible units)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 4), spacing: 14) {
                    metricCard(
                        title: "Completed Habits",
                        value: "\(stats.totalCompletedHabitInstances)",
                        subtitle: "In \(selectedRange.rawValue)",
                        color: palette.accent
                    )
                    metricCard(
                        title: "Total Tracked Time",
                        value: "\(NumberFormattingHelper.format(stats.totalTrackedMinutes)) min",
                        subtitle: String(format: "%.1f hours total", stats.totalTrackedMinutes / 60.0),
                        color: .purple
                    )
                    metricCard(
                        title: "Total Distance",
                        value: "\(NumberFormattingHelper.format(stats.totalDistanceKilometers)) km",
                        subtitle: "Distance habits only",
                        color: .mint
                    )
                    metricCard(
                        title: "Total Repetitions",
                        value: "\(NumberFormattingHelper.format(stats.totalRepetitions)) reps",
                        subtitle: "Counter habits only",
                        color: .pink
                    )
                }

                // Swift Charts Daily Completion Trend
                VStack(alignment: .leading, spacing: 12) {
                    Text("Daily Completion Trend (\(selectedRange.rawValue))")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)

                    Chart(stats.dailyTrendPoints) { pt in
                        AreaMark(
                            x: .value("Date", pt.date),
                            y: .value("Completion %", pt.percentage)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [palette.accent.opacity(0.38), palette.accent.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        LineMark(
                            x: .value("Date", pt.date),
                            y: .value("Completion %", pt.percentage)
                        )
                        .foregroundStyle(palette.accent)
                        .lineStyle(StrokeStyle(lineWidth: 2.2))
                    }
                    .chartYScale(domain: 0...100)
                    .frame(height: 210)
                }
                .habitFlowCard(palette: palette, padding: 18)

                // Most Consistent vs. Habits Needing Attention
                HStack(alignment: .top, spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Most Consistent Habits", systemImage: "flame.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.green)

                        if stats.mostConsistentHabits.isEmpty {
                            Text("Complete habits over multiple days to build consistency leaders.")
                                .font(.system(size: 12))
                                .foregroundStyle(palette.secondaryText)
                        } else {
                            ForEach(stats.mostConsistentHabits) { item in
                                habitMetricRow(item, highlightColor: .green)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .habitFlowCard(palette: palette, padding: 16)

                    VStack(alignment: .leading, spacing: 10) {
                        Label("Habits Needing Attention", systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.orange)

                        if stats.habitsNeedingAttention.isEmpty {
                            Text("All active habits are maintaining 85%+ consistency!")
                                .font(.system(size: 12))
                                .foregroundStyle(palette.secondaryText)
                        } else {
                            ForEach(stats.habitsNeedingAttention) { item in
                                habitMetricRow(item, highlightColor: .orange)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .habitFlowCard(palette: palette, padding: 16)
                }
            }
            .padding(32)
            .frame(maxWidth: 1020, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private func metricCard(title: String, value: String, subtitle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(palette.secondaryText)
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(palette.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .habitFlowCard(palette: palette, padding: 15)
    }

    private func habitMetricRow(_ item: HabitConsistencyMetric, highlightColor: Color) -> some View {
        Button {
            onSelectHabitDetail(item.habit)
        } label: {
            HStack(spacing: 10) {
                HabitIconBadge(icon: item.habit.icon, accent: highlightColor, isCompleted: false, size: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.habit.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.primaryText)
                    Text("Streak: \(item.currentStreak)d (Best \(item.longestStreak)d) • \(item.completedDays)/\(item.scheduledDays) days")
                        .font(.system(size: 11))
                        .foregroundStyle(palette.secondaryText)
                }
                Spacer()
                Text("\(Int(item.completionRate))%")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(highlightColor)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(palette.secondaryText)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 3. Individual Habit Detailed Statistics Modal (Section 15)

public struct HabitDetailAnalyticsModalView: View {
    @EnvironmentObject private var store: HabitStore
    @Environment(\.dismiss) private var dismiss

    public let habit: Habit
    public let palette: HabitFlowPalette

    public init(habit: Habit, palette: HabitFlowPalette) {
        self.habit = habit
        self.palette = palette
    }

    private var metric: HabitConsistencyMetric {
        let startKey = DateKeyHelper.addingDays(-29, to: store.currentDateKey)
        return store.calculateHabitMetric(for: habit, startKey: startKey, endKey: store.currentDateKey)
    }

    public var body: some View {
        let m = metric
        let last14Keys = DateKeyHelper.daysBetween(
            startKey: DateKeyHelper.addingDays(-13, to: store.currentDateKey),
            endKey: store.currentDateKey
        )

        return VStack(alignment: .leading, spacing: 18) {
            HStack {
                HabitIconBadge(icon: habit.icon, accent: palette.accent, isCompleted: false, size: 42)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(habit.name) — Detailed Analytics")
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)
                    Text("\(habit.category) • \(habit.measurementType.rawValue) (\(habit.unit))")
                        .font(.system(size: 12))
                        .foregroundStyle(palette.secondaryText)
                }
                Spacer()
                Button("Close") { dismiss() }
            }

            HStack(spacing: 12) {
                statBox(label: "Completion Rate (30d)", value: "\(Int(m.completionRate))%")
                statBox(label: "Current Streak", value: "\(m.currentStreak) days")
                statBox(label: "Longest Streak", value: "\(m.longestStreak) days")
                statBox(
                    label: "Total Logged (30d)",
                    value: NumberFormattingHelper.formatWithUnit(m.totalAccumulatedAmount, unit: habit.unit, measurementType: habit.measurementType)
                )
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Last 14 Days Performance")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(palette.primaryText)

                Chart(last14Keys, id: \.self) { key in
                    let st = store.status(for: habit, on: key)
                    BarMark(
                        x: .value("Day", String(key.suffix(5))),
                        y: .value("Completed", st.completedAmount)
                    )
                    .foregroundStyle(st.isCompleted ? Color.green : palette.accent)
                }
                .frame(height: 180)
            }
            .habitFlowCard(palette: palette, padding: 14)

            // Target History Audit Trail (Section 13)
            VStack(alignment: .leading, spacing: 6) {
                Text("Effective-Dated Target History")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(palette.primaryText)
                ForEach(habit.targetHistory) { th in
                    HStack {
                        Text("Effective from \(th.effectiveDateKey):")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(palette.secondaryText)
                        Spacer()
                        Text("Daily Target: \(NumberFormattingHelper.format(th.dailyTarget)) \(habit.unit) (Quick-Add +\(NumberFormattingHelper.format(th.quickAddIncrement)))")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(palette.primaryText)
                    }
                }
            }
            .habitFlowCard(palette: palette, padding: 14)

            Spacer()
        }
        .padding(24)
        .frame(width: 640, height: 520)
        .background(palette.windowBackground)
    }

    private func statBox(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(palette.secondaryText)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(palette.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .habitFlowCard(palette: palette, padding: 12)
    }
}
