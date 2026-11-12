# AGENTS.md

# Dart Stylizer — Agent Development Guidelines

## 1. Project Overview

**Dart Stylizer** is a Dart command-line tool that organizes class members within Dart (`*.dart`) files according to a configurable ordering strategy.

The primary goal is to make Dart source code consistent, predictable, and easier to read by automatically organizing constructors, variables, and methods.

The tool must preserve the original behavior of the source code. It should only reorganize declarations, never modify their implementation or semantics.

### Core Principles

- Use Dart AST parsing instead of regular expressions for source analysis.
- Preserve source code semantics.
- Preserve comments, annotations, and documentation.
- Apply deterministic ordering.
- Make behavior configurable.
- Avoid unnecessary formatting changes.
- Support modern Dart language syntax.
- Provide predictable CLI behavior.

---

## 2. Technology Stack

- Language: Dart
- Minimum SDK: Dart 3.3
- AST parsing: `package:analyzer`
- CLI argument parsing: `package:args`
- File matching: `package:glob`
- Path manipulation: `package:path`
- Testing: `package:test`

Use existing dependencies whenever possible. Avoid introducing additional dependencies unless they provide clear value.

---

## 3. Project Structure

Expected project structure:

```text
dart_stylizer/
├── bin/
│   └── dart_stylizer.dart
├── lib/
│   ├── dart_stylizer.dart
│   └── src/
│       ├── cli.dart
│       ├── config.dart
│       ├── organizer.dart
│       ├── parser/
│       ├── sorter/
│       └── formatter/
├── test/
│   ├── config_test.dart
│   ├── organizer_test.dart
│   └── fixtures/
├── pubspec.yaml
├── analysis_options.yaml
├── dart_stylizer.example.json
├── README.md
└── AGENTS.md
```

The structure may evolve as the project grows.

Keep responsibilities separated:

- `cli.dart`: CLI argument handling and execution.
- `config.dart`: Configuration models, defaults, validation, and loading.
- `organizer.dart`: Main orchestration of member organization.
- `parser/`: Dart AST inspection and declaration classification.
- `sorter/`: Sorting and grouping algorithms.
- `formatter/`: Source reconstruction and whitespace management.

Do not put all implementation logic into a single file.

---

## 4. Member Ordering Rules

The default member ordering is:

1. `public-constructor`
2. `named-constructors`
3. `public-static-variables`
4. `public-instance-variables`
5. `public-override-variables`
6. `private-static-variables`
7. `private-instance-variables`
8. `public-override-methods`
9. `public-other-methods`
10. `private-other-methods`
11. `build-method`

Each non-empty group must be separated by exactly one blank line.

Empty groups must not produce extra blank lines.

### 4.1 Main Constructor

- The unnamed public constructor must appear first.
- If no unnamed constructor exists, this group must be omitted.
- Preserve the constructor implementation and initializer list.
- Do not confuse named constructors with the main constructor.

### 4.2 Named Constructors

- Place named constructors after the main constructor.
- Sort named constructors alphabetically by constructor name.
- Keep their annotations and documentation comments attached.

### 4.3 Public Static Variables

- Include static class fields that are not private.
- Sort alphabetically by variable name.
- Preserve `static`, `final`, `const`, `late`, and type declarations.

### 4.4 Public Instance Variables

- Include non-static, non-private fields.
- Sort alphabetically by variable name.
- Preserve declaration modifiers and initialization expressions.

### 4.5 Public Override Variables

- Identify fields annotated with `@override`.
- Place them in their own group.
- Sort alphabetically by variable name.

### 4.6 Private Static Variables

- Include static fields whose names begin with `_`.
- Sort alphabetically.

### 4.7 Private Instance Variables

- Include non-static fields whose names begin with `_`.
- Sort alphabetically.

### 4.8 Public Override Methods

- Identify methods annotated with `@override`.
- Sort alphabetically by method name.
- Keep getters and setters correctly classified.

### 4.9 Public Other Methods

- Include public methods that are not constructors, override methods, or the `build` method.
- Preserve their original order by default.
- Sort alphabetically only when `sortOtherMethods` is enabled.

### 4.10 Private Other Methods

- Include private methods whose names begin with `_`.
- This group is optional in `memberOrdering`.
- When configured, private methods must be grouped separately from public methods.
- Preserve their original order unless the applicable sorting configuration says otherwise.

### 4.11 Build Method

- The `build` method must always be the final method group when present.
- It must not be classified as an ordinary method.
- Do not treat unrelated methods with similar names as build methods.

---

## 5. Configuration

The default configuration is:

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

### Configuration Requirements

- All boolean options must default to `false`.
- `memberOrdering` must default to the documented ordering.
- Reject unknown member group names.
- Reject duplicate member group names.
- Reject invalid JSON.
- Provide meaningful error messages.
- Never silently ignore invalid configuration.
- Allow users to omit optional groups.

### Configuration Options

#### `groupAndSortGetterMethods`

Controls grouping and alphabetical sorting of getter methods.

#### `groupAndSortVariableTypes`

Controls grouping and sorting of variable declarations by their types.

#### `memberOrdering`

Defines the order of supported member groups.

#### `processEnumsLikeClasses`

When enabled, apply compatible organization rules to enum declarations.

#### `sortClassesWithinFile`

When enabled, sort eligible top-level class declarations alphabetically by class name.

#### `sortOtherMethods`

When enabled, sort ordinary methods alphabetically instead of preserving their original order.

---

## 6. AST Processing Requirements

Use `package:analyzer` for Dart source analysis.

Never use regular expressions as the primary mechanism for identifying Dart declarations.

The implementation must correctly recognize:

- Class declarations.
- Enum declarations.
- Mixin declarations.
- Constructors.
- Named constructors.
- Factory constructors.
- Static fields.
- Instance fields.
- Getters.
- Setters.
- Methods.
- Override annotations.
- Documentation comments.
- Metadata annotations.

### Important AST Considerations

- Annotations must remain attached to their declarations.
- Documentation comments must remain attached to their declarations.
- Multiple variables in one field declaration must be handled safely.
- Factory constructors must be classified correctly.
- Generic declarations must remain unchanged.
- Async and generator methods must remain unchanged.
- Extension methods must not accidentally be treated as class members.
- Unrecognized declarations must not be discarded.

When a declaration cannot be confidently classified, preserve it safely rather than making an unsafe transformation.

---

## 7. Source Preservation

Source preservation is one of the most important requirements.

Dart Stylizer must not change the semantics of user code.

### Mandatory Rules

- Preserve method bodies exactly.
- Preserve constructor initializer lists.
- Preserve annotations.
- Preserve documentation comments.
- Preserve inline comments.
- Preserve string literals.
- Preserve multiline strings.
- Preserve imports and directives.
- Preserve class modifiers.
- Preserve generic type parameters.
- Preserve declaration modifiers.
- Preserve line endings where practical.

Do not reconstruct declarations by manually generating Dart syntax from AST properties.

Prefer moving original source ranges.

Use AST offsets carefully, including leading comments and metadata.

### Formatting

- Separate non-empty member groups with one blank line.
- Avoid excessive blank lines.
- Do not modify formatting inside method bodies.
- Do not reformat unrelated code.
- Preserve the original file's newline convention where possible.

---

## 8. CLI Requirements

The CLI executable is:

```bash
dart run dart_stylizer
```

Supported commands/options:

### Preview

```bash
dart run dart_stylizer lib/**/*.dart
```

Print organized source without modifying the original files.

### Write

```bash
dart run dart_stylizer --write lib/**/*.dart
```

Apply changes directly to files.

### Check

```bash
dart run dart_stylizer --check lib/**/*.dart
```

Return a non-zero exit code if any file requires organization.

### Custom Configuration

```bash
dart run dart_stylizer --config custom_config.json --write lib/**/*.dart
```

### Help

```bash
dart run dart_stylizer --help
```

### CLI Safety

- Preview must never modify files.
- Check must never modify files.
- Write must only modify matched Dart files.
- Do not process non-Dart files.
- Report parsing and filesystem errors clearly.
- Avoid partially writing files when processing fails.
- Use safe file-writing strategies where practical.

---

## 9. Error Handling

Errors should be explicit and actionable.

Handle:

- Invalid JSON configuration.
- Unknown configuration options.
- Invalid member ordering.
- Missing input paths.
- Unmatched glob patterns.
- File read failures.
- File write failures.
- Dart parsing errors.
- Unsupported syntax.
- Invalid CLI arguments.

Never silently corrupt or discard source code.

When parsing fails or a transformation cannot be performed safely, leave the original file unchanged.

---

## 10. Testing Requirements

Every new feature must include tests.

Use `package:test`.

### Configuration Tests

Test:

- Default configuration.
- Custom configuration.
- Missing optional properties.
- Invalid JSON.
- Invalid boolean values.
- Unknown member groups.
- Duplicate member groups.
- Custom member ordering.

### Organizer Tests

Test:

- Main constructor ordering.
- Factory constructor ordering.
- Named constructor sorting.
- Public static variable sorting.
- Public instance variable sorting.
- Override variable grouping.
- Private static variable sorting.
- Private instance variable sorting.
- Override method sorting.
- Ordinary method ordering.
- Private method ordering.
- Build method placement.
- Blank line separation.

### Source Preservation Tests

Test:

- Documentation comments.
- Inline comments.
- Metadata annotations.
- Multiple field declarations.
- Multiline constructors.
- Initializer lists.
- Generic classes.
- Async methods.
- Getters and setters.
- Multiline strings.
- Nested classes.
- Enums and mixins.

### Idempotency

A fundamental requirement:

Running Dart Stylizer twice on an already organized file must produce exactly the same output.

```dart
final first = organizer.organize(source);
final second = organizer.organize(first);

expect(second, equals(first));
```

---

## 11. Code Quality

Follow Dart and Effective Dart conventions.

- Use sound null safety.
- Prefer immutable models.
- Use `const` constructors where appropriate.
- Keep methods focused.
- Avoid unnecessary abstractions.
- Use descriptive names.
- Document public APIs.
- Avoid duplicated classification logic.
- Keep dependencies minimal.
- Do not suppress analyzer warnings without justification.

Run these commands before considering a change complete:

```bash
dart format .
dart analyze
dart test
```

All three should pass.

---

## 12. Development Workflow

When implementing a new feature:

1. Understand the existing architecture.
2. Inspect relevant configuration and AST models.
3. Define expected behavior.
4. Implement the smallest maintainable change.
5. Add unit tests.
6. Add regression tests for edge cases.
7. Run formatting.
8. Run static analysis.
9. Run the full test suite.
10. Update README documentation when necessary.

Do not introduce unrelated changes while implementing a feature.

Do not change existing behavior without updating the relevant tests and documentation.

---

## 13. Versioning and Compatibility

- Follow semantic versioning.
- Avoid breaking configuration changes without an explicit migration strategy.
- Keep configuration backward compatible where practical.
- Document newly introduced options.
- Add regression tests for previously supported behavior.

---

## 14. Definition of Done

A feature is considered complete only when:

- Its behavior matches the requirements.
- It uses AST-based analysis where appropriate.
- Existing source semantics are preserved.
- Comments and annotations remain attached.
- Tests cover normal and edge cases.
- The output is deterministic.
- The transformation is idempotent.
- `dart format .` passes.
- `dart analyze` passes.
- `dart test` passes.
- Relevant documentation is updated.

---

## 15. Final Guiding Principle

**Dart Stylizer is a source-code organizer, not a source-code generator or formatter.**

Its responsibility is to move existing Dart declarations into their correct positions while preserving everything else.

When choosing between an aggressive transformation and preserving potentially unrecognized source code, always prioritize source safety.

Correctness and source preservation are more important than aggressive organization.
