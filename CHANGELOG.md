# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Fixed

- Unknown versions are no longer displayed, e.g. for rolling-release distros like Arch

## [1.0.0] - 2026-09-07

### Fixed

- Dismissed restoration polkit dialog now sets 'Restoring...' to 'Restore' back
- Flashing status now is not being overwritten while paused
- Correct screenshots links in appstream file

### Changed

#### Large USB management refactor

Now USB provider is connected to service as interface, allowing multiple provider implementations.

#### Windows backend

Now Tailor works on Windows!

Look for installer in release assets.

## [0.1.1] - 2026-08-28

### Changed
- OS images are now cached instead of being downloaded directly into the user's downloads directory
- Flatpak: removed the `xdg-download` permission, no longer needed after switching to caching
- UI: clamped and centered the OS page contents

## [0.1.0] - 2026-08-27

First release of Tailor!

[Unreleased]: https://altlinux.space/qualimock/Tailor/compare/v1.0.0...HEAD
[1.0.0]: https://altlinux.space/qualimock/Tailor/compare/v0.1.1...v1.0.0
[0.1.1]: https://altlinux.space/qualimock/Tailor/compare/v0.1.0...v0.1.1
[0.1.0]: https://altlinux.space/qualimock/Tailor/releases/tag/v0.1.0
