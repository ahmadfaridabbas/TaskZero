# TaskZero Progress Notes

Updated: 2026-11-05

## Project

TaskZero is a native SwiftUI macOS menu-bar utility for reviewing applications and verified third-party background processes before cleanup. The cleanup flow preserves protected, unknown, system, and excluded processes according to its safety rules.

## Work completed

- Refreshed the menu-bar panel and cleanup review screen with a more structured layout and clearer action hierarchy.
- Replaced the earlier warm and teal colors with an adaptive neutral graphite palette for light and dark appearances.
- Added a Light/Dark appearance toggle to the main panel. The selected appearance is saved in preferences and applied to the app’s macOS appearance.
- Removed the Settings button from the main panel as requested. Appearance settings remain in the Settings window’s Appearance tab.
- Replaced the old dotted-circle mark with the supplied TaskZero glyph in the menu bar, monitor header, settings header, and About screen.
- Improved footer action sizing and contrast for the cleanup count and ready-state indicator.
- Added a search field to the cleanup review screen. It filters applications, background processes, protected processes, and exclusions by display name, PID, executable path, or bundle identifier.
- Added “Your system stays in your control” and “MIT License • © 2026 Ahmad Farid Abbas” to the bottom of the main panel.
- Added the MIT License to the repository root, linked it from the README, included it in the built app’s Resources folder, and noted the license on the About screen.

## Important files

- `TaskZero/Views/MenuBarView.swift` — main menu-bar panel, appearance toggle, footer.
- `TaskZero/Views/CleanupPreviewView.swift` — cleanup review and search filtering.
- `TaskZero/Views/ProcessMonitorView.swift` — read-only process monitor.
- `TaskZero/Views/SettingsView.swift` — preference tabs and appearance choices.
- `TaskZero/Utilities/Constants.swift` — adaptive graphite palette.
- `TaskZero/Services/PreferencesStore.swift` — persisted preferences and appearance updates.
- `TaskZero/App/AppDelegate.swift` — applies stored appearance after macOS app startup.
- `TaskZero/Resources/Assets.xcassets/TaskZeroMenuBarGlyph.imageset/` — menu-bar glyph at 1×, 2×, and 3×.
- `TaskZero/Resources/Assets.xcassets/AppIcon.appiconset/` — app icon assets sourced from `Icons/`.
- `LICENSE` — MIT License text.

## Build and app bundle

The latest Debug build succeeded on 2026-11-05 with:

```sh
xcodebuild -project TaskZero.xcodeproj -scheme TaskZero -configuration Debug -sdk macosx build CODE_SIGNING_ALLOWED=NO
```

The refreshed app bundle is `build/TaskZero.app`. It is an unsigned development build. The MIT License text is copied into `build/TaskZero.app/Contents/Resources/LICENSE` after building.

## Notes for continuing

- TaskZero is a menu-bar app. Launching it does not open a regular window; click the menu-bar glyph to show its panel.
- The Monitor button opens an inspection-only process window. It does not terminate processes. Right-click a row to add it as an exclusion.
- The main panel has History, Light/Dark, and Quit controls. There is no Settings button in the panel.

## Audit fixes (2026-11-05)

Applied a full round of audit fixes. All 17 tests pass (13 original + 4 new); Debug and Release both build clean with `SWIFT_STRICT_CONCURRENCY = complete`.

- Cleanup preview icons resolve the running app / outermost `.app` bundle, so apps and their helpers (e.g. Chrome helpers) show real icons instead of the generic "exec" glyph.
- Cleanup is now cancellable mid-run; a "Stop" button appears while cleaning and remaining items are recorded as skipped. No new signals are sent after cancellation.
- Termination timeouts are clamped to 1–60 s in the model (including on decode) and the Settings UI uses bounded steppers instead of free text.
- `signatureMatches` now requires exact signing/team-identifier equality (including nil-vs-value) to better detect PID recycling.
- `CodeSignatureVerifier` cache keys on path + modification date + size and evicts after 512 entries, so stale/updated binaries are re-verified and the cache no longer grows unbounded.
- Background helper processes are no longer pre-selected by default (only applications are); "Select all" still selects everything eligible.
- Fixed a misplaced-modifier layout bug in `CleanupReportView.ReportMetric`.
- Added `TaskZero/TaskZero.entitlements` (sandbox explicitly disabled) and enabled the hardened runtime for Developer ID + notarization. Bumped to 1.1 (build 2).
- Removed dead code: duplicate protected-process entry, unused palette colors, `ProcessUtilities.executableURL`; consolidated exclusion matching onto `ExclusionManager`.
- Added accessibility labels to icon-only controls and a Process Monitor right-click "Exclude" action.
- Documented the Apple-signed-by-location shortcut and the snapshot TOCTOU limitation in code.
