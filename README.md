# Dart Stylizer

[![CI](https://github.com/nguyenthang1597/dart_stylizer/actions/workflows/ci-release.yml/badge.svg)](https://github.com/nguyenthang1597/dart_stylizer/actions/workflows/ci-release.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

> A deterministic, AST-based command-line tool for organizing Dart class
> members without rewriting their implementation.

Dart Stylizer makes class layout consistent across a codebase. It recognizes
Dart declarations with `package:analyzer`, moves them into a configurable order,
and preserves the source text, comments, annotations, and method bodies that
make the code yours.

## Why Dart Stylizer?

- **Safe by default** — preview changes before writing them to disk.
- **AST-based** — classification is based on Dart syntax, not fragile regular
  expressions.
- **Minimal diffs** — declaration ranges are moved instead of regenerated.
- **Configurable** — customize member groups, sorting, and supported declaration
  types at project or user level.
- **CI-friendly** — `--check` returns a failing status when organization is
  needed, and `--diff` produces reviewable unified diffs.
- **Idempotent** — running the tool again on organized code produces no further
  changes.

## What it organizes

By default, Dart Stylizer organizes members inside classes using this order:

| Order | Group | Behavior |
| ---: | --- | --- |
| 1 | `public-constructor` | Unnamed public constructors first. |
| 2 | `named-constructors` | Named and factory constructors, sorted by name. |
| 3 | `public-static-variables` | Public static fields, sorted by name. |
| 4 | `public-instance-variables` | Public instance fields, sorted by name. |
| 5 | `public-override-variables` | Fields marked with `@override`. |
| 6 | `private-static-variables` | Private static fields, sorted by name. |
| 7 | `private-instance-variables` | Private instance fields, sorted by name. |
| 8 | `public-override-methods` | Methods marked with `@override`. |
| 9 | `public-other-methods` | Other public methods. |
| 10 | `private-other-methods` | Private methods, when enabled in the ordering. |
| 11 | `build-method` | A Flutter-style `build` method last. |

Non-empty groups are separated by one blank line. Methods retain their source
order by default; opt into alphabetical sorting with `sortOtherMethods`. The
same organization rules can optionally be applied to enums and mixins, and
eligible top-level classes can optionally be sorted within a file.

## Requirements

- Dart SDK 3.13 or later
- A Dart project containing the source files to organize

## Installation

### Run from source

Clone the repository, install dependencies, and invoke the CLI through Dart:

```sh
git clone https://github.com/nguyenthang1597/dart_stylizer.git
cd dart_stylizer
dart pub get
dart run dart_stylizer --help
```

### Build a standalone executable

Build a native executable for the current operating system and architecture:

```sh
dart run tool/build_binary.dart
```

The output is written to `build/dart_stylizer` (or
`build/dart_stylizer.exe` on Windows). Supply a path to choose another output
location:

```sh
dart run tool/build_binary.dart dist/dart_stylizer
```

### Install a release executable

The repository publishes checksum-verified executables for Linux x64, macOS
ARM64, and Windows x64. The installers download release assets over HTTPS and
verify each asset with `SHA256SUMS` before replacing an existing installation.

On Linux x64 or macOS ARM64:

```sh
sh scripts/install.sh
```

The Unix installer defaults to `~/.local/bin`. Pin a release or choose another
directory with:

```sh
sh scripts/install.sh --version v0.3.0 --install-dir "$HOME/.local/bin"
```

On Windows x64, run PowerShell:

```powershell
.\scripts\install.ps1
.\scripts\install.ps1 -Version v0.3.0
```

The Windows installer defaults to
`%LOCALAPPDATA%\Programs\DartStylizer`. Add the selected installation
directory to `PATH` to invoke `dart_stylizer` from any shell. See the
[releases](https://github.com/nguyenthang1597/dart_stylizer/releases) page for
available versions and assets.

## Quick start

Input arguments may be individual files or glob patterns. Only files with the
`.dart` extension are processed.

```sh
# Preview transformed files; do not modify the working tree
dart run dart_stylizer 'lib/**/*.dart'

# Preview only the changes as unified diffs
dart run dart_stylizer --diff 'lib/**/*.dart'

# Apply organization in place
dart run dart_stylizer --write 'lib/**/*.dart'

# Fail in CI when any file needs organization
dart run dart_stylizer --check 'lib/**/*.dart'

# Organize, then apply package:dart_style to the complete file
dart run dart_stylizer --format --write 'lib/**/*.dart'

# Use an explicit JSON configuration file
dart run dart_stylizer --config dart_stylizer.json --write 'lib/**/*.dart'
```

Quoting glob patterns prevents the shell from expanding them before Dart
Stylizer receives them. The default preview mode prints changed files and never
writes to disk.

## Command reference

```text
Usage: dart run dart_stylizer [options] <file-or-glob>...
```

| Option | Description |
| --- | --- |
| `-c, --config <path>` | Load an explicit JSON configuration file. |
| `-w, --write` | Write organized source back to the matched files. |
| `--check` | Exit with status `1` when any file would change. Never writes files. |
| `--format` | Run `package:dart_style` on each organized file as a second step. |
| `--diff` | Print unified diffs instead of full preview output or check summaries. |
| `-h, --help` | Show command usage. |

`--write` and `--check` are mutually exclusive. `--diff` is available in
preview and check modes, but cannot be combined with `--write`.

### Exit statuses

| Status | Meaning |
| ---: | --- |
| `0` | Success; no changes were needed, or changes were previewed/written. |
| `1` | A check found files that would change, or no Dart files matched. |
| `2` | Invalid arguments, configuration, input paths, or source parsing failed. |

A parsing or processing failure leaves the affected original file unchanged.

## Configuration

Configuration is layered from least specific to most specific:

1. Built-in defaults
2. Global configuration
3. The nearest project `.dart_stylizer.json` in the current directory or an
   ancestor
4. The file supplied with `--config`

Each layer overrides only the properties it contains. The global configuration
is read from `$XDG_CONFIG_HOME/dart_stylizer/config.json`, falling back to
`$HOME/.config/dart_stylizer/config.json` on Unix-like systems. On Windows, the
path is `%APPDATA%\\dart_stylizer\\config.json`.

Create `.dart_stylizer.json` at the root of a project to share its conventions:

```json
{
  "groupAndSortGetterMethods": false,
  "groupAndSortVariableTypes": false,
  "memberOrdering": [
    "public-constructor",
    "named-constructors",
    "public-static-variables",
    "public-instance-variables",
    "public-override-variables",
    "private-static-variables",
    "private-instance-variables",
    "public-override-methods",
    "public-other-methods",
    "private-other-methods",
    "build-method"
  ],
  "processEnumsLikeClasses": false,
  "sortClassesWithinFile": false,
  "sortOtherMethods": false
}
```

### Options

| Option | Default | Description |
| --- | :---: | --- |
| `groupAndSortGetterMethods` | `false` | Put getters before other methods in their method group and sort them by name. |
| `groupAndSortVariableTypes` | `false` | Group and sort variable declarations by declared type, then by name. |
| `memberOrdering` | See [default order](#what-it-organizes) | Choose and arrange supported member groups. |
| `processEnumsLikeClasses` | `false` | Apply compatible member organization to enums and mixins. Enum constants remain in place. |
| `sortClassesWithinFile` | `false` | Sort eligible top-level class, enum, and mixin declarations alphabetically by name. |
| `sortOtherMethods` | `false` | Sort ordinary methods alphabetically instead of preserving source order. |

`memberOrdering` accepts only the documented group names and cannot contain
duplicates. Omitting `private-other-methods` places private methods in the
public-method fallback group. Configuration errors are reported rather than
silently ignored.

The complete example is also available in
[`dart_stylizer.example.json`](dart_stylizer.example.json).

## Source preservation

Dart Stylizer is a source organizer, not a source generator. It uses the Dart
analyzer AST to identify declarations and moves their original source ranges.
It does not reconstruct method bodies or rewrite unrelated parts of a file.

The organizer is designed to preserve:

- Method bodies, constructor initializer lists, and string literals
- Documentation comments, inline comments, and metadata annotations
- Imports, directives, class modifiers, generic parameters, and declaration
  modifiers
- Existing line endings and formatting inside declarations

Use `--format` only when you intentionally want the entire transformed file
formatted with `package:dart_style`. For a large codebase, preview changes and
review representative files before using `--write` broadly.

## CI and release workflow

The GitHub Actions workflow runs formatting checks, static analysis, and tests
on pushes and pull requests. Pushing a version tag such as `v0.3.0` builds
native executables for Linux, Windows, and macOS, then publishes them with the
install scripts, `LICENSE`, and `SHA256SUMS` in a GitHub Release.

A typical CI check is:

```sh
dart pub get
dart run dart_stylizer --check 'lib/**/*.dart'
```

## Development

Install dependencies and run the project's quality checks locally:

```sh
dart pub get
dart format .
dart analyze
dart test
```

See [`CHANGELOG.md`](CHANGELOG.md) for release history and
[`Agents.md`](Agents.md) for project development guidelines.

## License

Dart Stylizer is available under the [MIT License](LICENSE).
