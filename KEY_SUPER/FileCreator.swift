import AppKit
import OSLog

enum FileCreator {
    private static let logger = Logger(subsystem: "com.keysuper.app", category: "FileCreator")

    @MainActor
    static func handle(_ requestURL: URL) {
        logger.notice("F01 handle started, URL=\(requestURL.absoluteString, privacy: .public)")
        guard requestURL.scheme == "key-super" else {
            logger.error("F02 rejected scheme=\(requestURL.scheme ?? "nil", privacy: .public)")
            return
        }
        if requestURL.host == "terminal" {
            handleTerminalRequest(requestURL)
            return
        }
        if requestURL.host == "template" {
            handleTemplateRequest(requestURL)
            return
        }
        guard requestURL.host == "create" else {
            logger.error("F03 rejected host=\(requestURL.host ?? "nil", privacy: .public)")
            return
        }
        guard let components = URLComponents(url: requestURL, resolvingAgainstBaseURL: false) else {
            logger.error("F04 URLComponents parsing failed")
            return
        }
        guard let path = components.queryItems?.first(where: { $0.name == "path" })?.value else {
            logger.error("F05 path query item missing")
            return
        }
        guard let typeValue = components.queryItems?.first(where: { $0.name == "type" })?.value else {
            logger.error("F06 type query item missing")
            return
        }
        guard let type = FileFormat(rawValue: typeValue) else {
            logger.error("F07 invalid type=\(typeValue, privacy: .public)")
            return
        }
        guard SharedSettings.loadEnabledFormats().contains(type) else {
            logger.error("F07 rejected disabled type=\(typeValue, privacy: .public)")
            return
        }
        logger.notice("F08 request parsed, path=\(path, privacy: .public), type=\(type.rawValue, privacy: .public)")

        let requestedDirectory = URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL
        guard let access = authorizedAccess(to: requestedDirectory) else {
            logger.error("F09 no security-scoped authorization for path=\(requestedDirectory.path, privacy: .public)")
            showError("此文件夹尚未授权", detail: "请打开 KEY SUPER，添加该文件夹或它的上级文件夹。")
            return
        }

        let didAccess = access.root.startAccessingSecurityScopedResource()
        logger.notice("F10 security scope started=\(didAccess, privacy: .public), root=\(access.root.path, privacy: .public)")
        defer {
            if didAccess {
                access.root.stopAccessingSecurityScopedResource()
            }
        }

        let directory = access.directory
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory)
        logger.notice("F11 destination checked, exists=\(exists, privacy: .public), isDirectory=\(isDirectory.boolValue, privacy: .public), path=\(directory.path, privacy: .public)")
        guard exists, isDirectory.boolValue else {
            logger.error("F12 destination is invalid")
            showError("目标文件夹不存在", detail: directory.path)
            return
        }

        do {
            let fileURL = availableURL(in: directory, for: type)
            logger.notice("F13 writing file=\(fileURL.path, privacy: .public)")
            try contents(for: type).write(to: fileURL, options: .atomic)
            logger.notice("F14 file created successfully=\(fileURL.path, privacy: .public)")
            NSWorkspace.shared.activateFileViewerSelecting([fileURL])
            logger.notice("F15 Finder selection requested")
            (NSApp.delegate as? AppDelegate)?.finishBackgroundRequest()
        } catch {
            logger.error("F16 write failed: \(error.localizedDescription, privacy: .public)")
            showError("无法在此位置创建文件", detail: error.localizedDescription)
        }
    }

    private static func authorizedAccess(to requestedDirectory: URL) -> (root: URL, directory: URL)? {
        let requestedPath = requestedDirectory.path
        let records = SharedSettings.loadFolders().sorted { $0.path.count > $1.path.count }

        for record in records {
            let recordedPath = URL(fileURLWithPath: record.path, isDirectory: true).standardizedFileURL.path
            guard requestedPath == recordedPath || requestedPath.hasPrefix(recordedPath + "/") else {
                continue
            }

            var isStale = false
            guard let resolvedRoot = try? URL(
                resolvingBookmarkData: record.bookmark,
                options: [.withSecurityScope, .withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) else {
                logger.error("F17 bookmark resolution failed for path=\(record.path, privacy: .public)")
                continue
            }

            let relativePath = String(requestedPath.dropFirst(recordedPath.count))
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let resolvedDirectory = relativePath.isEmpty
                ? resolvedRoot
                : resolvedRoot.appendingPathComponent(relativePath, isDirectory: true)
            logger.notice("F18 authorization matched, stale=\(isStale, privacy: .public), root=\(resolvedRoot.path, privacy: .public)")
            return (resolvedRoot, resolvedDirectory)
        }
        return nil
    }

    private static func availableURL(in directory: URL, for type: FileFormat) -> URL {
        var index = 0
        while true {
            let suffix = index == 0 ? "" : " \(index)"
            let candidate = directory.appendingPathComponent("\(type.baseName)\(suffix).\(type.rawValue)")
            if !FileManager.default.fileExists(atPath: candidate.path) { return candidate }
            index += 1
        }
    }

    private static func contents(for type: FileFormat) throws -> Data {
        switch type {
        case .txt, .markdown, .python:
            return Data()
        case .json:
            return Data("{\n  \n}\n".utf8)
        case .csv:
            // UTF-8 BOM keeps non-ASCII text compatible with common spreadsheet apps.
            return Data([0xEF, 0xBB, 0xBF])
        case .xlsx, .docx:
            guard let templateURL = Bundle.main.url(
                forResource: type == .xlsx ? "BlankWorkbook" : "BlankDocument",
                withExtension: type.rawValue
            ) else {
                throw CocoaError(.fileNoSuchFile)
            }
            return try Data(contentsOf: templateURL)
        }
    }

    @MainActor
    private static func handleTemplateRequest(_ requestURL: URL) {
        guard let components = URLComponents(url: requestURL, resolvingAgainstBaseURL: false),
              let destinationPath = components.queryItems?.first(where: { $0.name == "path" })?.value,
              let directoryIDValue = components.queryItems?.first(where: { $0.name == "directoryID" })?.value,
              let templateIDValue = components.queryItems?.first(where: { $0.name == "templateID" })?.value,
              let directoryID = UUID(uuidString: directoryIDValue),
              let templateID = UUID(uuidString: templateIDValue),
              let templateDirectory = SharedSettings.loadTemplateDirectories().first(where: { $0.id == directoryID }),
              let template = templateDirectory.templates.first(where: { $0.id == templateID }) else {
            logger.error("F23 template request parsing failed")
            return
        }

        let destinationURL = URL(fileURLWithPath: destinationPath, isDirectory: true).standardizedFileURL
        guard let destinationAccess = authorizedAccess(to: destinationURL) else {
            logger.error("F24 template destination unauthorized")
            showError("此文件夹尚未授权", detail: "请打开 KEY SUPER，添加目标文件夹或它的上级文件夹。")
            return
        }
        var isStale = false
        guard let templateRoot = try? URL(
            resolvingBookmarkData: templateDirectory.bookmark,
            options: [.withSecurityScope, .withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            logger.error("F25 template bookmark resolution failed")
            showError("无法读取模板目录", detail: "请在 KEY SUPER 设置中重新添加模板目录。")
            return
        }

        let destinationDidAccess = destinationAccess.root.startAccessingSecurityScopedResource()
        let templateDidAccess = templateRoot.startAccessingSecurityScopedResource()
        defer {
            if destinationDidAccess { destinationAccess.root.stopAccessingSecurityScopedResource() }
            if templateDidAccess { templateRoot.stopAccessingSecurityScopedResource() }
        }

        let sourceURL = templateRoot.appendingPathComponent(template.relativePath)
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            logger.error("F26 template source missing=\(sourceURL.path, privacy: .public)")
            showError("模板文件不存在", detail: "请在 KEY SUPER 设置中刷新模板。")
            return
        }
        do {
            let targetURL = availableTemplateURL(in: destinationAccess.directory, sourceName: sourceURL.lastPathComponent)
            try Data(contentsOf: sourceURL).write(to: targetURL, options: .atomic)
            logger.notice("F27 template copied source=\(sourceURL.path, privacy: .public), destination=\(targetURL.path, privacy: .public), stale=\(isStale, privacy: .public)")
            NSWorkspace.shared.activateFileViewerSelecting([targetURL])
            (NSApp.delegate as? AppDelegate)?.finishBackgroundRequest()
        } catch {
            logger.error("F28 template copy failed: \(error.localizedDescription, privacy: .public)")
            showError("无法创建模板文件", detail: error.localizedDescription)
        }
    }

    private static func availableTemplateURL(in directory: URL, sourceName: String) -> URL {
        let sourceURL = URL(fileURLWithPath: sourceName)
        let base = sourceURL.deletingPathExtension().lastPathComponent
        let ext = sourceURL.pathExtension
        var index = 0
        while true {
            let suffix = index == 0 ? "" : " \(index)"
            let name = ext.isEmpty ? "\(base)\(suffix)" : "\(base)\(suffix).\(ext)"
            let candidate = directory.appendingPathComponent(name)
            if !FileManager.default.fileExists(atPath: candidate.path) { return candidate }
            index += 1
        }
    }

    @MainActor
    private static func handleTerminalRequest(_ requestURL: URL) {
        guard let components = URLComponents(url: requestURL, resolvingAgainstBaseURL: false),
              let path = components.queryItems?.first(where: { $0.name == "path" })?.value,
              let appValue = components.queryItems?.first(where: { $0.name == "app" })?.value,
              let app = TerminalApp(rawValue: appValue) else {
            logger.error("F19 terminal request parsing failed")
            return
        }

        let directory = URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL
        logger.notice("F20 terminal request app=\(app.rawValue, privacy: .public), directory=\(directory.path, privacy: .public)")
        let didOpen: Bool
        switch app {
        case .warp:
            var components = URLComponents()
            components.scheme = "warp"
            components.host = "action"
            components.path = "/new_window"
            components.queryItems = [URLQueryItem(name: "path", value: directory.path)]
            didOpen = components.url.map(NSWorkspace.shared.open) ?? false
        case .iTerm:
            var components = URLComponents()
            components.scheme = "iterm2"
            components.path = "/command"
            components.queryItems = [
                URLQueryItem(name: "c", value: "pwd"),
                URLQueryItem(name: "d", value: directory.path)
            ]
            didOpen = components.url.map(NSWorkspace.shared.open) ?? false
        case .terminal:
            let command = "cd \(shellEscaped(directory.path))"
            didOpen = openTerminal(command: command)
        }

        logger.notice("F22 terminal open result=\(didOpen, privacy: .public)")
        if !didOpen {
            showError("无法打开 \(app.title)", detail: "请确认该终端已安装；也可以在 KEY SUPER 设置中将其关闭。")
        }
        (NSApp.delegate as? AppDelegate)?.finishBackgroundRequest()
    }

    private static func shellEscaped(_ path: String) -> String {
        "'\(path.replacingOccurrences(of: "'", with: "'\\\\''"))'"
    }

    @MainActor
    private static func openTerminal(command: String) -> Bool {
        let script = """
        tell application id "com.apple.Terminal"
            activate
            do script \(appleScriptString(command))
        end tell
        """
        var error: NSDictionary?
        let result = NSAppleScript(source: script)?.executeAndReturnError(&error)
        if let error {
            let number = error[NSAppleScript.errorNumber] ?? "unknown"
            let message = error[NSAppleScript.errorMessage] ?? "unknown error"
            logger.error("F21 Terminal automation failed number=\(String(describing: number), privacy: .public), message=\(String(describing: message), privacy: .public)")
            if (number as? Int) == -1743 {
                showError(
                    "需要允许控制 Terminal",
                    detail: "请在系统设置 > 隐私与安全性 > 自动化中，允许 KEY SUPER 控制 Terminal。"
                )
            }
            return false
        }
        logger.notice("F21 Terminal automation succeeded, result=\(result?.stringValue ?? "none", privacy: .public)")
        return true
    }

    private static func appleScriptString(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\n", with: "\\n")
        return "\"\(escaped)\""
    }

    @MainActor
    private static func showError(_ message: String, detail: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = message
        alert.informativeText = detail
        alert.runModal()
    }
}
