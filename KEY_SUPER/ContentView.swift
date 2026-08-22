import AppKit
import FinderSync
import OSLog
import SwiftUI

private enum SettingsSection: String, CaseIterable, Identifiable, Hashable {
    case authorization
    case menu
    case newFile
    case editor
    case terminal
    case ai
    case copyPath
    case organize

    var id: String { rawValue }

    var title: String {
        switch self {
        case .menu: "右键菜单"
        case .newFile: "新建文件"
        case .editor: "编辑器"
        case .terminal: "终端"
        case .ai: "AI 工具"
        case .copyPath: "路径复制"
        case .organize: "文件整理"
        case .authorization: "文件夹授权"
        }
    }

    var toolbarTitle: String {
        switch self {
        case .authorization: "授权"
        case .menu: "菜单"
        case .newFile: "新建"
        case .editor: "编辑器"
        case .terminal: "终端"
        case .ai: "AI"
        case .copyPath: "路径"
        case .organize: "整理"
        }
    }

    var icon: String {
        switch self {
        case .menu: "list.bullet.circle"
        case .newFile: "doc.badge.plus"
        case .editor: "chevron.left.forwardslash.chevron.right"
        case .terminal: "terminal"
        case .ai: "sparkles"
        case .copyPath: "doc.on.doc"
        case .organize: "folder.badge.gearshape"
        case .authorization: "lock.shield"
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
    @State private var selectedSection: SettingsSection = .authorization
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
        ZStack(alignment: .top) {
            Text("设置")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
                .padding(.top, 14)

            HStack(spacing: 7) {
                ForEach(SettingsSection.allCases) { section in
                    Button {
                        withAnimation(.easeInOut(duration: 0.16)) {
                            selectedSection = section
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: section.icon)
                                .font(.system(size: 25, weight: .regular))
                                .frame(width: 30, height: 29)

                            Text(section.toolbarTitle)
                                .font(.system(size: 13, weight: .medium))
                                .lineLimit(1)
                        }
                        .foregroundStyle(selectedSection == section ? Color.accentColor : Color.secondary)
                        .frame(width: 62, height: 66)
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
            .padding(.top, 42)
        }
        .frame(height: 118)
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
        case .editor:
            editorDetail
        case .terminal:
            terminalDetail
        case .ai:
            aiDetail
        case .copyPath:
            copyPathDetail
        case .organize:
            organizeDetail
        case .authorization:
            authorizationDetail
        }
    }

    private var menuDetail: some View {
        VStack(alignment: .leading, spacing: 24) {
            pageTitle("右键菜单", subtitle: "选择要显示在 Finder 中的功能。所有开关会实时同步到扩展。")

            GroupBox("显示功能") {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(MenuFeature.allCases.enumerated()), id: \.element.id) { index, feature in
                        HStack {
                            Text(feature.title)
                                .font(.system(size: 13))

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
                        }
                        .frame(minHeight: 42)

                        if index < MenuFeature.allCases.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private var newFileDetail: some View {
        VStack(alignment: .leading, spacing: 18) {
            pageTitle("新建文件", subtitle: "在当前 Finder 目录中直接创建空文件或模板。")

            GroupBox("空文件格式") {
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
                    Text("至少启用一种格式，Finder 中才会显示“空文件”菜单。")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(.top, 8)
                }
            }

            GroupBox("自定义后缀格式") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("添加 .log、.yaml、.conf 等自定义文件后缀，保存后会出现在 Finder 的“新建文件”菜单中。")
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
                        TextField("输入后缀，例如 log 或 yaml", text: $customFormatSuffix)
                            .textFieldStyle(.roundedBorder)
                        Button("添加") {
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

            GroupBox("创建时命名") {
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

            GroupBox("自定义模板") {
                VStack(alignment: .leading, spacing: 10) {
                    if folderStore.templateDirectories.isEmpty {
                        Text("添加目录时保存模板地址；目录内容变化后可手动刷新。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(folderStore.templateDirectories) { directory in
                            HStack(spacing: 9) {
                                Image(systemName: "folder")
                                    .foregroundStyle(.tint)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(directory.displayName)
                                    Text("\(directory.templates.count) 个模板地址")
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
                        Button("刷新模板地址") { folderStore.refreshTemplates() }
                            .disabled(folderStore.templateDirectories.isEmpty)
                    }
                }
                .padding(.vertical, 3)
            }
        }
    }

    private var editorDetail: some View {
        VStack(alignment: .leading, spacing: 18) {
            pageTitle("编辑器", subtitle: "选择在 Finder 中打开文件或文件夹时显示的编辑器。")
            GroupBox("可用编辑器") {
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
            Text("未安装的应用不会出现在 Finder 右键菜单中。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var terminalDetail: some View {
        VStack(alignment: .leading, spacing: 18) {
            pageTitle("终端", subtitle: "在当前 Finder 文件夹中打开终端窗口。")
            GroupBox("可用终端") {
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
            Text("Terminal 需要在系统设置的“隐私与安全性 > 自动化”中允许 KEY SUPER 控制它。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var aiDetail: some View {
        VStack(alignment: .leading, spacing: 18) {
            pageTitle("AI 工具", subtitle: "从 Finder 当前目录直接进入 AI 编程工作流。")
            GroupBox("可用工具") {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(AITool.allCases.enumerated()), id: \.element.id) { index, tool in
                        HStack {
                            Text(tool.title)
                                .font(.system(size: 13))

                            Spacer()

                            Toggle(
                                "",
                                isOn: Binding(
                                    get: { folderStore.isEnabled(tool) },
                                    set: { folderStore.setEnabled($0, for: tool) }
                                )
                            )
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.small)
                        }
                        .frame(minHeight: 42)

                        if index < AITool.allCases.count - 1 {
                            Divider()
                        }
                    }
                }
            }
            Text("未注册对应 URL scheme 的 AI 工具会自动从 Finder 菜单中隐藏。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var copyPathDetail: some View {
        VStack(alignment: .leading, spacing: 18) {
            pageTitle("路径复制", subtitle: "支持单选和多选项目，多个结果会按行复制。")
            GroupBox("复制格式") {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 9) {
                    ForEach(PathCopyFormat.allCases) { format in
                        Toggle(
                            format.title,
                            isOn: Binding(
                                get: { folderStore.isEnabled(format) },
                                set: { folderStore.setEnabled($0, for: format) }
                            )
                        )
                        .toggleStyle(.checkbox)
                    }
                }
                .padding(.vertical, 3)
            }
        }
    }

    private var organizeDetail: some View {
        VStack(alignment: .leading, spacing: 18) {
            pageTitle("文件整理", subtitle: "管理复制、移动和批量重命名功能。")
            GroupBox("功能") {
                VStack(alignment: .leading, spacing: 9) {
                    ForEach([MenuFeature.organize, MenuFeature.clipboard, MenuFeature.batchRename]) { feature in
                        Toggle(
                            feature.title,
                            isOn: Binding(
                                get: { folderStore.isEnabled(feature) },
                                set: { folderStore.setEnabled($0, for: feature) }
                            )
                        )
                        .toggleStyle(.checkbox)
                    }
                }
                .padding(.vertical, 3)
            }

            GroupBox("常用目录") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("这些目录会显示在 Finder 的“复制到”和“移动到”菜单中。")
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
                                Button(role: .destructive) {
                                    folderStore.removeFavoriteFolder(folder)
                                } label: {
                                    Image(systemName: "minus.circle")
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Button("添加常用目录…") { folderStore.chooseFavoriteFolders() }
                }
                .padding(.vertical, 3)
            }
        }
    }

    private var authorizationDetail: some View {
        VStack(alignment: .leading, spacing: 24) {
            pageTitle("文件夹授权", subtitle: "KEY SUPER 只会在这些文件夹及其子文件夹中显示右键菜单。")

            GroupBox("Finder 扩展") {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Finder 右键扩展")
                            .font(.system(size: 14, weight: .medium))
                        Text(isFinderExtensionEnabled ? "扩展已启用，可以在授权目录中使用。" : "扩展尚未启用，Finder 菜单不会显示。")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    extensionStatusButton()
                }
                .frame(minHeight: 44)
            }

            GroupBox("文件夹访问") {
                VStack(alignment: .leading, spacing: 9) {
                    if folderStore.folders.isEmpty {
                        Text("尚未授权文件夹。推荐授权个人主目录，以覆盖桌面、文稿和下载等常用位置。")
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
        }
    }

    private var folderSummary: some View {
        GroupBox {
            if folderStore.folders.isEmpty {
                Text("尚未授权文件夹")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(folderStore.folders.prefix(3)) { folder in
                        HStack(spacing: 8) {
                            Image(systemName: "folder.fill")
                                .foregroundStyle(.tint)
                            Text(folder.path)
                                .font(.callout)
                                .lineLimit(1)
                            Spacer()
                        }
                    }
                    if folderStore.folders.count > 3 {
                        Text("还有 \(folderStore.folders.count - 3) 个文件夹…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
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
                Text("未安装，自动隐藏")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Toggle("", isOn: Binding(get: { isOn }, set: setEnabled))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .frame(minHeight: 42)
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
