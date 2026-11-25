<p align="center">
  <img src="docs/rightly-icon.png" width="128" alt="Rightly icon">
</p>

<h1 align="center">Rightly（右点）</h1>

<p align="center">
  <b>A lightweight, fast macOS Finder extension for creating new files from the right-click menu.</b><br>
  ⚡ 极速 · 🪶 极轻量 —— 在 Finder 中右键即可新建文件，支持自定义格式、模板与快捷操作。
</p>

---

一个**资源占用极少、响应迅速**的 macOS Finder 右键新建文件工具。没有常驻菜单栏进程、数据库或网络请求——菜单即点即现，用完即隐。

## 功能特性

在 Finder 中右键点击文件夹（或选中一个文件），通过「新建文件」二级菜单创建：

- 文本文档（`.txt`）、Markdown 文档（`.md`）、Python 脚本（`.py`）
- JSON 文件（`.json`）、CSV 表格（`.csv`）
- Excel 工作簿（`.xlsx`）、Word 文档（`.docx`）（基于内置 Office 模板）
- **自定义后缀**：任意后缀均可加入新建菜单

更多右键功能（可在设置中逐项开关）：

- **打开方式**：在终端中打开、使用编辑器打开、使用 AI 工具打开
- **文件操作**：拷贝文件信息、拷贝或移动到常用文件夹、批量重命名、从剪贴板新建

细节体验：

- 文件命名策略可选：默认名称自动编号 / 创建后在 Finder 中重命名 / 创建前输入名称
- 同名文件自动编号，创建后直接进入重命名状态
- 支持添加模板目录，创建文件时实时复制模板内容

## 安装

1. 从 [Releases](../../releases) 下载最新的 `Rightly-x.x.x.dmg`，拖入「应用程序」文件夹。
2. 首次启动主 App，点击「添加授权文件夹」，推荐选择个人主目录。
3. 到「系统设置 → 通用 → 登录项与扩展」启用 **Rightly**。
4. 在已授权文件夹中右键即可使用；外接磁盘等其他位置需单独授权。

> 直接打开主 App 时会依次检查 Finder 扩展和辅助功能权限；若已启用的终端应用正在运行，也会检查它所需的自动化权限。缺少的权限会逐项引导授权，Finder 后台创建文件时不会弹出这些引导。

## 从源码构建

使用 Xcode 打开 `Rightly.xcodeproj`，为两个 target 选择同一个付费开发者团队，并确认 App Group `group.com.rightly.app` 已注册并关联到两个 Bundle ID，然后运行 `Rightly` scheme。

命令行编译检查：

```sh
xcodebuild -project Rightly.xcodeproj -scheme Rightly -configuration Release -sdk macosx build CODE_SIGNING_ALLOWED=NO
```

### Personal Team 本地测试

`Debug` 配置不依赖 App Group，主应用与扩展通过 `/Users/Shared/Rightly Debug/configuration.json` 共享测试设置。直接运行 Xcode 的 `Rightly` scheme 即可。此临时文件权限只存在于 Debug entitlements；`Release` 始终使用正式 App Group，提交商店时不会包含调试例外。

## 设计

主 App 与 Finder Sync 扩展均启用 App Sandbox，并通过 App Group 共享已授权目录。主 App 使用 security-scoped bookmark 恢复用户明确授予的文件夹权限，创建文件后隐藏。应用不读取或上传文件内容，也不请求网络、摄像头等权限。

## 许可证

本项目基于 [MIT License](LICENSE) 开源。
