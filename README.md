# Dart Stylizer

A configurable command-line tool for organizing members inside Dart classes.

## Requirements

- Dart SDK 3.3 or later

## Install dependencies

```sh
dart pub get
```

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

The default mode is a preview: it never modifies files. Use `--write` to apply
changes. `--check` is intended for CI.

## Configuration

Create `.dart_stylizer.json` in the working directory:

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
