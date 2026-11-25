import AppKit
import FinderSync
import OSLog
import SwiftUI

private enum SettingsSection: String, CaseIterable, Identifiable, Hashable {
    case general
    case newFile
    case openMethod
    case fileOperations

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "基本设置"
        case .newFile: "新建文件"
        case .openMethod: "打开方式"
        case .fileOperations: "文件操作"
        }
    }

    var toolbarTitle: String {
        switch self {
        case .general: "基本设置"
        case .newFile: "新建文件"
        case .openMethod: "打开方式"
        case .fileOperations: "文件操作"
        }
    }

    var icon: String {
        switch self {
        case .general: "gearshape"
        case .newFile: "doc.badge.plus"
        case .openMethod: "arrow.up.forward.app"
        case .fileOperations: "folder.badge.gearshape"
        }
    }
}

private struct PreferenceGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            configuration.label
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .padding(.leading, 2)

            configuration.content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.38))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}

struct ContentView: View {
    @StateObject private var folderStore = FolderAccessStore()
    @State private var selectedSection: SettingsSection = .general
    @State private var hoveredSection: SettingsSection?
    @State private var isFinderExtensionEnabled = FIFinderSyncController.isExtensionEnabled
    @State private var customFormatSuffix = ""
    @State private var customFormatValidationMessage: String?
    @State private var isShowingUninstallAlert = false
    @State private var isShowingUninstallResult = false
    @State private var uninstallResultMessage = ""
    private let logger = Logger(subsystem: "com.rightly.app", category: "SettingsUI")
    private let keySuperGreen = Color(red: 0.37, green: 0.72, blue: 0.21)

    var body: some View {
        VStack(spacing: 0) {
            settingsToolbar

            Divider()

            ScrollView(.vertical, showsIndicators: true) {
                detailSection(selectedSection)
                    .frame(maxWidth: 480, alignment: .topLeading)
                    .padding(.horizontal, 22)
                    .padding(.top, 20)
                    .padding(.bottom, 28)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .id(selectedSection)
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .groupBoxStyle(PreferenceGroupBoxStyle())
        .tint(keySuperGreen)
        .frame(minWidth: 520, idealWidth: 540, minHeight: 640, idealHeight: 760)
        .background(Color(nsColor: .windowBackgroundColor))
        .ignoresSafeArea(.container, edges: .top)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshExtensionStatus()
        }
        .onAppear {
            refreshExtensionStatus()
        }
    }

    private var settingsToolbar: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 12)

            HStack(spacing: 10) {
                ForEach(SettingsSection.allCases) { section in
                    Button {
                        withAnimation(.easeInOut(duration: 0.16)) {
                            selectedSection = section
                        }
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: section.icon)
                                .font(.system(size: 20, weight: .regular))
                                .symbolRenderingMode(.monochrome)
                                .frame(width: 30, height: 26)

                            Text(section.toolbarTitle)
                                .font(.system(size: 12, weight: .regular))
                                .lineLimit(1)
                        }
                        .foregroundStyle(selectedSection == section ? keySuperGreen : Color.secondary)
                        .frame(width: 82, height: 56)
                        .background {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(
                                    selectedSection == section
                                        ? keySuperGreen.opacity(0.08)
                                        : hoveredSection == section
                                            ? Color(nsColor: .separatorColor).opacity(0.12)
                                            : .clear
                                )
                        }
                        .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .onHover { isHovered in
                        hoveredSection = isHovered ? section : nil
                    }
                }
            }
            .frame(height: 62)

            Spacer(minLength: 6)
        }
        .frame(height: 82)
        .frame(maxWidth: .infinity)
        .background(.thinMaterial)
    }

    private var extensionManagementControls: some View {
        HStack(spacing: 10) {
            Text(isFinderExtensionEnabled ? "已开启" : "未开启")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isFinderExtensionEnabled ? keySuperGreen : Color.secondary)

            Button("管理…") {
                showExtensionManagement()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .help(isFinderExtensionEnabled ? "在系统设置中管理访达扩展" : "前往系统设置开启访达扩展")
    }


    @ViewBuilder
    private func detailSection(_ section: SettingsSection) -> some View {
        switch section {
        case .general:
            generalDetail
        case .newFile:
            newFileDetail
        case .openMethod:
            openMethodDetail
        case .fileOperations:
            fileOperationsDetail
        }
    }

    private var generalDetail: some View {
        VStack(alignment: .leading, spacing: 20) {
            GroupBox("开启右键菜单") {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("在访达中使用 Rightly")
                            .font(.system(size: 14, weight: .medium))
                        Text("开启后，Rightly 会显示在访达（Finder）的右键菜单中。")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    extensionManagementControls
                }
                .frame(minHeight: 44)
            }

            GroupBox("授权可用文件夹") {
                VStack(alignment: .leading, spacing: 9) {
                    Text("选择授权 Rightly 显示菜单的文件夹。添加的文件夹也包含里面的所有子文件夹。")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if folderStore.folders.isEmpty {
                        Text("还没有添加文件夹。添加后，Rightly 才会出现在对应位置的右键菜单中。")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(folderStore.folders) { folder in
                            HStack(spacing: 9) {
                                Image(systemName: "folder.fill")
                                    .foregroundStyle(.tint)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(folder.displayName)
                                    Text(folder.path)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Text("已授权")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Button(role: .destructive) {
                                    folderStore.remove(folder)
                                } label: {
                                    Image(systemName: "minus.circle")
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("移除文件夹 \(folder.displayName)")
                                .help("不再在这个文件夹中显示 Rightly")
                            }
                        }
                    }
                    Button("添加文件夹…") { folderStore.chooseFolders() }
                        .buttonStyle(.bordered)
                }
                .padding(.vertical, 3)
            }

            GroupBox("完整卸载") {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("卸载 Rightly")
                            .font(.system(size: 14, weight: .medium))
                        Text("清除全部设置、注销访达扩展，并将应用移到废纸篓。")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("卸载 Rightly…", role: .destructive) {
                        isShowingUninstallAlert = true
                    }
                    .buttonStyle(.bordered)
                }
                .frame(minHeight: 44)
            }
        }
        .alert("卸载 Rightly", isPresented: $isShowingUninstallAlert) {
            Button("取消", role: .cancel) {}
            Button("彻底卸载", role: .destructive) {
                uninstallRightly()
            }
        } message: {
            Text("这会删除授权文件夹、功能设置、模板与常用文件夹等全部 Rightly 数据，注销 Finder 扩展，然后将 Rightly 移到废纸篓。此操作无法撤销。")
        }
        .alert("无法卸载", isPresented: $isShowingUninstallResult) {
            Button("好") {}
        } message: {
            Text(uninstallResultMessage)
        }
    }

    private var newFileDetail: some View {
        VStack(alignment: .leading, spacing: 20) {
            GroupBox("新建文件") {
                VStack(alignment: .leading, spacing: 10) {
                    featureToggle(.newFile)
                    Divider()

                    Text("可以新建的文件类型")
                        .font(.system(size: 12, weight: .semibold))

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 8) {
                        ForEach(FileFormat.allCases) { format in
                            Toggle(
                                format.settingsTitle,
                                isOn: Binding(
                                    get: { folderStore.isEnabled(format) },
                                    set: { folderStore.setEnabled($0, for: format) }
                                )
                            )
                            .toggleStyle(.checkbox)
                            .frame(minHeight: 32)
                        }
                    }
                    .disabled(!folderStore.isEnabled(.newFile))

                    Divider()

                    Text("添加其他文件类型")
                        .font(.system(size: 12, weight: .semibold))
                    Text("输入扩展名，例如 yaml。此功能只创建空文件，适合文本、代码和配置文件，不适合 PDF、图片或压缩包。")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(folderStore.customFormats) { format in
                        HStack(spacing: 9) {
                            Toggle(
                                format.settingsTitle,
                                isOn: Binding(
                                    get: { format.isEnabled },
                                    set: { folderStore.setEnabled($0, for: format) }
                                )
                            )
                            .toggleStyle(.checkbox)
                            Spacer()
                            Button(role: .destructive) {
                                folderStore.removeCustomFormat(format)
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("移除文件类型 \(format.settingsTitle)")
                            .help("移除这个文件类型")
                        }
                        .frame(minHeight: 32)
                    }
                    .disabled(!folderStore.isEnabled(.newFile))

                    HStack(spacing: 8) {
                        TextField(
                            "输入扩展名，例如 yaml",
                            text: Binding(
                                get: { customFormatSuffix },
                                set: {
                                    customFormatSuffix = $0
                                    customFormatValidationMessage = nil
                                }
                            )
                        )
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(submitCustomFormat)
                        Button("添加") { submitCustomFormat() }
                            .buttonStyle(.bordered)
                            .disabled(trimmedCustomFormatSuffix.isEmpty)
                    }
                    .disabled(!folderStore.isEnabled(.newFile))

                    if let customFormatValidationMessage {
                        Text(customFormatValidationMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .accessibilityLabel("输入错误：\(customFormatValidationMessage)")
                    }

                    if enabledNewFileItemCount == 0 {
                        Text("请至少选择一种文件类型或添加一个模板，否则“新建文件”不会显示。")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                .padding(.vertical, 3)
            }

            GroupBox("用模板新建") {
                VStack(alignment: .leading, spacing: 10) {
                    if folderStore.templateDirectories.isEmpty {
                        Text("添加存放模板文件的文件夹，之后可以直接从右键菜单复制模板来创建文件。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(folderStore.templateDirectories) { directory in
                            HStack(spacing: 9) {
                                Image(systemName: "folder")
                                    .foregroundStyle(.tint)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(directory.displayName)
                                    Text(directory.path)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Button(role: .destructive) {
                                    folderStore.removeTemplateDirectory(directory)
                                } label: {
                                    Image(systemName: "minus.circle")
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("移除模板文件夹 \(directory.displayName)")
                                .help("移除这个模板文件夹")
                            }
                        }
                    }

                    HStack {
                        Button("添加模板文件夹…") { folderStore.chooseTemplateDirectory() }
                            .buttonStyle(.bordered)
                    }
                }
                .padding(.vertical, 3)
                .disabled(!folderStore.isEnabled(.newFile))
            }

            GroupBox("从剪贴板新建") {
                featureToggle(.clipboard)
            }
        }
    }

    private var openMethodDetail: some View {
        VStack(alignment: .leading, spacing: 20) {
            GroupBox("使用编辑器打开") {
                VStack(alignment: .leading, spacing: 0) {
                    featureToggle(.editor)
                    Divider()
                    ForEach(Array(EditorApp.allCases.enumerated()), id: \.element.id) { index, app in
                        appChoice(app.title, isOn: folderStore.isEnabled(app), installed: folderStore.isInstalled(bundleIdentifier: app.bundleIdentifier), featureEnabled: folderStore.isEnabled(.editor)) {
                            folderStore.setEnabled($0, for: app)
                        }

                        if index < EditorApp.allCases.count - 1 {
                            Divider()
                        }
                    }
                }
            }

            GroupBox("在终端中打开") {
                VStack(alignment: .leading, spacing: 0) {
                    featureToggle(.terminal)
                    Divider()
                    ForEach(Array(TerminalApp.allCases.enumerated()), id: \.element.id) { index, app in
                        appChoice(app.title, isOn: folderStore.isEnabled(app), installed: folderStore.isInstalled(bundleIdentifier: app.bundleIdentifier), featureEnabled: folderStore.isEnabled(MenuFeature.terminal)) {
                            folderStore.setEnabled($0, for: app)
                        }

                        if index < TerminalApp.allCases.count - 1 {
                            Divider()
                        }
                    }
                }
            }

            GroupBox("使用 AI 工具打开") {
                VStack(alignment: .leading, spacing: 0) {
                    featureToggle(.ai)
                    Divider()
                    ForEach(Array(AITool.allCases.enumerated()), id: \.element.id) { index, tool in
                        appChoice(tool.title, isOn: folderStore.isEnabled(tool), installed: isInstalled(tool), featureEnabled: folderStore.isEnabled(.ai)) {
                            folderStore.setEnabled($0, for: tool)
                        }

                        if index < AITool.allCases.count - 1 {
                            Divider()
                        }
                    }
                }
            }

            Text("没有安装的应用不会显示在访达右键菜单中。重新安装后，之前的选择会自动恢复。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var fileOperationsDetail: some View {
        VStack(alignment: .leading, spacing: 20) {
            GroupBox("拷贝文件信息") {
                VStack(alignment: .leading, spacing: 0) {
                    featureToggle(.copyPath)
                    Divider()
                    ForEach(Array(PathCopyFormat.allCases.enumerated()), id: \.element.id) { index, format in
                        Toggle(
                            format.title,
                            isOn: Binding(
                                get: { folderStore.isEnabled(format) },
                                set: { folderStore.setEnabled($0, for: format) }
                            )
                        )
                        .toggleStyle(.checkbox)
                        .frame(minHeight: 36)
                        .disabled(!folderStore.isEnabled(.copyPath))

                        if index < PathCopyFormat.allCases.count - 1 {
                            Divider()
                        }
                    }
                }
                .padding(.vertical, 3)
            }

            GroupBox("拷贝或移动到常用文件夹") {
                VStack(alignment: .leading, spacing: 10) {
                    featureToggle(.organize)
                    Divider()

                    Text("常用目标文件夹")
                        .font(.system(size: 12, weight: .semibold))
                    Text("添加后，可以从右键菜单快速把文件拷贝或移动到这些位置。")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if folderStore.favoriteFolders.isEmpty {
                        Text("还没有添加目标文件夹。添加后，“拷贝到”和“移动到”才会显示。")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(folderStore.favoriteFolders) { folder in
                            HStack(spacing: 9) {
                                Image(systemName: "folder")
                                    .foregroundStyle(.tint)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(folder.displayName)
                                    Text(folder.path)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Button(role: .destructive) {
                                    folderStore.removeFavoriteFolder(folder)
                                } label: {
                                    Image(systemName: "minus.circle")
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("移除目标文件夹 \(folder.displayName)")
                                .help("移除这个目标文件夹")
                            }
                        }
                        .disabled(!folderStore.isEnabled(.organize))
                    }

                    Button("添加目标文件夹…") { folderStore.chooseFavoriteFolders() }
                        .buttonStyle(.bordered)
                        .disabled(!folderStore.isEnabled(.organize))
                }
                .padding(.vertical, 3)
            }

            GroupBox("批量重命名") {
                VStack(alignment: .leading, spacing: 9) {
                    featureToggle(.batchRename)
                }
                .padding(.vertical, 3)
            }
        }
    }

    private var enabledNewFileItemCount: Int {
        folderStore.enabledFormats.count
            + folderStore.customFormats.filter(\.isEnabled).count
            + folderStore.templateDirectories.count
    }

    private func featureToggle(_ feature: MenuFeature) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(featureControlTitle(feature))
                    .font(.system(size: 13, weight: .medium))
                Text(featureSubtitle(feature))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle(
                "",
                isOn: Binding(
                    get: { folderStore.isEnabled(feature) },
                    set: { folderStore.setEnabled($0, for: feature) }
                )
            )
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
            .accessibilityLabel(feature.title)
        }
        .frame(minHeight: 44)
    }

    private func appChoice(
        _ title: String,
        isOn: Bool,
        installed: Bool,
        featureEnabled: Bool,
        setEnabled: @escaping (Bool) -> Void
    ) -> some View {
        HStack(spacing: 12) {
            Toggle(title, isOn: Binding(get: { isOn }, set: setEnabled))
                .toggleStyle(.checkbox)
                .disabled(!installed || !featureEnabled)
                .accessibilityLabel("在访达菜单中显示 \(title)")

            Spacer()

            Text(installed ? "已安装" : "未安装")
                .font(.caption)
                .foregroundStyle(.secondary)

        }
        .frame(minHeight: 38)
    }

    private var trimmedCustomFormatSuffix: String {
        customFormatSuffix.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func submitCustomFormat() {
        guard !trimmedCustomFormatSuffix.isEmpty else { return }
        folderStore.addCustomFormat(suffix: customFormatSuffix)
        customFormatValidationMessage = folderStore.errorMessage
        if customFormatValidationMessage == nil {
            customFormatSuffix = ""
        }
    }

    private func featureSubtitle(_ feature: MenuFeature) -> String {
        switch feature {
        case .newFile:
            "关闭后会保留下面选择的文件类型和模板。"
        case .clipboard:
            "剪贴板中有文字时可新建文本文件，有图片时可新建 PNG 图像。"
        case .editor:
            "使用已安装的编辑器打开所选文件或当前文件夹。"
        case .terminal:
            "从当前文件夹打开终端。"
        case .ai:
            "将当前文件夹发送到已安装的 AI 编程工具。"
        case .copyPath:
            "将文件名称、位置或链接拷贝到剪贴板。"
        case .organize:
            "快速把所选文件拷贝或移动到常用位置。"
        case .batchRename:
            "同时选择两个或更多文件时显示此操作。"
        }
    }

    private func featureControlTitle(_ feature: MenuFeature) -> String {
        switch feature {
        case .newFile:
            "在右键菜单中显示“新建文件”"
        case .clipboard:
            "根据剪贴板内容新建文件"
        case .editor:
            "显示编辑器列表"
        case .terminal:
            "显示终端应用列表"
        case .ai:
            "显示 AI 工具列表"
        case .copyPath:
            "显示“拷贝为”"
        case .organize:
            "显示“拷贝到”和“移动到”"
        case .batchRename:
            "显示“批量重命名”"
        }
    }

    private func isInstalled(_ tool: AITool) -> Bool {
        var components = URLComponents()
        switch tool {
        case .claudeCode:
            components.scheme = "claude"
            components.host = "code"
            components.path = "/new"
        case .codex:
            components.scheme = "codex"
            components.host = "new"
        }
        return components.url.flatMap(NSWorkspace.shared.urlForApplication(toOpen:)) != nil
    }

    private func showExtensionManagement() {
        logger.notice("P10 opening Finder extension management, enabled=\(isFinderExtensionEnabled, privacy: .public)")
        let helperURL = Bundle.main.bundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("MacOS", isDirectory: true)
            .appendingPathComponent("RightlyUninstaller", isDirectory: false)
        let appPath = Bundle.main.bundleURL.path

        guard FileManager.default.isExecutableFile(atPath: helperURL.path) else {
            FIFinderSyncController.showExtensionManagementInterface()
            refreshExtensionStatus()
            return
        }

        DispatchQueue.global(qos: .utility).async {
            let process = Process()
            process.executableURL = helperURL
            process.arguments = ["ensure", appPath]
            try? process.run()
            process.waitUntilExit()

            DispatchQueue.main.async {
                logger.notice("P10 Finder extension registration check completed: status=\(process.terminationStatus, privacy: .public)")
                FIFinderSyncController.showExtensionManagementInterface()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    refreshExtensionStatus()
                }
            }
        }
    }

    private func uninstallRightly() {
        let helperURL = Bundle.main.bundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("MacOS", isDirectory: true)
            .appendingPathComponent("RightlyUninstaller", isDirectory: false)
        guard FileManager.default.isExecutableFile(atPath: helperURL.path) else {
            uninstallResultMessage = "未找到卸载助手，无法完成卸载。"
            isShowingUninstallResult = true
            return
        }

        do {
            try SharedSettings.removeAllData()
            logger.notice("P20 all shared settings removed")
        } catch {
            uninstallResultMessage = "无法清除 Rightly 设置：\(error.localizedDescription)"
            isShowingUninstallResult = true
            return
        }

        let appPath = Bundle.main.bundleURL.path
        logger.notice("P20 starting complete uninstall helper")
        let process = Process()
        process.executableURL = helperURL
        process.arguments = ["uninstall", appPath, String(ProcessInfo.processInfo.processIdentifier)]

        do {
            try process.run()
            logger.notice("P21 uninstall helper started; terminating application")
            NSApp.terminate(nil)
        } catch {
            uninstallResultMessage = "无法启动卸载助手：\(error.localizedDescription)"
            isShowingUninstallResult = true
        }
    }

    private func refreshExtensionStatus() {
        updateExtensionStatus()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            updateExtensionStatus()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            updateExtensionStatus()
        }
    }

    private func updateExtensionStatus() {
        let currentValue = FIFinderSyncController.isExtensionEnabled
        if currentValue != isFinderExtensionEnabled {
            logger.notice("P11 Finder extension state changed to \(currentValue, privacy: .public)")
            isFinderExtensionEnabled = currentValue
        }
    }

}
