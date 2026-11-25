import AppKit
import OSLog

@MainActor
final class FolderAccessStore: ObservableObject {
    @Published private(set) var folders: [SharedSettings.FolderRecord] = []
    @Published private(set) var enabledFormats: [FileFormat] = []
    @Published private(set) var customFormats: [CustomFileFormat] = []
    @Published private(set) var enabledFeatures: [MenuFeature] = []
    @Published private(set) var enabledTerminalApps: [TerminalApp] = []
    @Published private(set) var enabledEditorApps: [EditorApp] = []
    @Published private(set) var enabledPathCopyFormats: [PathCopyFormat] = []
    @Published private(set) var enabledAITools: [AITool] = []
    @Published private(set) var templateDirectories: [TemplateDirectoryRecord] = []
    @Published private(set) var favoriteFolders: [FavoriteFolderRecord] = []
    @Published var errorMessage: String?

    private let logger = Logger(subsystem: "com.rightly.app", category: "FolderAccess")

    init() {
        reload()
    }

    func reload() {
        folders = SharedSettings.loadFolders()
        enabledFormats = SharedSettings.loadEnabledFormats()
        customFormats = SharedSettings.loadCustomFileFormats()
        enabledFeatures = SharedSettings.loadEnabledFeatures()
        enabledTerminalApps = SharedSettings.loadEnabledTerminalApps()
        enabledEditorApps = SharedSettings.loadEnabledEditorApps()
        enabledPathCopyFormats = SharedSettings.loadEnabledPathCopyFormats()
        enabledAITools = SharedSettings.loadEnabledAITools()
        templateDirectories = SharedSettings.loadTemplateDirectories()
        favoriteFolders = SharedSettings.loadFavoriteFolders()
        logger.notice("P01 loaded \(self.folders.count, privacy: .public) authorized folders")
    }

    func isEnabled(_ format: FileFormat) -> Bool {
        enabledFormats.contains(format)
    }

    func setEnabled(_ isEnabled: Bool, for format: FileFormat) {
        var enabled = Set(enabledFormats)
        if isEnabled {
            enabled.insert(format)
        } else {
            enabled.remove(format)
        }
        enabledFormats = FileFormat.allCases.filter(enabled.contains)
        do {
            try SharedSettings.saveEnabledFormats(enabledFormats)
            errorMessage = nil
            logger.notice("P06 saved \(self.enabledFormats.count, privacy: .public) enabled formats")
        } catch {
            errorMessage = "无法保存格式设置：\(error.localizedDescription)"
            logger.error("P07 format settings save failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func setEnabled(_ isEnabled: Bool, for format: CustomFileFormat) {
        guard let index = customFormats.firstIndex(where: { $0.id == format.id }) else { return }
        customFormats[index].isEnabled = isEnabled
        persistMenuSettings("文件类型") { try SharedSettings.saveCustomFileFormats(self.customFormats) }
    }

    func addCustomFormat(suffix rawSuffix: String) {
        var suffix = rawSuffix.trimmingCharacters(in: .whitespacesAndNewlines)
        while suffix.hasPrefix(".") {
            suffix.removeFirst()
        }
        guard !suffix.isEmpty,
              suffix.count <= 32,
              suffix.allSatisfy({ $0.isLetter || $0.isNumber || ".-_".contains($0) }) else {
            errorMessage = "扩展名只能包含字母、数字、点、短横线和下划线。"
            return
        }
        let normalized = suffix.lowercased()
        guard !FileFormat.allCases.contains(where: { $0.rawValue.lowercased() == normalized }),
              !customFormats.contains(where: { $0.suffix.lowercased() == normalized }) else {
            errorMessage = "这个文件类型已经添加过了。"
            return
        }
        customFormats.append(CustomFileFormat(suffix: suffix))
        customFormats.sort { $0.suffix.localizedStandardCompare($1.suffix) == .orderedAscending }
        persistMenuSettings("文件类型") { try SharedSettings.saveCustomFileFormats(self.customFormats) }
        errorMessage = nil
    }

    func removeCustomFormat(_ format: CustomFileFormat) {
        customFormats.removeAll { $0.id == format.id }
        persistMenuSettings("文件类型") { try SharedSettings.saveCustomFileFormats(self.customFormats) }
    }

    func isEnabled(_ feature: MenuFeature) -> Bool { enabledFeatures.contains(feature) }

    func setEnabled(_ isEnabled: Bool, for feature: MenuFeature) {
        var enabled = Set(enabledFeatures)
        if isEnabled {
            enabled.insert(feature)
        } else {
            enabled.remove(feature)
        }
        enabledFeatures = MenuFeature.allCases.filter(enabled.contains)
        persistMenuSettings("右键功能") { try SharedSettings.saveEnabledFeatures(self.enabledFeatures) }
    }

    func isEnabled(_ app: TerminalApp) -> Bool { enabledTerminalApps.contains(app) }

    func setEnabled(_ isEnabled: Bool, for app: TerminalApp) {
        var enabled = Set(enabledTerminalApps)
        if isEnabled {
            enabled.insert(app)
        } else {
            enabled.remove(app)
        }
        enabledTerminalApps = TerminalApp.allCases.filter(enabled.contains)
        persistMenuSettings("终端") { try SharedSettings.saveEnabledTerminalApps(self.enabledTerminalApps) }
    }

    func isEnabled(_ app: EditorApp) -> Bool { enabledEditorApps.contains(app) }

    func setEnabled(_ isEnabled: Bool, for app: EditorApp) {
        var enabled = Set(enabledEditorApps)
        if isEnabled {
            enabled.insert(app)
        } else {
            enabled.remove(app)
        }
        enabledEditorApps = EditorApp.allCases.filter(enabled.contains)
        persistMenuSettings("编辑器") { try SharedSettings.saveEnabledEditorApps(self.enabledEditorApps) }
    }

    func isInstalled(bundleIdentifier: String) -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) != nil
    }

    func isEnabled(_ format: PathCopyFormat) -> Bool { enabledPathCopyFormats.contains(format) }

    func setEnabled(_ isEnabled: Bool, for format: PathCopyFormat) {
        var enabled = Set(enabledPathCopyFormats)
        if isEnabled {
            enabled.insert(format)
        } else {
            enabled.remove(format)
        }
        enabledPathCopyFormats = PathCopyFormat.allCases.filter(enabled.contains)
        persistMenuSettings("路径拷贝") { try SharedSettings.saveEnabledPathCopyFormats(self.enabledPathCopyFormats) }
    }

    func isEnabled(_ tool: AITool) -> Bool { enabledAITools.contains(tool) }

    func setEnabled(_ isEnabled: Bool, for tool: AITool) {
        var enabled = Set(enabledAITools)
        if isEnabled {
            enabled.insert(tool)
        } else {
            enabled.remove(tool)
        }
        enabledAITools = AITool.allCases.filter(enabled.contains)
        persistMenuSettings("AI 工具") { try SharedSettings.saveEnabledAITools(self.enabledAITools) }
    }

    func chooseFolders() {
        let panel = NSOpenPanel()
        panel.title = "添加可以使用 Rightly 的文件夹"
        panel.message = "Rightly 会在所选文件夹及其所有子文件夹中显示右键菜单，并在执行操作时访问这些位置。"
        panel.prompt = "添加文件夹"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false
        // Start from the current user's home directory. Never derive this
        // from the build machine's path or a hard-coded username.
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser

        guard panel.runModal() == .OK else { return }
        addFolders(panel.urls)
    }

    func chooseTemplateDirectory() {
        let panel = NSOpenPanel()
        panel.title = "添加模板文件夹"
        panel.message = "以后可以从访达的“新建文件”菜单中使用这个文件夹里的模板。"
        panel.prompt = "添加模板文件夹"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let root = url.standardizedFileURL
            let bookmark = try root.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            let record = TemplateDirectoryRecord(
                id: UUID(),
                displayName: root.lastPathComponent.isEmpty ? root.path : root.lastPathComponent,
                path: root.path,
                bookmark: bookmark
            )
            templateDirectories.removeAll { $0.path == root.path }
            templateDirectories.append(record)
            templateDirectories.sort { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
            try SharedSettings.saveTemplateDirectories(templateDirectories)
            errorMessage = nil
            logger.notice("P12 added template directory=\(root.path, privacy: .public)")
        } catch {
            errorMessage = "无法保存模板文件夹：\(error.localizedDescription)"
            logger.error("P13 template directory save failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func chooseFavoriteFolders() {
        let panel = NSOpenPanel()
        panel.title = "添加目标文件夹"
        panel.message = "以后可以从访达的“拷贝到”和“移动到”菜单快速选择这些位置。"
        panel.prompt = "添加目标文件夹"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK else { return }
        do {
            for url in panel.urls {
                let root = url.standardizedFileURL
                let bookmark = try root.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                favoriteFolders.removeAll { $0.path == root.path }
                favoriteFolders.append(
                    FavoriteFolderRecord(
                        id: UUID(),
                        displayName: root.lastPathComponent.isEmpty ? root.path : root.lastPathComponent,
                        path: root.path,
                        bookmark: bookmark
                    )
                )
            }
            favoriteFolders.sort { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
            try SharedSettings.saveFavoriteFolders(favoriteFolders)
            errorMessage = nil
            logger.notice("P18 saved favorite folders=\(self.favoriteFolders.count, privacy: .public)")
        } catch {
            errorMessage = "无法保存目标文件夹：\(error.localizedDescription)"
            logger.error("P19 favorite folder save failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func removeFavoriteFolder(_ folder: FavoriteFolderRecord) {
        favoriteFolders.removeAll { $0.id == folder.id }
        persistMenuSettings("目标文件夹") { try SharedSettings.saveFavoriteFolders(self.favoriteFolders) }
    }

    func removeTemplateDirectory(_ directory: TemplateDirectoryRecord) {
        templateDirectories.removeAll { $0.id == directory.id }
        do {
            try SharedSettings.saveTemplateDirectories(templateDirectories)
            errorMessage = nil
            logger.notice("P14 removed template directory=\(directory.path, privacy: .public)")
        } catch {
            errorMessage = "无法保存模板文件夹：\(error.localizedDescription)"
            logger.error("P15 template directory removal failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func remove(_ folder: SharedSettings.FolderRecord) {
        folders.removeAll { $0.id == folder.id }
        persist()
    }

    private func addFolders(_ urls: [URL]) {
        do {
            for url in urls {
                let standardizedURL = url.standardizedFileURL
                let bookmark = try standardizedURL.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                folders.removeAll { $0.path == standardizedURL.path }
                folders.append(
                    .init(
                        id: UUID(),
                        displayName: standardizedURL.lastPathComponent.isEmpty ? standardizedURL.path : standardizedURL.lastPathComponent,
                        path: standardizedURL.path,
                        bookmark: bookmark
                    )
                )
                logger.notice("P02 authorized folder=\(standardizedURL.path, privacy: .public)")
            }
            folders.sort { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
            persist()
        } catch {
            errorMessage = "无法添加这个文件夹：\(error.localizedDescription)"
            logger.error("P03 bookmark creation failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func persist() {
        do {
            try SharedSettings.saveFolders(folders)
            errorMessage = nil
            logger.notice("P04 saved \(self.folders.count, privacy: .public) authorized folders")
        } catch {
            errorMessage = "无法保存设置：\(error.localizedDescription)"
            logger.error("P05 settings save failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func persistMenuSettings(_ name: String, operation: () throws -> Void) {
        do {
            try operation()
            errorMessage = nil
            logger.notice("P08 saved \(name, privacy: .public) settings")
        } catch {
            errorMessage = "无法保存\(name)设置：\(error.localizedDescription)"
            logger.error("P09 \(name, privacy: .public) settings save failed: \(error.localizedDescription, privacy: .public)")
        }
    }

}
