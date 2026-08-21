import AppKit
import SwiftUI

struct ContentView: View {
    @StateObject private var folderStore = FolderAccessStore()

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "cursorarrow.click.2")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(.tint)

            Text("KEY SUPER")
                .font(.headline)

            Text("先授权文件夹，再在 Finder 中右键新建 TXT、Markdown 或 JSON 文件。")
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

            GroupBox("右键菜单文件格式") {
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
                    Text("至少启用一种格式，Finder 中才会显示“新建文件”菜单。")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(.top, 4)
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
                Text("还需在「系统设置 → 通用 → 登录项与扩展 → 文件提供程序」中启用 KEY SUPER。")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(width: 500, height: 500)
    }
}
