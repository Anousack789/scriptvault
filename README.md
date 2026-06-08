# ScriptVault

ScriptVault is a Flutter macOS app for keeping shell scripts in one searchable
library, editing them with Bash syntax highlighting, and running them from the
app. It is developed with Flutter `3.44.1`.

## Features

- Create, edit, delete, and run shell scripts.
- Import existing local script files into the ScriptVault library.
- Organize scripts by group and tags.
- Search across script names, groups, tags, and script content.
- Collapse script groups in the sidebar.
- Pass command-line arguments before running a script.
- View stdout, stderr, exit code, and runtime details after execution.
- Choose a custom vault storage folder for scripts, hosts, and app settings.
- Adjust editor font size.
- Enable an optional password-based app lock.
- Prompt before running scripts that include higher-risk commands such as
  `sudo`, `rm`, `mv`, `chmod`, `chown`, `curl`, or `wget`.

## Project Structure

- `lib/data/`: repositories and services for persistence, settings, password
  hashing, and script execution.
- `lib/domain/`: script and settings domain models.
- `lib/router/`: GoRouter route definitions and providers.
- `lib/ui/`: screens, view models, and widgets.
- `macos/`: native macOS runner and entitlements.
- `test/`: unit and widget tests.

## Requirements

- macOS
- FVM
- Flutter `3.44.1` managed by FVM
- Dart `^3.11.5`

## Setup

Install dependencies:

```sh
fvm use 3.44.1
fvm flutter pub get
```

Run the macOS app:

```sh
fvm flutter run -d macos
```

## Development Commands

Run tests:

```sh
fvm flutter test
```

Run static analysis:

```sh
fvm flutter analyze
```

Format Dart source and tests:

```sh
fvm dart format lib test
```

Build a macOS release:

```sh
fvm flutter build macos
```

## Storage

By default, ScriptVault stores app data under the platform application support
directory in a `scriptvault` folder. Users can choose a custom vault storage
folder from Settings. When the storage folder changes, ScriptVault copies the
current vault data into the selected empty folder before switching.

The vault maintains:

- `script_index.json`: metadata for saved scripts.
- `host_index.json`: saved remote host definitions.
- `app_settings.json`: editor settings, collapsed groups, and optional app lock
  password hash data.
- `scripts/`: the saved `.sh` files.

Imported scripts are copied into the managed `scripts/` folder and become normal
ScriptVault scripts. Editing an imported script does not modify the original
source file.

On macOS, the storage service can migrate data from the older sandbox container
path used by `com.nonostack.scriptvault` when the current app support location
is empty.

## Security Notes

Script execution is intentionally powerful. Scripts run through `/bin/bash` with
the scripts directory as the working directory, and the app passes any arguments
entered in the editor. Treat saved scripts like executable code.

The app lock is a local convenience lock, not full disk encryption. Do not rely
on it as the only protection for sensitive scripts or secrets.

Be careful when changing `ScriptRunService`, macOS entitlements, storage paths,
or app lock behavior. Re-enabling App Sandbox would require redesigning script
execution around explicit permissions or a helper process.
