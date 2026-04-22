# AGENTS.md

## Workspace Layout

- This repository is a workspace root, not a single package root.
- Keep Swift packages under `Packages/`.
- Keep native app wrappers and other Xcode-managed app work under `Apps/`.
- Package-specific guidance belongs beside each package, such as `Packages/BriteLog/AGENTS.md`.
- Keep repository-level maintainer tooling at the root in `scripts/repo-maintenance/`.

## Repository Expectations

- Use `scripts/repo-maintenance/validate-all.sh` for local maintainer validation, `scripts/repo-maintenance/sync-shared.sh` for repo-local sync steps, and `scripts/repo-maintenance/release.sh` for releases.
- Keep `.swiftformat` at the repository root as the shared formatting source of truth unless the repo intentionally adopts a narrower package-local formatter later.
- Keep repo-facing docs and guidance aligned with the current workspace layout when packages or apps move.
- Treat generated SwiftPM and Xcode state such as `.build/`, `.swiftpm/`, and derived data as generated files, not source.

## Working In Packages

- When working inside `Packages/BriteLog`, follow the nearest package-local guidance in `Packages/BriteLog/AGENTS.md`.
- Use `swift-package-build-run-workflow` and `swift-package-testing-workflow` for ordinary SwiftPM work inside package directories.
- Re-run `sync-swift-package-guidance` when package guidance drifts, but be aware that the current skill may misclassify SwiftPM-generated `.swiftpm/xcode/package.xcworkspace` state as an Xcode app marker.

## Working In Apps

- Reserve `Apps/` for future Xcode-managed wrappers or native app surfaces that sit above the shared package code.
- Keep app-specific signing, entitlement, and permission behavior in `Apps/` rather than widening the package layout around app-only needs.
