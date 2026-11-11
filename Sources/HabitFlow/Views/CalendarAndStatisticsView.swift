import SwiftUI
import Charts

// MARK: - 1. Calendar, 365-Day GitHub Heatmap, & Daily Notes Page (Section 14 & Section 16)

public struct CalendarHistoryView: View {
    @AppStorage("interfaceLanguage") private var interfaceLanguage = "en"
    @EnvironmentObject private var store: HabitStore

    public let palette: HabitFlowPalette

    @State private var displayedMonthDate: Date = Date()
    @State private var selectedDateKey: String = DateKeyHelper.todayKey()
    @State private var draftNote: DailyNote = DailyNote(dateKey: DateKeyHelper.todayKey())
    @State private var noteSavedFeedback: Bool = false
    @State private var showsWeek = false

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
                        Text(L10n.tr("Calendar"))
                            .font(HabitFlowTypography.displayItalic(42, weight: .bold))
                            .foregroundStyle(palette.accentText)
                        Text(L10n.tr("История привычек, целей и заметок по дням"))
                            .font(HabitFlowTypography.body(13))
                            .foregroundStyle(palette.secondaryText)
                    }
                    Spacer()
                    Picker(L10n.tr("Режим календаря"), selection: $showsWeek) {
                        Text(L10n.tr("Месяц")).tag(false)
                        Text(L10n.tr("Неделя")).tag(true)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                    Button(L10n.tr("Сегодня")) {
                        displayedMonthDate = DateKeyHelper.date(from: store.currentDateKey) ?? Date()
                        selectDateKey(store.currentDateKey)
                    }
                    .buttonStyle(.bordered)
                }

                // Split Monthly Grid + Selected Day Details & Daily Notes
                HStack(alignment: .top, spacing: 16) {
                    monthlyCalendarCard
                        .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 18) {
                        selectedDayDetailsCard
                        dailyNotesCard
                    }
                    .frame(width: 300)
                }
                heatmapSectionCard
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 32)
            .frame(maxWidth: 1280, alignment: .leading)
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
                Text(L10n.tr("Активность за год"))
                    .font(HabitFlowTypography.body(15, weight: .semibold))
                    .foregroundStyle(palette.primaryText)
                Spacer()
                HStack(spacing: 4) {
                    Text(L10n.tr("Меньше"))
                        .font(.system(size: 10))
                        .foregroundStyle(palette.secondaryText)
                    ForEach([0.0, 25.0, 55.0, 85.0, 100.0], id: \.self) { level in
                        RoundedRectangle(cornerRadius: 2.5)
                            .fill(heatmapColor(for: level, scheduledCount: 1))
                            .frame(width: 10, height: 10)
                    }
                    Text(L10n.tr("Больше"))
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
                                    .help(L10n.tr("\(pt.dateKey): \(Int(pt.percentage))% (\(pt.completedCount)/\(pt.scheduledCount) habits)"))
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
        guard scheduledCount > 0 else { return palette.heatmapColors[0] }
        return palette.heatmapColors[min(4, max(1, Int(ceil(percentage / 25))))]
    }

    // MARK: - Monthly Calendar Grid

    private var monthlyCalendarCard: some View {
        let cal = Calendar.current
        let monthTitle: String = {
            let df = DateFormatter()
        df.locale = L10n.locale
            df.setLocalizedDateFormatFromTemplate("MMMM yyyy")
            return df.string(from: displayedMonthDate)
        }()

        let fullMonthGrid = buildMonthGridDates(for: displayedMonthDate)
        let daysInMonthGrid: [String?] = {
            guard showsWeek else { return fullMonthGrid }
            let selectedIndex = fullMonthGrid.firstIndex(where: { $0 == selectedDateKey }) ??
                fullMonthGrid.firstIndex(where: { $0 != nil }) ?? 0
            let start = (selectedIndex / 7) * 7
            return Array(fullMonthGrid.dropFirst(start).prefix(7))
        }()
        let orderedWeekdays = Weekday.ordered(startingOn: store.settings.weekStartDay)

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(L10n.tr(monthTitle))
                    .font(HabitFlowTypography.body(16, weight: .semibold))
                    .foregroundStyle(palette.primaryText)

                Spacer()

                HStack(spacing: 6) {
                    Button {
                        if let prev = cal.date(byAdding: .month, value: -1, to: displayedMonthDate) {
                            displayedMonthDate = prev
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        if let next = cal.date(byAdding: .month, value: 1, to: displayedMonthDate) {
                            displayedMonthDate = next
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.bordered)
                }
            }

            // Weekday Header Row
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(orderedWeekdays) { wd in
                    Text(L10n.tr(wd.shortName))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(palette.secondaryText)
                        .frame(maxWidth: .infinity)
                }

                ForEach(daysInMonthGrid.indices, id: \.self) { idx in
                    if let dKey = daysInMonthGrid[idx] {
                        calendarDayCell(for: dKey)
                    } else {
                        Color.clear
                            .frame(height: 72)
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
        let hasDeadline = store.goals.contains { $0.deadline == dateKey }
        let level = dateKey > store.currentDateKey || ov.totalScheduledCount == 0 ? 0 : min(4, max(1, Int(ceil(ov.completionPercentage / 25))))

        return Button {
            selectDateKey(dateKey)
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 2) {
                    Text(L10n.tr("\(dayNum)"))
                        .font(HabitFlowTypography.body(12, weight: isSelected || isToday ? .semibold : .medium))
                        .foregroundStyle(level >= 3 ? palette.onAccent : palette.primaryText)
                    if hasNote {
                        Circle()
                            .fill(palette.accent)
                            .frame(width: 4, height: 4)
                    }
                    Spacer()
                    if hasDeadline {
                        Image(systemName: "flag.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(palette.accentText)
                    }
                }

                if dateKey <= store.currentDateKey && ov.totalScheduledCount > 0 {
                    Text(L10n.tr("\(ov.completedCount)/\(ov.totalScheduledCount)"))
                        .font(HabitFlowTypography.body(10, weight: .medium))
                        .foregroundStyle(level >= 3 ? palette.onAccent : palette.secondaryText)
                } else {
                    Text(L10n.tr(" ")).font(HabitFlowTypography.body(10))
                }
                HStack(spacing: 3) {
                    ForEach(0..<min(3, ov.totalScheduledCount), id: \.self) { index in
                        Circle()
                            .fill(index < ov.completedCount ? palette.accent : palette.secondaryText.opacity(0.55))
                            .frame(width: 4, height: 4)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 72, alignment: .topLeading)
            .padding(.horizontal, 6)
            .padding(.top, 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(dateKey > store.currentDateKey ? palette.heatmapColors[0] :
                          heatmapColor(for: ov.completionPercentage, scheduledCount: ov.totalScheduledCount))
            )
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(isToday || isSelected ? palette.accent : Color.clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .help(L10n.tr("\(dateKey): \(ov.completedCount) из \(ov.totalScheduledCount) выполнено"))
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
                    Text(L10n.tr(title))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)
                    Text(L10n.tr("\(ov.completedCount) completed • \(ov.partialCount) partial • \(ov.incompleteCount) missed (\(Int(ov.completionPercentage))%)"))
                        .font(.system(size: 12))
                        .foregroundStyle(palette.secondaryText)
                }
                Spacer()
            }

            Divider()

            if ov.scheduledStatuses.isEmpty {
                Text(L10n.tr("No habits were scheduled on this date."))
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
                            Text(L10n.tr(st.progressText))
                                .font(.system(size: 11))
                                .foregroundStyle(palette.secondaryText)
                        }
                        Spacer()
                        Text(L10n.tr(st.state.rawValue))
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
                Label(L10n.tr("Daily Notes (\(selectedDateKey))"), systemImage: "note.text")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.primaryText)
                Spacer()
                if noteSavedFeedback {
                    Text(L10n.tr("Saved"))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.green)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.tr("What went well today?"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.secondaryText)
                TextField(L10n.tr("Highlights or wins..."), text: $draftNote.wentWell)
                    .textFieldStyle(.roundedBorder)

                Text(L10n.tr("What was difficult?"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.secondaryText)
                TextField(L10n.tr("Obstacles or distractions..."), text: $draftNote.wasDifficult)
                    .textFieldStyle(.roundedBorder)

                Text(L10n.tr("What would I improve tomorrow?"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.secondaryText)
                TextField(L10n.tr("One concrete adjustment for tomorrow..."), text: $draftNote.improveTomorrow)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Spacer()
                Button(L10n.tr("Save Daily Note")) {
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
    @AppStorage("interfaceLanguage") private var interfaceLanguage = "en"
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
                        Text(L10n.tr("Statistics"))
                            .font(HabitFlowTypography.displayItalic(42, weight: .bold))
                            .foregroundStyle(palette.accentText)
                        Text(L10n.tr("Выполнение, регулярность и серии"))
                            .font(HabitFlowTypography.body(13))
                            .foregroundStyle(palette.secondaryText)
                    }
                    Spacer()

                    Picker(L10n.tr("Период"), selection: $selectedRange) {
                        ForEach(AnalyticsTimeRange.allCases) { r in
                            Text(L10n.tr(rangeTitle(r))).tag(r)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 360)
                }

                // Completion Rate Cards (Daily, Weekly, Monthly, Streaks)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 4), spacing: 14) {
                    metricCard(title: "Выполнено норм", value: "\(stats.totalCompletedHabitInstances)", subtitle: "за выбранный период", color: palette.primaryText)
                    metricCard(title: "Средний процент", value: "\(Int(stats.rangeCompletionRate))%", subtitle: "выполнение по дням", color: palette.primaryText)
                    metricCard(title: "Лучшая серия", value: "\(stats.longestOverallStreak)", subtitle: "дней подряд", color: palette.primaryText)
                    metricCard(title: "Закрыто целей", value: "—", subtitle: "прогресс целей не отслеживается", color: palette.secondaryText)
                }

                activityHeatmap
                HStack(alignment: .top, spacing: 16) {
                    weekdayChart.frame(maxWidth: .infinity)
                    categoryChart.frame(maxWidth: .infinity)
                }
                periodReport

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
                        color: palette.primaryText
                    )
                    metricCard(
                        title: "Total Distance",
                        value: "\(NumberFormattingHelper.format(stats.totalDistanceKilometers)) km",
                        subtitle: "Distance habits only",
                        color: palette.primaryText
                    )
                    metricCard(
                        title: "Total Repetitions",
                        value: "\(NumberFormattingHelper.format(stats.totalRepetitions)) reps",
                        subtitle: "Counter habits only",
                        color: palette.primaryText
                    )
                }

                // Swift Charts Daily Completion Trend
                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.tr("Daily Completion Trend (\(selectedRange.rawValue))"))
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
                        Label(L10n.tr("Most Consistent Habits"), systemImage: "flame.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.green)

                        if stats.mostConsistentHabits.isEmpty {
                            Text(L10n.tr("Complete habits over multiple days to build consistency leaders."))
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
                        Label(L10n.tr("Habits Needing Attention"), systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.orange)

                        if stats.habitsNeedingAttention.isEmpty {
                            Text(L10n.tr("All active habits are maintaining 85%+ consistency!"))
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
            .padding(.horizontal, 40)
            .padding(.vertical, 32)
            .frame(maxWidth: 1280, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private func rangeTitle(_ range: AnalyticsTimeRange) -> String {
        switch range {
        case .days7: return "Неделя"
        case .days30: return "Месяц"
        case .days90: return "90 дней"
        case .days365: return "Год"
        case .allTime: return "Всё время"
        }
    }

    private var activityHeatmap: some View {
        let days = store.heatmapDaysLast365()
        let weeks = stride(from: 0, to: days.count, by: 7).map { Array(days[$0..<min($0 + 7, days.count)]) }
        return VStack(alignment: .leading, spacing: 12) {
            Text(L10n.tr("Активность"))
                .font(HabitFlowTypography.body(16, weight: .semibold))
                .foregroundStyle(palette.primaryText)
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(weeks.indices, id: \.self) { week in
                            VStack(spacing: 4) {
                                ForEach(weeks[week]) { day in
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(heatmapColor(day))
                                        .frame(width: 13, height: 13)
                                        .help(L10n.tr("\(day.dateKey): \(day.completedCount)/\(day.scheduledCount)"))
                                }
                            }
                            .id(week)
                        }
                    }
                }
                .onAppear { proxy.scrollTo(weeks.count - 1, anchor: .trailing) }
            }
            HStack(spacing: 5) {
                Text(L10n.tr("Меньше"))
                ForEach(0..<5, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(palette.heatmapColors[index]).frame(width: 12, height: 12)
                }
                Text(L10n.tr("Больше"))
            }
            .font(HabitFlowTypography.body(10)).foregroundStyle(palette.secondaryText)
        }
        .habitFlowCard(palette: palette)
    }

    private func heatmapColor(_ day: DailyCompletionPoint) -> Color {
        guard day.scheduledCount > 0 else { return palette.heatmapColors[0] }
        return palette.heatmapColors[min(4, max(1, Int(ceil(day.percentage / 25))))]
    }

    private var weekdayChart: some View {
        let points = summary.dailyTrendPoints
        let days = (1...7).map { weekday -> (Int, Double) in
            let matching = points.filter { Calendar.current.component(.weekday, from: $0.date) == weekday && $0.scheduledCount > 0 }
            return (weekday, matching.isEmpty ? 0 : matching.reduce(0) { $0 + $1.percentage } / Double(matching.count))
        }
        let best = days.map(\.1).max() ?? 0
        return VStack(alignment: .leading, spacing: 14) {
            Text(L10n.tr("По дням недели"))
                .font(HabitFlowTypography.body(15, weight: .semibold)).foregroundStyle(palette.primaryText)
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(days, id: \.0) { day in
                    VStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(day.1 == best && best > 0 ? palette.accent : palette.chartBar)
                            .frame(maxWidth: .infinity)
                            .frame(height: max(5, CGFloat(day.1) * 0.75))
                        Text(L10n.tr(L10n.locale.calendar.shortWeekdaySymbols[day.0 - 1]))
                            .font(HabitFlowTypography.body(10)).foregroundStyle(palette.secondaryText)
                            .lineLimit(1)
                    }
                }
            }
            .frame(height: 95, alignment: .bottom)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .habitFlowCard(palette: palette)
    }

    private var categoryChart: some View {
        let active = store.habits.filter { !$0.isArchived }
        let categories = Array(Set(active.map(\.category))).sorted().prefix(4)
        let start = selectedRange.dayCount.map {
            DateKeyHelper.addingDays(-($0 - 1), to: store.currentDateKey)
        } ?? active.map(\.createdAtDateKey).min() ?? store.currentDateKey
        return VStack(alignment: .leading, spacing: 10) {
            Text(L10n.tr("По категориям"))
                .font(HabitFlowTypography.body(15, weight: .semibold)).foregroundStyle(palette.primaryText)
            if categories.isEmpty {
                Text(L10n.tr("Пока нет привычек"))
                    .font(HabitFlowTypography.body(12)).foregroundStyle(palette.secondaryText)
            }
            ForEach(categories, id: \.self) { category in
                let habits = active.filter { $0.category == category }
                let rate = habits.isEmpty ? 0 : habits.reduce(0.0) {
                    $0 + store.calculateHabitMetric(for: $1, startKey: start, endKey: store.currentDateKey).completionRate
                } / Double(habits.count)
                HStack(spacing: 8) {
                    Text(L10n.tr(category))
                        .font(HabitFlowTypography.body(11)).foregroundStyle(palette.secondaryText)
                        .frame(width: 90, alignment: .leading).lineLimit(1)
                    SmoothProgressBar(fraction: rate / 100, accentColor: palette.chartBar,
                                      height: 7, trackColor: palette.progressTrack)
                    Text(L10n.tr("\(Int(rate))%"))
                        .font(HabitFlowTypography.body(11, weight: .semibold))
                        .foregroundStyle(palette.primaryText)
                        .frame(width: 36, alignment: .trailing)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .habitFlowCard(palette: palette)
    }

    private var periodReport: some View {
        let stats = summary
        return HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 7) {
                Text(L10n.tr("Итог периода"))
                    .font(HabitFlowTypography.body(15, weight: .semibold)).foregroundStyle(palette.primaryText)
                Text(L10n.tr("Выполнено \(stats.totalCompletedHabitInstances) норм. Среднее выполнение — \(Int(stats.rangeCompletionRate))%."))
                    .font(HabitFlowTypography.body(12)).foregroundStyle(palette.secondaryText)
            }
            Spacer()
            ForEach([7, 30, 100], id: \.self) { target in
                VStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(stats.longestOverallStreak >= target ? palette.accentText : palette.secondaryText)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(palette.secondarySurface))
                    Text(L10n.tr("\(target) дн."))
                        .font(HabitFlowTypography.body(10)).foregroundStyle(palette.secondaryText)
                }
                .help(L10n.tr(stats.longestOverallStreak >= target ? "Бейдж получен" : "Осталось \(target - stats.longestOverallStreak) дней"))
            }
        }
        .habitFlowCard(palette: palette)
    }

    private func metricCard(title: String, value: String, subtitle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.tr(title))
                .font(HabitFlowTypography.body(11, weight: .medium))
                .foregroundStyle(palette.secondaryText)
            Text(L10n.tr(value))
                .font(HabitFlowTypography.number(32, weight: .bold))
                .foregroundStyle(color)
            Text(L10n.tr(subtitle))
                .font(HabitFlowTypography.body(11))
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
                    Text(L10n.tr("Streak: \(item.currentStreak)d (Best \(item.longestStreak)d) • \(item.completedDays)/\(item.scheduledDays) days"))
                        .font(.system(size: 11))
                        .foregroundStyle(palette.secondaryText)
                }
                Spacer()
                Text(L10n.tr("\(Int(item.completionRate))%"))
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
    @AppStorage("interfaceLanguage") private var interfaceLanguage = "en"
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
                    Text(L10n.tr("\(habit.name) — Detailed Analytics"))
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)
                    Text(L10n.tr("\(habit.category) • \(habit.measurementType.rawValue) (\(habit.unit))"))
                        .font(.system(size: 12))
                        .foregroundStyle(palette.secondaryText)
                }
                Spacer()
                Button(L10n.tr("Close")) { dismiss() }
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
                Text(L10n.tr("Last 14 Days Performance"))
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
                Text(L10n.tr("Effective-Dated Target History"))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(palette.primaryText)
                ForEach(habit.targetHistory) { th in
                    HStack {
                        Text(L10n.tr("Effective from \(th.effectiveDateKey):"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(palette.secondaryText)
                        Spacer()
                        Text(L10n.tr("Daily Target: \(NumberFormattingHelper.format(th.dailyTarget)) \(habit.unit) (Quick-Add +\(NumberFormattingHelper.format(th.quickAddIncrement)))"))
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
            Text(L10n.tr(label))
                .font(.system(size: 11))
                .foregroundStyle(palette.secondaryText)
            Text(L10n.tr(value))
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(palette.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .habitFlowCard(palette: palette, padding: 12)
    }
}
