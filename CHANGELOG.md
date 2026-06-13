# Changelog

## 1.6.1+12 - 2026-06-13

- Fix local script runs on macOS so commands installed in common Homebrew and Docker Desktop paths can be found when ScriptVault is launched as an app.
- Preserve secret environment variables while adding `/opt/homebrew/bin` and `/usr/local/bin` to the local script execution `PATH`.

## 1.6.0+11 - 2026-06-13

- Add ScriptVault export and import for moving scripts, hosts, and encrypted secrets between devices.
- Export vault data to a `.scriptvault` archive from Settings and import compatible archives into another ScriptVault installation.
- Merge imported data safely by preserving existing vault contents, remapping colliding script and host IDs, and keeping encrypted secrets protected.

## 1.5.0+10 - 2026-06-10

- Add optional auto-save for script edits, disabled by default and configurable from Settings.
- Auto-save existing scripts and new script drafts after a short editing pause.
- Track editor save state explicitly with Unsaved, Saving, Saved, and Save failed statuses.

## 1.4.0+9 - 2026-06-10

- Add encrypted Secrets management with setup, password unlock, restore-key unlock, CRUD, and per-field reveal.
- Inject unlocked secrets into local and remote script runs as environment variables without writing secret values into script files.
- Add a Secrets workspace tab and show available secret environment variable names in the script editor run panel.

## 1.3.0+8 - 2026-06-09

- Redesign the app with a unified dark ScriptVault visual system across scripts and hosts.
- Refresh the script editor workspace with a redesigned sidebar, inspector, editor frame, and output area.
- Simplify run output display so successful diagnostic logs are shown as plain output instead of terminal chrome.

## 1.2.0+6 - 2026-06-08

- Add script import from existing local script files.
- Add custom vault storage folder selection with copy-before-switch behavior.

## 1.0.1+2 - 2026-06-02

- Initial release.
