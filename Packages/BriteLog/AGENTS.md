# AGENTS.md

## Package Boundary

- This file applies to the Swift package in `Packages/BriteLog`.
- The repository root is two levels up from this package directory.
- Repo-maintenance scripts and the checked-in formatter live at the repository root, not inside this package directory.
- Use the repository-root paths `scripts/repo-maintenance/validate-all.sh`, `scripts/repo-maintenance/sync-shared.sh`, `scripts/repo-maintenance/release.sh`, and `.swiftformat` when working on this package.
- Use the root [AGENTS.md](../../AGENTS.md) for workspace-level layout rules and future `Apps/` work.

## Package Expectations

- Use Swift Package Manager as the source of truth for the package in `Packages/BriteLog`.
- Use `swift-package-build-run-workflow` for manifest, dependency, resource, build, and run work when `Packages/BriteLog/Package.swift` is the source of truth.
- Use `swift-package-testing-workflow` for Swift Testing, XCTest holdouts, fixtures, and package test diagnosis.
- Use `sync-swift-package-guidance` when this package guidance drifts and needs to be refreshed or merged forward.
- Re-run `sync-swift-package-guidance` after substantial package-workflow or plugin updates so local guidance stays aligned.
- Validate package changes from `Packages/BriteLog` with `swift build` and `swift test`.
- Use the repository root `scripts/repo-maintenance/validate-all.sh` for repo-level maintainer validation.
- Treat `Package.resolved` and similar package-manager outputs as generated files; do not hand-edit them.
- Keep `Package.swift` explicit about its package-wide Swift language mode and preserve `swiftLanguageModes: [.v6]` unless the user asks for a narrower contract.

## Swift Preferences

- Prefer the simplest correct Swift that is easiest to read, reason about, and maintain.
- Prefer concrete types and straightforward data flow over extra wrappers and ceremony.
- Keep code modular and cohesive without fragmenting simple logic across unnecessary files or types.
- Keep strict concurrency checking enabled and make async APIs cancellation-aware.
- Prefer Swift Testing by default unless an external constraint requires XCTest.

## BriteLog Notes

- Keep shared log models, filters, and rendering primitives in `BriteLogCore`.
- Keep each ingestion path in its own target, such as `BriteLogOSLogStore`, instead of growing source-specific logic inside the CLI target.
- Treat `OSLogStore.local()` as permission-sensitive and verify broad log-store access with `britelog doctor` before promising cross-process or Xcode-adjacent log capture behavior.
- Keep operator-facing access failures explicit and practical, and preserve the current distinction between the safe `current-process` path and the broader `local-store` path.
