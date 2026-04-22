# BriteLog

BriteLog is a macOS-first Swift tool package for watching app log output and re-presenting it in a way that is easier to scan while debugging.

The near-term goal is simple: capture unified logging output from an app you are running from Xcode, then re-output it to Terminal or Console with configurable colors, lighter metadata, and stronger visual emphasis for the lines that matter most. Longer term, this can grow into richer filtering, persistent highlights, output simplification, and other operator-friendly log shaping.

Apple's unified logging docs are the main platform anchor for this repo:

- [Logging](https://developer.apple.com/documentation/os/logging)
- [Viewing Log Messages](https://developer.apple.com/documentation/os/viewing-log-messages)
- [Logger](https://developer.apple.com/documentation/os/logger)
- [OSLog](https://developer.apple.com/documentation/OSLog)
- [OSLogStore.local()](https://developer.apple.com/documentation/oslog/oslogstore/local%28%29)

Those docs matter here because Apple explicitly documents that unified log data can be viewed through the Console app, the `log` CLI, Xcode's debug console, and programmatically via the OSLog framework. Apple also documents that `OSLogStore.local()` opens the Mac's local store but requires system permission and the `com.apple.logging.local-store` entitlement. That gives BriteLog a clear product direction: stay close to the system logging model, then improve readability and workflow on top of it instead of inventing a parallel logging system.

## Module shape

- `BriteLogCore`: shared log record model, live-request and filter types, and terminal rendering
- `BriteLogOSLogStore`: the first ingestion module, built around `OSLogStore`
- `BriteLog`: the CLI surface that wires flags into an ingestion source and prints rendered output

This split is intentional. The first path is `OSLogStore`, but the package is already shaped so a second ingestion source can land as its own module later instead of being bolted into the CLI target.

## Current status

- Swift package bootstrap complete
- macOS 15.0 minimum target
- Swift language mode pinned to `.v6`
- Swift Testing baseline in place
- Live `watch` command implemented through `OSLogStore`
- Current-process scope is the safe default for the CLI
- Local-store scope is exposed as the broader macOS option, but it is permission-sensitive
- Subsystem, category, process name, and process-id filtering exposed in the CLI
- Basic terminal rendering with `xcode`, `neon`, and `plain` themes

## First likely milestones

- Map levels, subsystems, and categories into configurable terminal colors
- Suppress or compact repetitive metadata without losing important context
- Persist user-defined highlight rules and make important lines stay visible
- Add fixture-driven tests for log formatting and filtering behavior
- Add a second ingestion module without widening `BriteLogCore` beyond shared contracts
