# BriteLog Roadmap

Use this roadmap to track milestone-level delivery through checklist sections.

## Table of Contents

- [Vision](#vision)
- [Product Principles](#product-principles)
- [Milestone Progress](#milestone-progress)
- [Milestone 0: Signed App Foundation](#milestone-0-signed-app-foundation)
- [Milestone 1: Project Integration](#milestone-1-project-integration)
- [Milestone 2: First Viewer](#milestone-2-first-viewer)
- [Backlog Candidates](#backlog-candidates)
- [History](#history)

## Vision

- Make BriteLog the easiest way for a Mac developer to turn raw unified logs from their app into a readable, targeted, and visually useful debugging surface that fits naturally into Xcode-driven development.
- Ship BriteLog as a real signed macOS app product first, then grow it into a richer viewer and project-aware debugging companion without splitting the core logging engine across multiple incompatible workflows.

## Product Principles

- Keep `BriteLog.app` as the only supported product surface for entitlement-bearing log access and distribution.
- Keep the shared engine modular so ingestion, filtering, rendering, persistence, and Xcode integration can evolve without tangling app UI with logging internals.
- Prefer practical Xcode integration that helps developers during build and debug runs over clever editor-only features that do not actually own the run/debug lifecycle.
- Use the first release to prove the product is useful in real development before expanding into broader automation and extension surfaces.

## Milestone Progress

Use this section as a concise rollup of milestone names and statuses, not as a second task list.

- Milestone 0: Signed App Foundation - In Progress
- Milestone 1: Project Integration - In Progress
- Milestone 2: First Viewer - Planned

## Milestone 0: Signed App Foundation

### Status

In Progress

### Scope

- [ ] Finish the app-host foundation so `Apps/BriteLog` is the clear entitlement-bearing home for settings, persistence, packaging, and future viewer work.
- [ ] Keep the shared package executable as internal scaffolding only, with the real supported product story centered on `BriteLog.app`.

### Tickets

- [x] Promote `BriteLog.app` to the real signed host and retire the old Xcode CLI wrapper project.
- [x] Retarget smoke checks, release packaging, and repo docs to the app bundle.
- [x] Add app-owned configuration and storage primitives using `Application Support` and small preferences surfaces.
- [x] Define the app-side model for project installs, selected targets, and future viewer sessions.
- [ ] Verify the provisioning-profile path needed for `com.apple.logging.local-store` in the real app distribution flow.

### Exit Criteria

- [ ] The app is unambiguously the supported product surface in code, docs, and packaging.
- [x] The app has a stable place to store settings and project-level integration state.
- [ ] The repo has a documented and verified path for entitlement-bearing app builds.

## Milestone 1: Project Integration

### Status

Planned

### Scope

- [ ] Add a practical project-integration path that helps developers use BriteLog during Xcode debug runs without pretending build-time plugins own the live watch session.
- [ ] Start with a shared scheme pre-action and app-managed install story, leave Run Script build phases as a fallback, and leave source editor extension work as a later convenience layer.

### Tickets

- [x] Design the handoff contract from Xcode integration into `BriteLog.app` for project path, target, bundle identifier, configuration, and run intent.
- [ ] Add the first app UI for inspecting an `.xcodeproj`, resolving a shared scheme, and installing the BriteLog pre-action with safe shared-scheme backups, stale-write detection, and an "Xcode must be closed" guard for mutations.
- [ ] Persist the latest incoming run request and show its current observed app state in the host UI.
- [ ] Add install/update/remove flows for project integrations instead of install-only coverage.
- [ ] Add a Run Script build phase fallback for projects that cannot use the shared-scheme path cleanly.
- [ ] Document what the scheme hook writes, what the app owns, and how the live watch session is started.
- [ ] Revisit whether a SwiftPM/Xcode build plugin earns its keep as a metadata or installer helper after the scheme-first path is proven.

### Exit Criteria

- [ ] A developer can point BriteLog at an Xcode project and install a supported integration path from the app.
- [ ] The installed integration passes enough metadata for the app to target the right debug run.
- [ ] The scheme hook, fallback build phase path, and any future plugin helper responsibilities are clearly separated and documented.

## Milestone 2: First Viewer

### Status

Planned

### Scope

- [ ] Turn the app from a host shell into the first genuinely useful viewer for live targeted logs from another app.
- [ ] Deliver only the minimum viewer surface needed to prove the product is useful during real debugging sessions.

### Tickets

- [ ] Build a viewer model that owns the current watch session, live records, filters, and presentation state.
- [ ] Add a first log viewer window in the app for targeted live output.
- [ ] Surface saved theme selection and a small set of viewer preferences from app storage.
- [ ] Add at least one persistent highlighting or filtering primitive that survives app relaunch.
- [ ] Validate the first viewer against a real Xcode debug workflow and tighten the rough edges it exposes.

### Exit Criteria

- [ ] The app can show a real live log session for a targeted app in a usable viewer.
- [ ] Theme and basic viewer preferences are managed from the app rather than only from internal package scaffolding.
- [ ] The product is useful enough to demo to the person who suggested it and gather real interest feedback.

## Backlog Candidates

- [ ] Add an Xcode Source Editor Extension later as a convenience entrypoint for sending the current project or file context into `BriteLog.app`.
- [ ] Add richer saved highlight rules, pinned events, and persistent incident capture.
- [ ] Explore an embedded helper or subprocess model if the app needs a separate execution boundary for the live watcher.
- [ ] Add project templates or install presets for common Xcode integration patterns.
- [ ] Add export or share flows for notable log sessions.

## History

- Initial roadmap scaffold created.
- Added the first BriteLog roadmap with an app-first product shape and viewer-following milestones.
- Marked the app-owned Application Support model and project-install records as complete within Milestone 0.
- Switched Milestone 1 to a scheme-pre-action-first Xcode integration path, with a Run Script build phase fallback planned and build-plugin work deferred to a later helper decision.
