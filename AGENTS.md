# Repository Guidelines

## Project Structure & Module Organization

This is a Flutter macOS app for saving, editing, and running shell scripts. Application code lives in `lib/`, grouped by responsibility:

- `lib/data/`: repositories and services for storage and script execution.
- `lib/domain/`: script models and run result types.
- `lib/ui/`: Flutter screens, view models, and widgets.
- `lib/router/`: route definitions and providers.
- `macos/`: native macOS runner, signing entitlements, and Xcode config.
- `test/`: Flutter unit/widget tests.

Generated output stays in `build/` and should not be edited directly.

## Build, Test, and Development Commands

- `fvm flutter pub get`: install Dart and Flutter dependencies.
- `fvm flutter run -d macos`: run the macOS app locally.
- `fvm flutter test`: run all tests in `test/`.
- `fvm flutter analyze`: run static analysis using `flutter_lints`.
- `fvm dart format lib test`: format Dart source and tests.
- `fvm flutter build macos`: create a macOS release build.

Use FVM by default for all Flutter and Dart commands. The project requires Dart SDK `^3.11.5`; configure FVM with a Flutter SDK that includes a compatible Dart version.

## Coding Style & Naming Conventions

Use standard Dart formatting with two-space indentation. Keep files focused by layer: storage logic in services, orchestration in repositories, and UI state in view models. Name files with `snake_case.dart`, classes with `PascalCase`, and members with `camelCase`.

Prefer clear async APIs returning domain objects, as in `ScriptRepository` and `ScriptStorageService`. Keep comments brief.

## Testing Guidelines

Tests use `flutter_test`. Place tests in `test/` and name files with the `_test.dart` suffix, such as `script_repository_test.dart`. Use descriptive `test()` names.

For service and repository changes, cover create, update, delete, search, and script execution behavior where relevant. Run `fvm flutter test` and `fvm flutter analyze` before opening a pull request.

## Commit & Pull Request Guidelines

This checkout does not include Git history, so no project-specific commit convention is available. Use short imperative commit messages, for example `Fix script storage migration` or `Add repository search tests`.

Pull requests should include a concise summary, commands run, and user-visible behavior changes. For UI changes, include screenshots or a short recording. For macOS entitlement or storage changes, call out migration and permission implications.

## Security & Configuration Tips

Script execution is intentionally powerful. Be careful when changing `ScriptRunService`, macOS entitlements, or storage paths. Avoid re-enabling App Sandbox unless script execution is redesigned around a helper or explicit file/executable access.
