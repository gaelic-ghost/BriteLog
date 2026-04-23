# BriteLog

Like macOS logs, but they're colorful~

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Usage](#usage)
- [Development](#development)
- [Repo Structure](#repo-structure)
- [Release Notes](#release-notes)
- [License](#license)

## Overview

### Status

This project is in early development. `BriteLog.app` is the only supported product shape because it is the entitlement-bearing host needed for broad local-store access. The shared package executable still exists for development and internal testing, but it is not a supported standalone way to use or distribute BriteLog.

### What This Project Is

BriteLog is a macOS-first development tool for watching `OSLog` / `Logger` / Console output from an app you are running or debugging in Xcode, then re-outputting those logs in Terminal with configurable colors and cleaner presentation. This repository is a small workspace: the shared implementation lives in `Packages/BriteLog`, and the signed native app host lives in `Apps/BriteLog`.

### Motivation

The goal is to make the logs from another app easier to work with during development: colorize them, simplify the output, truncate unneeded metadata, and eventually grab and persistently highlight the important stuff instead of making you sift through the raw firehose every time.

## Quick Start

The supported product surface is the native app host in `Apps/BriteLog`.

```bash
xcodebuild -project Apps/BriteLog/BriteLog.xcodeproj -scheme BriteLog -configuration Debug build
open Apps/BriteLog/BriteLog.xcodeproj
```

Right now, that app is the entitlement-bearing shell for packaging, settings, persisted app state, and the first Xcode-project integration flow. The live viewer experience is still being built out, so the app is not yet a polished end-user log-viewing product.

## Usage

Today, BriteLog is used as a signed macOS app host rather than as a standalone CLI tool.

The current practical state is:

- `BriteLog.app` is the entitlement-bearing surface we build, sign, package, and distribute
- the package modules under `Packages/BriteLog` still hold most of the logging engine and command logic
- the app now owns persisted configuration, project integration records, and the current debug-run request in Application Support
- the app UI is currently a host shell for settings and future viewer work, not the finished day-to-day viewer experience yet

So the real supported workflow today is:

1. Build and run the native app target from Xcode or `xcodebuild`
2. Use that app host as the base for entitlement, provisioning, packaging, persisted app-owned state, and Xcode integration install flow
3. Treat the package executable as internal development scaffolding, not as the product

## Development

### Setup

Use macOS with Xcode installed. The shared package lives under `Packages/BriteLog`, and the native signed app host lives under `Apps/BriteLog`.

For SwiftPM work:

```bash
cd Packages/BriteLog
swift build
swift test
```

For native app work:

```bash
xcodebuild -project Apps/BriteLog/BriteLog.xcodeproj -scheme BriteLog -configuration Debug build
```

### Workflow

The normal repo flow is:

1. Work on the shared logging engine in `Packages/BriteLog` and keep cross-surface theme/rendering primitives there.
2. Keep app-owned signing, entitlement, persistence, settings, project integration, and future viewer behavior in `Apps/BriteLog`.
3. Validate SwiftPM changes from the package directory.
4. Validate workspace-level maintainer checks from the repo root.

Apple's unified logging docs are the main platform anchor for the logging side of this repo:

- [Logging](https://developer.apple.com/documentation/os/logging)
- [Viewing Log Messages](https://developer.apple.com/documentation/os/viewing-log-messages)
- [Logger](https://developer.apple.com/documentation/os/logger)
- [OSLog](https://developer.apple.com/documentation/OSLog)
- [OSLogStore.local()](https://developer.apple.com/documentation/oslog/oslogstore/local%28%29)

Those docs matter here because Apple documents that unified logs can be viewed through Console, the `log` CLI, Xcode's debug console, and programmatically through `OSLogStore`. Apple also documents that `OSLogStore.local()` requires system permission plus the `com.apple.logging.local-store` entitlement for broad local-store access, which is why this repo now keeps the signed app host under `Apps/`.

### Validation

Package-level validation:

```bash
cd Packages/BriteLog
swift test
```

Workspace-level validation:

```bash
scripts/repo-maintenance/validate-all.sh
xcodebuild -project Apps/BriteLog/BriteLog.xcodeproj -scheme BriteLog -configuration Debug test
```

Executable-level smoke checks:

```bash
scripts/integration/smoke-xcode-app.sh
```

The native-app smoke script accepts two honest outcomes:
- the signed app launches successfully
- macOS blocks launch with an `Unsatisfied Entitlements: com.apple.logging.local-store` policy failure, which confirms the current restricted-entitlement gate

## Current App State

The native app now persists its own host-level state under the user's Application Support directory for the app bundle identifier. At the moment that state includes:

- the selected default color theme
- whether the viewer should open when BriteLog is triggered from future project integration
- a stored list of project integration records for installed Xcode hooks
- the latest incoming debug-run request handed off from Xcode
- the current in-memory viewer session state derived from that run request and matched workspace app events
- the current live record buffer streamed from the local unified log store for the active targeted session

That gives the app a real storage home before the viewer lands, instead of leaving app-owned state trapped in package-only CLI scaffolding.

## Current Viewer Foundation

The app now owns the first real viewer-session model instead of stopping at "a run request exists."

- a fresh Xcode handoff opens a viewer session for that requested app target
- the session moves through `Idle`, `Waiting For Launch`, `Attached`, and `Ended`
- matching `NSWorkspace` launch and terminate events update the session with the real observed app name and PID
- the app now streams matching `OSLogStore` local-store records into that session buffer using the requested bundle identifier
- the app window already shows a small live record list for the current session, even though the more polished dedicated viewer window is still ahead

That means the app-side runtime boundary is now doing real work instead of only holding placeholders: the project integration path tells BriteLog what run is about to happen, and the app now owns both the session timeline and the first live targeted record stream for that run.

## Current Integration Path

The first real Xcode integration path is now a shared scheme pre-action installed by `BriteLog.app`.

- The app inspects an `.xcodeproj`, resolves a shared scheme, and installs a named pre-action into that scheme's `LaunchAction`.
- The app keeps this intentionally off the `.pbxproj` surface and only mutates the shared `.xcscheme`.
- The app treats open Xcode as a safety boundary and offers to quit Xcode, wait for it to fully terminate, apply the shared-scheme change, and reopen Xcode afterward instead of racing the IDE over project-owned files.
- The app fingerprints the scheme after inspection, creates an app-owned backup before mutation, and refuses stale writes if the scheme changed on disk before the user clicks install or remove.
- That pre-action writes a small run-request file into BriteLog's Application Support directory with the project path, scheme, target, bundle identifier, configuration, and built product path.
- `BriteLog.app` polls for that request, persists the latest one, and tracks matching app launches and terminations through `NSWorkspace`.

This is the current deliberate shape because a scheme pre-action is tied to "Run this scheme now", which is a much better first trigger than a generic build hook. A Run Script build phase is still the planned fallback if some projects cannot use shared-scheme pre-actions cleanly, and a SwiftPM/Xcode build plugin is now considered a future helper surface for metadata or installation support rather than the owner of the live watch session.

## Repo Structure

```text
.
├── Apps/
│   └── BriteLog/
│       ├── BriteLog.xcodeproj
│       └── BriteLog/
├── Packages/
│   └── BriteLog/
│       ├── Package.swift
│       ├── Sources/
│       │   ├── BriteLog/
│       │   ├── BriteLogCLI/
│       │   ├── BriteLogCore/
│       │   └── BriteLogOSLogStore/
│       └── Tests/
├── scripts/
│   └── repo-maintenance/
└── README.md
```

## Release Notes

Formal GitHub release notes are not established yet. For now, the main shipped milestones and structural changes are tracked in git history, and the workspace is still evolving quickly as the shared engine and native app host settle into shape.

The current direct-distribution plan is:

- a system-wide `.pkg` installer for `BriteLog.app`
- a `.zip` bundle containing `BriteLog.app` for drag-and-drop installation

Those artifacts can now be built under `dist/` and uploaded to the GitHub release for the matching tag through the repo-maintenance release flow when the signing and notarization inputs are configured.

See [docs/distribution.md](./docs/distribution.md) for the current packaging layout, signing/notarization inputs, and GitHub release-hosting commands.

## License

See [LICENSE](./LICENSE).
