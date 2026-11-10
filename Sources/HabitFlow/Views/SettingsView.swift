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
    @EnvironmentObject private var store: HabitStore

    public let palette: HabitFlowPalette

    @State private var isExportingBackup: Bool = false
    @State private var isImportingBackup: Bool = false
    @State private var backupDocumentToExport: HabitFlowBackupFileDocument? = nil
    @State private var statusBannerMessage: String? = nil

    public init(palette: HabitFlowPalette) {
        self.palette = palette
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Settings")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)
                    Text("Customize appearance, schedule defaults, notifications, and local offline backups.")
                        .font(.system(size: 13))
                        .foregroundStyle(palette.secondaryText)
                }

                if let msg = statusBannerMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(msg)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(palette.primaryText)
                        Spacer()
                        Button("Dismiss") { statusBannerMessage = nil }
                            .font(.system(size: 11))
                    }
                    .habitFlowCard(palette: palette, padding: 12)
                }

                // 1. Appearance Section (Dark Mode, Light Mode, System Appearance, Accent Color)
                VStack(alignment: .leading, spacing: 14) {
                    Label("Appearance", systemImage: "paintbrush.fill")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)

                    HStack {
                        Text("Theme Mode")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(palette.primaryText)
                        Spacer()
                        Picker("Theme Mode", selection: $store.settings.appearanceMode) {
                            ForEach(AppAppearanceMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 340)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Accent Color")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(palette.primaryText)

                        HStack(spacing: 12) {
                            ForEach(AccentThemeColor.allCases) { theme in
                                let isSelected = (store.settings.accentColor == theme)
                                Button {
                                    store.settings.accentColor = theme
                                } label: {
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(theme.color)
                                            .frame(width: 16, height: 16)
                                        Text(theme.rawValue)
                                            .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                                            .foregroundStyle(palette.primaryText)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(isSelected ? theme.color.opacity(0.18) : palette.secondarySurface)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .strokeBorder(isSelected ? theme.color : Color.clear, lineWidth: 1.5)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .habitFlowCard(palette: palette, padding: 18)

                // 2. Preferences Section (Week Starting Day, Default Frequency, Notifications, Dashboard Controls)
                VStack(alignment: .leading, spacing: 14) {
                    Label("Preferences", systemImage: "slider.horizontal.3")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)

                    HStack {
                        Text("Week Starting Day")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(palette.primaryText)
                        Spacer()
                        Picker("Week Starting Day", selection: $store.settings.weekStartDay) {
                            ForEach(WeekStartDay.allCases) { day in
                                Text(day.rawValue).tag(day)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 220)
                    }

                    Divider()

                    HStack {
                        Text("Default Habit Frequency")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(palette.primaryText)
                        Spacer()
                        Picker("Default Habit Frequency", selection: $store.settings.defaultFrequency) {
                            ForEach(HabitFrequency.allCases) { freq in
                                Text(freq.rawValue).tag(freq)
                            }
                        }
                        .frame(width: 220)
                    }

                    Divider()

                    Toggle("Show Decrease [ - ] Buttons on Dashboard Rows", isOn: $store.settings.showDecreaseButtonsOnDashboard)
                        .font(.system(size: 13, weight: .medium))

                    Toggle("Show Motivational Subtitle in Dashboard Header", isOn: $store.settings.showMotivationalGreeting)
                        .font(.system(size: 13, weight: .medium))

                    Toggle("Enable Native macOS Habit Reminder Notifications", isOn: $store.settings.notificationsEnabled)
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

                // 3. Data & Offline Backup Management Section
                VStack(alignment: .leading, spacing: 14) {
                    Label("Local Data & Backups", systemImage: "externaldrive.fill.badge.checkmark")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)

                    Text("All habits, historical target changes, progress entries, and daily notes are saved locally offline.")
                        .font(.system(size: 12))
                        .foregroundStyle(palette.secondaryText)

                    HStack(spacing: 12) {
                        Button {
                            if let data = try? store.exportBackupJSONData() {
                                backupDocumentToExport = HabitFlowBackupFileDocument(data: data)
                                isExportingBackup = true
                            }
                        } label: {
                            Label("Export Data / Create Backup...", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            isImportingBackup = true
                        } label: {
                            Label("Import / Restore Backup...", systemImage: "square.and.arrow.down")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .habitFlowCard(palette: palette, padding: 18)

                // 4. Application Info Section
                VStack(alignment: .leading, spacing: 10) {
                    Label("Application", systemImage: "info.circle.fill")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)

                    HStack {
                        Text("HabitFlow for macOS")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(palette.primaryText)
                        Spacer()
                        Text("Version 1.0.0 (Native Swift & SwiftUI)")
                            .font(.system(size: 12))
                            .foregroundStyle(palette.secondaryText)
                    }

                    Text("Designed for focused daily consistency, instant quick-add tracking, effective-dated target history, and distraction-free conditional missed-day reviews.")
                        .font(.system(size: 12))
                        .foregroundStyle(palette.secondaryText)
                }
                .habitFlowCard(palette: palette, padding: 18)
            }
            .padding(32)
            .frame(maxWidth: 920, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
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
