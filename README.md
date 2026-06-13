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
- Enable optional auto-save so script edits are saved after a short pause,
  including new script drafts.
- Pass command-line arguments before running a script.
- Save encrypted secrets such as database passwords or deployment keys.
- Inject unlocked secrets into script runs as environment variables without
  writing secret values into the script editor.
- View stdout, stderr, exit code, and runtime details after execution.
- Choose a custom vault storage folder for scripts, hosts, and app settings.
- Export scripts, hosts, and encrypted secrets to a `.scriptvault` archive for
  moving data to another device.
- Import `.scriptvault` archives into another ScriptVault installation while
  preserving existing vault contents.
- Adjust editor font size.
- Enable an optional password-based app lock.
- Prompt before running scripts that include higher-risk commands such as
  `sudo`, `rm`, `mv`, `chmod`, `chown`, `curl`, or `wget`.

## Project Structure

- `lib/data/`: repositories and services for persistence, settings, password
  hashing, and script execution.
- `lib/domain/`: script, host, secret, and settings domain models.
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
- `secret_index.json`: encrypted secret values and secret vault key metadata.
- `app_settings.json`: editor settings, auto-save preference, collapsed groups,
  and optional app lock password hash data.
- `scripts/`: the saved `.sh` files.

Imported scripts are copied into the managed `scripts/` folder and become normal
ScriptVault scripts. Editing an imported script does not modify the original
source file.

Vault exports are created from Settings as `.scriptvault` archives. The archive
contains script metadata, host definitions, encrypted secret vault data, and the
managed script files. Importing an archive merges scripts and hosts into the
current vault, preserving existing data and remapping colliding IDs or filenames
when needed.

Secrets are stored in the vault as encrypted values. Scripts refer to secrets by
environment variable name, such as `$DB_PASSWORD`. When the secret vault is
unlocked, ScriptVault injects those values into local script processes and remote
SSH script runs at execution time.

Exported secrets remain encrypted. A destination vault can import and unlock
them when it has the same secret vault key material, such as an import into a new
vault or a vault previously copied from the same source. ScriptVault rejects
secret merges from incompatible encrypted vaults instead of importing values that
cannot be decrypted.

On macOS, the storage service can migrate data from the older sandbox container
path used by `com.nonostack.scriptvault` when the current app support location
is empty.

## Security Notes

Script execution is intentionally powerful. Scripts run through `/bin/bash` with
the scripts directory as the working directory, and the app passes any arguments
entered in the editor. Treat saved scripts like executable code.

The app lock is a local convenience lock, not full disk encryption. Do not rely
on it as the only protection for sensitive scripts or secrets.

Secret values are encrypted at rest and can be unlocked with the configured
password or restore key. Once unlocked, secrets are available to running scripts
as environment variables, so treat script execution output, child processes, and
remote hosts as sensitive.

Be careful when changing `ScriptRunService`, macOS entitlements, storage paths,
secret encryption, or app lock behavior. Re-enabling App Sandbox would require
redesigning script execution around explicit permissions or a helper process.
