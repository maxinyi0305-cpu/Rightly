import Cocoa
import FinderSync
import OSLog

final class FinderSync: FIFinderSync {
    private let logger = Logger(subsystem: "com.keysuper.app", category: "FinderExtension")
    private var contextualDirectory: URL?
    private var contextualItem: URL?
    private var contextualFormats: [FileFormat] = []
    private var contextualTemplates: [(directory: TemplateDirectoryRecord, template: TemplateRecord)] = []
    private var contextualTerminalApps: [TerminalApp] = []
    private var contextualPathCopyFormats: [PathCopyFormat] = []
    private var contextualAITools: [AITool] = []

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
        for url in urls {
            logger.notice("E21 monitored directory=\(url.path, privacy: .public)")
        }
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        logger.notice("E03 menu requested, kind=\(menuKind.rawValue, privacy: .public)")
        guard let destination = destinationDirectory(for: menuKind) else {
            logger.error("E04 menu aborted: destination unavailable")
            return nil
        }
        logger.notice("E05 menu destination=\(destination.path, privacy: .public)")
        contextualDirectory = destination
        contextualItem = selectedItemURL(for: menuKind)
        contextualFormats = SharedSettings.loadEnabledFormats()
        contextualTemplates = SharedSettings.allTemplates()
        contextualTerminalApps = SharedSettings.loadEnabledTerminalApps()
        contextualPathCopyFormats = SharedSettings.loadEnabledPathCopyFormats()
        contextualAITools = SharedSettings.loadEnabledAITools()
        let enabledFeatures = Set(SharedSettings.loadEnabledFeatures())

        let menu = NSMenu(title: "KEY SUPER")
        if enabledFeatures.contains(.newFile), !contextualFormats.isEmpty || !contextualTemplates.isEmpty {
            let parentItem = NSMenuItem(title: "新建文件", action: nil, keyEquivalent: "")
            let submenu = NSMenu(title: "新建文件")
            if !contextualFormats.isEmpty {
                let emptyFilesItem = NSMenuItem(title: "空文件", action: nil, keyEquivalent: "")
                let emptyFilesMenu = NSMenu(title: "空文件")
                for (index, type) in contextualFormats.enumerated() {
                    let item = NSMenuItem(title: type.menuTitle, action: #selector(createFile(_:)), keyEquivalent: "")
                    item.target = self
                    item.tag = index
                    emptyFilesMenu.addItem(item)
                }
                emptyFilesItem.submenu = emptyFilesMenu
                submenu.addItem(emptyFilesItem)
            }
            if !contextualTemplates.isEmpty {
                let templatesItem = NSMenuItem(title: "模板", action: nil, keyEquivalent: "")
                let templatesMenu = NSMenu(title: "模板")
                for (index, template) in contextualTemplates.enumerated() {
                    let item = NSMenuItem(title: template.template.displayName, action: #selector(createTemplate(_:)), keyEquivalent: "")
                    item.target = self
                    item.tag = index
                    templatesMenu.addItem(item)
                }
                templatesItem.submenu = templatesMenu
                submenu.addItem(templatesItem)
            }
            parentItem.submenu = submenu
            menu.addItem(parentItem)
        } else {
            logger.notice("E23 new-file menu hidden: no enabled formats")
        }

        if enabledFeatures.contains(.terminal), !contextualTerminalApps.isEmpty {
            let parentItem = NSMenuItem(title: "在终端中打开", action: nil, keyEquivalent: "")
            let submenu = NSMenu(title: "在终端中打开")
            for (index, app) in contextualTerminalApps.enumerated() {
                let item = NSMenuItem(title: app.title, action: #selector(openTerminal(_:)), keyEquivalent: "")
                item.target = self
                item.tag = index
                submenu.addItem(item)
            }
            parentItem.submenu = submenu
            menu.addItem(parentItem)
        }

        if enabledFeatures.contains(.copyPath), !contextualPathCopyFormats.isEmpty {
            let parentItem = NSMenuItem(title: "复制路径", action: nil, keyEquivalent: "")
            let submenu = NSMenu(title: "复制路径")
            for (index, format) in contextualPathCopyFormats.enumerated() {
                let item = NSMenuItem(title: format.title, action: #selector(copyPath(_:)), keyEquivalent: "")
                item.target = self
                item.tag = index
                submenu.addItem(item)
            }
            parentItem.submenu = submenu
            menu.addItem(parentItem)
        }

        if enabledFeatures.contains(.ai), !contextualAITools.isEmpty {
            let aiParentItem = NSMenuItem(title: "用 AI 打开", action: nil, keyEquivalent: "")
            let aiSubmenu = NSMenu(title: "用 AI 打开")
            for (index, tool) in contextualAITools.enumerated() {
                let item = NSMenuItem(title: tool.title, action: #selector(openAI(_:)), keyEquivalent: "")
                item.target = self
                item.tag = index
                aiSubmenu.addItem(item)
            }
            aiParentItem.submenu = aiSubmenu
            menu.addItem(aiParentItem)
        }

        logger.notice("E06 menu returned: formats=\(self.contextualFormats.count, privacy: .public), terminals=\(self.contextualTerminalApps.count, privacy: .public), copies=\(self.contextualPathCopyFormats.count, privacy: .public), AI=\(self.contextualAITools.count, privacy: .public)")
        return menu
    }

    @objc private func createFile(_ sender: NSMenuItem) {
        logger.notice("E07 menu action received, tag=\(sender.tag, privacy: .public)")
        guard let directory = contextualDirectory else {
            logger.error("E08 action aborted: contextual directory missing")
            return
        }
        logger.notice("E08 contextual directory restored=\(directory.path, privacy: .public)")
        guard contextualFormats.indices.contains(sender.tag) else {
            logger.error("E09 action aborted: invalid tag=\(sender.tag, privacy: .public)")
            return
        }

        let type = contextualFormats[sender.tag]
        logger.notice("E10 preparing request, directory=\(directory.path, privacy: .public), type=\(type.rawValue, privacy: .public)")
        var components = URLComponents()
        components.scheme = "key-super"
        components.host = "create"
        components.queryItems = [
            URLQueryItem(name: "path", value: directory.path),
            URLQueryItem(name: "type", value: type.rawValue)
        ]
        guard let requestURL = components.url else {
            logger.error("E11 action aborted: URL construction failed")
            return
        }
        logger.notice("E12 opening request URL=\(requestURL.absoluteString, privacy: .public)")
        let didOpen = NSWorkspace.shared.open(requestURL)
        logger.notice("E13 NSWorkspace.open result=\(didOpen, privacy: .public)")
    }

    @objc private func createTemplate(_ sender: NSMenuItem) {
        guard let directory = contextualDirectory, contextualTemplates.indices.contains(sender.tag) else {
            logger.error("E34 template action aborted")
            return
        }
        let item = contextualTemplates[sender.tag]
        var components = URLComponents()
        components.scheme = "key-super"
        components.host = "template"
        components.queryItems = [
            URLQueryItem(name: "path", value: directory.path),
            URLQueryItem(name: "directoryID", value: item.directory.id.uuidString),
            URLQueryItem(name: "templateID", value: item.template.id.uuidString)
        ]
        guard let requestURL = components.url else { return }
        logger.notice("E35 opening template request=\(item.template.displayName, privacy: .public), destination=\(directory.path, privacy: .public)")
        logger.notice("E36 template request result=\(NSWorkspace.shared.open(requestURL), privacy: .public)")
    }

    @objc private func openAI(_ sender: NSMenuItem) {
        guard let directory = contextualDirectory else {
            logger.error("E24 AI open aborted: contextual directory missing")
            return
        }
        guard contextualAITools.indices.contains(sender.tag) else {
            logger.error("E25 AI open aborted: invalid tag=\(sender.tag, privacy: .public)")
            return
        }
        switch contextualAITools[sender.tag] {
        case .claudeCode:
            openClaudeCode(in: directory)
        case .codex:
            openCodex(in: directory)
        }
    }

    private func openClaudeCode(in directory: URL) {
        var components = URLComponents()
        components.scheme = "claude"
        components.host = "code"
        components.path = "/new"
        components.queryItems = [URLQueryItem(name: "folder", value: directory.path)]
        openAI(components.url, name: "Claude Code", directory: directory)
    }

    private func openCodex(in directory: URL) {
        var components = URLComponents()
        components.scheme = "codex"
        components.host = "new"
        components.queryItems = [URLQueryItem(name: "path", value: directory.path)]
        openAI(components.url, name: "Codex", directory: directory)
    }

    private func openAI(_ url: URL?, name: String, directory: URL) {
        guard let url else {
            logger.error("E26 \(name, privacy: .public) URL construction failed")
            return
        }
        logger.notice("E27 opening \(name, privacy: .public), directory=\(directory.path, privacy: .public), URL=\(url.absoluteString, privacy: .public)")
        let didOpen = NSWorkspace.shared.open(url)
        logger.notice("E28 \(name, privacy: .public) open result=\(didOpen, privacy: .public)")
    }

    @objc private func openTerminal(_ sender: NSMenuItem) {
        guard let directory = contextualDirectory, contextualTerminalApps.indices.contains(sender.tag) else {
            logger.error("E29 terminal action aborted")
            return
        }
        let app = contextualTerminalApps[sender.tag]
        var components = URLComponents()
        components.scheme = "key-super"
        components.host = "terminal"
        components.queryItems = [
            URLQueryItem(name: "path", value: directory.path),
            URLQueryItem(name: "app", value: app.rawValue)
        ]
        guard let requestURL = components.url else { return }
        logger.notice("E30 opening terminal request app=\(app.rawValue, privacy: .public), path=\(directory.path, privacy: .public)")
        logger.notice("E31 terminal request result=\(NSWorkspace.shared.open(requestURL), privacy: .public)")
    }

    @objc private func copyPath(_ sender: NSMenuItem) {
        guard let item = contextualItem, contextualPathCopyFormats.indices.contains(sender.tag) else {
            logger.error("E32 copy action aborted")
            return
        }
        let format = contextualPathCopyFormats[sender.tag]
        let value: String
        switch format {
        case .absolute:
            value = item.path
        case .fileURL:
            value = item.absoluteString
        case .terminal:
            value = shellEscaped(item.path)
        case .relative:
            value = relativePath(for: item)
        }
        NSPasteboard.general.clearContents()
        let didCopy = NSPasteboard.general.setString(value, forType: .string)
        logger.notice("E33 copied \(format.rawValue, privacy: .public), success=\(didCopy, privacy: .public), value=\(value, privacy: .public)")
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

    private func selectedItemURL(for menuKind: FIMenuKind) -> URL? {
        switch menuKind {
        case .contextualMenuForContainer, .contextualMenuForItems:
            return FIFinderSyncController.default().selectedItemURLs()?.first?.standardizedFileURL
        default:
            return nil
        }
    }

    private func destinationDirectory(for menuKind: FIMenuKind) -> URL? {
        let controller = FIFinderSyncController.default()
        let candidates: [URL]

        switch menuKind {
        case .contextualMenuForContainer:
            candidates = controller.selectedItemURLs() ?? []
        case .contextualMenuForItems:
            candidates = controller.selectedItemURLs() ?? []
        default:
            logger.error("E14 unsupported menu kind=\(menuKind.rawValue, privacy: .public)")
            return nil
        }

        logger.notice("E15 selected URL count=\(candidates.count, privacy: .public)")
        guard let selectedURL = candidates.first else {
            logger.error("E16 no selected URL")
            return nil
        }
        logger.notice("E17 selected URL=\(selectedURL.path, privacy: .public)")
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: selectedURL.path, isDirectory: &isDirectory) else {
            logger.error("E18 selected URL does not exist")
            return nil
        }
        let destination = isDirectory.boolValue ? selectedURL : selectedURL.deletingLastPathComponent()
        let isAuthorized = SharedSettings.loadFolders().contains { record in
            destination.path == record.path || destination.path.hasPrefix(record.path + "/")
        }
        guard isAuthorized else {
            logger.error("E22 destination is outside authorized folders")
            return nil
        }
        logger.notice("E19 resolved destination=\(destination.path, privacy: .public), selectedIsDirectory=\(isDirectory.boolValue, privacy: .public)")
        return destination
    }

}
