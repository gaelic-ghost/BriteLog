# BriteLog Workspace

This repository is now organized as a small workspace.

## Layout

- `Packages/BriteLog`: the Swift package that contains the current CLI, shared log model, and `OSLogStore` ingestion path
- `Apps/`: reserved for future Xcode-managed app or wrapper surfaces
- `scripts/repo-maintenance/`: repository-level maintainer validation, sync, and release helpers

## Current Focus

The active implementation lives in [Packages/BriteLog](Packages/BriteLog/README.md).

That package contains the current `britelog` CLI, the shared `BriteLogCore` module, and the first `OSLogStore`-backed ingestion path. If we later need a signed wrapper app or a richer macOS UI, that work should land under `Apps/` without collapsing the package layout back into the repository root.
