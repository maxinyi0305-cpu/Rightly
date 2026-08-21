# KEY SUPER

一个极轻量的 macOS Finder 右键新建文件工具。

支持在 Finder 中右键点击文件夹（或选中一个文件）后新建：

- 文本文档（`.txt`）
- Markdown 文档（`.md`）
- JSON 文件（`.json`）
- Excel 工作簿（`.xlsx`）
- CSV 表格（`.csv`）
- Word 文档（`.docx`）

## 运行

使用 Xcode 打开 `KEY_SUPER.xcodeproj`，为两个 target 选择同一个付费开发者团队，并确认 App Group `group.com.keysuper.app` 已注册并关联到两个 Bundle ID。

首次启动后：

1. 在主 App 中点击“添加授权文件夹”，推荐选择个人主目录。
2. 到「系统设置 → 通用 → 登录项与扩展 → 文件提供程序」启用 **KEY SUPER**。
3. 在已授权文件夹中右键即可使用；外接磁盘等其他位置需单独授权。

可在主 App 的“右键菜单文件格式”中随时启用或关闭格式。Finder 右键入口统一为“新建文件”二级菜单。

### Personal Team 本地测试

`Debug` 配置不依赖 App Group，主应用与扩展通过 `/Users/Shared/KEY SUPER Debug/configuration.json` 共享测试设置。直接运行 Xcode 的 `KEY SUPER` scheme 即可。此临时文件权限只存在于 Debug entitlements；`Release` 始终使用正式 App Group，提交商店时不会包含调试例外。

## 设计

没有常驻菜单栏进程、数据库或网络请求。主 App 与 Finder Sync 扩展均启用 App Sandbox，并通过 App Group 共享已授权目录。主 App 使用 security-scoped bookmark 恢复用户明确授予的文件夹权限，创建文件后隐藏。应用不读取或上传文件内容，也不请求网络、摄像头等权限。
