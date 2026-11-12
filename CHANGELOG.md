# Changelog

All notable changes to Dart Stylizer are documented here.

## [0.2.0] - 2026-11-12

### Added

- Support parsing, organizing, and formatting Dart 3.14 language-version source,
  including modern primary-constructor declarations.

### Changed

- Upgrade `analyzer` to 14.7.0 and `dart_style` to 3.1.14.
- Require Dart SDK 3.13 or later (previously 3.5 or later).

### Fixed

- Update organizer AST access for the analyzer's declaration body and name APIs.

## [0.1.0] - 2026-11-12

### Added

- Initial release of the Dart Stylizer CLI, with preview, check, and write modes.
- Configurable class member ordering, global/project configuration, and optional
  enum/mixin processing.
- Standalone executable builds and GitHub release artifacts for Linux, macOS,
  and Windows.

[0.2.0]: https://github.com/nguyenthang1597/dart_stylizer/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/nguyenthang1597/dart_stylizer/releases/tag/v0.1.0
