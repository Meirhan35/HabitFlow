import SwiftUI

// MARK: - 1. Sidebar Navigation Item

public enum SidebarDestination: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case myHabits = "My Habits"
    case assistant = "Assistant"
    case todaysGoals = "Today's Goals"
    case missedAndUnfinished = "Missed & Unfinished"
    case calendar = "Calendar"
    case statistics = "Statistics"
    case settings = "Settings"

    public var id: String { rawValue }

    public var sfSymbol: String {
        switch self {
        case .dashboard: return "square.grid.2x2.fill"
        case .myHabits: return "checklist"
        case .assistant: return "bubble.left.and.text.bubble.right.fill"
        case .todaysGoals: return "target"
        case .missedAndUnfinished: return "clock.arrow.circlepath"
        case .calendar: return "calendar"
        case .statistics: return "chart.bar.xaxis"
        case .settings: return "gearshape.fill"
        }
    }
}

// MARK: - 2. Adaptive Design Theme Tokens (Dark Primary + Light + System)

public struct HabitFlowPalette {
    public let colorScheme: ColorScheme
    public let accent: Color

    public init(colorScheme: ColorScheme, accent: Color) {
        self.colorScheme = colorScheme
        self.accent = accent
    }

    public var windowBackground: Color {
        colorScheme == .dark
            ? Color(red: 0.06, green: 0.065, blue: 0.08) // Deep charcoal/black (#0F1115)
            : Color(red: 0.97, green: 0.975, blue: 0.985) // Clean crisp alabaster/white
    }

    public var cardBackground: Color {
        colorScheme == .dark
            ? Color(red: 0.105, green: 0.115, blue: 0.14) // Elevated charcoal card (#1B1D24)
            : Color.white
    }

    public var secondarySurface: Color {
        colorScheme == .dark
            ? Color(red: 0.14, green: 0.155, blue: 0.19)
            : Color(red: 0.93, green: 0.94, blue: 0.96)
    }

    public var primaryText: Color {
        colorScheme == .dark
            ? Color(red: 0.96, green: 0.97, blue: 0.99)
            : Color(red: 0.09, green: 0.10, blue: 0.13)
    }

    public var secondaryText: Color {
        colorScheme == .dark
            ? Color(red: 0.62, green: 0.65, blue: 0.72)
            : Color(red: 0.42, green: 0.45, blue: 0.52)
    }

    public var subtleBorder: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.black.opacity(0.07)
    }

    public var cardShadow: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.35)
            : Color.black.opacity(0.05)
    }
}

public struct HabitFlowCardModifier: ViewModifier {
    let palette: HabitFlowPalette
    var paddingAmount: CGFloat = 18
    var cornerRadius: CGFloat = 14

    public func body(content: Content) -> some View {
        content
            .padding(paddingAmount)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(palette.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(palette.subtleBorder, lineWidth: 1)
            )
            .shadow(color: palette.cardShadow, radius: 10, x: 0, y: 4)
    }
}

extension View {
    public func habitFlowCard(palette: HabitFlowPalette, padding: CGFloat = 18, cornerRadius: CGFloat = 14) -> some View {
        modifier(HabitFlowCardModifier(palette: palette, paddingAmount: padding, cornerRadius: cornerRadius))
    }
}

// MARK: - 3. Elegant Smooth Progress Bar

public struct SmoothProgressBar: View {
    public let fraction: Double
    public let accentColor: Color
    public var height: CGFloat = 8
    public var trackColor: Color

    public init(fraction: Double, accentColor: Color, height: CGFloat = 8, trackColor: Color) {
        self.fraction = min(max(fraction, 0.0), 1.0)
        self.accentColor = accentColor
        self.height = height
        self.trackColor = trackColor
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(trackColor)
                    .frame(height: height)

                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [accentColor, accentColor.opacity(0.82)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, geo.size.width * fraction), height: height)
                    .animation(.spring(response: 0.35, dampingFraction: 0.82), value: fraction)
            }
        }
        .frame(height: height)
    }
}

// MARK: - 4. Habit Icon Badge

public struct HabitIconBadge: View {
    public let icon: String
    public let accent: Color
    public let isCompleted: Bool
    public var size: CGFloat = 38

    public init(icon: String, accent: Color, isCompleted: Bool, size: CGFloat = 38) {
        self.icon = icon
        self.accent = accent
        self.isCompleted = isCompleted
        self.size = size
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(isCompleted ? Color.green.opacity(0.18) : accent.opacity(0.15))
                .frame(width: size, height: size)

            if icon.unicodeScalars.first?.properties.isEmojiPresentation == true || icon.count == 1 {
                Text(icon)
                    .font(.system(size: size * 0.48))
            } else {
                Image(systemName: icon)
                    .font(.system(size: size * 0.44, weight: .semibold))
                    .foregroundStyle(isCompleted ? Color.green : accent)
            }
        }
    }
}

// MARK: - 5. Root MainWindowView (NavigationSplitView + Modals)

public struct MainWindowView: View {
    @EnvironmentObject private var store: HabitStore
    @EnvironmentObject private var timerManager: ActiveHabitTimerManager
    @Environment(\.colorScheme) private var systemColorScheme

    @State private var selectedSection: SidebarDestination = .dashboard
    @State private var isPresentingCreateHabitModal: Bool = false
    @State private var habitBeingEdited: Habit? = nil
    @State private var habitForDetailedStats: Habit? = nil

    private var effectiveColorScheme: ColorScheme {
        store.settings.appearanceMode.colorScheme ?? systemColorScheme
    }

    private var palette: HabitFlowPalette {
        HabitFlowPalette(
            colorScheme: effectiveColorScheme,
            accent: store.settings.accentColor.color
        )
    }

    public init() {}

    public var body: some View {
        NavigationSplitView {
            sidebarContent
                .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 270)
        } detail: {
            ZStack {
                palette.windowBackground
                    .ignoresSafeArea()

                detailContent
            }
        }
        .preferredColorScheme(store.settings.appearanceMode.colorScheme)
        .tint(store.settings.accentColor.color)
        .sheet(isPresented: $isPresentingCreateHabitModal) {
            HabitEditorModalView(
                mode: .create,
                palette: palette,
                onSave: { newHabit in
                    store.addHabit(newHabit)
                }
            )
            .environmentObject(store)
        }
        .sheet(item: $habitBeingEdited) { habitToEdit in
            HabitEditorModalView(
                mode: .edit(habitToEdit),
                palette: palette,
                onSave: { updatedHabit in
                    store.updateHabit(updatedHabit)
                }
            )
            .environmentObject(store)
        }
        .sheet(item: $habitForDetailedStats) { habit in
            HabitDetailAnalyticsModalView(habit: habit, palette: palette)
                .environmentObject(store)
        }
    }

    private var sidebarContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // App Brand Header
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [palette.accent, palette.accent.opacity(0.75)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                    Image(systemName: "checkmark.circle.badge.sparkles.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("HabitFlow")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)
                    Text("Personal Habit Studio")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(palette.secondaryText)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 14)

            // Prominent + Add Habit Button in Sidebar
            Button {
                isPresentingCreateHabitModal = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Add Habit")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text("⌘N")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .opacity(0.75)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(palette.accent)
                )
            }
            .buttonStyle(.plain)
            .keyboardShortcut("n", modifiers: [.command])
            .padding(.horizontal, 14)
            .padding(.bottom, 16)

            // Navigation Links
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(SidebarDestination.allCases) { item in
                        sidebarRow(for: item)
                    }
                }
                .padding(.horizontal, 10)
            }

            Spacer()

            // Active Timer Status Pill if running
            if let activeId = timerManager.activeHabitId,
               let activeHabit = store.habits.first(where: { $0.id == activeId }) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Circle()
                            .fill(timerManager.isRunning ? Color.green : Color.orange)
                            .frame(width: 7, height: 7)
                        Text(activeHabit.name)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(palette.primaryText)
                            .lineLimit(1)
                        Spacer()
                        Text(timerManager.formattedElapsed)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(palette.accent)
                    }
                    HStack(spacing: 8) {
                        Button(timerManager.isRunning ? "Pause" : "Resume") {
                            if timerManager.isRunning {
                                timerManager.pause()
                            } else {
                                timerManager.startOrResume(for: activeId)
                            }
                        }
                        .font(.system(size: 11, weight: .medium))

                        Button("Log & Finish") {
                            timerManager.stopAndCommit(into: store)
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(palette.accent)
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(palette.secondarySurface)
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            }

            // Compact Today Status Footer
            let todayOv = store.dailyProgressOverview(for: store.currentDateKey)
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .stroke(palette.secondarySurface, lineWidth: 3.5)
                        .frame(width: 26, height: 26)
                    Circle()
                        .trim(from: 0, to: todayOv.progressFraction)
                        .stroke(palette.accent, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 26, height: 26)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Today: \(Int(todayOv.completionPercentage))%")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(palette.primaryText)
                    Text("\(todayOv.completedCount) of \(todayOv.totalScheduledCount) completed")
                        .font(.system(size: 11))
                        .foregroundStyle(palette.secondaryText)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(palette.subtleBorder)
                    .frame(height: 1)
            }
        }
        .background(palette.cardBackground)
    }

    private func sidebarRow(for item: SidebarDestination) -> some View {
        let isSelected = (selectedSection == item)
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                selectedSection = item
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: item.sfSymbol)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? palette.accent : palette.secondaryText)
                    .frame(width: 20)

                Text(item.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? palette.primaryText : palette.secondaryText)

                Spacer()

                if item == .missedAndUnfinished {
                    let count = store.allMissedDaysHistory(lookbackDays: 60).count
                    if count > 0 {
                        Text("\(count)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(isSelected ? .white : palette.secondaryText)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(isSelected ? palette.accent : palette.secondarySurface)
                            )
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? palette.accent.opacity(0.14) : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selectedSection {
        case .dashboard:
            DashboardView(
                palette: palette,
                onAddHabit: { isPresentingCreateHabitModal = true },
                onEditHabit: { habitBeingEdited = $0 },
                onOpenAssistant: { selectedSection = .assistant },
                onOpenAllMissedHistory: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedSection = .missedAndUnfinished
                    }
                }
            )
        case .myHabits:
            MyHabitsView(
                palette: palette,
                onAddHabit: { isPresentingCreateHabitModal = true },
                onEditHabit: { habitBeingEdited = $0 },
                onInspectHabitStats: { habitForDetailedStats = $0 }
            )
        case .assistant:
            GoalAssistantView(palette: palette)
        case .todaysGoals:
            TodaysGoalsView(
                palette: palette,
                onAddHabit: { isPresentingCreateHabitModal = true }
            )
        case .missedAndUnfinished:
            MissedAndUnfinishedView(
                palette: palette,
                onEditHabit: { habitBeingEdited = $0 }
            )
        case .calendar:
            CalendarHistoryView(palette: palette)
        case .statistics:
            StatisticsAnalyticsView(
                palette: palette,
                onSelectHabitDetail: { habitForDetailedStats = $0 }
            )
        case .settings:
            SettingsPreferencesView(palette: palette)
        }
    }
}
