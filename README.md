# Dart Stylizer

A configurable command-line tool for organizing members inside Dart classes.

## Requirements

- Dart SDK 3.13 or later

## Install dependencies

```sh
dart pub get
```

## Build a standalone executable

Build the CLI for the current operating system and architecture:

```sh
dart run tool/build_binary.dart
```

The executable is written to `build/dart_stylizer` (`build/dart_stylizer.exe`
on Windows). You can choose a different output path:

```sh
dart run tool/build_binary.dart dist/dart_stylizer
```

## Install or update a standalone executable

The installers download release assets directly over HTTPS and verify them with
`SHA256SUMS`; the repository and release assets must be public for these
unauthenticated downloads to succeed.

From a source checkout, install the latest release on Linux x64 or macOS
ARM64 with:

```sh
sh scripts/install.sh
```

The installer places `dart_stylizer` in `~/.local/bin`, verifies the download
against the release's `SHA256SUMS`, and replaces an existing installation when
rerun. Pin a specific release or choose another install directory with:

```sh
sh scripts/install.sh --version v0.2.0 --install-dir "$HOME/.local/bin"
```

On Windows x64, run the PowerShell installer:

```powershell
.\scripts\install.ps1
.\scripts\install.ps1 -Version v0.2.0
```

It installs `dart_stylizer.exe` under `%LOCALAPPDATA%\Programs\DartStylizer` by
default and verifies the checksum before replacing the existing executable.
Add your chosen install directory to `PATH` if you want to invoke the command
without its full path. The current release provides Linux x64, macOS ARM64, and
Windows x64 binaries.

## GitHub Releases

GitHub Actions runs formatting checks, analysis, and tests on pushes and pull
requests. Pushing a version tag such as `v0.2.0` also builds native executables
for Linux, Windows, and macOS, then publishes the executables, `install.sh`,
`install.ps1`, and a `SHA256SUMS` file in a GitHub Release.

## Usage

```sh
# Preview changes (prints changed files to stdout)
dart run dart_stylizer lib/**/*.dart

# Modify files in place
dart run dart_stylizer --write lib/**/*.dart

# Check formatting in CI (exit code 1 when changes are needed)
dart run dart_stylizer --check lib/**/*.dart

# Use a custom configuration
dart run dart_stylizer --config dart_stylizer.json --write lib/**/*.dart
```

The default mode is a preview: it never modifies files. Organized source is
formatted with `package:dart_style` before previewing, checking, or writing, so
`--check` detects both member-ordering and Dart formatting changes. Use `--write`
to apply the result; `--check` is intended for CI.

## Configuration

Configuration is layered in this order: built-in defaults, global config, the
nearest project `.dart_stylizer.json` in the current directory or an ancestor,
then the file supplied by `--config`. Each file overrides only the options it
contains.

The global config path is `$XDG_CONFIG_HOME/dart_stylizer/config.json`, falling
back to `$HOME/.config/dart_stylizer/config.json` on Unix-like systems. On
Windows it is `%APPDATA%\\dart_stylizer\\config.json`.

Create `.dart_stylizer.json` at your project root to share project settings:

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

`memberOrdering` accepts the groups shown above. Omit `private-other-methods`
to keep private methods in the fallback group; include it to place them in a
separate section. Public and private other methods retain their source order
unless `sortOtherMethods` is true. When `groupAndSortGetterMethods` is enabled,
getters are grouped before other methods in their method section and sorted by
name. `groupAndSortVariableTypes` sorts each variable section by declared type,
then by variable name.

## Notes

Dart Stylizer uses the Dart analyzer AST rather than regular expressions to
classify declarations. The first implementation focuses on classes and
optionally enums/mixins. It preserves declaration text by moving source
ranges, but should be tested against project-specific comment and formatting
styles before enabling `--write` across a large codebase.
