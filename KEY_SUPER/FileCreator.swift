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
        case .txt, .markdown:
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
    private static func showError(_ message: String, detail: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = message
        alert.informativeText = detail
        alert.runModal()
    }
}
