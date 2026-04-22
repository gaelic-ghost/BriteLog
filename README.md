# BriteLog

BriteLog is a macOS-first Swift tool package for watching app log output and re-presenting it in a way that is easier to scan while debugging.

The near-term goal is simple: capture unified logging output from an app you are running from Xcode, then re-output it to Terminal or Console with configurable colors, lighter metadata, and stronger visual emphasis for the lines that matter most. Longer term, this can grow into richer filtering, persistent highlights, output simplification, and other operator-friendly log shaping.

Apple's unified logging docs are the main platform anchor for this repo:

- [Logging](https://developer.apple.com/documentation/os/logging)
- [Viewing Log Messages](https://developer.apple.com/documentation/os/viewing-log-messages)
- [Logger](https://developer.apple.com/documentation/os/logger)
- [OSLog](https://developer.apple.com/documentation/OSLog)

Those docs matter here because Apple explicitly documents that unified log data can be viewed through the Console app, the `log` CLI, Xcode's debug console, and programmatically via the OSLog framework. That gives BriteLog a clear product direction: stay close to the system logging model, then improve readability and workflow on top of it instead of inventing a parallel logging system.

## Current status

- Swift package bootstrap complete
- macOS 15.0 minimum target
- Swift language mode pinned to `.v6`
- Swift Testing baseline in place
- CLI tool surface scaffolded with an initial `watch` command
- Live log capture and rendering pipeline still to be implemented

## First likely milestones

- Read unified log entries for a target process or subsystem
- Map levels, subsystems, and categories into configurable terminal colors
- Suppress or compact repetitive metadata without losing important context
- Persist user-defined highlight rules and make important lines stay visible
- Add fixture-driven tests for log formatting and filtering behavior
