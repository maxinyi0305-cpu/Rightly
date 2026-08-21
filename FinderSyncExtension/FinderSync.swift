import Cocoa
import FinderSync
import OSLog

final class FinderSync: FIFinderSync {
    private let logger = Logger(subsystem: "com.keysuper.app", category: "FinderExtension")
    private var contextualDirectory: URL?
    private var contextualItems: [URL] = []
    private var contextualFormats: [FileFormat] = []
    private var contextualCustomFormats: [CustomFileFormat] = []
    private var contextualTemplates: [(directory: TemplateDirectoryRecord, template: TemplateRecord)] = []
    private var contextualTerminalApps: [TerminalApp] = []
    private var contextualEditorApps: [EditorApp] = []
    private var contextualPathCopyFormats: [PathCopyFormat] = []
    private var contextualAITools: [AITool] = []
    private var contextualFavoriteFolders: [FavoriteFolderRecord] = []

    override init() {
        super.init()
        logger.notice("E01 extension initialized")
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(foldersDidChange(_:)),
            name: SharedSettings.configurationDidChangeNotification,
            object: nil
        )
        reloadMonitoredDirectories()
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
    }

    @objc private func foldersDidChange(_ notification: Notification) {
        logger.notice("E20 shared configuration changed")
        reloadMonitoredDirectories()
    }

    private func reloadMonitoredDirectories() {
        let urls = SharedSettings.loadFolders().map {
            URL(fileURLWithPath: $0.path, isDirectory: true).standardizedFileURL
        }
        FIFinderSyncController.default().directoryURLs = Set(urls)
        logger.notice("E02 registered \(urls.count, privacy: .public) monitored directories")
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        logger.notice("E03 menu requested, kind=\(menuKind.rawValue, privacy: .public)")
        guard let context = context(for: menuKind) else {
            logger.error("E04 menu aborted: context unavailable")
            return nil
        }

        contextualDirectory = context.directory
        contextualItems = context.items
        contextualFormats = SharedSettings.loadEnabledFormats()
        contextualCustomFormats = SharedSettings.loadCustomFileFormats().filter(\.isEnabled)
        contextualTemplates = SharedSettings.allTemplates()
        contextualTerminalApps = SharedSettings.loadEnabledTerminalApps().filter(isInstalled)
        contextualEditorApps = SharedSettings.loadEnabledEditorApps().filter(isInstalled)
        contextualPathCopyFormats = SharedSettings.loadEnabledPathCopyFormats()
        contextualAITools = SharedSettings.loadEnabledAITools().filter(isInstalled)
        contextualFavoriteFolders = SharedSettings.loadFavoriteFolders()
        let enabledFeatures = Set(SharedSettings.loadEnabledFeatures())

        let menu = NSMenu(title: "KEY SUPER")

        if enabledFeatures.contains(.newFile), !contextualFormats.isEmpty || !contextualCustomFormats.isEmpty || !contextualTemplates.isEmpty {
            let submenu = NSMenu(title: "新建")
            if !contextualFormats.isEmpty || !contextualCustomFormats.isEmpty {
                addSectionTitle("空白文件", to: submenu)
                for (index, type) in contextualFormats.enumerated() {
                    addAction(type.menuTitle, to: submenu, selector: #selector(createFile(_:)), tag: index)
                }
                for (index, format) in contextualCustomFormats.enumerated() {
                    addAction(format.menuTitle, to: submenu, selector: #selector(createCustomFile(_:)), tag: index)
                }
            }
            if !contextualTemplates.isEmpty {
                if !submenu.items.isEmpty {
                    submenu.addItem(.separator())
                }
                addSectionTitle("模板文件", to: submenu)
                for (index, template) in contextualTemplates.enumerated() {
                    addAction(template.template.displayName, to: submenu, selector: #selector(createTemplate(_:)), tag: index)
                }
            }
            addSubmenu("新建", submenu: submenu, to: menu)
        }

        if enabledFeatures.contains(.clipboard) {
            let clipboardMenu = NSMenu(title: "从剪贴板创建")
            if NSPasteboard.general.availableType(from: [.string]) != nil {
                addAction("文本文件 (.txt)", to: clipboardMenu, selector: #selector(createFromClipboard(_:)), tag: 0)
                addAction("Markdown 文档 (.md)", to: clipboardMenu, selector: #selector(createFromClipboard(_:)), tag: 1)
            }
            if NSPasteboard.general.availableType(from: [.png, .tiff]) != nil {
                addAction("PNG 图片 (.png)", to: clipboardMenu, selector: #selector(createFromClipboard(_:)), tag: 2)
            }
            if !clipboardMenu.items.isEmpty {
                addSubmenu("从剪贴板创建", submenu: clipboardMenu, to: menu)
            }
        }

        if enabledFeatures.contains(.terminal), !contextualTerminalApps.isEmpty {
            let submenu = NSMenu(title: "在终端中打开")
            for (index, app) in contextualTerminalApps.enumerated() {
                addAction(app.title, to: submenu, selector: #selector(openTerminal(_:)), tag: index)
            }
            addSubmenu("在终端中打开", submenu: submenu, to: menu)
        }

        if enabledFeatures.contains(.editor), !contextualEditorApps.isEmpty {
            let submenu = NSMenu(title: "用编辑器打开")
            for (index, app) in contextualEditorApps.enumerated() {
                addAction(app.title, to: submenu, selector: #selector(openEditor(_:)), tag: index)
            }
            addSubmenu("用编辑器打开", submenu: submenu, to: menu)
        }

        if enabledFeatures.contains(.copyPath), !contextualItems.isEmpty, !contextualPathCopyFormats.isEmpty {
            let submenu = NSMenu(title: "复制")
            for (index, format) in contextualPathCopyFormats.enumerated() {
                addAction(format.title, to: submenu, selector: #selector(copyValue(_:)), tag: index)
            }
            addSubmenu(contextualItems.count > 1 ? "复制 \(contextualItems.count) 个项目的信息" : "复制", submenu: submenu, to: menu)
        }

        if enabledFeatures.contains(.ai), !contextualAITools.isEmpty {
            let submenu = NSMenu(title: "用 AI 打开")
            for (index, tool) in contextualAITools.enumerated() {
                addAction(tool.title, to: submenu, selector: #selector(openAI(_:)), tag: index)
            }
            addSubmenu("用 AI 打开", submenu: submenu, to: menu)
        }

        if enabledFeatures.contains(.organize), !contextualItems.isEmpty, !contextualFavoriteFolders.isEmpty {
            let copyMenu = NSMenu(title: "复制到")
            let moveMenu = NSMenu(title: "移动到")
            for (index, folder) in contextualFavoriteFolders.enumerated() {
                addAction(folder.displayName, to: copyMenu, selector: #selector(copyToFavorite(_:)), tag: index)
                addAction(folder.displayName, to: moveMenu, selector: #selector(moveToFavorite(_:)), tag: index)
            }
            addSubmenu("复制到", submenu: copyMenu, to: menu)
            addSubmenu("移动到", submenu: moveMenu, to: menu)
        }

        if enabledFeatures.contains(.batchRename), contextualItems.count > 1 {
            addAction("批量重命名 \(contextualItems.count) 个项目…", to: menu, selector: #selector(batchRename(_:)), tag: 0)
        }

        logger.notice("E06 menu returned: items=\(self.contextualItems.count, privacy: .public), entries=\(menu.items.count, privacy: .public)")
        return menu.items.isEmpty ? nil : menu
    }

    @objc private func createFile(_ sender: NSMenuItem) {
        guard let directory = contextualDirectory, contextualFormats.indices.contains(sender.tag) else {
            logger.error("E09 create action aborted")
            return
        }
        openSimpleRequest(host: "create", queryItems: [
            URLQueryItem(name: "path", value: directory.path),
            URLQueryItem(name: "type", value: contextualFormats[sender.tag].rawValue)
        ])
    }

    @objc private func createCustomFile(_ sender: NSMenuItem) {
        guard let directory = contextualDirectory,
              contextualCustomFormats.indices.contains(sender.tag) else {
            logger.error("E35 custom create action aborted")
            return
        }
        openSimpleRequest(host: "create", queryItems: [
            URLQueryItem(name: "path", value: directory.path),
            URLQueryItem(name: "type", value: "custom"),
            URLQueryItem(name: "customID", value: contextualCustomFormats[sender.tag].id.uuidString)
        ])
    }

    @objc private func createTemplate(_ sender: NSMenuItem) {
        guard let directory = contextualDirectory, contextualTemplates.indices.contains(sender.tag) else {
            logger.error("E34 template action aborted")
            return
        }
        let item = contextualTemplates[sender.tag]
        openSimpleRequest(host: "template", queryItems: [
            URLQueryItem(name: "path", value: directory.path),
            URLQueryItem(name: "directoryID", value: item.directory.id.uuidString),
            URLQueryItem(name: "relativePath", value: item.template.relativePath)
        ])
    }

    @objc private func createFromClipboard(_ sender: NSMenuItem) {
        guard let directory = contextualDirectory else { return }
        let types: [ClipboardFileType] = [.txt, .markdown, .png]
        guard types.indices.contains(sender.tag) else { return }
        sendRequest(ActionRequest(kind: .clipboardFile, destinationPath: directory.path, clipboardType: types[sender.tag]))
    }

    @objc private func openTerminal(_ sender: NSMenuItem) {
        guard let directory = contextualDirectory, contextualTerminalApps.indices.contains(sender.tag) else { return }
        openSimpleRequest(host: "terminal", queryItems: [
            URLQueryItem(name: "path", value: directory.path),
            URLQueryItem(name: "app", value: contextualTerminalApps[sender.tag].rawValue)
        ])
    }

    @objc private func openEditor(_ sender: NSMenuItem) {
        guard contextualEditorApps.indices.contains(sender.tag), let directory = contextualDirectory else { return }
        let app = contextualEditorApps[sender.tag]
        guard let applicationURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleIdentifier) else { return }
        let urls = contextualItems.isEmpty ? [directory] : contextualItems
        NSWorkspace.shared.open(
            urls,
            withApplicationAt: applicationURL,
            configuration: NSWorkspace.OpenConfiguration()
        ) { [logger] _, error in
            if let error {
                logger.error("E40 editor open failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    @objc private func copyValue(_ sender: NSMenuItem) {
        guard contextualPathCopyFormats.indices.contains(sender.tag), !contextualItems.isEmpty else { return }
        let format = contextualPathCopyFormats[sender.tag]
        let values = contextualItems.map { item -> String in
            switch format {
            case .absolute: return item.path
            case .relative: return relativePath(for: item)
            case .fileURL: return item.absoluteString
            case .terminal: return shellEscaped(item.path)
            case .fileName: return item.lastPathComponent
            case .baseName: return item.deletingPathExtension().lastPathComponent
            case .markdown:
                let label = item.lastPathComponent
                    .replacingOccurrences(of: "[", with: "\\[")
                    .replacingOccurrences(of: "]", with: "\\]")
                return "[\(label)](\(item.absoluteString))"
            }
        }
        NSPasteboard.general.clearContents()
        let didCopy = NSPasteboard.general.setString(values.joined(separator: "\n"), forType: .string)
        logger.notice("E33 copied \(values.count, privacy: .public) values, success=\(didCopy, privacy: .public)")
    }

    @objc private func openAI(_ sender: NSMenuItem) {
        guard let directory = contextualDirectory, contextualAITools.indices.contains(sender.tag) else { return }
        if let url = aiURL(for: contextualAITools[sender.tag], directory: directory) {
            _ = NSWorkspace.shared.open(url)
        }
    }

    @objc private func copyToFavorite(_ sender: NSMenuItem) {
        sendFileOperation(.copy, favoriteIndex: sender.tag)
    }

    @objc private func moveToFavorite(_ sender: NSMenuItem) {
        sendFileOperation(.move, favoriteIndex: sender.tag)
    }

    @objc private func batchRename(_ sender: NSMenuItem) {
        guard contextualItems.count > 1 else { return }
        sendRequest(ActionRequest(kind: .batchRename, paths: contextualItems.map(\.path)))
    }

    private func sendFileOperation(_ operation: FileOperation, favoriteIndex: Int) {
        guard contextualFavoriteFolders.indices.contains(favoriteIndex), !contextualItems.isEmpty else { return }
        sendRequest(
            ActionRequest(
                kind: .fileOperation,
                paths: contextualItems.map(\.path),
                destinationID: contextualFavoriteFolders[favoriteIndex].id,
                operation: operation
            )
        )
    }

    private func sendRequest(_ request: ActionRequest) {
        do {
            let id = try SharedSettings.saveRequest(request)
            openSimpleRequest(host: "request", queryItems: [URLQueryItem(name: "id", value: id.uuidString)])
        } catch {
            logger.error("E41 request save failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func openSimpleRequest(host: String, queryItems: [URLQueryItem]) {
        var components = URLComponents()
        components.scheme = "key-super"
        components.host = host
        components.queryItems = queryItems
        guard let url = components.url else { return }
        logger.notice("E12 opening request host=\(host, privacy: .public)")
        _ = NSWorkspace.shared.open(url)
    }

    private func addAction(_ title: String, to menu: NSMenu, selector: Selector, tag: Int) {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
        item.target = self
        item.tag = tag
        menu.addItem(item)
    }

    private func addSubmenu(_ title: String, submenu: NSMenu, to menu: NSMenu) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = submenu
        menu.addItem(item)
    }

    private func addSectionTitle(_ title: String, to menu: NSMenu) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
    }

    private func context(for menuKind: FIMenuKind) -> (directory: URL, items: [URL])? {
        let controller = FIFinderSyncController.default()
        let items: [URL]
        let destination: URL?

        switch menuKind {
        case .contextualMenuForContainer:
            items = []
            destination = controller.targetedURL()?.standardizedFileURL
        case .contextualMenuForItems:
            items = (controller.selectedItemURLs() ?? []).map(\.standardizedFileURL)
            if items.count == 1, let first = items.first {
                var isDirectory: ObjCBool = false
                destination = FileManager.default.fileExists(atPath: first.path, isDirectory: &isDirectory) && isDirectory.boolValue
                    ? first
                    : first.deletingLastPathComponent()
            } else {
                destination = controller.targetedURL()?.standardizedFileURL ?? items.first?.deletingLastPathComponent()
            }
        default:
            return nil
        }

        guard let destination, isAuthorized(destination) else { return nil }
        return (destination, items)
    }

    private func isAuthorized(_ directory: URL) -> Bool {
        let path = directory.standardizedFileURL.path
        return SharedSettings.loadFolders().contains { path == $0.path || path.hasPrefix($0.path + "/") }
    }

    private func isInstalled(_ app: TerminalApp) -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleIdentifier) != nil
    }

    private func isInstalled(_ app: EditorApp) -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleIdentifier) != nil
    }

    private func isInstalled(_ tool: AITool) -> Bool {
        guard let url = aiURL(for: tool, directory: URL(fileURLWithPath: "/", isDirectory: true)) else { return false }
        return NSWorkspace.shared.urlForApplication(toOpen: url) != nil
    }

    private func aiURL(for tool: AITool, directory: URL) -> URL? {
        var components = URLComponents()
        switch tool {
        case .claudeCode:
            components.scheme = "claude"
            components.host = "code"
            components.path = "/new"
            components.queryItems = [URLQueryItem(name: "folder", value: directory.path)]
        case .codex:
            components.scheme = "codex"
            components.host = "new"
            components.queryItems = [URLQueryItem(name: "path", value: directory.path)]
        }
        return components.url
    }

    private func relativePath(for item: URL) -> String {
        let itemPath = item.standardizedFileURL.path
        let root = SharedSettings.loadFolders()
            .map { URL(fileURLWithPath: $0.path, isDirectory: true).standardizedFileURL.path }
            .filter { itemPath == $0 || itemPath.hasPrefix($0 + "/") }
            .max { $0.count < $1.count }
        guard let root else { return item.lastPathComponent }
        let relative = String(itemPath.dropFirst(root.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return relative.isEmpty ? "." : relative
    }

    private func shellEscaped(_ path: String) -> String {
        "'\(path.replacingOccurrences(of: "'", with: "'\\\\''"))'"
    }
}
