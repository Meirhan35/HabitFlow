import SwiftUI

// MARK: - Section 4, 5, 8, 9 & 23: Clean Dashboard View

public struct DashboardView: View {
    @AppStorage("interfaceLanguage") private var interfaceLanguage = "en"
    @EnvironmentObject private var store: HabitStore
    @EnvironmentObject private var timerManager: ActiveHabitTimerManager
    @EnvironmentObject private var assistantHistory: AssistantChatStore

    public let palette: HabitFlowPalette
    public let onAddHabit: () -> Void
    public let onEditHabit: (Habit) -> Void
    public let onOpenAssistant: () -> Void
    public let onOpenAllMissedHistory: () -> Void

    @State private var expandedMissedDateKeys: Set<String> = []
    @State private var habitShowingEntriesPopover: UUID? = nil
    @State private var quickGoalText = ""

    public init(
        palette: HabitFlowPalette,
        onAddHabit: @escaping () -> Void,
        onEditHabit: @escaping (Habit) -> Void,
        onOpenAssistant: @escaping () -> Void,
        onOpenAllMissedHistory: @escaping () -> Void
    ) {
        self.palette = palette
        self.onAddHabit = onAddHabit
        self.onEditHabit = onEditHabit
        self.onOpenAssistant = onOpenAssistant
        self.onOpenAllMissedHistory = onOpenAllMissedHistory
    }

    private var todayOverview: DailyProgressOverview {
        store.dailyProgressOverview(for: store.currentDateKey)
    }

    private var unfinishedStatuses: [DailyHabitStatus] {
        todayOverview.scheduledStatuses.filter { !$0.isCompleted }
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                dashboardHeader
                HStack(alignment: .top, spacing: 16) {
                    focusCard.frame(maxWidth: .infinity)
                    todayRingCard.frame(width: 220)
                }
                if !store.goals.isEmpty { savedGoalsSection }
                habitStrip
                activityOverview
                todaysHabitsSection
                todaysRemainingGoalsSection
                if store.isMissedDaysUnlockedOnDashboard {
                    conditionalMissedDaysSection
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .bottom)),
                            removal: .opacity
                        ))
                }
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 32)
            .frame(maxWidth: 1280, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.84), value: store.isMissedDaysUnlockedOnDashboard)
    }

    // MARK: - 1. Header

    private var dashboardHeader: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.tr(formattedDayAndDate))
                    .font(HabitFlowTypography.body(12, weight: .semibold))
                    .foregroundStyle(palette.secondaryText)
                    .textCase(.uppercase)

                HStack(spacing: 6) {
                    Text(L10n.tr("Добрый"))
                        .foregroundStyle(palette.primaryText)
                    Text(L10n.tr(welcomeHeadline))
                        .italic()
                        .foregroundStyle(palette.accentText)
                }
                .font(HabitFlowTypography.display(44, weight: .bold))

                if store.settings.showMotivationalGreeting {
                    Text(L10n.tr(welcomeSubtitle))
                        .font(HabitFlowTypography.body(13))
                        .foregroundStyle(palette.secondaryText)
                }
            }

            Spacer()

            HStack(spacing: 0) {
                TextField(L10n.tr("Быстро добавить цель или привычку…"), text: $quickGoalText)
                    .textFieldStyle(.plain)
                    .font(HabitFlowTypography.body(13))
                    .onSubmit(submitQuickGoal)
                    .padding(.leading, 14)
                Button(L10n.tr("Добавить"), action: submitQuickGoal)
                    .font(HabitFlowTypography.body(12, weight: .semibold))
                    .foregroundStyle(palette.onAccent)
                    .padding(.horizontal, 14)
                    .frame(height: 36)
                    .background(Capsule().fill(palette.accent))
                    .buttonStyle(.plain)
                    .disabled(quickGoalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .frame(width: 280, height: 38)
            .background(Capsule().fill(palette.cardBackground))
            .overlay(Capsule().strokeBorder(palette.subtleBorder))

            Button {
                store.settings.appearanceMode = palette.colorScheme == .dark ? .light : .dark
            } label: {
                Image(systemName: palette.colorScheme == .dark ? "sun.max" : "moon")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.primaryText)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(palette.cardBackground))
                    .overlay(Circle().strokeBorder(palette.subtleBorder))
            }
            .buttonStyle(.plain)
            .help(L10n.tr("Сменить тему"))
        }
    }

    private func submitQuickGoal() {
        let prompt = quickGoalText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }
        assistantHistory.pendingPrompt = prompt
        quickGoalText = ""
        onOpenAssistant()
    }

    private var focusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.tr("ФОКУС ДНЯ"))
                    .font(HabitFlowTypography.body(11, weight: .semibold))
                    .tracking(2)
                    .foregroundStyle(Color.white.opacity(0.75))
                Spacer()
                if !unfinishedStatuses.isEmpty {
                    Text(L10n.tr("СЕГОДНЯ"))
                        .font(HabitFlowTypography.body(10, weight: .semibold))
                        .foregroundStyle(palette.onAccent)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(palette.accent))
                }
            }
            if let focus = unfinishedStatuses.first {
                Text(focus.habit.name)
                    .font(HabitFlowTypography.display(34, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text(L10n.tr(focus.progressText))
                    .font(HabitFlowTypography.body(12))
                    .foregroundStyle(Color.white.opacity(0.75))
                SmoothProgressBar(fraction: focus.progressFraction, accentColor: palette.accent,
                                  height: 10, trackColor: Color.white.opacity(0.18))
                Button { store.quickAdd(for: focus.habit.id, on: store.currentDateKey) } label: {
                    Label(L10n.tr("Отметить норму"), systemImage: "checkmark")
                        .font(HabitFlowTypography.body(12, weight: .semibold))
                        .foregroundStyle(palette.onAccent)
                        .padding(.horizontal, 15).frame(height: 36)
                        .background(Capsule().fill(palette.accent))
                }
                .buttonStyle(.plain)
            } else {
                Text(L10n.tr(todayOverview.totalScheduledCount == 0 ? "Выберите первую привычку" : "Всё на сегодня готово"))
                    .font(HabitFlowTypography.display(32, weight: .bold))
                    .foregroundStyle(.white)
                Text(L10n.tr(todayOverview.totalScheduledCount == 0 ? "Добавьте привычку, чтобы начать." : "Вы выполнили все запланированные нормы."))
                    .font(HabitFlowTypography.body(12))
                    .foregroundStyle(Color.white.opacity(0.75))
                Spacer(minLength: 32)
                if todayOverview.totalScheduledCount == 0 {
                    Button(L10n.tr("Добавить привычку"), action: onAddHabit)
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, minHeight: 220, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 22).fill(palette.heroBackground))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(palette.subtleBorder))
    }

    private var todayRingCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.tr("Сегодня"))
                .font(HabitFlowTypography.body(15, weight: .semibold))
                .foregroundStyle(palette.primaryText)
            Spacer(minLength: 0)
            ZStack {
                Circle().stroke(palette.progressTrack, lineWidth: 10)
                Circle().trim(from: 0, to: todayOverview.progressFraction)
                    .stroke(palette.accent, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(L10n.tr("\(Int(todayOverview.completionPercentage))%"))
                    .font(HabitFlowTypography.number(32))
                    .foregroundStyle(palette.primaryText)
            }
            .frame(width: 104, height: 104)
            .frame(maxWidth: .infinity)
            Spacer(minLength: 0)
            Text(L10n.tr("\(todayOverview.completedCount) из \(todayOverview.totalScheduledCount) выполнено"))
                .font(HabitFlowTypography.body(12))
                .foregroundStyle(palette.secondaryText)
        }
        .padding(20)
        .frame(height: 220)
        .background(RoundedRectangle(cornerRadius: 22).fill(palette.cardBackground))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(palette.subtleBorder))
    }

    private var savedGoalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.tr("Мои цели"))
                .font(HabitFlowTypography.body(16, weight: .semibold))
                .foregroundStyle(palette.primaryText)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 16)], spacing: 16) {
                ForEach(store.goals.prefix(3)) { goal in
                    VStack(alignment: .leading, spacing: 9) {
                        Text(goal.title)
                            .font(HabitFlowTypography.body(14, weight: .semibold))
                            .foregroundStyle(palette.primaryText)
                            .lineLimit(2)
                        Text(L10n.tr("\(goal.target.formatted()) \(goal.unit)"))
                            .font(HabitFlowTypography.number(31))
                            .foregroundStyle(palette.accentText)
                        Text(L10n.tr("До \(goal.deadline) · \(goal.milestones.count) этапов"))
                            .font(HabitFlowTypography.body(12))
                            .foregroundStyle(palette.secondaryText)
                        Text(L10n.tr("Прогресс цели пока не отслеживается"))
                            .font(HabitFlowTypography.body(11))
                            .foregroundStyle(palette.secondaryText)
                    }
                    .frame(maxWidth: .infinity, minHeight: 115, alignment: .topLeading)
                    .habitFlowCard(palette: palette)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(palette.priorityColor(goal.priority))
                            .frame(width: 3)
                            .padding(.vertical, 18)
                    }
                }
            }
        }
    }

    private var habitStrip: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.tr("Привычки сегодня"))
                .font(HabitFlowTypography.body(16, weight: .semibold))
                .foregroundStyle(palette.primaryText)
            if todayOverview.scheduledStatuses.isEmpty {
                Text(L10n.tr("Пока нет запланированных привычек"))
                    .font(HabitFlowTypography.body(12))
                    .foregroundStyle(palette.secondaryText)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        ForEach(todayOverview.scheduledStatuses) { status in
                            VStack(spacing: 6) {
                                ZStack {
                                    Circle()
                                        .fill(status.isCompleted ? palette.accent : palette.secondarySurface)
                                        .frame(width: 44, height: 44)
                                    Circle()
                                        .strokeBorder(status.isCompleted ? palette.accent : palette.subtleBorder, lineWidth: 1)
                                        .frame(width: 44, height: 44)
                                    Image(systemName: status.isCompleted ? "checkmark" : status.habit.icon)
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundStyle(status.isCompleted ? palette.onAccent : palette.primaryText)
                                }
                                Text(status.habit.name)
                                    .font(HabitFlowTypography.body(11, weight: .medium))
                                    .foregroundStyle(palette.primaryText)
                                    .lineLimit(1)
                                    .frame(width: 86)
                            }
                        }
                    }
                }
            }
        }
        .habitFlowCard(palette: palette)
    }

    private var activityOverview: some View {
        let days = Array(store.heatmapDaysLast365().suffix(42))
        return HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 14) {
                Text(L10n.tr("Активность"))
                    .font(HabitFlowTypography.body(15, weight: .semibold))
                    .foregroundStyle(palette.primaryText)
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(14), spacing: 5), count: 21), spacing: 5) {
                    ForEach(days) { day in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(heatmapColor(day))
                            .frame(width: 14, height: 14)
                            .help(L10n.tr("\(day.dateKey): \(Int(day.percentage))%"))
                    }
                }
                HStack(spacing: 5) {
                    Text(L10n.tr("Меньше"))
                    ForEach(0..<5, id: \.self) { level in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(palette.heatmapColors[level])
                            .frame(width: 12, height: 12)
                    }
                    Text(L10n.tr("Больше"))
                }
                .font(HabitFlowTypography.body(10))
                .foregroundStyle(palette.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .habitFlowCard(palette: palette)

            VStack(alignment: .leading, spacing: 14) {
                Text(L10n.tr("Неделя"))
                    .font(HabitFlowTypography.body(15, weight: .semibold))
                    .foregroundStyle(palette.primaryText)
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(Array(days.suffix(7))) { day in
                        VStack(spacing: 5) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(day.dateKey == store.currentDateKey ? palette.accent : palette.chartBar)
                                .frame(maxWidth: .infinity)
                                .frame(height: max(5, CGFloat(day.percentage) * 0.55))
                            Text(L10n.tr(day.date.formatted(.dateTime.weekday(.narrow).locale(L10n.locale))))
                                .font(HabitFlowTypography.body(10))
                                .foregroundStyle(palette.secondaryText)
                        }
                    }
                }
                .frame(height: 75, alignment: .bottom)
            }
            .frame(width: 170, alignment: .leading)
            .habitFlowCard(palette: palette)
        }
    }

    private func heatmapColor(_ day: DailyCompletionPoint) -> Color {
        guard day.scheduledCount > 0 else { return palette.heatmapColors[0] }
        let level = min(4, max(1, Int(ceil(day.percentage / 25))))
        return palette.heatmapColors[level]
    }

    private var formattedDayAndDate: String {
        guard let date = DateKeyHelper.date(from: store.currentDateKey) else {
            return store.currentDateKey
        }
        let df = DateFormatter()
        df.locale = L10n.locale
        df.setLocalizedDateFormatFromTemplate("EEEE MMMM d yyyy")
        return df.string(from: date)
    }

    private var welcomeHeadline: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "утро." }
        if hour < 18 { return "день." }
        return "вечер."
    }

    private var welcomeSubtitle: String {
        if todayOverview.allScheduledCompleted {
            return "All of today's scheduled habits are complete. Great consistency!"
        }
        let rem = todayOverview.totalScheduledCount - todayOverview.completedCount
        if rem == 1 {
            return "1 scheduled habit remaining to complete today's goals."
        }
        return "\(rem) scheduled habits remaining for today."
    }

    // MARK: - 2. Daily Progress Overview

    private var dailyProgressOverviewCard: some View {
        let ov = todayOverview
        let remainingHabitsCount = max(0, ov.totalScheduledCount - ov.completedCount)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(L10n.tr("Daily Progress: \(Int(ov.completionPercentage))%"))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.primaryText)

                Spacer()

                HStack(spacing: 14) {
                    Label(L10n.tr("\(ov.completedCount) of \(ov.totalScheduledCount) habits completed"), systemImage: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(ov.allScheduledCompleted ? palette.accent : palette.secondaryText)

                    if remainingHabitsCount > 0 {
                        Text(L10n.tr("•"))
                            .foregroundStyle(palette.secondaryText)
                        Text(L10n.tr("\(remainingHabitsCount) remaining"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(palette.secondaryText)
                    }
                }
            }

            SmoothProgressBar(
                fraction: ov.progressFraction,
                accentColor: palette.accent,
                height: 10,
                trackColor: palette.secondarySurface
            )
        }
        .habitFlowCard(palette: palette, padding: 18)
    }

    // MARK: - 3. Today's Habits

    private var todaysHabitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.tr("Today's Habits"))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.primaryText)

                Spacer()

                Text(L10n.tr("\(todayOverview.scheduledStatuses.count) scheduled"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(palette.secondaryText)
            }

            if todayOverview.scheduledStatuses.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 24))
                        .foregroundStyle(palette.accent)
                    Text(L10n.tr("No habits scheduled for today"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(palette.primaryText)
                    Text(L10n.tr("Click + Add Habit to create your daily routine."))
                        .font(.system(size: 13))
                        .foregroundStyle(palette.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .habitFlowCard(palette: palette)
            } else {
                VStack(spacing: 10) {
                    ForEach(todayOverview.scheduledStatuses) { status in
                        DashboardHabitRowView(
                            status: status,
                            palette: palette,
                            showDecreaseButton: store.settings.showDecreaseButtonsOnDashboard,
                            isEntriesPopoverPresented: Binding(
                                get: { habitShowingEntriesPopover == status.habit.id },
                                set: { isShown in
                                    habitShowingEntriesPopover = isShown ? status.habit.id : nil
                                }
                            ),
                            onQuickAdd: {
                                store.quickAdd(for: status.habit.id, on: store.currentDateKey)
                            },
                            onQuickDecrease: {
                                store.quickDecrease(for: status.habit.id, on: store.currentDateKey)
                            },
                            onEditHabit: {
                                onEditHabit(status.habit)
                            }
                        )
                    }
                }
            }
        }
    }

    // MARK: - 4. Today's Remaining Goals

    private var todaysRemainingGoalsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.tr("Today's Remaining Goals"))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.primaryText)

                Spacer()

                if todayOverview.totalEstimatedRemainingMinutes > 0 {
                    Label(L10n.tr("~\(todayOverview.totalEstimatedRemainingMinutes) min left"), systemImage: "clock")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(palette.secondaryText)
                }
            }

            if unfinishedStatuses.isEmpty && todayOverview.totalScheduledCount > 0 {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(palette.accent)
                    Text(L10n.tr("All scheduled goals for today have been completed!"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(palette.primaryText)
                    Spacer()
                }
            } else if unfinishedStatuses.isEmpty {
                Text(L10n.tr("No remaining goals scheduled for today."))
                    .font(.system(size: 13))
                    .foregroundStyle(palette.secondaryText)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(unfinishedStatuses) { st in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(palette.accent)
                                .frame(width: 6, height: 6)
                            Text(L10n.tr(st.remainingSummaryText))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(palette.primaryText)
                            Spacer()
                        }
                    }
                }
            }
        }
        .habitFlowCard(palette: palette, padding: 16)
    }

    // MARK: - 5. Missed Days (Conditionally Revealed Only After 100% of Today's Scheduled Habits Complete)

    private var conditionalMissedDaysSection: some View {
        let allMissed = store.allMissedDaysHistory(lookbackDays: 60)
        let latestThree = Array(allMissed.prefix(3))
        let totalMissedHabitsCount = allMissed.reduce(0) { $0 + $1.missedOrPartialStatuses.count }

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.open.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(palette.accent)
                        Text(L10n.tr("Missed Days"))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(palette.primaryText)
                    }

                    if !allMissed.isEmpty {
                        Text(L10n.tr("\(allMissed.count) previous missed days • \(totalMissedHabitsCount) unfinished habits"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(palette.secondaryText)
                    }
                }

                Spacer()

                Button(action: onOpenAllMissedHistory) {
                    HStack(spacing: 5) {
                        Text(L10n.tr("View All History"))
                            .font(.system(size: 12, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(palette.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(palette.accent.opacity(0.12))
                    )
                }
                .buttonStyle(.plain)
            }

            if latestThree.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16))
                        .foregroundStyle(palette.accent)
                    Text(L10n.tr("You're all caught up!"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(palette.primaryText)
                    Spacer()
                }
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 10) {
                    ForEach(latestThree) { record in
                        let isExpanded = !expandedMissedDateKeys.contains(record.dateKey) // Default expanded for immediate clarity, toggleable
                        VStack(alignment: .leading, spacing: 8) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    if expandedMissedDateKeys.contains(record.dateKey) {
                                        expandedMissedDateKeys.remove(record.dateKey)
                                    } else {
                                        expandedMissedDateKeys.insert(record.dateKey)
                                    }
                                }
                            } label: {
                                HStack {
                                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(palette.secondaryText)
                                        .frame(width: 14)

                                    Text(L10n.tr(record.friendlyTitle))
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(palette.primaryText)

                                    Spacer()

                                    Text(L10n.tr("\(record.missedOrPartialStatuses.count) unfinished • \(Int(record.completionPercentage))% day completion"))
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(palette.secondaryText)
                                }
                            }
                            .buttonStyle(.plain)

                            if isExpanded {
                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(record.missedOrPartialStatuses) { st in
                                        HStack(spacing: 8) {
                                            Circle()
                                                .fill(st.state == .partial ? Color.orange : Color.red.opacity(0.8))
                                                .frame(width: 6, height: 6)
                                            Text(L10n.tr("\(st.habit.name):"))
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundStyle(palette.primaryText)
                                            if st.state == .notStarted {
                                                Text(L10n.tr("Not completed"))
                                                    .font(.system(size: 12))
                                                    .foregroundStyle(palette.secondaryText)
                                            } else {
                                                Text(L10n.tr(st.progressText))
                                                    .font(.system(size: 12))
                                                    .foregroundStyle(palette.secondaryText)
                                            }
                                            Spacer()
                                        }
                                        .padding(.leading, 22)
                                    }
                                }
                                .padding(.top, 2)
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(palette.secondarySurface.opacity(0.65))
                        )
                    }
                }
            }
        }
        .habitFlowCard(palette: palette, padding: 18)
    }
}

// MARK: - Dashboard Habit Row with Inline Quick-Add [-][+] & Multi-Entry Popover

public struct DashboardHabitRowView: View {
    @AppStorage("interfaceLanguage") private var interfaceLanguage = "en"
    @EnvironmentObject private var store: HabitStore
    @EnvironmentObject private var timerManager: ActiveHabitTimerManager

    public let status: DailyHabitStatus
    public let palette: HabitFlowPalette
    public let showDecreaseButton: Bool
    @Binding public var isEntriesPopoverPresented: Bool
    public let onQuickAdd: () -> Void
    public let onQuickDecrease: () -> Void
    public let onEditHabit: () -> Void

    @State private var customEntryAmountText: String = ""
    @State private var customEntryLabelText: String = "Morning"

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 14) {
                HabitIconBadge(
                    icon: status.habit.icon,
                    accent: palette.accent,
                    isCompleted: status.isCompleted,
                    size: 40
                )

                // Habit Name, Category, Current Progress & Remaining
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(status.habit.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(palette.primaryText)

                        Text(L10n.tr(status.habit.category))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(palette.secondaryText)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(palette.secondarySurface)
                            )

                        if status.entries.count > 1 {
                            Button {
                                isEntriesPopoverPresented.toggle()
                            } label: {
                                Text(L10n.tr("\(status.entries.count) entries"))
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(palette.accent)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill(palette.accent.opacity(0.14))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    HStack(spacing: 10) {
                        Text(L10n.tr(status.progressText))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(status.isCompleted ? palette.accent : palette.primaryText)

                        if !status.isCompleted && status.habit.measurementType != .checkbox {
                            Text(L10n.tr("•"))
                                .foregroundStyle(palette.secondaryText)
                            Text(L10n.tr("\(NumberFormattingHelper.format(status.remainingAmount)) \(status.habit.unit) left"))
                                .font(.system(size: 12))
                                .foregroundStyle(palette.secondaryText)
                        } else if status.isCompleted {
                            Text(L10n.tr("• Completed"))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(palette.accent)
                        }
                    }
                }

                Spacer()

                // Optional Duration Timer Quick Button for Duration Habits
                if status.habit.measurementType == .duration {
                    let isTimingThis = (timerManager.activeHabitId == status.habit.id)
                    Button {
                        if isTimingThis && timerManager.isRunning {
                            timerManager.stopAndCommit(into: store)
                        } else {
                            timerManager.startOrResume(for: status.habit.id)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: isTimingThis && timerManager.isRunning ? "stop.fill" : "timer")
                                .font(.system(size: 11, weight: .semibold))
                            Text(L10n.tr(isTimingThis ? timerManager.formattedElapsed : "Timer"))
                                .font(.system(size: 11, weight: .semibold, design: isTimingThis ? .monospaced : .default))
                        }
                        .foregroundStyle(isTimingThis ? .white : palette.secondaryText)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(isTimingThis ? Color.orange : palette.secondarySurface)
                        )
                    }
                    .buttonStyle(.plain)
                    .help(L10n.tr("Start or log built-in duration timer"))
                }

                // Multi-entry log button
                Button {
                    isEntriesPopoverPresented.toggle()
                } label: {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(palette.secondaryText)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(palette.secondarySurface)
                        )
                }
                .buttonStyle(.plain)
                .help(L10n.tr("View or add multiple daily entries"))
                .popover(isPresented: $isEntriesPopoverPresented, arrowEdge: .bottom) {
                    multiEntriesPopoverContent
                }

                // Inline Instant Controls: [ - ] [ + ] or [ Complete ]
                inlineQuickControls
            }

            // Progress Bar
            SmoothProgressBar(
                fraction: status.progressFraction,
                accentColor: status.isCompleted ? .green : palette.accent,
                height: 6,
                trackColor: palette.secondarySurface
            )
        }
        .habitFlowCard(palette: palette, padding: 14, cornerRadius: 12)
        .contextMenu {
            Button(L10n.tr("Edit Habit...")) { onEditHabit() }
            Button(L10n.tr("Manage Today's Entries...")) { isEntriesPopoverPresented = true }
            Divider()
            Button(L10n.tr(status.habit.isPaused ? "Resume Habit" : "Pause Habit")) {
                store.togglePauseHabit(status.habit.id)
            }
        }
    }

    @ViewBuilder
    private var inlineQuickControls: some View {
        if status.habit.measurementType == .checkbox {
            Button(action: onQuickAdd) {
                HStack(spacing: 6) {
                    Image(systemName: status.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 13, weight: .semibold))
                    Text(L10n.tr(status.isCompleted ? "Completed" : "Complete"))
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(status.isCompleted ? .white : palette.primaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(status.isCompleted ? palette.accent : palette.secondarySurface)
                )
            }
            .buttonStyle(.plain)
        } else {
            HStack(spacing: 6) {
                if showDecreaseButton {
                    Button(action: onQuickDecrease) {
                        Image(systemName: "minus")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(status.completedAmount > 0 ? palette.primaryText : palette.secondaryText.opacity(0.4))
                            .frame(width: 30, height: 28)
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(palette.secondarySurface)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(status.completedAmount <= 0)
                    .help(L10n.tr("Subtract \(NumberFormattingHelper.format(status.quickAddIncrement)) \(status.habit.unit)"))
                }

                Button(action: onQuickAdd) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                        Text(L10n.tr(NumberFormattingHelper.format(status.quickAddIncrement)))
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(status.isCompleted ? palette.accent : palette.accent)
                    )
                }
                .buttonStyle(.plain)
                .help(L10n.tr("Quick add +\(NumberFormattingHelper.format(status.quickAddIncrement)) \(status.habit.unit)"))
            }
        }
    }

    private var multiEntriesPopoverContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.tr("\(status.habit.name) — Today's Entries"))
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                Text(L10n.tr("Total: \(status.progressText)"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.accent)
            }

            Divider()

            if status.entries.isEmpty {
                Text(L10n.tr("No progress entries logged today yet."))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(status.entries) { entry in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(L10n.tr(entry.label))
                                        .font(.system(size: 12, weight: .semibold))
                                    Text(entry.timestamp, style: .time)
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(L10n.tr("+\(NumberFormattingHelper.format(entry.amount)) \(status.habit.unit)"))
                                    .font(.system(size: 12, weight: .bold))
                                Button {
                                    store.deleteProgressEntry(entry.id)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .frame(maxHeight: 160)
            }

            Divider()

            Text(L10n.tr("Add Specific Session Entry"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Picker(L10n.tr(""), selection: $customEntryLabelText) {
                    Text(L10n.tr("Morning")).tag("Morning")
                    Text(L10n.tr("Afternoon")).tag("Afternoon")
                    Text(L10n.tr("Evening")).tag("Evening")
                }
                .labelsHidden()
                .frame(width: 110)

                TextField(L10n.tr("Amount (\(status.habit.unit))"), text: $customEntryAmountText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)

                Button(L10n.tr("Add")) {
                    if let val = Double(customEntryAmountText), val > 0 {
                        store.addProgressEntry(
                            for: status.habit.id,
                            dateKey: status.dateKey,
                            amount: val,
                            label: customEntryLabelText
                        )
                        customEntryAmountText = ""
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(14)
        .frame(width: 340)
    }
}
