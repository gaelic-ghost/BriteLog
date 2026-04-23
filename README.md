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

Right now, that app is the entitlement-bearing shell for packaging, settings, and future viewer work. The live viewer experience is still being built out, so the app is not yet a polished end-user log-viewing product.

## Usage

Today, BriteLog is used as a signed macOS app host rather than as a standalone CLI tool.

The current practical state is:

- `BriteLog.app` is the entitlement-bearing surface we build, sign, package, and distribute
- the package modules under `Packages/BriteLog` still hold most of the logging engine and command logic
- the app UI is currently a host shell for settings and future viewer work, not the finished day-to-day viewer experience yet

So the real supported workflow today is:

1. Build and run the native app target from Xcode or `xcodebuild`
2. Use that app host as the base for entitlement, provisioning, packaging, and future persisted settings
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

1. Work on the shared logging engine and app-support code in `Packages/BriteLog`.
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

Formal GitHub release notes are not established yet. For now, the main shipped milestones and structural changes are tracked in git history, and the workspace is still evolving quickly as the shared engine and native app host settle into shape.

The current direct-distribution plan is:

- a system-wide `.pkg` installer for `BriteLog.app`
- a `.zip` bundle containing `BriteLog.app` for drag-and-drop installation

Those artifacts can now be built under `dist/` and uploaded to the GitHub release for the matching tag through the repo-maintenance release flow when the signing and notarization inputs are configured.

See [docs/distribution.md](./docs/distribution.md) for the current packaging layout, signing/notarization inputs, and GitHub release-hosting commands.

## License

See [LICENSE](./LICENSE).
