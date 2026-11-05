# TaskZero

**One click. Zero clutter.**

TaskZero is a native SwiftUI macOS menu-bar utility for reviewing and closing user-owned applications and verified third-party background processes. It uses Apple's process and application APIs locally and leaves anything it cannot confidently identify untouched.

## Requirements

- macOS 13 Ventura or later
- Xcode 15 or later (the project is validated with Xcode 27.2)
- Swift 5 language mode

The bundle identifier is `net.ahmadfaridabbas.TaskZero` and the deployment target is macOS 13.0.

## Build

Open `TaskZero.xcodeproj` in Xcode and select the **TaskZero** scheme. From Terminal:

```sh
xcodebuild \
  -project TaskZero.xcodeproj \
  -scheme TaskZero \
  -configuration Debug \
  -sdk macosx \
  build \
  CODE_SIGNING_ALLOWED=NO
```

The unsigned development bundle is written to Xcode's DerivedData products directory. A local archive can be created with:

```sh
xcodebuild \
  -project TaskZero.xcodeproj \
  -scheme TaskZero \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  archive \
  -archivePath build/TaskZero.xcarchive
```

For distribution, choose a Developer ID signing team in Xcode or provide the appropriate signing settings at archive time. Notarization is intentionally not performed by this repository; complete signing, notarization, stapling, and Gatekeeper validation with the distribution account that owns the bundle identifier.

### Sandboxing and hardened runtime

TaskZero is **not** sandboxed and is **not** a Mac App Store app. A process-management
utility must enumerate and signal the current user's own processes, which the macOS App
Sandbox does not permit. The target therefore ships `TaskZero/TaskZero.entitlements` with
`com.apple.security.app-sandbox` set to `false`, and builds with the **hardened runtime
enabled** (`ENABLE_HARDENED_RUNTIME = YES`) so the app can be Developer ID signed and
notarized. No hardened-runtime exceptions are required: TaskZero loads no third-party
plug-ins, uses no JIT, and does not disable library validation.

## Test

```sh
xcodebuild test \
  -project TaskZero.xcodeproj \
  -scheme TaskZero \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO
```

The tests use mock termination providers and never signal a real process. They cover Apple/system protection, root ownership, unknown signatures, exclusions, graceful termination, force termination, PID identity checks, overlapping cleanup prevention, mid-cleanup cancellation, and timeout clamping.

## Safety model

The cleanup pipeline is deliberately conservative:

1. `ProcessInspector` takes one libproc snapshot and collects PID, parent PID, user, executable path, start time, resource data, bundle ID, and signature metadata.
2. `ApplicationManager` discovers regular applications through `NSWorkspace.shared.runningApplications`.
3. `ProcessSafetyManager` protects TaskZero, root/other-user processes, critical session services, Apple/system locations, Apple-signed background processes, unknown identities, and user exclusions.
4. Current-user regular GUI applications with a verified Apple or third-party signature can receive a graceful close request. Only verified third-party processes are eligible for background cleanup; Apple background services remain protected.
5. Applications receive a graceful termination request and background processes receive `SIGTERM` first.
6. Before any force operation, TaskZero waits, revalidates executable identity and start time, then uses `forceTerminate()` or `SIGKILL` only when enabled.

TaskZero never uses `sudo`, changes SIP or Gatekeeper, unloads launch agents/daemons, or escalates privileges. It does not terminate from the process monitor; that screen is inspection-only.

## Project structure

```text
TaskZero/
├── App/             Application lifecycle and MenuBarExtra scene
├── Models/          Codable process, settings, exclusion, and result models
├── Services/        libproc, NSWorkspace, termination, safety, persistence
├── ViewModels/      Main-actor state for menu bar, settings, and monitor
├── Views/           Menu bar, preview, report, monitor, settings, history
├── Utilities/       Signature verification, constants, process helpers
└── Resources/       Asset catalog and 1024 × 1024 SVG brand master
```

## Privacy

Inspection and cleanup happen on the Mac. TaskZero has no account, analytics, telemetry, cloud processing, or external API calls. Preferences and cleanup summaries are stored in the app's local `UserDefaults` domain. See [`docs/Privacy.md`](docs/Privacy.md).

## License

TaskZero is released under the [MIT License](LICENSE).

## Icon and branding

The icon is a geometric zero with a termination mark rather than a broom or spray motif. The 1024 × 1024 master is available at `TaskZero/Resources/Branding/TaskZeroIcon.svg` and is included in the `AppIcon` asset catalog.
