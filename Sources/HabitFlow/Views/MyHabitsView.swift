import SwiftUI

public struct MyHabitsView: View {
    @AppStorage("interfaceLanguage") private var interfaceLanguage = "en"
    @EnvironmentObject private var store: HabitStore

    public let palette: HabitFlowPalette
    public let onAddHabit: () -> Void
    public let onEditHabit: (Habit) -> Void
    public let onInspectHabitStats: (Habit) -> Void

    @State private var category = "All"
    @State private var status = "Все"
    @State private var search = ""
    @State private var showsCards = false
    @State private var selectedHabitID: UUID?
    @State private var habitPendingDeletion: Habit?

    public init(palette: HabitFlowPalette, onAddHabit: @escaping () -> Void,
                onEditHabit: @escaping (Habit) -> Void, onInspectHabitStats: @escaping (Habit) -> Void) {
        self.palette = palette
        self.onAddHabit = onAddHabit
        self.onEditHabit = onEditHabit
        self.onInspectHabitStats = onInspectHabitStats
    }

    private var activeHabits: [Habit] { store.habits.filter { !$0.isArchived } }
    private var visibleHabits: [Habit] {
        activeHabits.filter { habit in
            (category == "All" || habit.category == category) &&
            (status == "Все" || (status == "Активные" && !habit.isPaused) || (status == "На паузе" && habit.isPaused)) &&
            (search.isEmpty || habit.name.localizedCaseInsensitiveContains(search))
        }
    }
    private var selectedHabit: Habit? { activeHabits.first { $0.id == selectedHabitID } }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                summaryCards
                filters
                HStack(alignment: .top, spacing: 16) {
                    Group {
                        if visibleHabits.isEmpty {
                            emptyState
                        } else if showsCards {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 16)], spacing: 16) {
                                ForEach(visibleHabits) { habit in habitCard(habit) }
                            }
                        } else {
                            LazyVStack(spacing: 10) {
                                ForEach(visibleHabits) { habit in habitRow(habit) }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    if let selectedHabit {
                        detailPanel(selectedHabit)
                            .frame(width: 280)
                    }
                }
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 32)
            .frame(maxWidth: 1280, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .alert(L10n.tr("Удалить или архивировать привычку?"), isPresented: Binding(
            get: { habitPendingDeletion != nil }, set: { if !$0 { habitPendingDeletion = nil } }
        ), presenting: habitPendingDeletion) { habit in
            Button(L10n.tr("Архивировать")) { store.deleteHabit(habit.id, deleteHistoricalRecords: false); selectedHabitID = nil }
            Button(L10n.tr("Удалить навсегда"), role: .destructive) {
                store.deleteHabit(habit.id, deleteHistoricalRecords: true); selectedHabitID = nil
            }
            Button(L10n.tr("Отмена"), role: .cancel) { habitPendingDeletion = nil }
        } message: { habit in
            Text(L10n.tr("«\(habit.name)»: архив сохраняет историю; удаление навсегда стирает и её."))
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text(L10n.tr("My")).foregroundStyle(palette.primaryText)
                    Text(L10n.tr("Habits")).italic().foregroundStyle(palette.accentText)
                }
                .font(HabitFlowTypography.display(42, weight: .bold))
                Text(L10n.tr("Управляйте привычками и отслеживайте регулярность"))
                    .font(HabitFlowTypography.body(13)).foregroundStyle(palette.secondaryText)
            }
            Spacer()
            Button(action: onAddHabit) {
                Label(L10n.tr("Add Habit"), systemImage: "plus")
                    .font(HabitFlowTypography.body(13, weight: .semibold))
                    .foregroundStyle(palette.onAccent)
                    .padding(.horizontal, 16).frame(height: 38)
                    .background(Capsule().fill(palette.accent))
            }
            .buttonStyle(.plain)
        }
    }

    private var summaryCards: some View {
        let today = store.dailyProgressOverview(for: store.currentDateKey)
        let monthly = store.calculateStatistics(for: .days30)
        return HStack(spacing: 16) {
            summaryCard("Сегодня", value: "\(today.completedCount) из \(today.totalScheduledCount)", subtitle: "норм выполнено")
            summaryCard("Лучшая серия", value: "\(monthly.longestOverallStreak)", subtitle: "дней подряд")
            summaryCard("За месяц", value: "\(Int(monthly.monthlyCompletionRate))%", subtitle: "среднее выполнение")
        }
    }

    private func summaryCard(_ title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.tr(title)).font(HabitFlowTypography.body(12, weight: .medium)).foregroundStyle(palette.secondaryText)
            Text(L10n.tr(value)).font(HabitFlowTypography.number(34)).foregroundStyle(palette.primaryText)
            Text(L10n.tr(subtitle)).font(HabitFlowTypography.body(11)).foregroundStyle(palette.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .habitFlowCard(palette: palette)
    }

    private var filters: some View {
        HStack(spacing: 10) {
            Picker(L10n.tr("Категория"), selection: $category) {
                Text(L10n.tr("Все категории")).tag("All")
                ForEach(store.settings.allCategories, id: \.self) { Text(L10n.tr($0)).tag($0) }
            }
            .labelsHidden()
            .frame(width: 150)
            Picker(L10n.tr("Статус"), selection: $status) {
                ForEach(["Все", "Активные", "На паузе"], id: \.self) { Text(L10n.tr($0)).tag($0) }
            }
            .labelsHidden()
            .frame(width: 120)
            TextField(L10n.tr("Поиск привычки"), text: $search)
                .textFieldStyle(.roundedBorder)
                .font(HabitFlowTypography.body(12))
                .frame(maxWidth: 190)
            Spacer(minLength: 0)
            Picker(L10n.tr("Вид"), selection: $showsCards) {
                Text(L10n.tr("Список")).tag(false)
                Text(L10n.tr("Карточки")).tag(true)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 150)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "checklist").font(.system(size: 26)).foregroundStyle(palette.accentText)
            Text(L10n.tr(activeHabits.isEmpty ? "Пока нет привычек" : "По фильтру ничего не найдено"))
                .font(HabitFlowTypography.body(15, weight: .semibold)).foregroundStyle(palette.primaryText)
            if activeHabits.isEmpty { Button(L10n.tr("Добавить привычку"), action: onAddHabit).buttonStyle(.borderedProminent) }
        }
        .frame(maxWidth: .infinity, minHeight: 180)
        .habitFlowCard(palette: palette)
    }

    private func habitRow(_ habit: Habit) -> some View {
        let today = store.status(for: habit, on: store.currentDateKey)
        let metric = metricFor(habit)
        return HStack(spacing: 12) {
            Button {
                if !today.isCompleted { store.quickAdd(for: habit.id, on: store.currentDateKey) }
            } label: {
                Image(systemName: today.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 26))
                    .foregroundStyle(today.isCompleted ? palette.accent : palette.secondaryText)
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(.plain)
            .help(L10n.tr(today.isCompleted ? "Норма выполнена" : "Отметить выполнение"))
            VStack(alignment: .leading, spacing: 4) {
                Text(habit.name)
                    .font(HabitFlowTypography.body(14, weight: .semibold))
                    .foregroundStyle(palette.primaryText)
                Text(L10n.tr("\(habit.frequency.rawValue) · \(reminderText(habit))"))
                    .font(HabitFlowTypography.body(11))
                    .foregroundStyle(palette.secondaryText)
                    .lineLimit(1)
                if !habit.habitDescription.isEmpty {
                    Text(L10n.tr(habit.habitDescription))
                        .font(HabitFlowTypography.body(11))
                        .foregroundStyle(palette.secondaryText)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            if habit.isPaused { Text(L10n.tr("На паузе")).font(HabitFlowTypography.body(11)).foregroundStyle(palette.secondaryText) }
            Label(L10n.tr("\(metric.currentStreak)"), systemImage: "flame.fill")
                .font(HabitFlowTypography.body(12, weight: .semibold))
                .foregroundStyle(palette.accentText)
                .frame(width: 48)
            weekDots(for: habit)
            Button { selectedHabitID = selectedHabitID == habit.id ? nil : habit.id } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.primaryText)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .help(L10n.tr("Показать подробности"))
        }
        .habitFlowCard(palette: palette, padding: 14)
        .contentShape(RoundedRectangle(cornerRadius: 22))
        .onTapGesture { selectedHabitID = habit.id }
        .contextMenu { contextMenu(for: habit) }
    }

    private func habitCard(_ habit: Habit) -> some View {
        let today = store.status(for: habit, on: store.currentDateKey)
        let metric = metricFor(habit)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                HabitIconBadge(icon: habit.icon, accent: palette.accent, isCompleted: today.isCompleted)
                Spacer()
                Text(L10n.tr("\(metric.currentStreak) дней"))
                    .font(HabitFlowTypography.body(11, weight: .semibold))
                    .foregroundStyle(palette.accentText)
            }
            Text(habit.name).font(HabitFlowTypography.body(15, weight: .semibold)).foregroundStyle(palette.primaryText)
            Text(L10n.tr(habit.habitDescription.isEmpty ? habit.frequency.rawValue : habit.habitDescription))
                .font(HabitFlowTypography.body(11)).foregroundStyle(palette.secondaryText).lineLimit(2)
            weekDots(for: habit)
            SmoothProgressBar(fraction: today.progressFraction, accentColor: palette.accent,
                              height: 6, trackColor: palette.progressTrack)
            Text(L10n.tr(today.progressText)).font(HabitFlowTypography.body(11)).foregroundStyle(palette.secondaryText)
        }
        .frame(maxWidth: .infinity, minHeight: 145, alignment: .topLeading)
        .habitFlowCard(palette: palette)
        .contentShape(RoundedRectangle(cornerRadius: 22))
        .onTapGesture { selectedHabitID = habit.id }
        .contextMenu { contextMenu(for: habit) }
    }

    private func weekDots(for habit: Habit) -> some View {
        HStack(spacing: 4) {
            ForEach((0..<7).reversed(), id: \.self) { offset in
                let key = DateKeyHelper.addingDays(-offset, to: store.currentDateKey)
                let day = store.status(for: habit, on: key)
                Circle().fill(day.isCompleted ? palette.accent : palette.progressTrack)
                    .frame(width: 8, height: 8)
                    .help(L10n.tr("\(key): \(day.state.rawValue)"))
            }
        }
    }

    private func metricFor(_ habit: Habit) -> HabitConsistencyMetric {
        store.calculateHabitMetric(for: habit,
            startKey: DateKeyHelper.addingDays(-29, to: store.currentDateKey), endKey: store.currentDateKey)
    }

    private func reminderText(_ habit: Habit) -> String {
        habit.reminderEnabled ? String(format: "%02d:%02d", habit.reminderHour, habit.reminderMinute) : "без напоминания"
    }

    private func detailPanel(_ habit: Habit) -> some View {
        let metric = metricFor(habit)
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(habit.name).font(HabitFlowTypography.display(25, weight: .bold)).foregroundStyle(palette.primaryText)
                Spacer()
                Button { selectedHabitID = nil } label: { Image(systemName: "xmark").frame(width: 36, height: 36) }
                    .buttonStyle(.plain).help(L10n.tr("Закрыть подробности"))
            }
            Text(L10n.tr("\(habit.frequency.rawValue) · \(reminderText(habit))"))
                .font(HabitFlowTypography.body(12)).foregroundStyle(palette.secondaryText)
            Text(L10n.tr("За 30 дней: \(metric.completedDays) из \(metric.scheduledDays) выполнено"))
                .font(HabitFlowTypography.body(12)).foregroundStyle(palette.primaryText)
            SmoothProgressBar(fraction: metric.completionRate / 100, accentColor: palette.accent,
                              height: 8, trackColor: palette.progressTrack)
            Text(L10n.tr("Серия: \(metric.currentStreak) дней"))
                .font(HabitFlowTypography.body(12, weight: .semibold)).foregroundStyle(palette.accentText)
            if !habit.habitDescription.isEmpty {
                Text(L10n.tr(habit.habitDescription))
                    .font(HabitFlowTypography.body(12)).foregroundStyle(palette.secondaryText)
            }
            Button(L10n.tr("Подробная статистика")) { onInspectHabitStats(habit) }.buttonStyle(.bordered)
            Button(L10n.tr("Изменить")) { onEditHabit(habit) }.buttonStyle(.bordered)
            Text(L10n.tr("Заморозка серии пока не поддерживается моделью данных"))
                .font(HabitFlowTypography.body(11)).foregroundStyle(palette.secondaryText)
            Spacer(minLength: 0)
        }
        .habitFlowCard(palette: palette)
    }

    @ViewBuilder private func contextMenu(for habit: Habit) -> some View {
        Button(L10n.tr("Отметить сегодня")) { store.quickAdd(for: habit.id, on: store.currentDateKey) }
        Button(L10n.tr("Изменить")) { onEditHabit(habit) }
        Button(L10n.tr(habit.isPaused ? "Возобновить" : "Поставить на паузу")) { store.togglePauseHabit(habit.id) }
        Button(L10n.tr("Архивировать…")) { habitPendingDeletion = habit }
    }
}
