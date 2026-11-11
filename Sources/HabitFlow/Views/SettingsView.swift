import SwiftUI
import UniformTypeIdentifiers

// MARK: - 1. Backup FileDocument for Native macOS Export/Import Dialogs

public struct HabitFlowBackupFileDocument: FileDocument {
    public static var readableContentTypes: [UTType] { [.json] }

    public var data: Data

    public init(data: Data) {
        self.data = data
    }

    public init(configuration: ReadConfiguration) throws {
        guard let fileData = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = fileData
    }

    public func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - 2. Settings & Preferences Page (Section 2 & Section 18)

public struct SettingsPreferencesView: View {
    @AppStorage("interfaceLanguage") private var interfaceLanguage = "en"
    @EnvironmentObject private var store: HabitStore

    public let palette: HabitFlowPalette

    @State private var isExportingBackup: Bool = false
    @State private var isImportingBackup: Bool = false
    @State private var backupDocumentToExport: HabitFlowBackupFileDocument? = nil
    @State private var statusBannerMessage: String? = nil
    @State private var selectedSection = "Внешний вид"
    private let sections = ["Внешний вид", "Уведомления", "Данные и резервные копии", "Язык", "Аккаунт", "О приложении"]

    private var displayedAppearanceMode: AppAppearanceMode {
        if ProcessInfo.processInfo.arguments.contains("--preview-theme=dark") { return .dark }
        if ProcessInfo.processInfo.arguments.contains("--preview-theme=light") { return .light }
        return store.settings.appearanceMode
    }

    public init(palette: HabitFlowPalette) {
        self.palette = palette
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 5) {
                ForEach(sections, id: \.self) { section in
                    Button { selectedSection = section } label: {
                        Text(L10n.tr(section))
                            .font(HabitFlowTypography.body(12, weight: selectedSection == section ? .semibold : .medium))
                            .foregroundStyle(selectedSection == section ? palette.accentText : palette.menuText)
                            .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
                            .padding(.horizontal, 12)
                            .background(RoundedRectangle(cornerRadius: 12)
                                .fill(selectedSection == section ? palette.activeNavigation : Color.clear))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(14)
            .frame(width: 210)
            .background(palette.sidebarBackground)
            Rectangle().fill(palette.subtleBorder).frame(width: 1)
            ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.tr("Settings"))
                        .font(HabitFlowTypography.display(42, weight: .bold))
                        .foregroundStyle(palette.primaryText)
                    Text(L10n.tr(selectedSection))
                        .font(HabitFlowTypography.body(13))
                        .foregroundStyle(palette.secondaryText)
                }

                if let msg = statusBannerMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(L10n.tr(msg))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(palette.primaryText)
                        Spacer()
                        Button(L10n.tr("Dismiss")) { statusBannerMessage = nil }
                            .font(.system(size: 11))
                    }
                    .habitFlowCard(palette: palette, padding: 12)
                }

                if selectedSection == "Внешний вид" {
                // 1. Appearance Section
                VStack(alignment: .leading, spacing: 14) {
                    Label(L10n.tr("Appearance"), systemImage: "paintbrush.fill")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)

                    HStack(spacing: 12) {
                        ForEach(AppAppearanceMode.allCases) { mode in
                            Button { store.settings.appearanceMode = mode } label: {
                                VStack(alignment: .leading, spacing: 9) {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(mode == .light ? Color.white : Color(red: 0.06, green: 0.11, blue: 0.25))
                                        .frame(height: 55)
                                        .overlay(alignment: .leading) {
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(mode == .light ? Color(red: 0.95, green: 0.96, blue: 0.98) : Color(red: 0.09, green: 0.16, blue: 0.36))
                                                .frame(width: 24)
                                                .padding(6)
                                        }
                                    Text(L10n.tr(mode == .light ? "Светлая" : mode == .dark ? "Тёмная" : "Как в системе"))
                                        .font(HabitFlowTypography.body(12, weight: .medium))
                                        .foregroundStyle(palette.primaryText)
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity)
                                .background(RoundedRectangle(cornerRadius: 14).fill(palette.secondarySurface))
                                .overlay(RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(displayedAppearanceMode == mode ? palette.accent : palette.subtleBorder,
                                                  lineWidth: displayedAppearanceMode == mode ? 2 : 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Text(L10n.tr("Единый акцент приложения — тёплый оранжевый."))
                        .font(HabitFlowTypography.body(12))
                        .foregroundStyle(palette.secondaryText)
                }
                .habitFlowCard(palette: palette, padding: 18)
                }

                if selectedSection == "Уведомления" {
                // 2. Preferences Section (Week Starting Day, Default Frequency, Notifications, Dashboard Controls)
                VStack(alignment: .leading, spacing: 14) {
                    Label(L10n.tr("Preferences"), systemImage: "slider.horizontal.3")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)

                    HStack {
                        Text(L10n.tr("Week Starting Day"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(palette.primaryText)
                        Spacer()
                        Picker(L10n.tr("Week Starting Day"), selection: $store.settings.weekStartDay) {
                            ForEach(WeekStartDay.allCases) { day in
                                Text(L10n.tr(day.rawValue)).tag(day)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 220)
                    }

                    Divider()

                    HStack {
                        Text(L10n.tr("Default Habit Frequency"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(palette.primaryText)
                        Spacer()
                        Picker(L10n.tr("Default Habit Frequency"), selection: $store.settings.defaultFrequency) {
                            ForEach(HabitFrequency.allCases) { freq in
                                Text(L10n.tr(freq.rawValue)).tag(freq)
                            }
                        }
                        .frame(width: 220)
                    }

                    Divider()

                    Toggle(L10n.tr("Show Decrease [ - ] Buttons on Dashboard Rows"), isOn: $store.settings.showDecreaseButtonsOnDashboard)
                        .font(.system(size: 13, weight: .medium))

                    Toggle(L10n.tr("Show Motivational Subtitle in Dashboard Header"), isOn: $store.settings.showMotivationalGreeting)
                        .font(.system(size: 13, weight: .medium))

                    Toggle(L10n.tr("Enable Native macOS Habit Reminder Notifications"), isOn: $store.settings.notificationsEnabled)
                        .font(.system(size: 13, weight: .medium))
                        .onChange(of: store.settings.notificationsEnabled) { _, enabled in
                            if enabled {
                                HabitNotificationScheduler.shared.requestAuthorizationIfNeeded { _ in
                                    HabitNotificationScheduler.shared.syncNotifications(for: store.habits, globallyEnabled: true)
                                }
                            } else {
                                HabitNotificationScheduler.shared.syncNotifications(for: store.habits, globallyEnabled: false)
                            }
                        }
                }
                .habitFlowCard(palette: palette, padding: 18)
                Text(L10n.tr("Повторное вечернее напоминание и утренняя сводка пока недоступны."))
                    .font(HabitFlowTypography.body(12))
                    .foregroundStyle(palette.secondaryText)
                }

                if selectedSection == "Данные и резервные копии" {
                // 3. Data & Offline Backup Management Section
                VStack(alignment: .leading, spacing: 14) {
                    Label(L10n.tr("Local Data & Backups"), systemImage: "externaldrive.fill.badge.checkmark")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)

                    Text(L10n.tr("All habits, historical target changes, progress entries, and daily notes are saved locally offline."))
                        .font(.system(size: 12))
                        .foregroundStyle(palette.secondaryText)

                    HStack(spacing: 12) {
                        Button {
                            if let data = try? store.exportBackupJSONData() {
                                backupDocumentToExport = HabitFlowBackupFileDocument(data: data)
                                isExportingBackup = true
                            }
                        } label: {
                            Label(L10n.tr("Export Data / Create Backup..."), systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            isImportingBackup = true
                        } label: {
                            Label(L10n.tr("Import / Restore Backup..."), systemImage: "square.and.arrow.down")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .habitFlowCard(palette: palette, padding: 18)
                Text(L10n.tr("CSV-экспорт и удаление всех данных пока недоступны."))
                    .font(HabitFlowTypography.body(12))
                    .foregroundStyle(palette.secondaryText)
                }

                if selectedSection == "Язык" {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.tr("Язык интерфейса"))
                            .font(HabitFlowTypography.body(16, weight: .semibold))
                            .foregroundStyle(palette.primaryText)
                        Picker(L10n.tr("Язык интерфейса"), selection: $interfaceLanguage) {
                            Text("English").tag("en")
                            Text("Русский").tag("ru")
                        }
                        .pickerStyle(.segmented)
                        Text(L10n.tr("Language changes apply immediately and are saved on this Mac."))
                            .font(HabitFlowTypography.body(12))
                            .foregroundStyle(palette.secondaryText)
                    }
                    .habitFlowCard(palette: palette)
                }

                if selectedSection == "Аккаунт" {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.tr("Локальный профиль"))
                            .font(HabitFlowTypography.body(16, weight: .semibold))
                            .foregroundStyle(palette.primaryText)
                        Text(L10n.tr("Данные хранятся на этом Mac. Учётная запись и синхронизация пока недоступны."))
                            .font(HabitFlowTypography.body(12))
                            .foregroundStyle(palette.secondaryText)
                    }
                    .habitFlowCard(palette: palette)
                }

                if selectedSection == "О приложении" {
                // 4. Application Info Section
                VStack(alignment: .leading, spacing: 10) {
                    Label(L10n.tr("Application"), systemImage: "info.circle.fill")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)

                    HStack {
                        Text(L10n.tr("HabitFlow for macOS"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(palette.primaryText)
                        Spacer()
                        Text(L10n.tr("Version 1.0.0 (Native Swift & SwiftUI)"))
                            .font(.system(size: 12))
                            .foregroundStyle(palette.secondaryText)
                    }

                    Text(L10n.tr("Designed for focused daily consistency, instant quick-add tracking, effective-dated target history, and distraction-free conditional missed-day reviews."))
                        .font(.system(size: 12))
                        .foregroundStyle(palette.secondaryText)
                }
                .habitFlowCard(palette: palette, padding: 18)
                }
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 32)
            .frame(maxWidth: 1060, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .fileExporter(
            isPresented: $isExportingBackup,
            document: backupDocumentToExport,
            contentType: .json,
            defaultFilename: "HabitFlow_Backup_\(store.currentDateKey).json"
        ) { result in
            if case .success = result {
                statusBannerMessage = "Backup exported successfully."
            }
        }
        .fileImporter(
            isPresented: $isImportingBackup,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let firstURL = urls.first {
                if let data = try? Data(contentsOf: firstURL) {
                    try? store.importBackupJSONData(data)
                    statusBannerMessage = "Backup restored successfully."
                }
            }
        }
    }
}
