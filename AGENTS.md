# Repository Guidelines

## Project Structure & Module Organization

`KEY_SUPER/` contains the SwiftUI host application. `KeySuperApp.swift` defines the app lifecycle, `ContentView.swift` provides the setup UI, and `FileCreator.swift` handles validated file creation requests. `FinderSyncExtension/` contains the Finder Sync extension, including contextual-menu construction and request forwarding. Each target has its own `Info.plist` and entitlements file. Xcode project configuration lives in `KEY_SUPER.xcodeproj/`.

Office template sources live in `TemplateSources/`, while the packaged XLSX and DOCX resources live in `KEY_SUPER/Templates/`. There is currently no test target or asset catalog. Add tests under `KEY_SUPERTests/` and `FinderSyncExtensionTests/` when introducing testable logic.

## Architecture Overview

The sandboxed Finder extension identifies the selected directory and sends a `key-super://create` request. The host app performs filesystem writes because Finder extensions cannot write freely outside their sandbox. Keep this separation intact. The extension should remain fast and avoid networking, persistent polling, or file-content reads.

Debug uses a local configuration file so Personal Team builds can be tested without App Groups. Release uses `group.com.keysuper.app`. Never copy Debug temporary-exception entitlements into Release.

## Build, Test, and Development Commands

- `open KEY_SUPER.xcodeproj` opens the project in Xcode.
- `xcodebuild -project KEY_SUPER.xcodeproj -scheme "KEY SUPER" -configuration Debug -sdk macosx build` builds both targets with local signing.
- `xcodebuild -project KEY_SUPER.xcodeproj -scheme "KEY SUPER" -configuration Release -sdk macosx -derivedDataPath /tmp/key-super-build build CODE_SIGNING_ALLOWED=NO` performs a certificate-independent compile check.
- In Xcode, use `Shift+Cmd+K` before testing extension-registration or entitlement changes, then run the `KEY SUPER` scheme with `Cmd+R`.

## Coding Style & Naming Conventions

Use four-space indentation and standard Swift API naming: `UpperCamelCase` for types and `lowerCamelCase` for methods and properties. Prefer small enums and focused helpers over stringly typed branching. Keep user-facing text in concise Simplified Chinese. Use `Logger` with subsystem `com.keysuper.app`; preserve the existing `E`, `A`, and `F` diagnostic prefixes while troubleshooting.

## Testing Guidelines

No automated test suite exists yet. Before submitting changes, compile Release and manually verify every enabled format, valid Office template opening, duplicate-name numbering, Finder extension enablement, and behavior in an unauthorized directory. Name future XCTest methods descriptively, for example `testDuplicateNameAddsNumericSuffix()`.

## Commit & Pull Request Guidelines

No Git history is available, so use short imperative commits such as `Fix Finder menu destination retention`. Keep each commit focused. Pull requests should explain behavior changes, list manual test results, identify entitlement or signing changes, and include screenshots for visible UI updates. Never commit certificates, provisioning profiles, DerivedData, or `xcuserdata` files.
