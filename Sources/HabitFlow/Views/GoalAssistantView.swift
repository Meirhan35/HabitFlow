import SwiftUI

public struct GoalAssistantView: View {
    @EnvironmentObject private var store: HabitStore
    @EnvironmentObject private var history: AssistantChatStore
    public let palette: HabitFlowPalette
    @State private var selectedChatID: UUID?
    @State private var input = ""
    @State private var busy = false
    @State private var error: String?
    @State private var choosing = false
    @State private var selectedParts: Set<String> = []

    public init(palette: HabitFlowPalette) { self.palette = palette }

    private var chat: AssistantChat? { history.chats.first { $0.id == selectedChatID } }

    public var body: some View {
        HStack(spacing: 0) {
            historySidebar
                .frame(width: 190)
                .background(palette.cardBackground)
            Divider()
            VStack(spacing: 0) {
                header
                Divider()
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            if let chat, !chat.messages.isEmpty {
                                ForEach(chat.messages) { message in
                                    messageBubble(message)
                                }
                                if !chat.questions.isEmpty { questionsCard(chat.questions) }
                                if let plan = chat.plan { planCard(plan, saved: chat.saved) }
                            } else { emptyState }
                            Color.clear.frame(height: 1).id("bottom")
                        }
                        .padding(24)
                        .frame(maxWidth: 760, alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .onChange(of: chat?.messages.count) { _, _ in withAnimation { proxy.scrollTo("bottom") } }
                }
                if let error { Text(error).font(.system(size: 12)).foregroundStyle(.red).padding(.horizontal, 20) }
                composer
            }
        }
        .onAppear { if selectedChatID == nil { selectedChatID = history.chats.first?.id ?? history.newChat() } }
    }

    private var historySidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button { selectedChatID = history.newChat(); input = ""; choosing = false; error = nil } label: {
                Label("Новый чат", systemImage: "plus")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }.buttonStyle(.borderedProminent)
            Text("История").font(.system(size: 12, weight: .bold)).foregroundStyle(palette.secondaryText)
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(history.chats) { item in
                        Button {
                            selectedChatID = item.id; choosing = false; error = nil
                        } label: {
                            Text(item.title).font(.system(size: 12, weight: selectedChatID == item.id ? .semibold : .regular))
                                .lineLimit(2).frame(maxWidth: .infinity, alignment: .leading).padding(8)
                                .background(selectedChatID == item.id ? palette.accent.opacity(0.15) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                        }.buttonStyle(.plain)
                    }
                }
            }
            Spacer()
        }.padding(12)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Assistant").font(.system(size: 22, weight: .bold, design: .rounded)).foregroundStyle(palette.primaryText)
                Text("Планируйте цели и привычки вместе с Groq").font(.system(size: 12)).foregroundStyle(palette.secondaryText)
            }
            Spacer()
        }.padding(.horizontal, 24).padding(.vertical, 16)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "sparkles").font(.system(size: 30)).foregroundStyle(palette.accent)
            Text("С чего начнём?").font(.system(size: 22, weight: .bold, design: .rounded)).foregroundStyle(palette.primaryText)
            Text("Напишите желание обычными словами. Ассистент уточнит детали и предложит план. Сохранение произойдёт только после нажатия кнопки.")
                .font(.system(size: 13)).foregroundStyle(palette.secondaryText)
            ForEach(["Хочу научиться Python", "Хочу регулярно заниматься спортом", "Пропускаю занятия — помоги облегчить план"], id: \.self) { example in
                Button(example) { input = example }
                    .buttonStyle(.bordered)
            }
        }.habitFlowCard(palette: palette).frame(maxWidth: 520)
    }

    private func messageBubble(_ message: AssistantMessage) -> some View {
        HStack {
            if message.role == "user" { Spacer(minLength: 70) }
            Text(message.text).font(.system(size: 13)).foregroundStyle(palette.primaryText)
                .padding(12).background(message.role == "user" ? palette.accent.opacity(0.18) : palette.cardBackground,
                                        in: RoundedRectangle(cornerRadius: 12))
            if message.role != "user" { Spacer(minLength: 70) }
        }
    }

    private func questionsCard(_ questions: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Уточните, пожалуйста").font(.system(size: 14, weight: .semibold))
            ForEach(questions, id: \.self) { Text("• \($0)").font(.system(size: 13)) }
        }.foregroundStyle(palette.primaryText).habitFlowCard(palette: palette)
    }

    private func planCard(_ plan: AssistantPlan, saved: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("План", systemImage: "target").font(.system(size: 17, weight: .bold)).foregroundStyle(palette.accent)
            part("goal", title: "\(plan.goal.title) · \(plan.goal.target.formatted()) \(plan.goal.unit) до \(plan.goal.deadline)", detail: "Приоритет: \(plan.goal.priority) · \(plan.goal.category)")
            Text("Этапы").font(.system(size: 13, weight: .bold))
            ForEach(Array(plan.milestones.enumerated()), id: \.offset) { index, item in
                part("milestone-\(index)", title: item.title, detail: "До \(item.due)")
            }
            Text("Привычки").font(.system(size: 13, weight: .bold))
            ForEach(Array(plan.habits.enumerated()), id: \.offset) { index, item in
                let existing = store.habits.contains { $0.name.localizedCaseInsensitiveCompare(item.title) == .orderedSame && !$0.isArchived }
                part("habit-\(index)", title: item.title + (existing ? " · обновить" : ""),
                     detail: "\(item.frequency) · \(item.time) · минимум: \(item.minimum_version)")
            }
            Text("Идеи").font(.system(size: 13, weight: .bold))
            ForEach(Array(plan.ideas.enumerated()), id: \.offset) { index, item in
                part("idea-\(index)", title: item.title, detail: item.description)
            }
            Text("Реалистичность: \(plan.reality_check.level)").font(.system(size: 13, weight: .bold))
            Text(plan.reality_check.comment).font(.system(size: 12)).foregroundStyle(palette.secondaryText)
            if !saved {
                HStack {
                    Button("Сохранить всё") { save(plan, all: true) }.buttonStyle(.borderedProminent)
                    Button(choosing ? "Скрыть выбор" : "Выбрать, что сохранить") {
                        choosing.toggle()
                        if choosing { selectedParts = allParts(plan) }
                    }.buttonStyle(.bordered)
                    Button("Изменить план") { input = "Измени план: " }.buttonStyle(.bordered)
                }
                if choosing {
                    Button("Сохранить выбранное") { save(plan, all: false) }
                        .buttonStyle(.borderedProminent).disabled(selectedParts.isEmpty)
                }
            } else {
                Label("План сохранён", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            }
        }.foregroundStyle(palette.primaryText).habitFlowCard(palette: palette)
    }

    private func part(_ key: String, title: String, detail: String) -> some View {
        HStack(alignment: .top) {
            if choosing {
                Toggle("", isOn: Binding(get: { selectedParts.contains(key) }, set: { on in
                    if on { selectedParts.insert(key) } else { selectedParts.remove(key) }
                })).labelsHidden().toggleStyle(.checkbox)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(detail).font(.system(size: 12)).foregroundStyle(palette.secondaryText)
            }
            Spacer()
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 9) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(["Сделай полегче", "Убери вечерние напоминания", "У меня 20 минут в день"], id: \.self) { hint in
                        Button(hint) { input = hint }.buttonStyle(.bordered)
                    }
                }
            }
            HStack(alignment: .bottom) {
                TextField("Напишите желание или уточнение…", text: $input, axis: .vertical)
                    .lineLimit(1...4).textFieldStyle(.roundedBorder)
                    .onSubmit { Task { await send() } }
                Button { Task { await send() } } label: { Image(systemName: "arrow.up.circle.fill").font(.system(size: 26)) }
                    .buttonStyle(.plain).disabled(busy || input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if busy { ProgressView("Готовлю ответ…").controlSize(.small) }
        }.padding(16).background(palette.cardBackground)
    }

    @MainActor private func send() async {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !busy, !text.isEmpty, var current = chat else { return }
        busy = true; error = nil; input = ""
        current.messages.append(AssistantMessage(role: "user", text: text))
        if current.messages.count == 1 { current.title = String(text.prefix(42)) }
        history.update(current)
        do {
            let reply = try await GoalAssistantService.respond(chat: current, context: contextSummary, today: store.currentDateKey)
            current.messages.append(AssistantMessage(role: "model", text: reply.message))
            current.questions = reply.questions
            if let plan = reply.plan { current.plan = plan; current.saved = false; choosing = false }
            history.update(current)
        } catch { self.error = error.localizedDescription }
        busy = false
    }

    private var contextSummary: String {
        let goals = store.goals.map { "\($0.title), цель \($0.target) \($0.unit), срок \($0.deadline)" }.joined(separator: "; ")
        let habits = store.habits.filter { !$0.isArchived }.map { habit in
            let metric = store.calculateHabitMetric(for: habit,
                startKey: DateKeyHelper.addingDays(-13, to: store.currentDateKey), endKey: store.currentDateKey)
            return "\(habit.name): \(habit.frequency.rawValue), цель \(habit.dailyTarget) \(habit.unit), выполнено \(metric.completedDays)/\(metric.scheduledDays) дней за 14 дней"
        }.joined(separator: "; ")
        return "Цели: \(goals.isEmpty ? "нет" : goals). Привычки: \(habits.isEmpty ? "нет" : habits)."
    }

    private func allParts(_ plan: AssistantPlan) -> Set<String> {
        Set(["goal"] + plan.milestones.indices.map { "milestone-\($0)" } +
            plan.habits.indices.map { "habit-\($0)" } + plan.ideas.indices.map { "idea-\($0)" })
    }

    private func save(_ plan: AssistantPlan, all: Bool) {
        guard var current = chat, !current.saved else { return }
        let selected = all ? allParts(plan) : selectedParts
        var habitIDs: [UUID] = []
        for (index, item) in plan.habits.enumerated() where selected.contains("habit-\(index)") {
            let days = Set(item.days.compactMap(Weekday.init(rawValue:)))
            let frequency: HabitFrequency = item.frequency == "daily" ? .daily : item.frequency == "weekdays" ? .weekdays : .customDays
            let pieces = item.time.split(separator: ":")
            let hour = Int(pieces[0]) ?? 20; let minute = Int(pieces[1]) ?? 0
            if let existing = store.habits.first(where: { $0.name.localizedCaseInsensitiveCompare(item.title) == .orderedSame && !$0.isArchived }) {
                var updated = existing
                updated.frequency = frequency; updated.scheduledWeekdays = days
                updated.reminderEnabled = true; updated.reminderHour = hour; updated.reminderMinute = minute
                updated.habitDescription = "Минимум на сложный день: \(item.minimum_version)"
                store.updateHabit(updated)
                habitIDs.append(updated.id)
            } else {
                let habit = Habit(name: item.title, habitDescription: "Минимум на сложный день: \(item.minimum_version)",
                                  icon: "sparkles", category: plan.goal.category,
                                  measurementType: .checkbox, unit: "completion", dailyTarget: 1,
                                  frequency: frequency, scheduledWeekdays: days,
                                  reminderEnabled: true, reminderHour: hour, reminderMinute: minute)
                store.addHabit(habit)
                habitIDs.append(habit.id)
            }
        }
        if selected.contains("goal") {
            let goal = SavedGoal(title: plan.goal.title, unit: plan.goal.unit, target: plan.goal.target,
                                 deadline: plan.goal.deadline, category: plan.goal.category, priority: plan.goal.priority,
                                 milestones: plan.milestones.enumerated().compactMap { selected.contains("milestone-\($0.offset)") ? $0.element : nil },
                                 ideas: plan.ideas.enumerated().compactMap { selected.contains("idea-\($0.offset)") ? $0.element : nil },
                                 habitIDs: habitIDs)
            store.goals.append(goal)
        }
        current.saved = true; current.questions = []
        let first = plan.habits.enumerated().first(where: { selected.contains("habit-\($0.offset)") }).map { "Сегодня начните с «\($0.element.minimum_version)» для привычки «\($0.element.title)»." }
            ?? "Сегодня выберите первый небольшой шаг к цели."
        current.messages.append(AssistantMessage(role: "model", text: "Сохранено. \(first)"))
        history.update(current)
        choosing = false
    }
}
