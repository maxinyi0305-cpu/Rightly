import AppKit
import FinderSync
import OSLog
import SwiftUI

private enum SettingsSection: String, CaseIterable, Identifiable, Hashable {
    case menu
    case newFile
    case openMethod
    case fileOperations

    var id: String { rawValue }

    var title: String {
        switch self {
        case .menu: "右键菜单"
        case .newFile: "新建文件"
        case .openMethod: "打开方式"
        case .fileOperations: "文件操作"
        }
    }

    var toolbarTitle: String {
        switch self {
        case .menu: "授权"
        case .newFile: "新建"
        case .openMethod: "打开方式"
        case .fileOperations: "文件操作"
        }
    }

    var icon: String {
        switch self {
        case .menu: "list.bullet.circle"
        case .newFile: "doc.badge.plus"
        case .openMethod: "arrow.up.forward.app"
        case .fileOperations: "folder.badge.gearshape"
        }
    }
}

private struct PreferenceGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            configuration.label
                .font(.system(size: 15, weight: .semibold))

            configuration.content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.55), lineWidth: 0.7)
                }
        }
    }
}

struct ContentView: View {
    @StateObject private var folderStore = FolderAccessStore()
    @State private var selectedSection: SettingsSection = .menu
    @State private var hoveredSection: SettingsSection?
    @State private var isFinderExtensionEnabled = FIFinderSyncController.isExtensionEnabled
    @State private var customFormatSuffix = ""
    private let logger = Logger(subsystem: "com.keysuper.app", category: "SettingsUI")

    var body: some View {
        VStack(spacing: 0) {
            settingsToolbar

            Divider()

            ScrollView(.vertical, showsIndicators: true) {
                detailSection(selectedSection)
                    .frame(maxWidth: 620, alignment: .topLeading)
                    .padding(.horizontal, 40)
                    .padding(.top, 34)
                    .padding(.bottom, 44)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .id(selectedSection)
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .groupBoxStyle(PreferenceGroupBoxStyle())
        .frame(minWidth: 820, idealWidth: 900, minHeight: 590, idealHeight: 720)
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
            Text("设置")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(height: 32)

            HStack(spacing: 7) {
                ForEach(SettingsSection.allCases) { section in
                    Button {
                        withAnimation(.easeInOut(duration: 0.16)) {
                            selectedSection = section
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: section.icon)
                                .font(.system(size: 20, weight: .regular))
                                .frame(width: 30, height: 29)

                            Text(section.toolbarTitle)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)
                        }
                        .foregroundStyle(selectedSection == section ? Color.accentColor : Color.secondary)
                        .frame(width: 62, height: 58)
                        .background {
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(
                                    selectedSection == section
                                        ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.1)
                                        : hoveredSection == section
                                            ? Color(nsColor: .separatorColor).opacity(0.12)
                                            : .clear
                                )
                        }
                        .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .onHover { isHovered in
                        hoveredSection = isHovered ? section : nil
                    }
                }
            }
            .frame(height: 68)
        }
        .frame(height: 100)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
    }

    private func extensionStatusButton() -> some View {
        Button {
            showExtensionManagement()
        } label: {
            Text(isFinderExtensionEnabled ? "功能已启用 · 点击管理" : "功能未启用 · 点击启用")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(
                    isFinderExtensionEnabled
                        ? Color(red: 0.102, green: 0.557, blue: 0.239)
                        : Color(red: 0.73, green: 0.102, blue: 0.102)
                )
                .padding(.horizontal, 13)
                .padding(.vertical, 7)
                .background(
                    isFinderExtensionEnabled
                        ? Color(red: 0.894, green: 0.973, blue: 0.922)
                        : Color(red: 1, green: 0.91, blue: 0.9)
                )
                .clipShape(Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(isFinderExtensionEnabled ? "点击打开系统设置并关闭 Finder 扩展" : "点击打开系统设置并启用 Finder 扩展")
    }


    @ViewBuilder
    private func detailSection(_ section: SettingsSection) -> some View {
        switch section {
        case .menu:
            menuDetail
        case .newFile:
            newFileDetail
        case .openMethod:
            openMethodDetail
        case .fileOperations:
            fileOperationsDetail
        }
    }

    private var menuDetail: some View {
        VStack(alignment: .leading, spacing: 24) {
            pageTitle("右键菜单", subtitle: "设置 Finder 中显示哪些功能，并管理菜单使用权限。")

            GroupBox("Finder 扩展") {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Finder 右键菜单")
                            .font(.system(size: 14, weight: .medium))
                        Text("启用后，KEY SUPER 菜单会显示在 Finder 的右键菜单中。")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    extensionStatusButton()
                }
                .frame(minHeight: 44)
            }

            GroupBox("授权") {
                VStack(alignment: .leading, spacing: 9) {
                    if folderStore.folders.isEmpty {
                        Text("尚未授权文件夹。添加后，KEY SUPER 才会在对应位置显示右键菜单。")
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
                                Button(role: .destructive) {
                                    folderStore.remove(folder)
                                } label: {
                                    Image(systemName: "minus.circle")
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    Button("添加授权文件夹…") { folderStore.chooseFolders() }
                        .buttonStyle(.borderedProminent)
                }
                .padding(.vertical, 3)
            }

            GroupBox("右键功能") {
                VStack(alignment: .leading, spacing: 0) {
                    navigationRow(
                        title: "新建文件",
                        subtitle: "创建空白文件或模板文件",
                        section: .newFile,
                        status: "\(enabledNewFileCount) 项"
                    )
                    Divider()
                    navigationRow(
                        title: "打开方式",
                        subtitle: "选择终端、编辑器或 AI 工具",
                        section: .openMethod,
                        status: "\(enabledOpenMethodCount) 项"
                    )
                    Divider()
                    navigationRow(
                        title: "文件操作",
                        subtitle: "复制路径、复制移动和批量处理",
                        section: .fileOperations,
                        status: "\(enabledFileOperationCount) 项"
                    )
                }
                .padding(.vertical, 3)
            }
        }
    }

    private var newFileDetail: some View {
        VStack(alignment: .leading, spacing: 18) {
            pageTitle("新建文件", subtitle: "配置空白文件和模板文件的创建方式。")

            GroupBox("空白文件格式") {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 9) {
                    ForEach(FileFormat.allCases) { format in
                        Toggle(
                            format.shortName,
                            isOn: Binding(
                                get: { folderStore.isEnabled(format) },
                                set: { folderStore.setEnabled($0, for: format) }
                            )
                        )
                        .toggleStyle(.checkbox)
                    }
                }
                .padding(.vertical, 3)

                if folderStore.enabledFormats.isEmpty {
                    Text("至少启用一种格式，Finder 中才会显示“新建”菜单。")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(.top, 8)
                }
            }

            GroupBox("自定义后缀") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("添加后，后缀会出现在 Finder 的“新建”菜单中。")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if !folderStore.customFormats.isEmpty {
                        ForEach(folderStore.customFormats) { format in
                            HStack(spacing: 9) {
                                Toggle(
                                    format.menuTitle,
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
                            }
                        }
                    }

                    HStack(spacing: 8) {
                        TextField("例如：log、yaml、conf", text: $customFormatSuffix)
                            .textFieldStyle(.roundedBorder)
                        Button("添加后缀") {
                            folderStore.addCustomFormat(suffix: customFormatSuffix)
                            if folderStore.errorMessage == nil {
                                customFormatSuffix = ""
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(.vertical, 3)
            }

            GroupBox("文件命名") {
                Picker(
                    "命名方式",
                    selection: Binding(
                        get: { folderStore.newFileNamingMode },
                        set: { folderStore.setNewFileNamingMode($0) }
                    )
                ) {
                    ForEach(NewFileNamingMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
            }

            GroupBox("模板文件") {
                VStack(alignment: .leading, spacing: 10) {
                    if folderStore.templateDirectories.isEmpty {
                        Text("只保存模板目录地址，创建时实时复制模板内容。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(folderStore.templateDirectories) { directory in
                            HStack(spacing: 9) {
                                Image(systemName: "folder")
                                    .foregroundStyle(.tint)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(directory.displayName)
                                    Text("模板目录")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button(role: .destructive) {
                                    folderStore.removeTemplateDirectory(directory)
                                } label: {
                                    Image(systemName: "minus.circle")
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    HStack {
                        Button("添加模板目录…") { folderStore.chooseTemplateDirectory() }
                    }
                }
                .padding(.vertical, 3)
            }
        }
    }

    private var openMethodDetail: some View {
        VStack(alignment: .leading, spacing: 18) {
            pageTitle("打开方式", subtitle: "选择可以从 Finder 中打开文件或文件夹的应用。")

            GroupBox("编辑器") {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(EditorApp.allCases.enumerated()), id: \.element.id) { index, app in
                        appToggle(app.title, isOn: folderStore.isEnabled(app), installed: folderStore.isInstalled(bundleIdentifier: app.bundleIdentifier)) {
                            folderStore.setEnabled($0, for: app)
                        }

                        if index < EditorApp.allCases.count - 1 {
                            Divider()
                        }
                    }
                }
            }

            GroupBox("终端") {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(TerminalApp.allCases.enumerated()), id: \.element.id) { index, app in
                        appToggle(app.title, isOn: folderStore.isEnabled(app), installed: folderStore.isInstalled(bundleIdentifier: app.bundleIdentifier)) {
                            folderStore.setEnabled($0, for: app)
                        }

                        if index < TerminalApp.allCases.count - 1 {
                            Divider()
                        }
                    }
                }
            }

            GroupBox("AI 工具") {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(AITool.allCases.enumerated()), id: \.element.id) { index, tool in
                        appToggle(tool.title, isOn: folderStore.isEnabled(tool), installed: isInstalled(tool)) {
                            folderStore.setEnabled($0, for: tool)
                        }

                        if index < AITool.allCases.count - 1 {
                            Divider()
                        }
                    }
                }
            }

            Text("未找到的应用会自动从 Finder 菜单中隐藏。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var fileOperationsDetail: some View {
        VStack(alignment: .leading, spacing: 18) {
            pageTitle("文件操作", subtitle: "配置路径复制、文件复制移动和批量处理功能。")

            GroupBox("复制内容") {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(PathCopyFormat.allCases.enumerated()), id: \.element.id) { index, format in
                        Toggle(
                            format.title,
                            isOn: Binding(
                                get: { folderStore.isEnabled(format) },
                                set: { folderStore.setEnabled($0, for: format) }
                            )
                        )
                        .toggleStyle(.checkbox)
                        .frame(minHeight: 38)

                        if index < PathCopyFormat.allCases.count - 1 {
                            Divider()
                        }
                    }
                }
                .padding(.vertical, 3)
            }

            GroupBox("复制和移动") {
                VStack(alignment: .leading, spacing: 9) {
                    featureToggle(MenuFeature.organize)
                }
                .padding(.vertical, 3)
            }

            GroupBox("常用目录") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("这些目录会显示在“复制到”和“移动到”菜单中。")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if folderStore.favoriteFolders.isEmpty {
                        Text("尚未添加常用目录。")
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
                                Button("移除", role: .destructive) {
                                    folderStore.removeFavoriteFolder(folder)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Button("添加常用目录…") { folderStore.chooseFavoriteFolders() }
                }
                .padding(.vertical, 3)
            }

            GroupBox("批量处理") {
                VStack(alignment: .leading, spacing: 9) {
                    featureToggle(MenuFeature.batchRename)
                }
                .padding(.vertical, 3)
            }
        }
    }

    private func navigationRow(title: String, subtitle: String, section: SettingsSection, status: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.16)) {
                selectedSection = section
            }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var enabledNewFileCount: Int {
        folderStore.enabledFormats.count
            + folderStore.customFormats.filter(\.isEnabled).count
            + folderStore.templateDirectories.count
    }

    private var enabledOpenMethodCount: Int {
        folderStore.enabledEditorApps.count
            + folderStore.enabledTerminalApps.count
            + folderStore.enabledAITools.count
    }

    private var enabledFileOperationCount: Int {
        folderStore.enabledPathCopyFormats.count
            + (folderStore.isEnabled(.organize) ? 1 : 0)
            + (folderStore.isEnabled(.batchRename) ? 1 : 0)
    }

    private func featureToggle(_ feature: MenuFeature) -> some View {
        Toggle(
            feature.title,
            isOn: Binding(
                get: { folderStore.isEnabled(feature) },
                set: { folderStore.setEnabled($0, for: feature) }
            )
        )
        .toggleStyle(.switch)
        .controlSize(.small)
        .frame(minHeight: 42)
    }

    private func pageTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 20, weight: .semibold))
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
    }

    private func sectionHeading(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .padding(.top, 2)
    }

    private func appToggle(
        _ title: String,
        isOn: Bool,
        installed: Bool,
        setEnabled: @escaping (Bool) -> Void
    ) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13))

            Spacer()

            if installed {
                Text("已安装")
                    .font(.caption)
                    .foregroundStyle(.green)
            } else {
                Text("未找到应用")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Toggle("", isOn: Binding(get: { isOn }, set: setEnabled))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .disabled(!installed)
        }
        .frame(minHeight: 42)
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
        FIFinderSyncController.showExtensionManagementInterface()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            refreshExtensionStatus()
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
