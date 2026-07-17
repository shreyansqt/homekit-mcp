# Apps

This directory contains the macOS-facing pieces of HomeKit MCP.

- [`helper-catalyst`](helper-catalyst) — Mac Catalyst app that owns Apple Home / HomeKit permission and exposes the localhost helper API.
- [`menubar`](menubar) — native AppKit `LSUIElement` menu-bar wrapper that talks to the helper over localhost.

Each app has an XcodeGen `project.yml`. Treat those YAML files as the source of truth and regenerate the checked-in Xcode projects with `xcodegen generate` from the app directory after project-structure changes.
