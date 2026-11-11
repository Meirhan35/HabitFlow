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
        self.accent = Self.color(0xFC734D)
    }

    private static func color(_ hex: UInt32) -> Color {
        Color(red: Double((hex >> 16) & 0xFF) / 255,
              green: Double((hex >> 8) & 0xFF) / 255,
              blue: Double(hex & 0xFF) / 255)
    }

    public var accentText: Color { Self.color(colorScheme == .dark ? 0xFC734D : 0xB8380F) }
    public var onAccent: Color { Self.color(0x0A1430) }
    public var sidebarBackground: Color { Self.color(colorScheme == .dark ? 0x071029 : 0xF8FAFD) }
    public var menuText: Color { Self.color(colorScheme == .dark ? 0xC3CDE6 : 0x34405E) }
    public var activeNavigation: Color { Self.color(colorScheme == .dark ? 0x1B2A55 : 0xFDEAE3) }
    public var progressTrack: Color { Self.color(colorScheme == .dark ? 0x1B2A55 : 0xE8EBF4) }
    public var heroBackground: Color { Self.color(colorScheme == .dark ? 0x16275A : 0x0A1430) }
    public var aheadColor: Color { Self.color(colorScheme == .dark ? 0x3FB950 : 0x166534) }
    public var onTrackColor: Color { Self.color(colorScheme == .dark ? 0xE3B341 : 0x92400E) }
    public var atRiskColor: Color { Self.color(colorScheme == .dark ? 0xFF7B8B : 0xB42318) }
    public var chartBar: Color { Self.color(colorScheme == .dark ? 0x1D5F99 : 0x8CC8EE) }
    public var heatmapColors: [Color] {
        (colorScheme == .dark ? [0x172650, 0x4A3650, 0x9A4A4C, 0xFC734D, 0xFFB199]
                              : [0xEDEFF6, 0xFDD5C7, 0xFCA68B, 0xFC734D, 0xB93A16]).map(Self.color)
    }
    public func priorityColor(_ priority: String) -> Color {
        switch priority {
        case "high": return Self.color(0xFC734D)
        case "medium": return Self.color(0x0297DE)
        default: return Self.color(0x94A3B8)
        }
    }

    public var windowBackground: Color {
        Self.color(colorScheme == .dark ? 0x0A1430 : 0xF3F5FA)
    }

    public var cardBackground: Color {
        Self.color(colorScheme == .dark ? 0x101C40 : 0xFFFFFF)
    }

    public var secondarySurface: Color {
        Self.color(colorScheme == .dark ? 0x1B2A55 : 0xE8EBF4)
    }

    public var primaryText: Color {
        Self.color(colorScheme == .dark ? 0xEEF3FF : 0x0A1430)
    }

    public var secondaryText: Color {
        Self.color(colorScheme == .dark ? 0x9FADCC : 0x55607C)
    }

    public var subtleBorder: Color {
        Self.color(colorScheme == .dark ? 0x22305B : 0xE1E6F0)
    }

    public var cardShadow: Color {
        Color.clear
    }
}

public struct HabitFlowCardModifier: ViewModifier {
    let palette: HabitFlowPalette
    var paddingAmount: CGFloat = 20
    var cornerRadius: CGFloat = 22

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
    }
}

extension View {
    public func habitFlowCard(palette: HabitFlowPalette, padding: CGFloat = 20, cornerRadius: CGFloat = 22) -> some View {
        modifier(HabitFlowCardModifier(palette: palette, paddingAmount: padding, cornerRadius: cornerRadius))
    }
}

// MARK: - 3. Elegant Smooth Progress Bar

public struct SmoothProgressBar: View {
    @AppStorage("interfaceLanguage") private var interfaceLanguage = "en"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: fraction)
            }
        }
        .frame(height: height)
    }
}

// MARK: - 4. Habit Icon Badge

public struct HabitIconBadge: View {
    @AppStorage("interfaceLanguage") private var interfaceLanguage = "en"
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
                .fill(accent.opacity(isCompleted ? 0.22 : 0.15))
                .frame(width: size, height: size)

            if icon.unicodeScalars.first?.properties.isEmojiPresentation == true || icon.count == 1 {
                Text(L10n.tr(icon))
                    .font(.system(size: size * 0.48))
            } else {
                Image(systemName: icon)
                    .font(.system(size: size * 0.44, weight: .semibold))
                    .foregroundStyle(accent)
            }
        }
    }
}

// MARK: - 5. Root MainWindowView (NavigationSplitView + Modals)

public struct MainWindowView: View {
    @AppStorage("interfaceLanguage") private var interfaceLanguage = "en"
    @EnvironmentObject private var store: HabitStore
    @EnvironmentObject private var timerManager: ActiveHabitTimerManager
    @EnvironmentObject private var assistantHistory: AssistantChatStore
    @Environment(\.colorScheme) private var systemColorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var connectivity = ConnectivityMonitor()

    @State private var selectedSection: SidebarDestination = .dashboard
    @State private var isPresentingCreateHabitModal: Bool = false
    @State private var habitBeingEdited: Habit? = nil
    @State private var habitForDetailedStats: Habit? = nil
    @State private var hoveredSection: SidebarDestination? = nil
    @State private var recentlyAddedHabit: Habit?

    private var effectiveColorScheme: ColorScheme {
        previewColorScheme ?? store.settings.appearanceMode.colorScheme ?? systemColorScheme
    }

    private var previewColorScheme: ColorScheme? {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--preview-theme=dark") { return .dark }
        if arguments.contains("--preview-theme=light") { return .light }
        return nil
    }

    private var palette: HabitFlowPalette {
        HabitFlowPalette(
            colorScheme: effectiveColorScheme,
            accent: store.settings.accentColor.color
        )
    }

    public init() {}

    public var body: some View {
        GeometryReader { geometry in
            let isCompact = geometry.size.width < 900
            HStack(spacing: 0) {
                sidebarContent(isCompact: isCompact)
                    .frame(width: isCompact ? 72 : 248)

                Rectangle()
                    .fill(palette.subtleBorder)
                    .frame(width: 1)

                ZStack {
                    palette.windowBackground.ignoresSafeArea()
                    detailContent
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .top) {
                    if connectivity.isOffline || ProcessInfo.processInfo.arguments.contains("--preview-offline") {
                        Label(L10n.tr("Нет подключения к интернету. Данные привычек доступны локально."),
                              systemImage: "wifi.slash")
                            .font(HabitFlowTypography.body(12, weight: .medium))
                            .foregroundStyle(palette.primaryText)
                            .padding(.horizontal, 14)
                            .frame(height: 36)
                            .background(Capsule().fill(palette.cardBackground))
                            .overlay(Capsule().strokeBorder(palette.subtleBorder))
                            .padding(.top, 8)
                    }
                }
            }
        }
        .background(keyboardNavigation)
        .overlay(alignment: .bottomTrailing) {
            if let recentlyAddedHabit {
                HStack(spacing: 12) {
                    Label(L10n.tr("Привычка сохранена"), systemImage: "checkmark.circle.fill")
                        .font(HabitFlowTypography.body(12, weight: .medium))
                    Button(L10n.tr("Отменить")) {
                        store.deleteHabit(recentlyAddedHabit.id, deleteHistoricalRecords: true)
                        self.recentlyAddedHabit = nil
                    }
                    .font(HabitFlowTypography.body(12, weight: .semibold))
                    .foregroundStyle(palette.accentText)
                }
                .foregroundStyle(palette.primaryText)
                .padding(.horizontal, 16)
                .frame(height: 44)
                .background(RoundedRectangle(cornerRadius: 14).fill(palette.cardBackground))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(palette.subtleBorder))
                .padding(20)
            }
        }
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("--preview-modal=addHabit") {
                isPresentingCreateHabitModal = true
            }
            if let destinationName = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--preview-section=") })?.replacingOccurrences(of: "--preview-section=", with: ""),
               let destination = SidebarDestination.allCases.first(where: { String(describing: $0) == destinationName }) {
                selectedSection = destination
            }
        }
        .preferredColorScheme(previewColorScheme ?? store.settings.appearanceMode.colorScheme)
        .tint(palette.accent)
        .sheet(isPresented: $isPresentingCreateHabitModal) {
            HabitEditorModalView(
                mode: .create,
                palette: palette,
                onSave: { newHabit in
                    store.addHabit(newHabit)
                    recentlyAddedHabit = newHabit
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        if recentlyAddedHabit?.id == newHabit.id { recentlyAddedHabit = nil }
                    }
                },
                onDiscussWithAssistant: { prompt in
                    assistantHistory.pendingPrompt = prompt
                    selectedSection = .assistant
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

    private func sidebarContent(isCompact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // App Brand Header
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(palette.heroBackground)
                        .frame(width: 36, height: 36)
                    Image(systemName: "sparkles")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(palette.accent)
                }

                if !isCompact { VStack(alignment: .leading, spacing: 1) {
                    Text(L10n.tr("HabitFlow"))
                        .font(HabitFlowTypography.body(16, weight: .semibold))
                        .foregroundStyle(palette.primaryText)
                    Text(L10n.tr("Personal Habit Studio"))
                        .font(HabitFlowTypography.body(11, weight: .medium))
                        .foregroundStyle(palette.secondaryText)
                } }
                Spacer()
            }
            .padding(.horizontal, isCompact ? 18 : 16)
            .padding(.top, 22)
            .padding(.bottom, 24)

            // Prominent + Add Habit Button in Sidebar
            Button {
                isPresentingCreateHabitModal = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .bold))
                        .frame(width: isCompact ? 20 : nil)
                    if !isCompact {
                        Text(L10n.tr("Add Habit"))
                            .lineLimit(1).minimumScaleFactor(0.75)
                            .font(HabitFlowTypography.body(13, weight: .semibold))
                        Spacer()
                        Text(L10n.tr("⌘N"))
                            .font(HabitFlowTypography.body(11, weight: .medium))
                            .opacity(0.75)
                    }
                }
                .foregroundStyle(palette.onAccent)
                .frame(minHeight: 38)
                .padding(.horizontal, isCompact ? 11 : 14)
                .background(
                    Capsule(style: .continuous)
                        .fill(palette.accent)
                )
            }
            .buttonStyle(.plain)
            .keyboardShortcut("n", modifiers: [.command])
            .help(L10n.tr("Add Habit ⌘N"))
            .padding(.horizontal, isCompact ? 8 : 14)
            .padding(.bottom, 22)

            // Navigation Links
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(SidebarDestination.allCases) { item in
                        sidebarRow(for: item, isCompact: isCompact)
                    }
                }
                .padding(.horizontal, isCompact ? 8 : 10)
            }

            Spacer()

            // Active Timer Status Pill if running
            if !isCompact, let activeId = timerManager.activeHabitId,
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
                        Text(L10n.tr(timerManager.formattedElapsed))
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(palette.accent)
                    }
                    HStack(spacing: 8) {
                        Button(L10n.tr(timerManager.isRunning ? "Pause" : "Resume")) {
                            if timerManager.isRunning {
                                timerManager.pause()
                            } else {
                                timerManager.startOrResume(for: activeId)
                            }
                        }
                        .font(.system(size: 11, weight: .medium))

                        Button(L10n.tr("Log & Finish")) {
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

            let streak = store.calculateStatistics(for: .days30).currentOverallStreak
            if !isCompact {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text(L10n.tr("\(streak)"))
                            .font(HabitFlowTypography.number(35))
                            .foregroundStyle(palette.accentText)
                        Text(L10n.tr("дней подряд"))
                            .font(HabitFlowTypography.body(12, weight: .semibold))
                            .foregroundStyle(palette.primaryText)
                    }
                    Text(L10n.tr(streak >= 100 ? "Серия из 100 дней получена" : "До следующего бейджа: \(nextBadge(after: streak) - streak) дн."))
                        .font(HabitFlowTypography.body(11))
                        .foregroundStyle(palette.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 18).fill(palette.cardBackground))
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(palette.subtleBorder))
                .padding(.horizontal, 12)
                .padding(.bottom, 16)
            } else {
                Image(systemName: "flame.fill")
                    .foregroundStyle(palette.accentText)
                    .frame(maxWidth: .infinity)
                    .help(L10n.tr("Серия: \(streak) дней"))
                    .padding(.bottom, 20)
            }
        }
        .background(palette.sidebarBackground)
    }

    private func nextBadge(after streak: Int) -> Int {
        [7, 30, 100].first(where: { streak < $0 }) ?? 100
    }

    private func sidebarRow(for item: SidebarDestination, isCompact: Bool) -> some View {
        let isSelected = (selectedSection == item)
        return Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                selectedSection = item
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: item.sfSymbol)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? palette.accentText : palette.menuText)
                    .frame(width: 22)

                if !isCompact { Text(L10n.tr(item.rawValue))
                    .font(HabitFlowTypography.body(13, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? palette.accentText : palette.menuText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82) }

                Spacer()

                if item == .missedAndUnfinished && !isCompact {
                    let count = store.allMissedDaysHistory(lookbackDays: 60).count
                    if count > 0 {
                        Text(L10n.tr("\(count)"))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(palette.secondaryText)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(palette.secondarySurface)
                            )
                    }
                }
            }
            .padding(.horizontal, isCompact ? 14 : 12)
            .frame(minHeight: 40)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? palette.activeNavigation : (hoveredSection == item ? palette.secondarySurface.opacity(0.55) : Color.clear))
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(L10n.tr(item.rawValue))
        .onHover { hoveredSection = $0 ? item : (hoveredSection == item ? nil : hoveredSection) }
    }

    private var keyboardNavigation: some View {
        Group {
            ForEach(Array(SidebarDestination.allCases.enumerated()), id: \.element.id) { index, destination in
                Button(L10n.tr(destination.rawValue)) { selectedSection = destination }
                    .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: [.command])
            }
            Button(L10n.tr("Open Assistant")) { selectedSection = .assistant }
                .keyboardShortcut("j", modifiers: [.command])
            Button(L10n.tr("Quick Goal Input")) { selectedSection = .assistant }
                .keyboardShortcut("k", modifiers: [.command])
            Button(L10n.tr("Open Settings")) { selectedSection = .settings }
                .keyboardShortcut(",", modifiers: [.command])
        }
        .hidden()
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
