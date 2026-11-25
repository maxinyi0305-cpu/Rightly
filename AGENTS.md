# Repository Guidelines

## Project Structure & Module Organization

`Rightly/` contains the SwiftUI host application. `RightlyApp.swift` defines the app lifecycle, `ContentView.swift` provides the setup UI, and `FileCreator.swift` handles validated file creation requests. `RightlyFinderExtension/` contains the Finder Sync extension, including contextual-menu construction and request forwarding. `RightlyUninstaller/` contains the non-sandboxed helper that unregisters the Finder extension before removal. Xcode project configuration lives in `Rightly.xcodeproj/`.

Office template sources live in `TemplateSources/`, while the packaged XLSX and DOCX resources live in `Rightly/Templates/`. There is currently no test target or asset catalog. Add tests under `RightlyTests/` and `RightlyFinderExtensionTests/` when introducing testable logic.

## Architecture Overview

The sandboxed Finder extension identifies the selected directory and sends a `rightly://create` request. The host app performs filesystem writes because Finder extensions cannot write freely outside their sandbox. Keep this separation intact. The extension should remain fast and avoid networking, persistent polling, or file-content reads. The host app invokes the embedded non-sandboxed `RightlyUninstaller` helper only for Finder extension deregistration.

Debug uses a local configuration file so Personal Team builds can be tested without App Groups. Release uses `group.com.rightly.app`. Never copy Debug temporary-exception entitlements into Release.

## Build, Test, and Development Commands

- `open Rightly.xcodeproj` opens the project in Xcode.
- `xcodebuild -project Rightly.xcodeproj -scheme Rightly -configuration Debug -sdk macosx build` builds both targets with local signing.
- `xcodebuild -project Rightly.xcodeproj -scheme Rightly -configuration Release -sdk macosx -derivedDataPath /tmp/rightly-build build CODE_SIGNING_ALLOWED=NO` performs a certificate-independent compile check.
- In Xcode, use `Shift+Cmd+K` before testing extension-registration or entitlement changes, then run the `Rightly` scheme with `Cmd+R`.

## Coding Style & Naming Conventions

Use four-space indentation and standard Swift API naming: `UpperCamelCase` for types and `lowerCamelCase` for methods and properties. Prefer small enums and focused helpers over stringly typed branching. Keep user-facing text in concise Simplified Chinese. Use `Logger` with subsystem `com.rightly.app`; preserve the existing `E`, `A`, and `F` diagnostic prefixes while troubleshooting.

## Testing Guidelines

No automated test suite exists yet. Before submitting changes, compile Release and manually verify every enabled format, valid Office template opening, duplicate-name numbering, Finder extension enablement, and behavior in an unauthorized directory. Name future XCTest methods descriptively, for example `testDuplicateNameAddsNumericSuffix()`.

## Commit & Pull Request Guidelines

No Git history is available, so use short imperative commits such as `Fix Finder menu destination retention`. Keep each commit focused. Pull requests should explain behavior changes, list manual test results, identify entitlement or signing changes, and include screenshots for visible UI updates. Never commit certificates, provisioning profiles, DerivedData, or `xcuserdata` files.
