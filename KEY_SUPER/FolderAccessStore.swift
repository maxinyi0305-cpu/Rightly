import AppKit
import OSLog

@MainActor
final class FolderAccessStore: ObservableObject {
    @Published private(set) var folders: [SharedSettings.FolderRecord] = []
    @Published private(set) var enabledFormats: [FileFormat] = []
    @Published private(set) var enabledFeatures: [MenuFeature] = []
    @Published private(set) var enabledTerminalApps: [TerminalApp] = []
    @Published private(set) var enabledPathCopyFormats: [PathCopyFormat] = []
    @Published private(set) var enabledAITools: [AITool] = []
    @Published private(set) var templateDirectories: [TemplateDirectoryRecord] = []
    @Published var errorMessage: String?

    private let logger = Logger(subsystem: "com.keysuper.app", category: "FolderAccess")

    init() {
        reload()
    }

    func reload() {
        folders = SharedSettings.loadFolders()
        enabledFormats = SharedSettings.loadEnabledFormats()
        enabledFeatures = SharedSettings.loadEnabledFeatures()
        enabledTerminalApps = SharedSettings.loadEnabledTerminalApps()
        enabledPathCopyFormats = SharedSettings.loadEnabledPathCopyFormats()
        enabledAITools = SharedSettings.loadEnabledAITools()
        templateDirectories = SharedSettings.loadTemplateDirectories()
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

    func isEnabled(_ format: PathCopyFormat) -> Bool { enabledPathCopyFormats.contains(format) }

    func setEnabled(_ isEnabled: Bool, for format: PathCopyFormat) {
        var enabled = Set(enabledPathCopyFormats)
        if isEnabled {
            enabled.insert(format)
        } else {
            enabled.remove(format)
        }
        enabledPathCopyFormats = PathCopyFormat.allCases.filter(enabled.contains)
        persistMenuSettings("路径复制") { try SharedSettings.saveEnabledPathCopyFormats(self.enabledPathCopyFormats) }
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
        panel.title = "选择允许 KEY SUPER 新建文件的文件夹"
        panel.message = "推荐选择个人主目录，以覆盖桌面、文稿和下载等常用位置。"
        panel.prompt = "授权此文件夹"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false

        guard panel.runModal() == .OK else { return }
        addFolders(panel.urls)
    }

    func chooseTemplateDirectory() {
        let panel = NSOpenPanel()
        panel.title = "选择模板目录"
        panel.message = "目录中的文件会显示在 Finder 的“新建文件 > 模板”菜单中。"
        panel.prompt = "使用此目录"
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
                bookmark: bookmark,
                templates: scanTemplates(in: root)
            )
            templateDirectories.removeAll { $0.path == root.path }
            templateDirectories.append(record)
            templateDirectories.sort { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
            try SharedSettings.saveTemplateDirectories(templateDirectories)
            errorMessage = nil
            logger.notice("P12 added template directory=\(root.path, privacy: .public), templates=\(record.templates.count, privacy: .public)")
        } catch {
            errorMessage = "无法保存模板目录：\(error.localizedDescription)"
            logger.error("P13 template directory save failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func removeTemplateDirectory(_ directory: TemplateDirectoryRecord) {
        templateDirectories.removeAll { $0.id == directory.id }
        do {
            try SharedSettings.saveTemplateDirectories(templateDirectories)
            errorMessage = nil
            logger.notice("P14 removed template directory=\(directory.path, privacy: .public)")
        } catch {
            errorMessage = "无法保存模板目录：\(error.localizedDescription)"
            logger.error("P15 template directory removal failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func refreshTemplates() {
        do {
            templateDirectories = try templateDirectories.map { directory in
                var isStale = false
                let root = try URL(
                    resolvingBookmarkData: directory.bookmark,
                    options: [.withSecurityScope, .withoutUI],
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                let didAccess = root.startAccessingSecurityScopedResource()
                defer { if didAccess { root.stopAccessingSecurityScopedResource() } }
                return TemplateDirectoryRecord(
                    id: directory.id,
                    displayName: directory.displayName,
                    path: directory.path,
                    bookmark: directory.bookmark,
                    templates: scanTemplates(in: root)
                )
            }
            try SharedSettings.saveTemplateDirectories(templateDirectories)
            errorMessage = nil
            logger.notice("P16 refreshed template directories=\(self.templateDirectories.count, privacy: .public)")
        } catch {
            errorMessage = "无法刷新模板：\(error.localizedDescription)"
            logger.error("P17 template refresh failed: \(error.localizedDescription, privacy: .public)")
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
            errorMessage = "无法保存文件夹授权：\(error.localizedDescription)"
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

    private func scanTemplates(in root: URL) -> [TemplateRecord] {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .isHiddenKey]
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var templates: [TemplateRecord] = []
        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(forKeys: keys)
            guard values?.isRegularFile == true else { continue }
            let relativePath = String(fileURL.path.dropFirst(root.path.count))
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard !relativePath.isEmpty else { continue }
            templates.append(.init(id: UUID(), displayName: relativePath, relativePath: relativePath))
        }
        return templates.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }
}
