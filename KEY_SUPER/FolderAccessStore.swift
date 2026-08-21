import AppKit
import OSLog

@MainActor
final class FolderAccessStore: ObservableObject {
    @Published private(set) var folders: [SharedSettings.FolderRecord] = []
    @Published private(set) var enabledFormats: [FileFormat] = []
    @Published var errorMessage: String?

    private let logger = Logger(subsystem: "com.keysuper.app", category: "FolderAccess")

    init() {
        reload()
    }

    func reload() {
        folders = SharedSettings.loadFolders()
        enabledFormats = SharedSettings.loadEnabledFormats()
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
}
