import AppKit
import FinderSync
import OSLog
import SwiftUI

struct ContentView: View {
    @StateObject private var folderStore = FolderAccessStore()
    @State private var isFinderExtensionEnabled = FIFinderSyncController.isExtensionEnabled
    private let logger = Logger(subsystem: "com.keysuper.app", category: "SettingsUI")

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 16) {
            Image(systemName: "cursorarrow.click.2")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(.tint)

            Text("KEY SUPER")
                .font(.headline)

            Text("配置 Finder 右键菜单：新建文件、终端、路径复制与 AI 工具。")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 380)

            GroupBox("已授权文件夹") {
                if folderStore.folders.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "folder.badge.questionmark")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("尚未授权文件夹")
                            .font(.headline)
                        Text("推荐授权个人主目录，以覆盖常用文件夹。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(height: 105)
                } else {
                    List(folderStore.folders) { folder in
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundStyle(.tint)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(folder.displayName)
                                Text(folder.path)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Button(role: .destructive) {
                                folderStore.remove(folder)
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.plain)
                            .help("移除授权")
                        }
                    }
                    .frame(height: 125)
                }
            }

            GroupBox("右键菜单功能") {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(MenuFeature.allCases) { feature in
                        Toggle(
                            feature.title,
                            isOn: Binding(
                                get: { folderStore.isEnabled(feature) },
                                set: { folderStore.setEnabled($0, for: feature) }
                            )
                        )
                        .toggleStyle(.checkbox)
                    }
                }
                .padding(.vertical, 4)
            }

            if folderStore.isEnabled(MenuFeature.newFile) {
                GroupBox("新建文件格式") {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: 3),
                        alignment: .leading,
                        spacing: 10
                    ) {
                        ForEach(FileFormat.allCases) { format in
                            Toggle(
                                format.shortName,
                                isOn: Binding(
                                    get: { folderStore.isEnabled(format) },
                                    set: { folderStore.setEnabled($0, for: format) }
                                )
                            )
                            .toggleStyle(.checkbox)
                        }
                    }
                    .padding(.vertical, 4)

                    if folderStore.enabledFormats.isEmpty {
                        Text("至少启用一种格式，Finder 中才会显示“空文件”菜单。")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .padding(.top, 4)
                    }
                }

                GroupBox("自定义模板") {
                    VStack(alignment: .leading, spacing: 8) {
                        if folderStore.templateDirectories.isEmpty {
                            Text("添加一个目录后，其中的文件会显示在“新建文件 > 模板”中。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(folderStore.templateDirectories) { directory in
                                HStack {
                                    Image(systemName: "folder")
                                        .foregroundStyle(.tint)
                                    Text(directory.displayName)
                                    Text("\(directory.templates.count) 个模板")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Button(role: .destructive) {
                                        folderStore.removeTemplateDirectory(directory)
                                    } label: {
                                        Image(systemName: "minus.circle")
                                    }
                                    .buttonStyle(.plain)
                                    .help("移除模板目录")
                                }
                            }
                        }

                        HStack {
                            Button("添加模板目录…") {
                                folderStore.chooseTemplateDirectory()
                            }
                            Button("刷新模板") {
                                folderStore.refreshTemplates()
                            }
                            .disabled(folderStore.templateDirectories.isEmpty)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            if folderStore.isEnabled(MenuFeature.terminal) {
                GroupBox("显示的终端") {
                    HStack(spacing: 18) {
                        ForEach(TerminalApp.allCases) { app in
                            Toggle(
                                app.title,
                                isOn: Binding(
                                    get: { folderStore.isEnabled(app) },
                                    set: { folderStore.setEnabled($0, for: app) }
                                )
                            )
                            .toggleStyle(.checkbox)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            if folderStore.isEnabled(MenuFeature.copyPath) {
                GroupBox("显示的路径格式") {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: 2),
                        alignment: .leading,
                        spacing: 8
                    ) {
                        ForEach(PathCopyFormat.allCases) { format in
                            Toggle(
                                format.title,
                                isOn: Binding(
                                    get: { folderStore.isEnabled(format) },
                                    set: { folderStore.setEnabled($0, for: format) }
                                )
                            )
                            .toggleStyle(.checkbox)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            if folderStore.isEnabled(MenuFeature.ai) {
                GroupBox("显示的 AI 工具") {
                    HStack(spacing: 18) {
                        ForEach(AITool.allCases) { tool in
                            Toggle(
                                tool.title,
                                isOn: Binding(
                                    get: { folderStore.isEnabled(tool) },
                                    set: { folderStore.setEnabled($0, for: tool) }
                                )
                            )
                            .toggleStyle(.checkbox)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Button("添加授权文件夹…") {
                folderStore.chooseFolders()
            }
            .buttonStyle(.borderedProminent)

            if let errorMessage = folderStore.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            } else {
                HStack(spacing: 12) {
                    Label(
                        isFinderExtensionEnabled ? "Finder 右键扩展已启用" : "Finder 右键扩展未启用",
                        systemImage: isFinderExtensionEnabled ? "checkmark.circle.fill" : "exclamationmark.circle.fill"
                    )
                    .font(.footnote)
                    .foregroundStyle(isFinderExtensionEnabled ? .green : .orange)

                    Spacer()

                    Button(isFinderExtensionEnabled ? "管理或关闭…" : "启用扩展…") {
                        logger.notice(
                            "P10 opening Finder extension management, enabled=\(isFinderExtensionEnabled, privacy: .public)"
                        )
                        FIFinderSyncController.showExtensionManagementInterface()
                    }
                    .buttonStyle(.bordered)
                }
            }
            }
            .padding(24)
        }
        .frame(width: 500, height: 800)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            let currentValue = FIFinderSyncController.isExtensionEnabled
            if currentValue != isFinderExtensionEnabled {
                logger.notice("P11 Finder extension state changed to \(currentValue, privacy: .public)")
                isFinderExtensionEnabled = currentValue
            }
        }
    }
}
