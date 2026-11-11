import SwiftUI

// MARK: - 2. Dedicated Missed & Unfinished Page + Smart Recovery (Section 12)

public struct MissedAndUnfinishedView: View {
    @AppStorage("interfaceLanguage") private var interfaceLanguage = "en"
    @EnvironmentObject private var store: HabitStore

    public let palette: HabitFlowPalette
    public let onEditHabit: (Habit) -> Void

    @State private var expandedDateKeys: Set<String> = []
    @State private var filterMode: String = "All Unfinished"
    @State private var itemTypeFilter = "Все"

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
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 7) {
                            Text(L10n.tr("Missed &")).foregroundStyle(palette.primaryText)
                            Text(L10n.tr("Unfinished")).italic().foregroundStyle(palette.accentText)
                        }
                        .font(HabitFlowTypography.display(42, weight: .bold))
                        Text(L10n.tr("История пропущенных и незавершённых норм"))
                            .font(HabitFlowTypography.body(13))
                            .foregroundStyle(palette.secondaryText)
                    }
                    Spacer()
                    Text(L10n.tr("\(missedRecords.reduce(0) { $0 + $1.missedOrPartialStatuses.count }) пунктов"))
                        .font(HabitFlowTypography.body(12, weight: .semibold))
                        .foregroundStyle(palette.atRiskColor)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Capsule().fill(palette.secondarySurface))
                }

                HStack(spacing: 12) {
                    Picker(L10n.tr("Тип"), selection: $itemTypeFilter) {
                        ForEach(["Все", "Только привычки", "Только цели"], id: \.self) { Text(L10n.tr($0)).tag($0) }
                    }
                    .frame(width: 190)
                    Picker(L10n.tr("Состояние"), selection: $filterMode) {
                        Text(L10n.tr("Все пропуски")).tag("All Unfinished")
                        Text(L10n.tr("Частично выполнено")).tag("Partially Completed Only")
                        Text(L10n.tr("Не начато")).tag("Fully Missed Only")
                    }
                    .frame(width: 220)
                }

                // Smart Recovery Gentle Banner (Section 12)
                if itemTypeFilter != "Только цели" && !recoverySuggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "heart.text.square.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(palette.accent)
                            Text(L10n.tr("Smart Recovery Suggestion"))
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(palette.primaryText)
                        }

                        ForEach(recoverySuggestions) { suggestion in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(L10n.tr(suggestion.message))
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(palette.primaryText)

                                HStack(spacing: 10) {
                                    Button(L10n.tr("Continue Normal Target")) {
                                        store.dismissRecoverySuggestion(for: suggestion.habit.id)
                                    }
                                    .buttonStyle(.bordered)

                                    if suggestion.habit.measurementType != .checkbox {
                                        Button(L10n.tr("Temporarily Reduce to \(NumberFormattingHelper.format(suggestion.suggestedReducedTarget)) \(suggestion.habit.unit)")) {
                                            store.applyTemporaryTargetReduction(for: suggestion)
                                        }
                                        .buttonStyle(.borderedProminent)
                                    }

                                    Button(L10n.tr("Change Schedule...")) {
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
                if itemTypeFilter == "Только цели" {
                    VStack(spacing: 10) {
                        Image(systemName: "target")
                            .font(.system(size: 24)).foregroundStyle(palette.secondaryText)
                        Text(L10n.tr("История выполнения целей пока не отслеживается"))
                            .font(HabitFlowTypography.body(14, weight: .semibold))
                            .foregroundStyle(palette.primaryText)
                        Text(L10n.tr("Здесь появятся цели после добавления учёта их прогресса."))
                            .font(HabitFlowTypography.body(12)).foregroundStyle(palette.secondaryText)
                    }
                    .frame(maxWidth: .infinity, minHeight: 140)
                    .habitFlowCard(palette: palette)
                } else if missedRecords.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.green)
                        Text(L10n.tr("You're all caught up!"))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(palette.primaryText)
                        Text(L10n.tr("No missed or partially completed scheduled habits in your history."))
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
                                        Text(L10n.tr(record.friendlyTitle))
                                            .font(HabitFlowTypography.body(15, weight: .semibold))
                                            .foregroundStyle(palette.primaryText)

                                        Text(L10n.tr("(\(record.dateKey))"))
                                            .font(.system(size: 12))
                                            .foregroundStyle(palette.secondaryText)

                                        Spacer()

                                        Text(L10n.tr("Day Completion: \(Int(record.completionPercentage))% • \(record.fullyMissedCount) missed, \(record.partialCount) partial"))
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
                                                Text(L10n.tr("Effective target on \(record.dateKey): \(NumberFormattingHelper.formatWithUnit(st.target, unit: st.habit.unit, measurementType: st.habit.measurementType))"))
                                                    .font(.system(size: 11))
                                                    .foregroundStyle(palette.secondaryText)
                                            }

                                            Spacer()

                                            HStack(spacing: 8) {
                                                Circle().fill(palette.atRiskColor).frame(width: 6, height: 6)
                                                Text(L10n.tr("Под угрозой"))
                                                    .font(HabitFlowTypography.body(11, weight: .semibold))
                                                    .foregroundStyle(palette.atRiskColor)
                                                Button(L10n.tr("Отметить задним числом")) {
                                                    store.addProgressEntry(for: st.habit.id, dateKey: record.dateKey,
                                                                           amount: st.remainingAmount,
                                                                           label: "Запись задним числом")
                                                }
                                                .font(HabitFlowTypography.body(11, weight: .medium))
                                                .buttonStyle(.bordered)
                                            }
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
            .padding(.horizontal, 40)
            .padding(.vertical, 32)
            .frame(maxWidth: 1280, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}
