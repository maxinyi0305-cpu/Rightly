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
        if requestURL.host == "request" {
            handleStoredRequest(requestURL)
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
        let suggestedBaseName: String
        let fileExtension: String
        let selectedBuiltInType: FileFormat?
        if typeValue == "custom" {
            guard let customIDValue = components.queryItems?.first(where: { $0.name == "customID" })?.value,
                  let customID = UUID(uuidString: customIDValue),
                  let custom = SharedSettings.loadCustomFileFormats().first(where: { $0.id == customID && $0.isEnabled }) else {
                logger.error("F07 rejected invalid or disabled custom format")
                return
            }
            suggestedBaseName = custom.baseName
            fileExtension = custom.suffix
            selectedBuiltInType = nil
            logger.notice("F08 custom format selected, suffix=\(custom.suffix, privacy: .public)")
        } else {
            guard let type = FileFormat(rawValue: typeValue) else {
                logger.error("F07 invalid type=\(typeValue, privacy: .public)")
                return
            }
            guard SharedSettings.loadEnabledFormats().contains(type) else {
                logger.error("F07 rejected disabled type=\(typeValue, privacy: .public)")
                return
            }
            suggestedBaseName = type.baseName
            fileExtension = type.rawValue
            selectedBuiltInType = type
            logger.notice("F08 request parsed, path=\(path, privacy: .public), type=\(type.rawValue, privacy: .public)")
        }

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
            let fileContents: Data
            if let selectedBuiltInType {
                fileContents = try contents(for: selectedBuiltInType)
            } else {
                fileContents = Data()
            }
            guard let fileURL = creationURL(
                in: directory,
                suggestedBaseName: suggestedBaseName,
                extension: fileExtension
            ) else {
                (NSApp.delegate as? AppDelegate)?.finishBackgroundRequest()
                return
            }
            logger.notice("F13 writing file=\(fileURL.path, privacy: .public)")
            try fileContents.write(to: fileURL, options: .atomic)
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

    @MainActor
    private static func creationURL(in directory: URL, suggestedBaseName: String, extension fileExtension: String) -> URL? {
        guard SharedSettings.loadNewFileNamingMode() == .askBeforeCreating else {
            return availableNamedURL(in: directory, baseName: suggestedBaseName, extension: fileExtension)
        }
        guard let enteredName = promptForName(suggestedBaseName) else { return nil }
        let enteredURL = URL(fileURLWithPath: enteredName)
        var baseName = enteredURL.deletingPathExtension().lastPathComponent
        var chosenExtension = enteredURL.pathExtension
        if chosenExtension.isEmpty {
            baseName = enteredName
            chosenExtension = fileExtension
        }
        guard isValidFileName(baseName), isValidFileName(chosenExtension) else {
            showError("文件名无效", detail: "名称不能为空，也不能包含斜杠。")
            return nil
        }
        return availableNamedURL(in: directory, baseName: baseName, extension: chosenExtension)
    }

    private static func availableNamedURL(in directory: URL, baseName: String, extension fileExtension: String) -> URL {
        var index = 0
        while true {
            let suffix = index == 0 ? "" : " \(index)"
            let name = fileExtension.isEmpty ? "\(baseName)\(suffix)" : "\(baseName)\(suffix).\(fileExtension)"
            let candidate = directory.appendingPathComponent(name)
            if !FileManager.default.fileExists(atPath: candidate.path) { return candidate }
            index += 1
        }
    }

    @MainActor
    private static func promptForName(_ suggestedName: String) -> String? {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "输入文件名"
        alert.informativeText = "若名称中不包含扩展名，将自动使用所选文件类型的扩展名。"
        alert.addButton(withTitle: "创建")
        alert.addButton(withTitle: "取消")
        let field = NSTextField(string: suggestedName)
        field.frame = NSRect(x: 0, y: 0, width: 320, height: 24)
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        return field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isValidFileName(_ name: String) -> Bool {
        !name.isEmpty && name != "." && name != ".." && !name.contains("/") && !name.contains(":")
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
              let directoryID = UUID(uuidString: directoryIDValue),
              let relativePath = components.queryItems?.first(where: { $0.name == "relativePath" })?.value,
              let templateDirectory = SharedSettings.loadTemplateDirectories().first(where: { $0.id == directoryID }) else {
            logger.error("F23 template request parsing failed")
            return
        }

        let normalizedRelativePath = relativePath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let relativeComponents = normalizedRelativePath.split(separator: "/")
        guard !normalizedRelativePath.isEmpty,
              !relativeComponents.contains("..") else {
            logger.error("F23 invalid template relative path")
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

        let sourceURL = templateRoot.appendingPathComponent(normalizedRelativePath).standardizedFileURL
        let templateRootPath = templateRoot.standardizedFileURL.path
        guard sourceURL.path.hasPrefix(templateRootPath + "/") else {
            logger.error("F26 template path escaped source directory")
            return
        }
        let sourceValues = try? sourceURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard sourceValues?.isRegularFile == true, sourceValues?.isSymbolicLink != true else {
            logger.error("F26 template source missing=\(sourceURL.path, privacy: .public)")
            showError("模板文件不存在", detail: "请确认模板目录中的源文件仍然存在。")
            return
        }
        do {
            let sourceExtension = sourceURL.pathExtension
            let sourceBaseName = sourceURL.deletingPathExtension().lastPathComponent
            guard let targetURL = creationURL(
                in: destinationAccess.directory,
                suggestedBaseName: sourceBaseName,
                extension: sourceExtension
            ) else {
                (NSApp.delegate as? AppDelegate)?.finishBackgroundRequest()
                return
            }
            try FileManager.default.copyItem(at: sourceURL, to: targetURL)
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
    private static func handleStoredRequest(_ requestURL: URL) {
        guard let components = URLComponents(url: requestURL, resolvingAgainstBaseURL: false),
              let idValue = components.queryItems?.first(where: { $0.name == "id" })?.value,
              let id = UUID(uuidString: idValue),
              let request = SharedSettings.takeRequest(id: id) else {
            logger.error("F30 stored request parsing failed")
            showError("请求已失效", detail: "请返回 Finder 后重新执行此操作。")
            return
        }

        switch request.kind {
        case .fileOperation:
            handleFileOperation(request)
        case .clipboardFile:
            handleClipboardFile(request)
        case .batchRename:
            handleBatchRename(request)
        }
    }

    @MainActor
    private static func handleFileOperation(_ request: ActionRequest) {
        guard let destinationID = request.destinationID,
              let operation = request.operation,
              let favorite = SharedSettings.loadFavoriteFolders().first(where: { $0.id == destinationID }),
              !request.paths.isEmpty else {
            showError("无法处理文件", detail: "操作参数不完整。")
            return
        }

        var isStale = false
        guard let destination = try? URL(
            resolvingBookmarkData: favorite.bookmark,
            options: [.withSecurityScope, .withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            showError("无法访问常用目录", detail: "请在 KEY SUPER 设置中移除后重新添加该目录。")
            return
        }

        let destinationDidAccess = destination.startAccessingSecurityScopedResource()
        defer { if destinationDidAccess { destination.stopAccessingSecurityScopedResource() } }
        var destinationIsDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: destination.path, isDirectory: &destinationIsDirectory),
              destinationIsDirectory.boolValue else {
            showError("常用目录不存在", detail: "请在 KEY SUPER 设置中移除后重新添加该目录。")
            return
        }

        var createdURLs: [URL] = []
        var failures: [String] = []
        for path in request.paths {
            let originalURL = URL(fileURLWithPath: path).standardizedFileURL
            guard let resolved = resolvedAuthorizedItem(originalURL) else {
                failures.append("\(originalURL.lastPathComponent)：未授权")
                continue
            }
            let sourceDidAccess = resolved.root.startAccessingSecurityScopedResource()
            defer { if sourceDidAccess { resolved.root.stopAccessingSecurityScopedResource() } }

            let destinationPath = destination.standardizedFileURL.path
            let sourcePath = resolved.item.standardizedFileURL.path
            if operation == .move && destinationPath == resolved.item.deletingLastPathComponent().standardizedFileURL.path {
                failures.append("\(originalURL.lastPathComponent)：已在目标目录")
                continue
            }
            if destinationPath == sourcePath || destinationPath.hasPrefix(sourcePath + "/") {
                failures.append("\(originalURL.lastPathComponent)：目标位于项目内部")
                continue
            }

            let target = availableTemplateURL(in: destination, sourceName: resolved.item.lastPathComponent)
            do {
                switch operation {
                case .copy:
                    try FileManager.default.copyItem(at: resolved.item, to: target)
                case .move:
                    try FileManager.default.moveItem(at: resolved.item, to: target)
                }
                createdURLs.append(target)
            } catch {
                failures.append("\(originalURL.lastPathComponent)：\(error.localizedDescription)")
            }
        }

        if !createdURLs.isEmpty {
            NSWorkspace.shared.activateFileViewerSelecting(createdURLs)
        }
        if !failures.isEmpty {
            showError(
                operation == .copy ? "部分项目复制失败" : "部分项目移动失败",
                detail: failures.prefix(8).joined(separator: "\n")
            )
        }
        logger.notice("F31 file operation=\(operation.rawValue, privacy: .public), completed=\(createdURLs.count, privacy: .public), failed=\(failures.count, privacy: .public)")
        (NSApp.delegate as? AppDelegate)?.finishBackgroundRequest()
    }

    private static func resolvedAuthorizedItem(_ requestedItem: URL) -> (root: URL, item: URL)? {
        let requestedPath = requestedItem.standardizedFileURL.path
        let records = SharedSettings.loadFolders().sorted { $0.path.count > $1.path.count }
        for record in records {
            let recordedPath = URL(fileURLWithPath: record.path, isDirectory: true).standardizedFileURL.path
            guard requestedPath == recordedPath || requestedPath.hasPrefix(recordedPath + "/") else { continue }
            var isStale = false
            guard let resolvedRoot = try? URL(
                resolvingBookmarkData: record.bookmark,
                options: [.withSecurityScope, .withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) else { continue }
            let relativePath = String(requestedPath.dropFirst(recordedPath.count))
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let resolvedItem = relativePath.isEmpty
                ? resolvedRoot
                : resolvedRoot.appendingPathComponent(relativePath)
            return (resolvedRoot, resolvedItem)
        }
        return nil
    }

    @MainActor
    private static func handleClipboardFile(_ request: ActionRequest) {
        guard let destinationPath = request.destinationPath,
              let type = request.clipboardType,
              let access = authorizedAccess(to: URL(fileURLWithPath: destinationPath, isDirectory: true)) else {
            showError("无法从剪贴板创建文件", detail: "目标目录无效或尚未授权。")
            return
        }

        let didAccess = access.root.startAccessingSecurityScopedResource()
        defer { if didAccess { access.root.stopAccessingSecurityScopedResource() } }

        let data: Data?
        let baseName: String
        let fileExtension: String
        switch type {
        case .txt:
            data = NSPasteboard.general.string(forType: .string).map { Data($0.utf8) }
            baseName = "剪贴板文本"
            fileExtension = "txt"
        case .markdown:
            data = NSPasteboard.general.string(forType: .string).map { Data($0.utf8) }
            baseName = "剪贴板内容"
            fileExtension = "md"
        case .png:
            if let png = NSPasteboard.general.data(forType: .png) {
                data = png
            } else if let tiff = NSPasteboard.general.data(forType: .tiff),
                      let bitmap = NSBitmapImageRep(data: tiff) {
                data = bitmap.representation(using: .png, properties: [:])
            } else {
                data = nil
            }
            baseName = "剪贴板图片"
            fileExtension = "png"
        }

        guard let data else {
            showError("剪贴板中没有可用内容", detail: type == .png ? "请先复制一张图片。" : "请先复制一段文本。")
            return
        }
        guard let target = creationURL(in: access.directory, suggestedBaseName: baseName, extension: fileExtension) else {
            (NSApp.delegate as? AppDelegate)?.finishBackgroundRequest()
            return
        }
        do {
            try data.write(to: target, options: .atomic)
            NSWorkspace.shared.activateFileViewerSelecting([target])
            logger.notice("F32 clipboard file created=\(target.path, privacy: .public)")
            (NSApp.delegate as? AppDelegate)?.finishBackgroundRequest()
        } catch {
            showError("无法创建剪贴板文件", detail: error.localizedDescription)
        }
    }

    private struct BatchRenameOptions {
        let prefix: String
        let suffix: String
        let find: String
        let replacement: String
        let addsNumber: Bool
    }

    @MainActor
    private static func handleBatchRename(_ request: ActionRequest) {
        guard request.paths.count > 1 else { return }
        guard let options = promptForBatchRename(count: request.paths.count) else {
            (NSApp.delegate as? AppDelegate)?.finishBackgroundRequest()
            return
        }

        var resolvedItems: [(root: URL, source: URL, target: URL)] = []
        var accessedRoots: [URL] = []
        defer { accessedRoots.forEach { $0.stopAccessingSecurityScopedResource() } }

        for (index, path) in request.paths.enumerated() {
            let original = URL(fileURLWithPath: path).standardizedFileURL
            guard let resolved = resolvedAuthorizedItem(original) else {
                showError("无法批量重命名", detail: "无法访问 \(original.lastPathComponent)。")
                return
            }
            if resolved.root.startAccessingSecurityScopedResource() {
                accessedRoots.append(resolved.root)
            }
            let fileExtension = resolved.item.pathExtension
            var baseName = resolved.item.deletingPathExtension().lastPathComponent
            if !options.find.isEmpty {
                baseName = baseName.replacingOccurrences(of: options.find, with: options.replacement)
            }
            let number = options.addsNumber ? " \(index + 1)" : ""
            let newBaseName = "\(options.prefix)\(baseName)\(options.suffix)\(number)"
            guard isValidFileName(newBaseName) else {
                showError("无法批量重命名", detail: "生成的文件名无效。")
                return
            }
            let finalName = fileExtension.isEmpty ? newBaseName : "\(newBaseName).\(fileExtension)"
            let target = resolved.item.deletingLastPathComponent().appendingPathComponent(finalName)
            resolvedItems.append((resolved.root, resolved.item, target))
        }

        let sourcePaths = Set(resolvedItems.map { $0.source.path })
        let targetPaths = resolvedItems.map { $0.target.path }
        guard Set(targetPaths).count == targetPaths.count else {
            showError("无法批量重命名", detail: "多个项目会得到相同的名称，请调整规则。")
            return
        }
        if let conflict = resolvedItems.first(where: {
            $0.source.path != $0.target.path && FileManager.default.fileExists(atPath: $0.target.path) && !sourcePaths.contains($0.target.path)
        }) {
            showError("名称已存在", detail: conflict.target.lastPathComponent)
            return
        }

        var staged: [(source: URL, temporary: URL, target: URL)] = []
        do {
            for item in resolvedItems where item.source.path != item.target.path {
                let temporary = item.source.deletingLastPathComponent()
                    .appendingPathComponent(".key-super-rename-\(UUID().uuidString)")
                try FileManager.default.moveItem(at: item.source, to: temporary)
                staged.append((item.source, temporary, item.target))
            }
            for item in staged {
                try FileManager.default.moveItem(at: item.temporary, to: item.target)
            }
            let targets = resolvedItems.map(\.target)
            NSWorkspace.shared.activateFileViewerSelecting(targets)
            logger.notice("F33 batch renamed count=\(targets.count, privacy: .public)")
            (NSApp.delegate as? AppDelegate)?.finishBackgroundRequest()
        } catch {
            for item in staged.reversed() {
                if FileManager.default.fileExists(atPath: item.temporary.path) {
                    try? FileManager.default.moveItem(at: item.temporary, to: item.source)
                } else if FileManager.default.fileExists(atPath: item.target.path),
                          !FileManager.default.fileExists(atPath: item.source.path) {
                    try? FileManager.default.moveItem(at: item.target, to: item.source)
                }
            }
            showError("批量重命名失败", detail: error.localizedDescription)
        }
    }

    @MainActor
    private static func promptForBatchRename(count: Int) -> BatchRenameOptions? {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "批量重命名 \(count) 个项目"
        alert.informativeText = "文件扩展名会保持不变。留空的规则不会生效。"
        alert.addButton(withTitle: "重命名")
        alert.addButton(withTitle: "取消")

        let view = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 150))
        let labels = ["添加前缀", "添加后缀", "查找文本", "替换为"]
        var fields: [NSTextField] = []
        for (index, label) in labels.enumerated() {
            let y = 122 - CGFloat(index * 30)
            let text = NSTextField(labelWithString: label)
            text.frame = NSRect(x: 0, y: y + 2, width: 76, height: 20)
            let field = NSTextField(frame: NSRect(x: 82, y: y, width: 278, height: 24))
            view.addSubview(text)
            view.addSubview(field)
            fields.append(field)
        }
        let numberButton = NSButton(checkboxWithTitle: "按当前顺序添加编号", target: nil, action: nil)
        numberButton.frame = NSRect(x: 82, y: 0, width: 220, height: 22)
        view.addSubview(numberButton)
        alert.accessoryView = view
        alert.window.initialFirstResponder = fields[0]

        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        let options = BatchRenameOptions(
            prefix: fields[0].stringValue,
            suffix: fields[1].stringValue,
            find: fields[2].stringValue,
            replacement: fields[3].stringValue,
            addsNumber: numberButton.state == .on
        )
        guard !options.prefix.isEmpty || !options.suffix.isEmpty || !options.find.isEmpty || options.addsNumber else {
            showError("没有重命名规则", detail: "请至少填写一项规则。")
            return nil
        }
        return options
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
