import Cocoa
import FinderSync
import OSLog

final class FinderSync: FIFinderSync {
    private let logger = Logger(subsystem: "com.keysuper.app", category: "FinderExtension")
    private var contextualDirectory: URL?
    private var contextualFormats: [FileFormat] = []

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
        contextualFormats = SharedSettings.loadEnabledFormats()

        let menu = NSMenu(title: "KEY SUPER")
        if !contextualFormats.isEmpty {
            let parentItem = NSMenuItem(title: "新建文件", action: nil, keyEquivalent: "")
            let submenu = NSMenu(title: "新建文件")
            for (index, type) in contextualFormats.enumerated() {
                let item = NSMenuItem(title: type.menuTitle, action: #selector(createFile(_:)), keyEquivalent: "")
                item.target = self
                item.tag = index
                submenu.addItem(item)
            }
            parentItem.submenu = submenu
            menu.addItem(parentItem)
        } else {
            logger.notice("E23 new-file menu hidden: no enabled formats")
        }

        let aiParentItem = NSMenuItem(title: "用 AI 打开", action: nil, keyEquivalent: "")
        let aiSubmenu = NSMenu(title: "用 AI 打开")
        let claudeItem = NSMenuItem(title: "Claude Code", action: #selector(openClaudeCode(_:)), keyEquivalent: "")
        claudeItem.target = self
        aiSubmenu.addItem(claudeItem)
        let codexItem = NSMenuItem(title: "Codex", action: #selector(openCodex(_:)), keyEquivalent: "")
        codexItem.target = self
        aiSubmenu.addItem(codexItem)
        aiParentItem.submenu = aiSubmenu
        menu.addItem(aiParentItem)

        logger.notice("E06 menu returned with \(self.contextualFormats.count, privacy: .public) file formats and \(aiSubmenu.items.count, privacy: .public) AI tools")
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

    @objc private func openClaudeCode(_ sender: NSMenuItem) {
        guard let directory = contextualDirectory else {
            logger.error("E24 Claude Code aborted: contextual directory missing")
            return
        }
        var components = URLComponents()
        components.scheme = "claude"
        components.host = "code"
        components.path = "/new"
        components.queryItems = [URLQueryItem(name: "folder", value: directory.path)]
        openAI(components.url, name: "Claude Code", directory: directory)
    }

    @objc private func openCodex(_ sender: NSMenuItem) {
        guard let directory = contextualDirectory else {
            logger.error("E25 Codex aborted: contextual directory missing")
            return
        }
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
