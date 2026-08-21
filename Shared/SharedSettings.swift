import Foundation
import OSLog

enum FileFormat: String, Codable, CaseIterable, Identifiable {
    case txt
    case markdown = "md"
    case json
    case xlsx
    case csv
    case docx

    var id: String { rawValue }

    var menuTitle: String {
        switch self {
        case .txt: "文本文档 (.txt)"
        case .markdown: "Markdown 文档 (.md)"
        case .json: "JSON 文件 (.json)"
        case .xlsx: "Excel 工作簿 (.xlsx)"
        case .csv: "CSV 表格 (.csv)"
        case .docx: "Word 文档 (.docx)"
        }
    }

    var shortName: String {
        switch self {
        case .txt: "TXT"
        case .markdown: "Markdown"
        case .json: "JSON"
        case .xlsx: "Excel"
        case .csv: "CSV"
        case .docx: "Word"
        }
    }

    var baseName: String {
        switch self {
        case .txt: "新建文本文档"
        case .markdown: "新建 Markdown 文档"
        case .json: "新建 JSON 文件"
        case .xlsx: "新建 Excel 工作簿"
        case .csv: "新建 CSV 表格"
        case .docx: "新建 Word 文档"
        }
    }
}

enum SharedSettings {
    private static let logger = Logger(subsystem: "com.keysuper.app", category: "SharedSettings")
    static let appGroupIdentifier = "group.com.keysuper.app"
    static let configurationDidChangeNotification = Notification.Name("com.keysuper.app.configuration-did-change")
    private static let foldersKey = "authorizedFolders"
    private static let enabledFormatsKey = "enabledFileFormats"

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
    }

    private static var debugConfigurationURL: URL {
        URL(fileURLWithPath: "/Users/Shared", isDirectory: true)
            .appendingPathComponent("KEY SUPER Debug", isDirectory: true)
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
            return FileFormat.allCases
        }
#else
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              defaults.object(forKey: enabledFormatsKey) != nil else {
            return FileFormat.allCases
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
}
