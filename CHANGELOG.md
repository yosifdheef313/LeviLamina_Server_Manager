# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/)
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.1.1] - 2026-09-29

### Added

- **Automated CI/CD Workflow**: Added GitHub Actions workflow to automatically compile and release Windows installer binaries on published releases and main pushes.

### Changed

- **Author and Metadata**: Updated author and company metadata to `yosifdheef313` across the application, installer, and build scripts.
- **Ecosystem Links**: Renamed legacy LiteLDev references to LeviMC and updated broken links across the About page to active resources.
- **Changelog Standards**: Formatted changelog structure to adhere to the Keep a Changelog standard.

## [1.1.0] - 2026-09-28

This update focuses on making the addon store much more reliable, fixing search issues, preventing download failures, and making the download experience smoother.

### Added

- **Live MCPEDL Search**: The search bar now queries MCPEDL's live catalog directly. You can now search for any mod or addon (like guns, furniture, backpacks, shaders, or maps) and find real results right away, instead of only browsing whatever was on the first page.
- **Quick-Search Chips**: Added one-click search chips for popular addon topics (Furniture, Backpacks, Weapons, Guns, Zombies, Shaders, Vehicles, and SkyBlock).
- **New Download Progress Bar**: Replaced the small spinning wheel with a full animated progress bar. It shows you the progress percentage and download animation across all addon pages so you can see that your file is actively downloading.
- **In-Tab Catalog Sync**: Added a "Check Updates & Sync" button at the top of the MCPEDL tab so you can refresh the catalog and get the latest uploads without restarting the app.
- **Default Operator Cheats**: When creating a new server, operator permissions now have cheats enabled by default so you can use server commands right after joining.

### Fixed

- **Fixed the "HTTP 403 Forbidden" Download Error**: Some addons would fail to install with a 403 error because of outdated download links. We updated the downloader to resolve the official ForgeCDN file mirrors directly and added automatic retries if a link ever expires.
- **Fixed Download Timeouts on Large Addons**: Large addon packages (15MB to 50MB+) sometimes timed out after 15 seconds. The downloader now has a dedicated client with a 10-minute timeout so large worlds and heavy packs finish downloading reliably.
- **No More Duplicate Cards on "Load More"**: Clicking "Load More" previously repeated some cards on screen. We added item deduplication so only new addons are appended to your list.
- **Clean App Shutdown**: Addressed an issue where background processes (like the uninstaller or server helpers) could stay running in Task Manager after exiting. The manager now shuts down all related processes completely when closed.
- **RAM Percentage & Progress Bar Alignment**: Fixed how memory percentage was calculated and ensured the progress bar displays correctly from left to right in both English and Arabic views.
- **BDS Setup Checks**: Improved server setup validation so newly downloaded server archives are checked and cached properly.

## [1.0.0] - 2026-09-28

The first public release of LeviLamina Server Manager!
- Clean desktop control panel to start, stop, and restart Bedrock Dedicated Server instances with LeviLamina.
- Native `lip` package manager support to install and update LeviLamina plugins directly from the UI.
- Live server telemetry showing actual TPS, MSPT, CPU, and RAM usage.
- Drag-and-drop installer for `.mcaddon` and `.mcpack` files with automatic world configuration.
- Built-in world manager and zip backup tool.
- Windows Job Object integration to keep child server processes tied to the manager and prevent orphaned background tasks.
- Multilingual support including English and Arabic.

[Unreleased]: https://github.com/yosifdheef313/LeviLamina_Server_Manager/compare/v1.1.1...HEAD
[1.1.1]: https://github.com/yosifdheef313/LeviLamina_Server_Manager/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/yosifdheef313/LeviLamina_Server_Manager/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/yosifdheef313/LeviLamina_Server_Manager/releases/tag/v1.0.0
