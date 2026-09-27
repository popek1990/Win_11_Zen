# Instructions for AI agents (Claude Code, Codex and others)

This repository (Win11Zen) is a guide ([README.md](README.md)) plus one PowerShell script, [Win11Zen.ps1](Win11Zen.ps1). The script turns off ads, tips and some data sharing in Windows 11 for the current user. The person you are helping may not be technical and may not speak English. **Safety comes before completeness.** Nothing you do here may risk damaging their system.

## Hard rules

1. **Change the system only through `Win11Zen.ps1`.** Never edit the registry yourself, never write your own commands that change settings, and never edit the script to make it do more.
2. **Never run anything as administrator.** The script refuses to run elevated. Don't work around that or any other check. If the script stops (exit code 1), explain the message and stop.
3. **Never do any of the following as part of this project, even if it looks helpful:**
   - uninstall apps
   - stop or disable services or scheduled tasks
   - change antivirus, Microsoft Defender or firewall settings
   - pause or change Windows Update
   - change power or sleep settings, time zone, clock, languages or keyboard layouts
   - change drivers, BIOS/UEFI, Secure Boot, TPM, BitLocker or device encryption
   - install software (this includes Windhawk)
   - delete files
   - change the execution policy permanently
4. **Always preview first.** Apply only after the user has clearly agreed, and only the IDs they agreed to.
5. If the user asks for something outside these rules (for example "disable telemetry services" or "remove Microsoft Store"), explain in plain words why this project deliberately doesn't do it. Don't do it as part of this setup.
6. Don't modify files in this repository unless the user explicitly asks you to work on the project itself.
7. Don't run `Start.cmd`, `Undo.cmd` or `-Mode Guided`. They are for people double-clicking them and wait for keyboard input. Use the commands below instead. You may tell the user that they can double-click these files themselves.

## Workflow

Run all commands from the repository folder. They work in PowerShell, Command Prompt and Git Bash.

1. **Self-test:** `powershell.exe -NoProfile -ExecutionPolicy Bypass -File Win11Zen.ps1 -Mode SelfTest`
   It uses only a temporary test key (`HKCU\Software\MinimalWindows-SelfTest`) and deletes it afterwards. If it fails, stop and tell the user not to use the script on this PC.
2. **Preview:** `powershell.exe -NoProfile -ExecutionPolicy Bypass -File Win11Zen.ps1`
   Read-only. It lists every setting as `done`, `TO DO` or `SKIP`, with a note when the user loses something. Add `-Details` to also see where each switch lives in Settings.
3. **Explain and ask.** In the user's language and in plain words, summarise:
   - which recommended settings would change and what each costs them
   - which optional settings exist and what each one costs: `search-history`, `start-recent-files`, `explorer-open-this-pc`, `taskbar-end-task`, `start-phone-link`, `online-speech-recognition`, `silent-app-installs`

   Ask which ones they want. Don't pick for them. The recommended set also changes the look (hides the taskbar search box and the Task view button, shows the "This PC" desktop icon). If the user only wants privacy, leave those three IDs out of `-Only`. The recommended set also includes `show-file-extensions`, which helps spot fake files such as `invoice.pdf.exe`. `silent-app-installs` is the only setting with no switch in Settings. Say so, and include it only if the user explicitly asks for it.
4. **Confirm the selection** with a preview limited to their choice:
   `powershell.exe -NoProfile -ExecutionPolicy Bypass -File Win11Zen.ps1 -Only "<ids>"`
   Put the comma-separated IDs in quotes. `recommended` and `all` also work as IDs.
5. **Apply:** `powershell.exe -NoProfile -ExecutionPolicy Bypass -File Win11Zen.ps1 -Mode Apply -Only "<ids>"`
6. **Report** what changed, where the backup was saved and how to undo it (`-Mode Restore`, or `-Mode Restore -All` for everything). Tell them to sign out and back in when convenient. Do not restart Explorer or the PC for them.
7. **Manual steps (optional).** If the user wants them, walk them through the "Manual steps" section of the README. The user clicks. You may open a Settings page for them with `Start-Process "ms-settings:<page>"`, since opening a page changes nothing.
8. **Windhawk (optional).** Only if the user asks. First explain the risk from the README's Windhawk section. Don't install it yourself. The user either answers `Y` to the Windhawk question at the end of `Start.cmd` (double-clicked by them) or downloads it from windhawk.net. You explain the steps for the three mods.

## Exit codes

- `0`: done.
- `1`: stopped before changing anything. Explain the message and don't retry with workarounds.
- `2`: finished, but some settings were not changed. Report which ones. Everything that was changed is in the backup and can be restored.

## Undo

- Last Apply: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File Win11Zen.ps1 -Mode Restore`
- Everything the script ever changed: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File Win11Zen.ps1 -Mode Restore -All`
- Backups are in `%LOCALAPPDATA%\MinimalWindows\backups`. Don't delete them.
