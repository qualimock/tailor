# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Fixes:

- Use single FD for both writing and verifying. Some software could mount device between writing and verifying. Using single FD for both operations fixes it
- Retry any connection issue, not only stalled
- Bundle icons to application

## [1.1.1] - 2026-09-16

### New - primary OS translations:

Now Tailor detects OS id in 'primary-os' field and put translatable primary OS title on DownloadPage.
If id is not found, Tailor uses fallback 'OS images'.

### Fixes:

- Flashing an OS detected from a local ISO file now writes that file directly
- Fixed device staying "busy" after cancelling a flash

## [1.1.0] - 2026-09-15

### New - OS detection!

Now Tailor can detect an operating system in your .iso file.

Click 'Install from File' and select an image - if Tailor knows that OS, it will
navigate you to OsPage to display OS information.

Then create downloadable USB as before.

### Changes:

- Tailor can now be translated conveniently! You can see translation progress in Weblate
- Tailor got Nightly release
- Set default window size to 600x680
- New branding scheme in metainfo
- Updated screenshots

### Fixes:

- Unknown versions are no longer displayed, e.g. for rolling-release distros like Arch
- OSes with single edition like GNU Guix does not display that single edition
- FlashPage title is now build from non-empty parts

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

[Unreleased]: https://altlinux.space/qualimock/Tailor/compare/v1.1.1...HEAD
[1.1.1]: https://altlinux.space/qualimock/Tailor/compare/v1.1.0...v1.1.1
[1.1.0]: https://altlinux.space/qualimock/Tailor/compare/v1.0.0...v1.1.0
[1.0.0]: https://altlinux.space/qualimock/Tailor/compare/v0.1.1...v1.0.0
[0.1.1]: https://altlinux.space/qualimock/Tailor/compare/v0.1.0...v0.1.1
[0.1.0]: https://altlinux.space/qualimock/Tailor/releases/tag/v0.1.0
