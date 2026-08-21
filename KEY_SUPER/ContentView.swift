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

    var icon: String {
        switch self {
        case .menu: "cursorarrow.click.2"
        case .newFile: "doc.badge.plus"
        case .editor: "chevron.left.forwardslash.chevron.right"
        case .terminal: "terminal"
        case .ai: "sparkles"
        case .copyPath: "doc.on.clipboard"
        case .organize: "folder.badge.gearshape"
        case .authorization: "lock.shield"
        }
    }
}

private struct SectionPositionPreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGFloat] = [:]

    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
    }
}

private struct ScrollContentFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

private struct ScrollViewportFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

private struct LastSectionBottomPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ContentView: View {
    @StateObject private var folderStore = FolderAccessStore()
    @State private var selectedSection: SettingsSection = .authorization
    @State private var isFinderExtensionEnabled = FIFinderSyncController.isExtensionEnabled
    @State private var customFormatSuffix = ""
    @State private var rightDetailsContentFrame: CGRect = .zero
    @State private var rightDetailsViewportFrame: CGRect = .zero
    @State private var rightDetailsViewportHeight: CGFloat = 0
    @State private var lastSectionBottom: CGFloat = 0
    private let logger = Logger(subsystem: "com.keysuper.app", category: "SettingsUI")

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollViewReader { proxy in
                HStack(alignment: .top, spacing: 0) {
                    sidebar { section in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedSection = section
                            proxy.scrollTo(section, anchor: .top)
                        }
                    }
                    Divider()
                    ScrollView(.vertical, showsIndicators: true) {
                        details
                    }
                    .coordinateSpace(name: "rightDetailsScroll")
                    .overlay {
                        GeometryReader { geometry in
                            Color.clear.preference(
                                key: ScrollViewportFramePreferenceKey.self,
                                value: geometry.frame(in: .global)
                            )
                        }
                    }
                    .onPreferenceChange(ScrollViewportFramePreferenceKey.self) { frame in
                        rightDetailsViewportFrame = frame
                        rightDetailsViewportHeight = frame.height
                        updateSelectedSection(from: [:])
                    }
                    .onPreferenceChange(SectionPositionPreferenceKey.self) { positions in
                        updateSelectedSection(from: positions)
                    }
                    .onPreferenceChange(ScrollContentFramePreferenceKey.self) { frame in
                        rightDetailsContentFrame = frame
                        updateSelectedSection(from: [:])
                    }
                    .onPreferenceChange(LastSectionBottomPreferenceKey.self) { bottom in
                        lastSectionBottom = bottom
                        updateSelectedSection(from: [:])
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(minWidth: 800, idealWidth: 860, minHeight: 560, idealHeight: 660)
        .background(Color(nsColor: .windowBackgroundColor))
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshExtensionStatus()
        }
        .onAppear {
            refreshExtensionStatus()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "cursorarrow.click.2")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 3) {
                Text("KEY SUPER")
                    .font(.title2.weight(.semibold))
                Text("让文件在当前位置立即进入下一步工作")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                showExtensionManagement()
            } label: {
                HStack(spacing: 7) {
                    Circle()
                        .fill(isFinderExtensionEnabled ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(isFinderExtensionEnabled ? "功能已启用 · 点击管理" : "功能未启用 · 点击启用")
                        .font(.callout.weight(.medium))
                }
                .foregroundStyle(isFinderExtensionEnabled ? Color.green : Color.red)
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background((isFinderExtensionEnabled ? Color.green : Color.red).opacity(0.1))
                .clipShape(Capsule())
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .help(isFinderExtensionEnabled ? "点击打开系统设置并关闭 Finder 扩展" : "点击打开系统设置并启用 Finder 扩展")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
    }

    private func sidebar(scrollTo: @escaping (SettingsSection) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(SettingsSection.allCases) { section in
                Button {
                    scrollTo(section)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: section.icon)
                            .frame(width: 18)
                        Text(section.title)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(selectedSection == section ? Color.accentColor : .primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(selectedSection == section ? Color.accentColor.opacity(0.13) : .clear)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer(minLength: 12)

            Text("状态")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 8)

            HStack(spacing: 7) {
                Circle()
                    .fill(folderStore.folders.isEmpty ? Color.orange : Color.green)
                    .frame(width: 7, height: 7)
                Text(folderStore.folders.isEmpty ? "尚未授权文件夹" : "已授权 \(folderStore.folders.count) 个文件夹")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
        }
        .frame(width: 230, alignment: .topLeading)
        .padding(16)
    }

    @ViewBuilder
    private var details: some View {
        VStack(alignment: .leading, spacing: 30) {
            ForEach(SettingsSection.allCases) { section in
                detailSection(section)
                    .id(section)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .background {
                        GeometryReader { geometry in
                            Color.clear.preference(
                                key: SectionPositionPreferenceKey.self,
                                value: [section.rawValue: geometry.frame(in: .named("rightDetailsScroll")).minY]
                            )
                        }
                    }
                    .background {
                        if section == .organize {
                            GeometryReader { geometry in
                                Color.clear.preference(
                                    key: LastSectionBottomPreferenceKey.self,
                                    value: geometry.frame(in: .named("rightDetailsScroll")).maxY
                                )
                            }
                        }
                    }

                if section != .organize {
                    Divider()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(24)
        // Reserve enough trailing space for the last section to reach the
        // top of the viewport, so scroll-position highlighting can select it.
        .padding(.bottom, max(rightDetailsViewportHeight * 0.5, 24))
        .background {
            GeometryReader { geometry in
                Color.clear.preference(
                    key: ScrollContentFramePreferenceKey.self,
                    value: geometry.frame(in: .global)
                )
            }
        }
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
        VStack(alignment: .leading, spacing: 18) {
            pageTitle("右键菜单", subtitle: "选择要显示在 Finder 中的功能。所有开关会实时同步到扩展。")

            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(MenuFeature.allCases) { feature in
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
            GroupBox {
                VStack(alignment: .leading, spacing: 9) {
                    ForEach(EditorApp.allCases) { app in
                        appToggle(app.title, isOn: folderStore.isEnabled(app), installed: folderStore.isInstalled(bundleIdentifier: app.bundleIdentifier)) {
                            folderStore.setEnabled($0, for: app)
                        }
                    }
                }
                .padding(.vertical, 3)
            }
            Text("未安装的应用不会出现在 Finder 右键菜单中。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var terminalDetail: some View {
        VStack(alignment: .leading, spacing: 18) {
            pageTitle("终端", subtitle: "在当前 Finder 文件夹中打开终端窗口。")
            GroupBox {
                VStack(alignment: .leading, spacing: 9) {
                    ForEach(TerminalApp.allCases) { app in
                        appToggle(app.title, isOn: folderStore.isEnabled(app), installed: folderStore.isInstalled(bundleIdentifier: app.bundleIdentifier)) {
                            folderStore.setEnabled($0, for: app)
                        }
                    }
                }
                .padding(.vertical, 3)
            }
            Text("Terminal 需要在系统设置的“隐私与安全性 > 自动化”中允许 KEY SUPER 控制它。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var aiDetail: some View {
        VStack(alignment: .leading, spacing: 18) {
            pageTitle("AI 工具", subtitle: "从 Finder 当前目录直接进入 AI 编程工作流。")
            GroupBox {
                VStack(alignment: .leading, spacing: 9) {
                    ForEach(AITool.allCases) { tool in
                        Toggle(
                            tool.title,
                            isOn: Binding(
                                get: { folderStore.isEnabled(tool) },
                                set: { folderStore.setEnabled($0, for: tool) }
                            )
                        )
                        .toggleStyle(.checkbox)
                    }
                }
                .padding(.vertical, 3)
            }
            Text("未注册对应 URL scheme 的 AI 工具会自动从 Finder 菜单中隐藏。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var copyPathDetail: some View {
        VStack(alignment: .leading, spacing: 18) {
            pageTitle("路径复制", subtitle: "支持单选和多选项目，多个结果会按行复制。")
            GroupBox {
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
        VStack(alignment: .leading, spacing: 18) {
            pageTitle("文件夹授权", subtitle: "KEY SUPER 只会在这些文件夹及其子文件夹中显示右键菜单。")
            GroupBox {
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
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.title2.weight(.semibold))
            Text(subtitle)
                .font(.callout)
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
            Toggle(title, isOn: Binding(get: { isOn }, set: setEnabled))
                .toggleStyle(.checkbox)
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
        }
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

    private func updateSelectedSection(from positions: [String: CGFloat]) {
        if rightDetailsViewportFrame != .zero,
           rightDetailsContentFrame != .zero,
           rightDetailsContentFrame.height > rightDetailsViewportFrame.height + 24,
           rightDetailsContentFrame.maxY <= rightDetailsViewportFrame.maxY + 24,
           let lastSection = SettingsSection.allCases.last,
           selectedSection != lastSection {
            selectedSection = lastSection
            return
        }

        if rightDetailsViewportHeight > 0,
           lastSectionBottom > 0,
           rightDetailsContentFrame.height > rightDetailsViewportHeight + 24,
           lastSectionBottom <= rightDetailsViewportHeight + 24,
           let lastSection = SettingsSection.allCases.last,
           selectedSection != lastSection {
            selectedSection = lastSection
            return
        }

        guard !positions.isEmpty else { return }
        let threshold = max(36, rightDetailsViewportHeight * 0.42)
        let visibleAtTop = positions
            .filter { $0.value <= threshold }
            .max { $0.value < $1.value }
        let candidate = visibleAtTop ?? positions.min { $0.value < $1.value }
        guard let candidate, let section = SettingsSection(rawValue: candidate.key) else { return }
        if selectedSection != section {
            selectedSection = section
        }
    }
}
