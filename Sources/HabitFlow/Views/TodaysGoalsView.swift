import SwiftUI

public struct TodaysGoalsView: View {
    @AppStorage("interfaceLanguage") private var interfaceLanguage = "en"
    @EnvironmentObject private var store: HabitStore
    public let palette: HabitFlowPalette
    public let onAddHabit: () -> Void

    public init(palette: HabitFlowPalette, onAddHabit: @escaping () -> Void) {
        self.palette = palette
        self.onAddHabit = onAddHabit
    }

    private var overview: DailyProgressOverview { store.dailyProgressOverview(for: store.currentDateKey) }
    private var unfinished: [DailyHabitStatus] { overview.scheduledStatuses.filter { !$0.isCompleted } }
    private var completed: [DailyHabitStatus] { overview.scheduledStatuses.filter(\.isCompleted) }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                dayProgress
                if let focus = unfinished.first { focusCard(focus) }
                if overview.totalScheduledCount == 0 {
                    VStack(spacing: 10) {
                        Text(L10n.tr("На сегодня пока ничего не запланировано"))
                            .font(HabitFlowTypography.display(27)).foregroundStyle(palette.primaryText)
                        Button(L10n.tr("Добавить привычку"), action: onAddHabit).buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, minHeight: 140)
                    .habitFlowCard(palette: palette)
                } else if unfinished.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 27)).foregroundStyle(palette.accentText)
                        Text(L10n.tr("Всё на сегодня готово"))
                            .font(HabitFlowTypography.display(30)).foregroundStyle(palette.primaryText)
                        Text(L10n.tr("Все запланированные нормы выполнены"))
                            .font(HabitFlowTypography.body(12)).foregroundStyle(palette.secondaryText)
                    }
                    .frame(maxWidth: .infinity, minHeight: 140)
                    .habitFlowCard(palette: palette)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L10n.tr("Осталось сделать"))
                            .font(HabitFlowTypography.body(16, weight: .semibold))
                            .foregroundStyle(palette.primaryText)
                        ForEach(unfinished) { item in taskRow(item) }
                    }
                }
                if !completed.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L10n.tr("Выполнено"))
                            .font(HabitFlowTypography.body(16, weight: .semibold))
                            .foregroundStyle(palette.primaryText)
                        ForEach(completed) { item in taskRow(item) }
                    }
                }
                weeklyProgress
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 32)
            .frame(maxWidth: 1280, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(L10n.tr("Today's")).foregroundStyle(palette.primaryText)
                    Text(L10n.tr("Goals")).italic().foregroundStyle(palette.accentText)
                }
                .font(HabitFlowTypography.display(42, weight: .bold))
                Text(L10n.tr(Date().formatted(.dateTime.weekday(.wide).day().month(.wide).locale(L10n.locale))))
                    .font(HabitFlowTypography.body(12)).foregroundStyle(palette.secondaryText)
            }
            Spacer()
            if overview.totalEstimatedRemainingMinutes > 0 {
                Label(L10n.tr("≈ \(overview.totalEstimatedRemainingMinutes) мин осталось"), systemImage: "clock")
                    .font(HabitFlowTypography.body(12)).foregroundStyle(palette.secondaryText)
            }
        }
    }

    private var dayProgress: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(L10n.tr("\(overview.completedCount) из \(overview.totalScheduledCount) выполнено"))
                    .font(HabitFlowTypography.body(14, weight: .semibold))
                    .foregroundStyle(palette.primaryText)
                Spacer()
                Text(L10n.tr("\(Int(overview.completionPercentage))%"))
                    .font(HabitFlowTypography.number(28)).foregroundStyle(palette.accentText)
            }
            SmoothProgressBar(fraction: overview.progressFraction, accentColor: palette.accent,
                              height: 10, trackColor: palette.progressTrack)
        }
        .habitFlowCard(palette: palette)
    }

    private func focusCard(_ item: DailyHabitStatus) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.tr("ФОКУС ДНЯ"))
                .font(HabitFlowTypography.body(11, weight: .semibold))
                .tracking(2).foregroundStyle(Color.white.opacity(0.75))
            Text(item.habit.name)
                .font(HabitFlowTypography.display(34, weight: .bold))
                .foregroundStyle(.white)
            Text(L10n.tr(item.progressText))
                .font(HabitFlowTypography.body(12))
                .foregroundStyle(Color.white.opacity(0.75))
            SmoothProgressBar(fraction: item.progressFraction, accentColor: palette.accent,
                              height: 10, trackColor: Color.white.opacity(0.18))
            Button { store.quickAdd(for: item.habit.id, on: store.currentDateKey) } label: {
                Label(L10n.tr("Отметить норму"), systemImage: "checkmark")
                    .font(HabitFlowTypography.body(12, weight: .semibold))
                    .foregroundStyle(palette.onAccent)
                    .padding(.horizontal, 15).frame(height: 36)
                    .background(Capsule().fill(palette.accent))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(RoundedRectangle(cornerRadius: 22).fill(palette.heroBackground))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(palette.subtleBorder))
    }

    private func taskRow(_ item: DailyHabitStatus) -> some View {
        let relatedGoal = store.goals.first { $0.habitIDs.contains(item.habit.id) }
        return HStack(spacing: 12) {
            Button {
                if item.isCompleted && item.habit.measurementType != .checkbox {
                    store.quickDecrease(for: item.habit.id, on: store.currentDateKey)
                } else {
                    store.quickAdd(for: item.habit.id, on: store.currentDateKey)
                }
            } label: {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundStyle(item.isCompleted ? palette.accent : palette.secondaryText)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.habit.name)
                    .font(HabitFlowTypography.body(14, weight: .semibold))
                    .foregroundStyle(item.isCompleted ? palette.secondaryText : palette.primaryText)
                    .strikethrough(item.isCompleted)
                HStack(spacing: 7) {
                    Label(L10n.tr(relatedGoal.map { "Цель: \($0.title)" } ?? "Привычка"),
                          systemImage: relatedGoal == nil ? "repeat" : "target")
                    Text(L10n.tr("· \(item.progressText)"))
                    if item.habit.reminderEnabled {
                        Text(L10n.tr("· " + String(format: "%02d:%02d", item.habit.reminderHour, item.habit.reminderMinute)))
                    }
                }
                .font(HabitFlowTypography.body(11))
                .foregroundStyle(palette.secondaryText)
                .lineLimit(1)
            }
            Spacer()
            if !item.isCompleted && item.habit.measurementType != .checkbox {
                Text(L10n.tr("осталось \(NumberFormattingHelper.format(item.remainingAmount)) \(item.habit.unit)"))
                    .font(HabitFlowTypography.body(11))
                    .foregroundStyle(palette.secondaryText)
            }
        }
        .habitFlowCard(palette: palette, padding: 14)
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(palette.priorityColor(relatedGoal?.priority ?? "low"))
                .frame(width: 3).padding(.vertical, 12)
        }
    }

    private var weeklyProgress: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.tr("Нормы на неделю"))
                .font(HabitFlowTypography.body(16, weight: .semibold))
                .foregroundStyle(palette.primaryText)
            ForEach(store.weeklyHabitProgressList(for: store.currentDateKey)) { item in
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text(item.habit.name)
                            .font(HabitFlowTypography.body(12, weight: .medium))
                            .foregroundStyle(palette.primaryText)
                        Spacer()
                        Text(L10n.tr("\(Int(item.completionPercentage))%"))
                            .font(HabitFlowTypography.body(11))
                            .foregroundStyle(palette.secondaryText)
                    }
                    SmoothProgressBar(fraction: item.completionPercentage / 100,
                                      accentColor: palette.accent, height: 6, trackColor: palette.progressTrack)
                }
            }
        }
        .habitFlowCard(palette: palette)
    }
}
