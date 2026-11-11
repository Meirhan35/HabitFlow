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
    @AppStorage("interfaceLanguage") private var interfaceLanguage = "en"
    @EnvironmentObject private var store: HabitStore
    @Environment(\.dismiss) private var dismiss

    public let mode: HabitEditorMode
    public let palette: HabitFlowPalette
    public let onSave: (Habit) -> Void
    public let onDiscussWithAssistant: (String) -> Void

    @State private var naturalLanguageInput: String = ""
    @State private var editorKind = "Привычка"

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

    public init(mode: HabitEditorMode, palette: HabitFlowPalette,
                onSave: @escaping (Habit) -> Void,
                onDiscussWithAssistant: @escaping (String) -> Void = { _ in }) {
        self.mode = mode
        self.palette = palette
        self.onSave = onSave
        self.onDiscussWithAssistant = onDiscussWithAssistant
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Modal Header
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.tr(mode.isEditing ? "Edit Habit" : "Add Habit"))
                        .font(HabitFlowTypography.display(31, weight: .bold))
                        .foregroundStyle(palette.primaryText)
                    Text(L10n.tr("Задайте норму и расписание для новой привычки"))
                        .font(HabitFlowTypography.body(12))
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
                    if !mode.isEditing {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(L10n.tr("Опишите обычными словами"))
                                .font(HabitFlowTypography.body(14, weight: .semibold))
                                .foregroundStyle(palette.primaryText)
                            TextField(L10n.tr("Например: хочу читать по 20 страниц каждый день"), text: $naturalLanguageInput)
                                .textFieldStyle(.roundedBorder)
                            HStack {
                                Text(L10n.tr("Для разбора текста и плана откройте Assistant"))
                                    .font(HabitFlowTypography.body(11))
                                    .foregroundStyle(palette.secondaryText)
                                Spacer()
                                Button(L10n.tr("Обсудить с Assistant")) {
                                    onDiscussWithAssistant(naturalLanguageInput)
                                    dismiss()
                                }
                                .font(HabitFlowTypography.body(12, weight: .semibold))
                                .disabled(naturalLanguageInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        }
                        .habitFlowCard(palette: palette, padding: 18)
                        Picker(L10n.tr("Тип"), selection: $editorKind) {
                            Text(L10n.tr("Привычка")).tag("Привычка")
                            Text(L10n.tr("Цель")).tag("Цель")
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 220)
                    }
                    if editorKind == "Цель" && !mode.isEditing {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.tr("Постановка цели"))
                                .font(HabitFlowTypography.body(15, weight: .semibold))
                                .foregroundStyle(palette.primaryText)
                            Text(L10n.tr("Assistant уточнит срок, этапы и привычки, затем покажет план перед сохранением. Цель не будет создана без подтверждения в чате."))
                                .font(HabitFlowTypography.body(12))
                                .foregroundStyle(palette.secondaryText)
                        }
                        .habitFlowCard(palette: palette)
                    } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.tr("Вот что я понял"))
                            .font(HabitFlowTypography.body(14, weight: .semibold))
                            .foregroundStyle(palette.primaryText)
                        Text(L10n.tr("Поля ниже заполняются вручную. Автоматический разбор доступен в Assistant."))
                            .font(HabitFlowTypography.body(11))
                            .foregroundStyle(palette.secondaryText)
                    }
                    // Basic Identity
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L10n.tr("Habit Identity"))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(palette.accent)

                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(L10n.tr("Habit Name"))
                                    .font(.system(size: 12, weight: .semibold))
                                TextField(L10n.tr("e.g., Read a book, Run 5 km, Drink Water"), text: $name)
                                    .textFieldStyle(.roundedBorder)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text(L10n.tr("Category"))
                                    .font(.system(size: 12, weight: .semibold))
                                HStack(spacing: 6) {
                                    if isAddingCustomCategory {
                                        TextField(L10n.tr("Custom category"), text: $customCategoryName)
                                            .textFieldStyle(.roundedBorder)
                                        Button(L10n.tr("Use")) {
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
                                        Picker(L10n.tr(""), selection: $category) {
                                            ForEach(store.settings.allCategories, id: \.self) { cat in
                                                Text(L10n.tr(cat)).tag(cat)
                                            }
                                        }
                                        .labelsHidden()
                                        .frame(width: 170)

                                        Button(L10n.tr("+ Custom")) {
                                            isAddingCustomCategory = true
                                        }
                                        .font(.system(size: 11, weight: .semibold))
                                    }
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text(L10n.tr("Description (Optional)"))
                                .font(.system(size: 12, weight: .semibold))
                            TextField(L10n.tr("Why does this habit matter to you?"), text: $habitDescription)
                                .textFieldStyle(.roundedBorder)
                        }

                        // Icon Picker
                        VStack(alignment: .leading, spacing: 6) {
                            Text(L10n.tr("Icon or Emoji"))
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
                                                .foregroundStyle(isSelected ? palette.onAccent : palette.primaryText)
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
                        Text(L10n.tr("Measurement Type & Targets"))
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
                                        Text(L10n.tr(mType.rawValue))
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

                        Text(L10n.tr(measurementType.description))
                            .font(.system(size: 11))
                            .foregroundStyle(palette.secondaryText)

                        // Dynamic fields based on selected measurement type
                        dynamicMeasurementFields
                    }
                    .habitFlowCard(palette: palette, padding: 16)

                    // Schedule & Reminders
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L10n.tr("Schedule & Reminders"))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(palette.accent)

                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(L10n.tr("Frequency"))
                                    .font(.system(size: 12, weight: .semibold))
                                Picker(L10n.tr(""), selection: $frequency) {
                                    ForEach(HabitFrequency.allCases) { freq in
                                        Text(L10n.tr(freq.rawValue)).tag(freq)
                                    }
                                }
                                .labelsHidden()
                                .frame(width: 200)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text(L10n.tr("Estimated Duration (mins, optional)"))
                                    .font(.system(size: 12, weight: .semibold))
                                TextField(L10n.tr("e.g., 30"), text: $estimatedDurationText)
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
                                        Text(L10n.tr(day.shortName))
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
                            Toggle(L10n.tr("Enable Daily Reminder Notification"), isOn: $reminderEnabled)
                                .font(.system(size: 12, weight: .semibold))

                            if reminderEnabled {
                                HStack(spacing: 6) {
                                    Picker(L10n.tr("Hour"), selection: $reminderHour) {
                                        ForEach(0..<24, id: \.self) { h in
                                            Text(String(format: "%02d", h)).tag(h)
                                        }
                                    }
                                    .labelsHidden()
                                    .frame(width: 65)

                                    Text(L10n.tr(":"))
                                        .font(.system(size: 13, weight: .bold))

                                    Picker(L10n.tr("Minute"), selection: $reminderMinute) {
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

                    }

                    if let validationMessage = validationMessage {
                        Text(L10n.tr(validationMessage))
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
                    Text(L10n.tr("Target changes are saved with today's effective date so historical completion percentages remain intact."))
                        .font(.system(size: 11))
                        .foregroundStyle(palette.secondaryText)
                }
                Spacer()
                Button(L10n.tr("Отмена")) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(L10n.tr(mode.isEditing ? "Save Changes" : (editorKind == "Цель" ? "Обсудить цель" : "Сохранить привычку"))) {
                    if editorKind == "Цель" && !mode.isEditing {
                        onDiscussWithAssistant(naturalLanguageInput)
                        dismiss()
                    } else {
                        saveHabit()
                    }
                }
                .font(HabitFlowTypography.body(12, weight: .semibold))
                .foregroundStyle(palette.onAccent)
                .padding(.horizontal, 16)
                .frame(height: 36)
                .background(Capsule().fill(palette.accent))
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
                .disabled(editorKind == "Цель" && naturalLanguageInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(palette.cardBackground)
        }
        .frame(width: 640, height: 660)
        .background(palette.windowBackground)
        .tint(palette.accent)
        .onAppear(perform: populateInitialValues)
    }

    @ViewBuilder
    private var dynamicMeasurementFields: some View {
        switch measurementType {
        case .duration:
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(L10n.tr("Time Unit"))
                        .font(.system(size: 11, weight: .semibold))
                    Picker(L10n.tr(""), selection: $unit) {
                        Text(L10n.tr("Minutes")).tag("minutes")
                        Text(L10n.tr("Hours")).tag("hours")
                    }
                    .labelsHidden()
                    .frame(width: 120)
                }
                numericalTargetInputs
            }

        case .distance:
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(L10n.tr("Distance Unit"))
                        .font(.system(size: 11, weight: .semibold))
                    Picker(L10n.tr(""), selection: $unit) {
                        Text(L10n.tr("Kilometers (km)")).tag("km")
                        Text(L10n.tr("Meters (m)")).tag("meters")
                    }
                    .labelsHidden()
                    .frame(width: 150)
                }
                numericalTargetInputs
            }

        case .checkbox:
            HStack(spacing: 16) {
                Label(L10n.tr("Single-click daily completion button (no numerical target needed)."), systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(palette.primaryText)
                Spacer()
                VStack(alignment: .leading, spacing: 5) {
                    Text(L10n.tr("Weekly Target (sessions, optional)"))
                        .font(.system(size: 11, weight: .semibold))
                    TextField(L10n.tr("e.g., 5"), text: $weeklyTargetText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 110)
                }
            }

        case .counter:
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(L10n.tr("Repetition Label"))
                        .font(.system(size: 11, weight: .semibold))
                    TextField(L10n.tr("reps, words, exercises"), text: $unit)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 140)
                }
                numericalTargetInputs
            }

        case .quantity, .customUnit:
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(L10n.tr(measurementType == .quantity ? "Quantity Unit" : "Custom Unit Name"))
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
                Text(L10n.tr("Daily Target"))
                    .font(.system(size: 11, weight: .semibold))
                TextField(L10n.tr("e.g., 30"), text: $dailyTargetText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 95)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(L10n.tr("Quick-Add (+) Increment"))
                    .font(.system(size: 11, weight: .semibold))
                TextField(L10n.tr("e.g., 5"), text: $quickAddIncrementText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 95)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(L10n.tr("Weekly Target (Optional)"))
                    .font(.system(size: 11, weight: .semibold))
                TextField(L10n.tr("Auto"), text: $weeklyTargetText)
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
