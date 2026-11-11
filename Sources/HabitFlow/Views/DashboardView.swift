import SwiftUI

// MARK: - Section 4, 5, 8, 9 & 23: Clean Dashboard View

public struct DashboardView: View {
    @EnvironmentObject private var store: HabitStore
    @EnvironmentObject private var timerManager: ActiveHabitTimerManager

    public let palette: HabitFlowPalette
    public let onAddHabit: () -> Void
    public let onEditHabit: (Habit) -> Void
    public let onOpenAssistant: () -> Void
    public let onOpenAllMissedHistory: () -> Void

    @State private var expandedMissedDateKeys: Set<String> = []
    @State private var habitShowingEntriesPopover: UUID? = nil

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
            VStack(alignment: .leading, spacing: 24) {
                // 1. HEADER: Current date, day of the week, short welcome message, + Add Habit button
                dashboardHeader

                // 2. DAILY PROGRESS OVERVIEW: Compact daily completion percentage, completed/remaining counts, simple progress bar
                dailyProgressOverviewCard

                if !store.goals.isEmpty { savedGoalsSection }

                // 3. TODAY'S HABITS: Clean minimalistic rows with inline quick-add controls
                todaysHabitsSection

                // 4. TODAY'S REMAINING GOALS: Compact summary of unfinished work
                todaysRemainingGoalsSection

                // 5. MISSED DAYS — CONDITIONAL VISIBILITY:
                // Appears ONLY AFTER ALL of today's scheduled habits have reached 100% of their target.
                // Immediately hides if any habit is reduced or unchecked.
                if store.isMissedDaysUnlockedOnDashboard {
                    conditionalMissedDaysSection
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .bottom)),
                            removal: .opacity
                        ))
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 28)
            .frame(maxWidth: 960, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.84), value: store.isMissedDaysUnlockedOnDashboard)
    }

    // MARK: - 1. Header

    private var dashboardHeader: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(formattedDayAndDate)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.accent)
                    .textCase(.uppercase)

                Text(welcomeHeadline)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.primaryText)

                if store.settings.showMotivationalGreeting {
                    Text(welcomeSubtitle)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(palette.secondaryText)
                }
            }

            Spacer()

            Button(action: onOpenAssistant) {
                Label("Assistant", systemImage: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(.bordered)

            Button(action: onAddHabit) {
                HStack(spacing: 7) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                    Text("Add Habit")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(palette.accent)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var savedGoalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Мои цели").font(.system(size: 18, weight: .bold, design: .rounded)).foregroundStyle(palette.primaryText)
            ForEach(store.goals) { goal in
                HStack(alignment: .top) {
                    Image(systemName: "target").foregroundStyle(palette.accent)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(goal.title).font(.system(size: 14, weight: .semibold)).foregroundStyle(palette.primaryText)
                        Text("\(goal.target.formatted()) \(goal.unit) · до \(goal.deadline) · \(goal.milestones.count) этапов")
                            .font(.system(size: 12)).foregroundStyle(palette.secondaryText)
                    }
                    Spacer()
                }.padding(12).background(palette.secondarySurface, in: RoundedRectangle(cornerRadius: 10))
            }
        }.habitFlowCard(palette: palette)
    }

    private var formattedDayAndDate: String {
        guard let date = DateKeyHelper.date(from: store.currentDateKey) else {
            return store.currentDateKey
        }
        let df = DateFormatter()
        df.dateFormat = "EEEE, MMMM d, yyyy"
        return df.string(from: date)
    }

    private var welcomeHeadline: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning" }
        if hour < 18 { return "Good afternoon" }
        return "Good evening"
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
                Text("Daily Progress: \(Int(ov.completionPercentage))%")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.primaryText)

                Spacer()

                HStack(spacing: 14) {
                    Label("\(ov.completedCount) of \(ov.totalScheduledCount) habits completed", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(ov.allScheduledCompleted ? Color.green : palette.secondaryText)

                    if remainingHabitsCount > 0 {
                        Text("•")
                            .foregroundStyle(palette.secondaryText)
                        Text("\(remainingHabitsCount) remaining")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(palette.secondaryText)
                    }
                }
            }

            SmoothProgressBar(
                fraction: ov.progressFraction,
                accentColor: ov.allScheduledCompleted ? .green : palette.accent,
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
                Text("Today's Habits")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.primaryText)

                Spacer()

                Text("\(todayOverview.scheduledStatuses.count) scheduled")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(palette.secondaryText)
            }

            if todayOverview.scheduledStatuses.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 24))
                        .foregroundStyle(palette.accent)
                    Text("No habits scheduled for today")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(palette.primaryText)
                    Text("Click + Add Habit to create your daily routine.")
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
                Text("Today's Remaining Goals")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.primaryText)

                Spacer()

                if todayOverview.totalEstimatedRemainingMinutes > 0 {
                    Label("~\(todayOverview.totalEstimatedRemainingMinutes) min left", systemImage: "clock")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(palette.secondaryText)
                }
            }

            if unfinishedStatuses.isEmpty && todayOverview.totalScheduledCount > 0 {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.green)
                    Text("All scheduled goals for today have been completed!")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(palette.primaryText)
                    Spacer()
                }
            } else if unfinishedStatuses.isEmpty {
                Text("No remaining goals scheduled for today.")
                    .font(.system(size: 13))
                    .foregroundStyle(palette.secondaryText)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(unfinishedStatuses) { st in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(palette.accent)
                                .frame(width: 6, height: 6)
                            Text(st.remainingSummaryText)
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
                            .foregroundStyle(.green)
                        Text("Missed Days")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(palette.primaryText)
                    }

                    if !allMissed.isEmpty {
                        Text("\(allMissed.count) previous missed days • \(totalMissedHabitsCount) unfinished habits")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(palette.secondaryText)
                    }
                }

                Spacer()

                Button(action: onOpenAllMissedHistory) {
                    HStack(spacing: 5) {
                        Text("View All History")
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
                        .foregroundStyle(.green)
                    Text("You're all caught up!")
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

                                    Text(record.friendlyTitle)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(palette.primaryText)

                                    Spacer()

                                    Text("\(record.missedOrPartialStatuses.count) unfinished • \(Int(record.completionPercentage))% day completion")
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
                                            Text("\(st.habit.name):")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundStyle(palette.primaryText)
                                            if st.state == .notStarted {
                                                Text("Not completed")
                                                    .font(.system(size: 12))
                                                    .foregroundStyle(palette.secondaryText)
                                            } else {
                                                Text(st.progressText)
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

                        Text(status.habit.category)
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
                                Text("\(status.entries.count) entries")
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
                        Text(status.progressText)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(status.isCompleted ? Color.green : palette.primaryText)

                        if !status.isCompleted && status.habit.measurementType != .checkbox {
                            Text("•")
                                .foregroundStyle(palette.secondaryText)
                            Text("\(NumberFormattingHelper.format(status.remainingAmount)) \(status.habit.unit) left")
                                .font(.system(size: 12))
                                .foregroundStyle(palette.secondaryText)
                        } else if status.isCompleted {
                            Text("• Completed")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.green)
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
                            Text(isTimingThis ? timerManager.formattedElapsed : "Timer")
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
                    .help("Start or log built-in duration timer")
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
                .help("View or add multiple daily entries")
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
            Button("Edit Habit...") { onEditHabit() }
            Button("Manage Today's Entries...") { isEntriesPopoverPresented = true }
            Divider()
            Button(status.habit.isPaused ? "Resume Habit" : "Pause Habit") {
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
                    Text(status.isCompleted ? "Completed" : "Complete")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(status.isCompleted ? .white : palette.primaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(status.isCompleted ? Color.green : palette.secondarySurface)
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
                    .help("Subtract \(NumberFormattingHelper.format(status.quickAddIncrement)) \(status.habit.unit)")
                }

                Button(action: onQuickAdd) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                        Text(NumberFormattingHelper.format(status.quickAddIncrement))
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(status.isCompleted ? Color.green : palette.accent)
                    )
                }
                .buttonStyle(.plain)
                .help("Quick add +\(NumberFormattingHelper.format(status.quickAddIncrement)) \(status.habit.unit)")
            }
        }
    }

    private var multiEntriesPopoverContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(status.habit.name) — Today's Entries")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                Text("Total: \(status.progressText)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.accent)
            }

            Divider()

            if status.entries.isEmpty {
                Text("No progress entries logged today yet.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(status.entries) { entry in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.label)
                                        .font(.system(size: 12, weight: .semibold))
                                    Text(entry.timestamp, style: .time)
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("+\(NumberFormattingHelper.format(entry.amount)) \(status.habit.unit)")
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

            Text("Add Specific Session Entry")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Picker("", selection: $customEntryLabelText) {
                    Text("Morning").tag("Morning")
                    Text("Afternoon").tag("Afternoon")
                    Text("Evening").tag("Evening")
                }
                .labelsHidden()
                .frame(width: 110)

                TextField("Amount (\(status.habit.unit))", text: $customEntryAmountText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)

                Button("Add") {
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
