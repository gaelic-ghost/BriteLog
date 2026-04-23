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

This project is in early development. The shared package CLI builds and runs today, and the native `BriteLog.app` host is now the entitlement-bearing product surface for packaging, settings, and future viewer work.

### What This Project Is

BriteLog is a macOS-first development tool for watching `OSLog` / `Logger` / Console output from an app you are running or debugging in Xcode, then re-outputting those logs in Terminal with configurable colors and cleaner presentation. This repository is a small workspace: the shared implementation lives in `Packages/BriteLog`, and the signed native app host lives in `Apps/BriteLog`.

### Motivation

The goal is to make the logs from another app easier to work with during development: colorize them, simplify the output, truncate unneeded metadata, and eventually grab and persistently highlight the important stuff instead of making you sift through the raw firehose every time.

## Quick Start

The project is still early, so the package CLI is the quickest way to try it:

```bash
cd Packages/BriteLog
swift run BriteLog watch --help
swift run BriteLog watch --this-app
```

If you want the signed app-host path for entitlement work, open `Apps/BriteLog/BriteLog.xcodeproj` in Xcode and build the `BriteLog` scheme.
On this machine today, launching that built app outside the right provisioning context is still blocked by macOS policy because `com.apple.logging.local-store` is being enforced as a restricted entitlement.

## Usage

The current workflow is centered on the shared CLI in `Packages/BriteLog`.

Watch the app described by the current directory's single `.xcodeproj`:

```bash
cd Packages/BriteLog
swift run BriteLog watch --this-app
```

Watch a specific app by bundle identifier:

```bash
cd Packages/BriteLog
swift run BriteLog watch --bundle-id com.example.MyApp
```

Start the broader Console-like stream explicitly:

```bash
cd Packages/BriteLog
swift run BriteLog watch --all
```

List and select terminal color themes:

```bash
cd Packages/BriteLog
swift run BriteLog themes list
swift run BriteLog themes select neon
```

Check the current `OSLogStore` capability surface:

```bash
cd Packages/BriteLog
swift run BriteLog doctor
```

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

1. Work on the shared CLI and logging behavior in `Packages/BriteLog`.
2. Keep app-only signing, entitlement, and future viewer behavior in `Apps/BriteLog`.
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
swift run BriteLog watch --help
swift run BriteLog doctor
```

Workspace-level validation:

```bash
scripts/repo-maintenance/validate-all.sh
xcodebuild -project Apps/BriteLog/BriteLog.xcodeproj -scheme BriteLog -configuration Debug build
```

Executable-level smoke checks:

```bash
cd Packages/BriteLog
swift test
scripts/integration/smoke-xcode-app.sh
```

The native-app smoke script accepts two honest outcomes:
- the signed app launches successfully
- macOS blocks launch with an `Unsatisfied Entitlements: com.apple.logging.local-store` policy failure, which confirms the current restricted-entitlement gate

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

Formal GitHub release notes are not established yet. For now, the main shipped milestones and structural changes are tracked in git history, and the workspace is still evolving quickly as the package CLI and native app host settle into shape.

The current direct-distribution plan is:

- a system-wide `.pkg` installer for `BriteLog.app`
- a `.zip` bundle containing `BriteLog.app` for drag-and-drop installation

Those artifacts can now be built under `dist/` and uploaded to the GitHub release for the matching tag through the repo-maintenance release flow when the signing and notarization inputs are configured.

See [docs/distribution.md](./docs/distribution.md) for the current packaging layout, signing/notarization inputs, and GitHub release-hosting commands.

## License

See [LICENSE](./LICENSE).
