import SwiftUI

// MARK: - 1. Habit Creation & Edit Modal (Section 6 & Section 7: Six Measurement Types)

public enum HabitEditorMode: Equatable {
    case create
    case edit(Habit)

    public var isEditing: Bool {
        if case .edit = self { return true }
        return false
    }
}

public struct HabitEditorModalView: View {
    @EnvironmentObject private var store: HabitStore
    @Environment(\.dismiss) private var dismiss

    public let mode: HabitEditorMode
    public let palette: HabitFlowPalette
    public let onSave: (Habit) -> Void

    @State private var name: String = ""
    @State private var habitDescription: String = ""
    @State private var icon: String = "book.fill"
    @State private var category: String = DefaultCategory.education.rawValue
    @State private var customCategoryName: String = ""
    @State private var isAddingCustomCategory: Bool = false

    @State private var measurementType: MeasurementType = .duration
    @State private var unit: String = "minutes"
    @State private var dailyTargetText: String = "30"
    @State private var weeklyTargetText: String = ""
    @State private var quickAddIncrementText: String = "5"

    @State private var frequency: HabitFrequency = .daily
    @State private var selectedWeekdays: Set<Weekday> = Set(Weekday.allCases)

    @State private var reminderEnabled: Bool = false
    @State private var reminderHour: Int = 20
    @State private var reminderMinute: Int = 0
    @State private var estimatedDurationText: String = ""
    @State private var validationMessage: String? = nil

    private let suggestedIcons: [String] = [
        "book.fill", "figure.run", "drop.fill", "graduationcap.fill",
        "flame.fill", "sparkles", "brain.head.profile", "bolt.fill",
        "heart.fill", "bed.double.fill", "cup.and.saucer.fill", "dumbbell.fill",
        "pencil.and.outline", "laptopcomputer", "leaf.fill", "moon.stars.fill"
    ]

    public init(mode: HabitEditorMode, palette: HabitFlowPalette, onSave: @escaping (Habit) -> Void) {
        self.mode = mode
        self.palette = palette
        self.onSave = onSave
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Modal Header
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(mode.isEditing ? "Edit Habit" : "Create New Habit")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)
                    Text("Configure measurement type, daily & weekly targets, and quick-add increments.")
                        .font(.system(size: 12))
                        .foregroundStyle(palette.secondaryText)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(palette.secondaryText)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .background(palette.cardBackground)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Basic Identity
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Habit Identity")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(palette.accent)

                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Habit Name")
                                    .font(.system(size: 12, weight: .semibold))
                                TextField("e.g., Read a book, Run 5 km, Drink Water", text: $name)
                                    .textFieldStyle(.roundedBorder)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Category")
                                    .font(.system(size: 12, weight: .semibold))
                                HStack(spacing: 6) {
                                    if isAddingCustomCategory {
                                        TextField("Custom category", text: $customCategoryName)
                                            .textFieldStyle(.roundedBorder)
                                        Button("Use") {
                                            let trimmed = customCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
                                            if !trimmed.isEmpty {
                                                category = trimmed
                                                if !store.settings.customCategories.contains(trimmed) {
                                                    store.settings.customCategories.append(trimmed)
                                                }
                                                isAddingCustomCategory = false
                                            }
                                        }
                                    } else {
                                        Picker("", selection: $category) {
                                            ForEach(store.settings.allCategories, id: \.self) { cat in
                                                Text(cat).tag(cat)
                                            }
                                        }
                                        .labelsHidden()
                                        .frame(width: 170)

                                        Button("+ Custom") {
                                            isAddingCustomCategory = true
                                        }
                                        .font(.system(size: 11, weight: .semibold))
                                    }
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Description (Optional)")
                                .font(.system(size: 12, weight: .semibold))
                            TextField("Why does this habit matter to you?", text: $habitDescription)
                                .textFieldStyle(.roundedBorder)
                        }

                        // Icon Picker
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Icon or Emoji")
                                .font(.system(size: 12, weight: .semibold))
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(suggestedIcons, id: \.self) { sym in
                                        let isSelected = (icon == sym)
                                        Button {
                                            icon = sym
                                        } label: {
                                            Image(systemName: sym)
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundStyle(isSelected ? .white : palette.primaryText)
                                                .frame(width: 32, height: 32)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                        .fill(isSelected ? palette.accent : palette.secondarySurface)
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    .habitFlowCard(palette: palette, padding: 16)

                    // Six Measurement Types Dynamic Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Measurement Type & Targets")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(palette.accent)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(MeasurementType.allCases) { mType in
                                let selected = (measurementType == mType)
                                Button {
                                    measurementType = mType
                                    applyDefaultsForMeasurementType(mType)
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: mType.iconName)
                                            .font(.system(size: 13, weight: .semibold))
                                        Text(mType.rawValue)
                                            .font(.system(size: 12, weight: .semibold))
                                        Spacer()
                                    }
                                    .foregroundStyle(selected ? .white : palette.primaryText)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(selected ? palette.accent : palette.secondarySurface)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Text(measurementType.description)
                            .font(.system(size: 11))
                            .foregroundStyle(palette.secondaryText)

                        // Dynamic fields based on selected measurement type
                        dynamicMeasurementFields
                    }
                    .habitFlowCard(palette: palette, padding: 16)

                    // Schedule & Reminders
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Schedule & Reminders")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(palette.accent)

                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Frequency")
                                    .font(.system(size: 12, weight: .semibold))
                                Picker("", selection: $frequency) {
                                    ForEach(HabitFrequency.allCases) { freq in
                                        Text(freq.rawValue).tag(freq)
                                    }
                                }
                                .labelsHidden()
                                .frame(width: 200)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Estimated Duration (mins, optional)")
                                    .font(.system(size: 12, weight: .semibold))
                                TextField("e.g., 30", text: $estimatedDurationText)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 120)
                            }
                        }

                        if frequency == .customDays {
                            HStack(spacing: 8) {
                                ForEach(Weekday.ordered(startingOn: store.settings.weekStartDay)) { day in
                                    let isSelected = selectedWeekdays.contains(day)
                                    Button {
                                        if isSelected && selectedWeekdays.count > 1 {
                                            selectedWeekdays.remove(day)
                                        } else {
                                            selectedWeekdays.insert(day)
                                        }
                                    } label: {
                                        Text(day.shortName)
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(isSelected ? .white : palette.primaryText)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(
                                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                                    .fill(isSelected ? palette.accent : palette.secondarySurface)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        Divider()

                        HStack(spacing: 16) {
                            Toggle("Enable Daily Reminder Notification", isOn: $reminderEnabled)
                                .font(.system(size: 12, weight: .semibold))

                            if reminderEnabled {
                                HStack(spacing: 6) {
                                    Picker("Hour", selection: $reminderHour) {
                                        ForEach(0..<24, id: \.self) { h in
                                            Text(String(format: "%02d", h)).tag(h)
                                        }
                                    }
                                    .labelsHidden()
                                    .frame(width: 65)

                                    Text(":")
                                        .font(.system(size: 13, weight: .bold))

                                    Picker("Minute", selection: $reminderMinute) {
                                        ForEach([0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55], id: \.self) { m in
                                            Text(String(format: "%02d", m)).tag(m)
                                        }
                                    }
                                    .labelsHidden()
                                    .frame(width: 65)
                                }
                            }
                        }
                    }
                    .habitFlowCard(palette: palette, padding: 16)

                    if let validationMessage = validationMessage {
                        Text(validationMessage)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.red)
                    }
                }
                .padding(24)
            }

            Divider()

            // Modal Footer
            HStack {
                if mode.isEditing {
                    Text("Target changes are saved with today's effective date so historical completion percentages remain intact.")
                        .font(.system(size: 11))
                        .foregroundStyle(palette.secondaryText)
                }
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(mode.isEditing ? "Save Changes" : "Create Habit") {
                    saveHabit()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(palette.cardBackground)
        }
        .frame(width: 640, height: 660)
        .background(palette.windowBackground)
        .onAppear(perform: populateInitialValues)
    }

    @ViewBuilder
    private var dynamicMeasurementFields: some View {
        switch measurementType {
        case .duration:
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Time Unit")
                        .font(.system(size: 11, weight: .semibold))
                    Picker("", selection: $unit) {
                        Text("Minutes").tag("minutes")
                        Text("Hours").tag("hours")
                    }
                    .labelsHidden()
                    .frame(width: 120)
                }
                numericalTargetInputs
            }

        case .distance:
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Distance Unit")
                        .font(.system(size: 11, weight: .semibold))
                    Picker("", selection: $unit) {
                        Text("Kilometers (km)").tag("km")
                        Text("Meters (m)").tag("meters")
                    }
                    .labelsHidden()
                    .frame(width: 150)
                }
                numericalTargetInputs
            }

        case .checkbox:
            HStack(spacing: 16) {
                Label("Single-click daily completion button (no numerical target needed).", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(palette.primaryText)
                Spacer()
                VStack(alignment: .leading, spacing: 5) {
                    Text("Weekly Target (sessions, optional)")
                        .font(.system(size: 11, weight: .semibold))
                    TextField("e.g., 5", text: $weeklyTargetText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 110)
                }
            }

        case .counter:
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Repetition Label")
                        .font(.system(size: 11, weight: .semibold))
                    TextField("reps, words, exercises", text: $unit)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 140)
                }
                numericalTargetInputs
            }

        case .quantity, .customUnit:
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(measurementType == .quantity ? "Quantity Unit" : "Custom Unit Name")
                        .font(.system(size: 11, weight: .semibold))
                    TextField(measurementType == .quantity ? "glasses, pages, servings" : "pages, sessions, assignments", text: $unit)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 160)
                }
                numericalTargetInputs
            }
        }
    }

    private var numericalTargetInputs: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Daily Target")
                    .font(.system(size: 11, weight: .semibold))
                TextField("e.g., 30", text: $dailyTargetText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 95)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("Quick-Add (+) Increment")
                    .font(.system(size: 11, weight: .semibold))
                TextField("e.g., 5", text: $quickAddIncrementText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 95)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("Weekly Target (Optional)")
                    .font(.system(size: 11, weight: .semibold))
                TextField("Auto", text: $weeklyTargetText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 95)
            }
        }
    }

    private func applyDefaultsForMeasurementType(_ type: MeasurementType) {
        switch type {
        case .duration:
            unit = "minutes"
            dailyTargetText = "30"
            quickAddIncrementText = "5"
        case .distance:
            unit = "km"
            dailyTargetText = "5"
            quickAddIncrementText = "0.5"
        case .checkbox:
            unit = "completion"
            dailyTargetText = "1"
            quickAddIncrementText = "1"
        case .counter:
            unit = "reps"
            dailyTargetText = "20"
            quickAddIncrementText = "5"
        case .quantity:
            unit = "glasses"
            dailyTargetText = "6"
            quickAddIncrementText = "1"
        case .customUnit:
            unit = "pages"
            dailyTargetText = "2"
            quickAddIncrementText = "1"
        }
    }

    private func populateInitialValues() {
        switch mode {
        case .create:
            frequency = store.settings.defaultFrequency
        case .edit(let existing):
            name = existing.name
            habitDescription = existing.habitDescription
            icon = existing.icon
            category = existing.category
            measurementType = existing.measurementType
            unit = existing.unit
            dailyTargetText = NumberFormattingHelper.format(existing.dailyTarget)
            if let wt = existing.weeklyTarget {
                weeklyTargetText = NumberFormattingHelper.format(wt)
            }
            quickAddIncrementText = NumberFormattingHelper.format(existing.quickAddIncrement)
            frequency = existing.frequency
            selectedWeekdays = existing.scheduledWeekdays
            reminderEnabled = existing.reminderEnabled
            reminderHour = existing.reminderHour
            reminderMinute = existing.reminderMinute
            if let est = existing.estimatedDurationMinutes {
                estimatedDurationText = "\(est)"
            }
        }
    }

    private func saveHabit() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            validationMessage = "Please enter a habit name."
            return
        }

        let resolvedTarget: Double
        let resolvedIncrement: Double

        if measurementType == .checkbox {
            resolvedTarget = 1.0
            resolvedIncrement = 1.0
        } else {
            guard let t = Double(dailyTargetText), t > 0 else {
                validationMessage = "Please enter a valid positive daily target."
                return
            }
            guard let inc = Double(quickAddIncrementText), inc > 0 else {
                validationMessage = "Please enter a valid positive quick-add increment."
                return
            }
            resolvedTarget = t
            resolvedIncrement = inc
        }

        let resolvedWeekly = Double(weeklyTargetText)
        let resolvedEstDuration = Int(estimatedDurationText)

        switch mode {
        case .create:
            let newHabit = Habit(
                name: trimmedName,
                habitDescription: habitDescription.trimmingCharacters(in: .whitespacesAndNewlines),
                icon: icon,
                category: category,
                measurementType: measurementType,
                unit: unit.trimmingCharacters(in: .whitespacesAndNewlines),
                dailyTarget: resolvedTarget,
                weeklyTarget: resolvedWeekly,
                quickAddIncrement: resolvedIncrement,
                frequency: frequency,
                scheduledWeekdays: selectedWeekdays,
                reminderEnabled: reminderEnabled,
                reminderHour: reminderHour,
                reminderMinute: reminderMinute,
                estimatedDurationMinutes: resolvedEstDuration,
                createdAtDateKey: store.currentDateKey
            )
            onSave(newHabit)
            dismiss()

        case .edit(var existing):
            existing.name = trimmedName
            existing.habitDescription = habitDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            existing.icon = icon
            existing.category = category
            existing.measurementType = measurementType
            existing.unit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
            existing.dailyTarget = resolvedTarget
            existing.weeklyTarget = resolvedWeekly
            existing.quickAddIncrement = resolvedIncrement
            existing.frequency = frequency
            existing.scheduledWeekdays = selectedWeekdays
            existing.reminderEnabled = reminderEnabled
            existing.reminderHour = reminderHour
            existing.reminderMinute = reminderMinute
            existing.estimatedDurationMinutes = resolvedEstDuration
            onSave(existing)
            dismiss()
        }
    }
}

// MARK: - 2. My Habits Management View (Section 6 & Section 13)

public struct MyHabitsView: View {
    @EnvironmentObject private var store: HabitStore

    public let palette: HabitFlowPalette
    public let onAddHabit: () -> Void
    public let onEditHabit: (Habit) -> Void
    public let onInspectHabitStats: (Habit) -> Void

    @State private var selectedCategoryFilter: String = "All"
    @State private var habitPendingDeletion: Habit? = nil

    public init(
        palette: HabitFlowPalette,
        onAddHabit: @escaping () -> Void,
        onEditHabit: @escaping (Habit) -> Void,
        onInspectHabitStats: @escaping (Habit) -> Void
    ) {
        self.palette = palette
        self.onAddHabit = onAddHabit
        self.onEditHabit = onEditHabit
        self.onInspectHabitStats = onInspectHabitStats
    }

    private var visibleHabits: [Habit] {
        store.habits.filter { habit in
            guard !habit.isArchived else { return false }
            if selectedCategoryFilter == "All" { return true }
            return habit.category == selectedCategoryFilter
        }
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("My Habits")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(palette.primaryText)
                        Text("Manage active and paused habits, adjust flexible targets, or inspect per-habit analytics.")
                            .font(.system(size: 13))
                            .foregroundStyle(palette.secondaryText)
                    }
                    Spacer()
                    Button(action: onAddHabit) {
                        Label("Add Habit", systemImage: "plus")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(RoundedRectangle(cornerRadius: 9).fill(palette.accent))
                    }
                    .buttonStyle(.plain)
                }

                // Category Filter Bar
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(["All"] + store.settings.allCategories, id: \.self) { cat in
                            let selected = (selectedCategoryFilter == cat)
                            Button {
                                selectedCategoryFilter = cat
                            } label: {
                                Text(cat)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(selected ? .white : palette.primaryText)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(selected ? palette.accent : palette.cardBackground)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Habits List
                VStack(spacing: 12) {
                    ForEach(visibleHabits) { habit in
                        let st = store.status(for: habit, on: store.currentDateKey)
                        HStack(spacing: 14) {
                            HabitIconBadge(
                                icon: habit.icon,
                                accent: habit.isPaused ? .gray : palette.accent,
                                isCompleted: st.isCompleted,
                                size: 42
                            )

                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    Text(habit.name)
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(palette.primaryText)

                                    Text(habit.measurementType.rawValue)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(palette.accent)
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(palette.accent.opacity(0.14)))

                                    Text(habit.category)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(palette.secondaryText)
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(palette.secondarySurface))

                                    if habit.isPaused {
                                        Text("PAUSED")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(.orange)
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 2)
                                            .background(Capsule().fill(Color.orange.opacity(0.16)))
                                    }
                                }

                                Text("Daily Target: \(NumberFormattingHelper.formatWithUnit(habit.dailyTarget, unit: habit.unit, measurementType: habit.measurementType)) • Quick-Add: +\(NumberFormattingHelper.format(habit.quickAddIncrement)) • \(habit.frequency.rawValue)")
                                    .font(.system(size: 12))
                                    .foregroundStyle(palette.secondaryText)
                            }

                            Spacer()

                            Button {
                                onInspectHabitStats(habit)
                            } label: {
                                Label("Stats", systemImage: "chart.line.uptrend.xyaxis")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .buttonStyle(.bordered)

                            Button {
                                onEditHabit(habit)
                            } label: {
                                Label("Edit", systemImage: "slider.horizontal.3")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .buttonStyle(.bordered)

                            Button {
                                store.togglePauseHabit(habit.id)
                            } label: {
                                Text(habit.isPaused ? "Resume" : "Pause")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .buttonStyle(.bordered)

                            Button {
                                habitPendingDeletion = habit
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.bordered)
                        }
                        .habitFlowCard(palette: palette, padding: 16)
                    }
                }
            }
            .padding(32)
            .frame(maxWidth: 960, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .alert(
            "Delete or Archive Habit?",
            isPresented: Binding(
                get: { habitPendingDeletion != nil },
                set: { if !$0 { habitPendingDeletion = nil } }
            ),
            presenting: habitPendingDeletion
        ) { habit in
            Button("Archive (Keep Historical Records)") {
                store.deleteHabit(habit.id, deleteHistoricalRecords: false)
                habitPendingDeletion = nil
            }
            Button("Permanently Delete Everything", role: .destructive) {
                store.deleteHabit(habit.id, deleteHistoricalRecords: true)
                habitPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                habitPendingDeletion = nil
            }
        } message: { habit in
            Text("Archiving removes '\(habit.name)' from active schedules while preserving all past daily completion records. Permanent deletion removes both the habit and its history.")
        }
    }
}
