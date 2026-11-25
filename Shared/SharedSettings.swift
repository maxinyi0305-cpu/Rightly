import AppKit
import Foundation
import OSLog

enum FileFormat: String, Codable, CaseIterable, Identifiable {
    case txt
    case markdown = "md"
    case python = "py"
    case json
    case xlsx
    case csv
    case docx

    var id: String { rawValue }

    var settingsTitle: String {
        switch self {
        case .txt: "文本文件（.txt）"
        case .markdown: "Markdown 文档（.md）"
        case .python: "Python 脚本（.py）"
        case .json: "JSON 文件（.json）"
        case .xlsx: "Excel 工作簿（.xlsx）"
        case .csv: "CSV 表格（.csv）"
        case .docx: "Word 文档（.docx）"
        }
    }

    var menuTitle: String {
        switch self {
        case .txt: "纯文本 (.txt)"
        case .markdown: "Markdown (.md)"
        case .python: "Python 脚本 (.py)"
        case .json: "JSON (.json)"
        case .xlsx: "Excel 工作簿 (.xlsx)"
        case .csv: "CSV 表格 (.csv)"
        case .docx: "Word 文档 (.docx)"
        }
    }

    var shortName: String {
        switch self {
        case .txt: ".txt"
        case .markdown: ".md"
        case .python: ".py"
        case .json: ".json"
        case .xlsx: ".xlsx"
        case .csv: ".csv"
        case .docx: ".docx"
        }
    }

    var baseName: String {
        switch self {
        case .txt: "新建文本文档"
        case .markdown: "新建 Markdown 文档"
        case .python: "新建 Python 脚本"
        case .json: "新建 JSON 文件"
        case .xlsx: "新建 Excel 工作簿"
        case .csv: "新建 CSV 表格"
        case .docx: "新建 Word 文档"
        }
    }
}

struct CustomFileFormat: Codable, Identifiable, Hashable {
    let id: UUID
    var suffix: String
    var isEnabled: Bool

    init(id: UUID = UUID(), suffix: String, isEnabled: Bool = true) {
        self.id = id
        self.suffix = suffix
        self.isEnabled = isEnabled
    }

    var settingsTitle: String { ".\(suffix)" }
    var menuTitle: String { "\(suffix.uppercased()) (.\(suffix))" }
    var shortName: String { ".\(suffix)" }
    var baseName: String { "新建 \(suffix.uppercased()) 文件" }
}

enum MenuFeature: String, Codable, CaseIterable, Identifiable {
    case newFile
    case terminal
    case editor
    case copyPath
    case ai
    case organize
    case clipboard
    case batchRename

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newFile: "新建文件"
        case .terminal: "在终端中打开"
        case .editor: "使用编辑器打开"
        case .copyPath: "拷贝文件信息"
        case .ai: "使用 AI 工具打开"
        case .organize: "拷贝或移动到常用文件夹"
        case .clipboard: "从剪贴板新建"
        case .batchRename: "批量重命名"
        }
    }
}

enum TerminalApp: String, Codable, CaseIterable, Identifiable {
    case terminal
    case ghostty
    case iTerm
    case warp
    case wezTerm
    case alacritty
    case kitty

    var id: String { rawValue }

    var title: String {
        switch self {
        case .terminal: "终端（Terminal）"
        case .ghostty: "Ghostty"
        case .iTerm: "iTerm2"
        case .warp: "Warp"
        case .wezTerm: "WezTerm"
        case .alacritty: "Alacritty"
        case .kitty: "kitty"
        }
    }

    var menuTitle: String {
        switch self {
        case .terminal: "终端"
        default: title
        }
    }

    var bundleIdentifier: String {
        switch self {
        case .terminal: "com.apple.Terminal"
        case .ghostty: "com.mitchellh.ghostty"
        case .iTerm: "com.googlecode.iterm2"
        case .warp: "dev.warp.Warp"
        case .wezTerm: "com.github.wez.wezterm"
        case .alacritty: "org.alacritty"
        case .kitty: "net.kovidgoyal.kitty"
        }
    }

    func launchArguments(workingDirectory path: String) -> [String]? {
        switch self {
        case .ghostty:
            ["--working-directory=\(path)"]
        case .wezTerm:
            ["start", "--cwd", path]
        case .alacritty:
            ["--working-directory", path]
        case .kitty:
            ["--directory", path]
        case .terminal, .iTerm, .warp:
            nil
        }
    }
}

enum EditorApp: String, Codable, CaseIterable, Identifiable {
    case visualStudioCode
    case cursor
    case zed
    case xcode
    case sublimeText

    var id: String { rawValue }

    var title: String {
        switch self {
        case .visualStudioCode: "Visual Studio Code"
        case .cursor: "Cursor"
        case .zed: "Zed"
        case .xcode: "Xcode"
        case .sublimeText: "Sublime Text"
        }
    }

    var bundleIdentifier: String {
        switch self {
        case .visualStudioCode: "com.microsoft.VSCode"
        case .cursor: "com.todesktop.230313mzl4w4u92"
        case .zed: "dev.zed.Zed"
        case .xcode: "com.apple.dt.Xcode"
        case .sublimeText: "com.sublimetext.4"
        }
    }
}

enum PathCopyFormat: String, Codable, CaseIterable, Identifiable {
    case absolute
    case relative
    case fileURL
    case terminal
    case fileName
    case baseName
    case markdown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .absolute: "完整位置（/Users/…）"
        case .relative: "相对于已添加文件夹的位置"
        case .fileURL: "文件链接（file://…）"
        case .terminal: "可粘贴到终端的位置"
        case .fileName: "文件名"
        case .baseName: "文件名，不含扩展名"
        case .markdown: "Markdown 链接"
        }
    }

    var menuTitle: String {
        switch self {
        case .absolute: "完整路径"
        case .relative: "相对路径"
        case .fileURL: "文件 URL"
        case .terminal: "终端路径"
        case .fileName: "文件名"
        case .baseName: "文件名（不含扩展名）"
        case .markdown: "Markdown 链接"
        }
    }
}

enum AITool: String, Codable, CaseIterable, Identifiable {
    case claudeCode
    case codex

    var id: String { rawValue }

    var title: String {
        switch self {
        case .claudeCode: "Claude Code"
        case .codex: "Codex"
        }
    }
}

struct TemplateDirectoryRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let displayName: String
    let path: String
    let bookmark: Data

    init(id: UUID, displayName: String, path: String, bookmark: Data) {
        self.id = id
        self.displayName = displayName
        self.path = path
        self.bookmark = bookmark
    }
}

struct FavoriteFolderRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let displayName: String
    let path: String
    let bookmark: Data
}

enum FileOperation: String, Codable {
    case copy
    case move
}

enum ClipboardFileType: String, Codable {
    case txt
    case markdown
    case png
}

enum ActionRequestKind: String, Codable {
    case fileOperation
    case clipboardFile
    case batchRename
}

struct ActionRequest: Codable {
    let kind: ActionRequestKind
    var paths: [String] = []
    var destinationID: UUID?
    var operation: FileOperation?
    var destinationPath: String?
    var clipboardType: ClipboardFileType?
}

enum SharedSettings {
    private static let logger = Logger(subsystem: "com.rightly.app", category: "SharedSettings")
    static let appGroupIdentifier = "group.com.rightly.app"
    static let configurationDidChangeNotification = Notification.Name("com.rightly.app.configuration-did-change")
    private static let foldersKey = "authorizedFolders"
    private static let enabledFormatsKey = "enabledFileFormats"
    private static let customFormatsKey = "customFileFormats"
    private static let enabledFeaturesKey = "enabledMenuFeatures"
    private static let enabledTerminalAppsKey = "enabledTerminalApps"
    private static let enabledEditorAppsKey = "enabledEditorApps"
    private static let enabledPathCopyFormatsKey = "enabledPathCopyFormats"
    private static let enabledAIToolsKey = "enabledAITools"
    private static let templateDirectoriesKey = "templateDirectories"
    private static let favoriteFoldersKey = "favoriteFolders"

    struct FolderRecord: Codable, Identifiable, Equatable {
        let id: UUID
        let displayName: String
        let path: String
        let bookmark: Data
    }

#if DEBUG
    private struct DebugConfiguration: Codable {
        var folders: [FolderRecord] = []
        var enabledFormatRawValues: [String]?
        var customFormats: [CustomFileFormat]?
        var enabledFeatureRawValues: [String]?
        var enabledTerminalAppRawValues: [String]?
        var enabledEditorAppRawValues: [String]?
        var enabledPathCopyFormatRawValues: [String]?
        var enabledAIToolRawValues: [String]?
        var templateDirectories: [TemplateDirectoryRecord] = []
        var favoriteFolders: [FavoriteFolderRecord]?
    }

    private static var debugConfigurationURL: URL {
        URL(fileURLWithPath: "/Users/Shared", isDirectory: true)
            .appendingPathComponent("Rightly Debug", isDirectory: true)
            .appendingPathComponent("configuration.json")
    }

    private static func loadDebugConfiguration() -> DebugConfiguration {
        logger.notice("D01 loading Debug configuration from \(debugConfigurationURL.path, privacy: .public)")
        let data: Data
        do {
            data = try Data(contentsOf: debugConfigurationURL)
        } catch {
            logger.error("D02 configuration read failed: \(error.localizedDescription, privacy: .public)")
            return DebugConfiguration()
        }
        do {
            let configuration = try JSONDecoder().decode(DebugConfiguration.self, from: data)
            logger.notice("D03 configuration decoded: folders=\(configuration.folders.count, privacy: .public), bytes=\(data.count, privacy: .public)")
            return configuration
        } catch {
            logger.error("D04 configuration decode failed: \(error.localizedDescription, privacy: .public)")
            return DebugConfiguration()
        }
    }

    private static func saveDebugConfiguration(_ configuration: DebugConfiguration) throws {
        let directory = debugConfigurationURL.deletingLastPathComponent()
        logger.notice("D05 creating Debug directory=\(directory.path, privacy: .public)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        logger.notice("D06 directory ready: exists=\(FileManager.default.fileExists(atPath: directory.path), privacy: .public), writable=\(FileManager.default.isWritableFile(atPath: directory.path), privacy: .public)")
        let data = try JSONEncoder().encode(configuration)
        logger.notice("D07 writing configuration bytes=\(data.count, privacy: .public), folders=\(configuration.folders.count, privacy: .public)")
        try data.write(to: debugConfigurationURL, options: .atomic)
        logger.notice("D08 configuration write completed: exists=\(FileManager.default.fileExists(atPath: debugConfigurationURL.path), privacy: .public)")
    }
#endif

    static func loadFolders() -> [FolderRecord] {
#if DEBUG
        let folders = loadDebugConfiguration().folders
        logger.notice("D09 loadFolders returning \(folders.count, privacy: .public) records")
        return folders
#else
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = defaults.data(forKey: foldersKey),
              let folders = try? JSONDecoder().decode([FolderRecord].self, from: data) else {
            return []
        }
        return folders
#endif
    }

    static func saveFolders(_ folders: [FolderRecord]) throws {
#if DEBUG
        logger.notice("D10 saveFolders called with \(folders.count, privacy: .public) records")
        var configuration = loadDebugConfiguration()
        configuration.folders = folders
        try saveDebugConfiguration(configuration)
#else
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else {
            throw CocoaError(.fileWriteUnknown)
        }
        let data = try JSONEncoder().encode(folders)
        defaults.set(data, forKey: foldersKey)
#endif
        notifyConfigurationChanged()
    }

    private static func notifyConfigurationChanged() {
        logger.notice("D11 posting configuration change notification")
        DistributedNotificationCenter.default().postNotificationName(
            configurationDidChangeNotification,
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }

    static func loadEnabledFormats() -> [FileFormat] {
#if DEBUG
        guard let rawValues = loadDebugConfiguration().enabledFormatRawValues else {
            return [.txt, .markdown, .python, .json, .xlsx, .csv, .docx]
        }
#else
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              defaults.object(forKey: enabledFormatsKey) != nil else {
            return [.txt, .markdown, .python, .json, .xlsx, .csv, .docx]
        }
        let rawValues = defaults.stringArray(forKey: enabledFormatsKey) ?? []
#endif
        let enabled = Set(rawValues.compactMap(FileFormat.init(rawValue:)))
        return FileFormat.allCases.filter(enabled.contains)
    }

    static func saveEnabledFormats(_ formats: [FileFormat]) throws {
#if DEBUG
        var configuration = loadDebugConfiguration()
        configuration.enabledFormatRawValues = formats.map(\.rawValue)
        try saveDebugConfiguration(configuration)
#else
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else {
            throw CocoaError(.fileWriteUnknown)
        }
        defaults.set(formats.map(\.rawValue), forKey: enabledFormatsKey)
#endif
        notifyConfigurationChanged()
    }

    static func loadCustomFileFormats() -> [CustomFileFormat] {
#if DEBUG
        return loadDebugConfiguration().customFormats ?? []
#else
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = defaults.data(forKey: customFormatsKey),
              let formats = try? JSONDecoder().decode([CustomFileFormat].self, from: data) else {
            return []
        }
        return formats
#endif
    }

    static func saveCustomFileFormats(_ formats: [CustomFileFormat]) throws {
#if DEBUG
        var configuration = loadDebugConfiguration()
        configuration.customFormats = formats
        try saveDebugConfiguration(configuration)
#else
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else {
            throw CocoaError(.fileWriteUnknown)
        }
        defaults.set(try JSONEncoder().encode(formats), forKey: customFormatsKey)
#endif
        notifyConfigurationChanged()
    }

    static func loadEnabledFeatures() -> [MenuFeature] {
#if DEBUG
        let rawValues = loadDebugConfiguration().enabledFeatureRawValues
#else
        let rawValues = UserDefaults(suiteName: appGroupIdentifier)?.stringArray(forKey: enabledFeaturesKey)
#endif
        guard let rawValues else {
            return [
                .newFile,
                .terminal,
                .editor,
                .copyPath,
                .ai,
                .organize,
                .clipboard,
                .batchRename,
            ]
        }
        let enabled = Set(rawValues.compactMap(MenuFeature.init(rawValue:)))
        return MenuFeature.allCases.filter(enabled.contains)
    }

    static func saveEnabledFeatures(_ features: [MenuFeature]) throws {
#if DEBUG
        var configuration = loadDebugConfiguration()
        configuration.enabledFeatureRawValues = features.map(\.rawValue)
        try saveDebugConfiguration(configuration)
#else
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else { throw CocoaError(.fileWriteUnknown) }
        defaults.set(features.map(\.rawValue), forKey: enabledFeaturesKey)
#endif
        notifyConfigurationChanged()
    }

    static func loadEnabledTerminalApps() -> [TerminalApp] {
#if DEBUG
        let rawValues = loadDebugConfiguration().enabledTerminalAppRawValues
#else
        let rawValues = UserDefaults(suiteName: appGroupIdentifier)?.stringArray(forKey: enabledTerminalAppsKey)
#endif
        guard let rawValues else {
            return [.terminal, .ghostty, .iTerm, .warp, .wezTerm, .alacritty, .kitty]
        }
        let enabled = Set(rawValues.compactMap(TerminalApp.init(rawValue:)))
        return TerminalApp.allCases.filter(enabled.contains)
    }

    static func saveEnabledTerminalApps(_ apps: [TerminalApp]) throws {
#if DEBUG
        var configuration = loadDebugConfiguration()
        configuration.enabledTerminalAppRawValues = apps.map(\.rawValue)
        try saveDebugConfiguration(configuration)
#else
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else { throw CocoaError(.fileWriteUnknown) }
        defaults.set(apps.map(\.rawValue), forKey: enabledTerminalAppsKey)
#endif
        notifyConfigurationChanged()
    }

    static func loadEnabledEditorApps() -> [EditorApp] {
#if DEBUG
        let rawValues = loadDebugConfiguration().enabledEditorAppRawValues
#else
        let rawValues = UserDefaults(suiteName: appGroupIdentifier)?.stringArray(forKey: enabledEditorAppsKey)
#endif
        guard let rawValues else {
            return [.visualStudioCode, .cursor, .zed, .xcode, .sublimeText]
        }
        let enabled = Set(rawValues.compactMap(EditorApp.init(rawValue:)))
        return EditorApp.allCases.filter(enabled.contains)
    }

    static func saveEnabledEditorApps(_ apps: [EditorApp]) throws {
#if DEBUG
        var configuration = loadDebugConfiguration()
        configuration.enabledEditorAppRawValues = apps.map(\.rawValue)
        try saveDebugConfiguration(configuration)
#else
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else { throw CocoaError(.fileWriteUnknown) }
        defaults.set(apps.map(\.rawValue), forKey: enabledEditorAppsKey)
#endif
        notifyConfigurationChanged()
    }

    static func loadEnabledPathCopyFormats() -> [PathCopyFormat] {
#if DEBUG
        let rawValues = loadDebugConfiguration().enabledPathCopyFormatRawValues
#else
        let rawValues = UserDefaults(suiteName: appGroupIdentifier)?.stringArray(forKey: enabledPathCopyFormatsKey)
#endif
        guard let rawValues else {
            return [.absolute, .relative, .terminal, .fileName]
        }
        let enabled = Set(rawValues.compactMap(PathCopyFormat.init(rawValue:)))
        return PathCopyFormat.allCases.filter(enabled.contains)
    }

    static func saveEnabledPathCopyFormats(_ formats: [PathCopyFormat]) throws {
#if DEBUG
        var configuration = loadDebugConfiguration()
        configuration.enabledPathCopyFormatRawValues = formats.map(\.rawValue)
        try saveDebugConfiguration(configuration)
#else
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else { throw CocoaError(.fileWriteUnknown) }
        defaults.set(formats.map(\.rawValue), forKey: enabledPathCopyFormatsKey)
#endif
        notifyConfigurationChanged()
    }

    static func loadEnabledAITools() -> [AITool] {
#if DEBUG
        let rawValues = loadDebugConfiguration().enabledAIToolRawValues
#else
        let rawValues = UserDefaults(suiteName: appGroupIdentifier)?.stringArray(forKey: enabledAIToolsKey)
#endif
        guard let rawValues else { return [.claudeCode, .codex] }
        let enabled = Set(rawValues.compactMap(AITool.init(rawValue:)))
        return AITool.allCases.filter(enabled.contains)
    }

    static func saveEnabledAITools(_ tools: [AITool]) throws {
#if DEBUG
        var configuration = loadDebugConfiguration()
        configuration.enabledAIToolRawValues = tools.map(\.rawValue)
        try saveDebugConfiguration(configuration)
#else
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else { throw CocoaError(.fileWriteUnknown) }
        defaults.set(tools.map(\.rawValue), forKey: enabledAIToolsKey)
#endif
        notifyConfigurationChanged()
    }

    static func loadTemplateDirectories() -> [TemplateDirectoryRecord] {
#if DEBUG
        return loadDebugConfiguration().templateDirectories
#else
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = defaults.data(forKey: templateDirectoriesKey),
              let directories = try? JSONDecoder().decode([TemplateDirectoryRecord].self, from: data) else {
            return []
        }
        return directories
#endif
    }

    static func saveTemplateDirectories(_ directories: [TemplateDirectoryRecord]) throws {
#if DEBUG
        var configuration = loadDebugConfiguration()
        configuration.templateDirectories = directories
        try saveDebugConfiguration(configuration)
#else
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else { throw CocoaError(.fileWriteUnknown) }
        defaults.set(try JSONEncoder().encode(directories), forKey: templateDirectoriesKey)
#endif
        notifyConfigurationChanged()
    }

    static func loadFavoriteFolders() -> [FavoriteFolderRecord] {
#if DEBUG
        return loadDebugConfiguration().favoriteFolders ?? []
#else
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = defaults.data(forKey: favoriteFoldersKey),
              let folders = try? JSONDecoder().decode([FavoriteFolderRecord].self, from: data) else {
            return []
        }
        return folders
#endif
    }

    static func saveFavoriteFolders(_ folders: [FavoriteFolderRecord]) throws {
#if DEBUG
        var configuration = loadDebugConfiguration()
        configuration.favoriteFolders = folders
        try saveDebugConfiguration(configuration)
#else
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else { throw CocoaError(.fileWriteUnknown) }
        defaults.set(try JSONEncoder().encode(folders), forKey: favoriteFoldersKey)
#endif
        notifyConfigurationChanged()
    }

    static func saveRequest(_ request: ActionRequest) throws -> UUID {
        let id = UUID()
        let directory = requestDirectoryURL
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(request)
        try data.write(to: directory.appendingPathComponent("\(id.uuidString).json"), options: .atomic)
        return id
    }

    static func takeRequest(id: UUID) -> ActionRequest? {
        let url = requestDirectoryURL.appendingPathComponent("\(id.uuidString).json")
        guard let data = try? Data(contentsOf: url),
              let request = try? JSONDecoder().decode(ActionRequest.self, from: data) else {
            return nil
        }
        try? FileManager.default.removeItem(at: url)
        return request
    }

    static func removeAllData() throws {
#if DEBUG
        let debugDirectory = debugConfigurationURL.deletingLastPathComponent()
        if FileManager.default.fileExists(atPath: debugDirectory.path) {
            try FileManager.default.removeItem(at: debugDirectory)
        }
#else
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else {
            throw CocoaError(.fileWriteUnknown)
        }
        let keys = [
            foldersKey,
            enabledFormatsKey,
            customFormatsKey,
            enabledFeaturesKey,
            enabledTerminalAppsKey,
            enabledEditorAppsKey,
            enabledPathCopyFormatsKey,
            enabledAIToolsKey,
            templateDirectoriesKey,
            favoriteFoldersKey,
        ]
        for key in keys {
            defaults.removeObject(forKey: key)
        }
        defaults.synchronize()

        let requestDirectory = requestDirectoryURL
        if FileManager.default.fileExists(atPath: requestDirectory.path) {
            try FileManager.default.removeItem(at: requestDirectory)
        }
#endif
        notifyConfigurationChanged()
    }

    private static var requestDirectoryURL: URL {
#if DEBUG
        return debugConfigurationURL.deletingLastPathComponent().appendingPathComponent("Requests", isDirectory: true)
#else
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)!
            .appendingPathComponent("Requests", isDirectory: true)
#endif
    }
}
