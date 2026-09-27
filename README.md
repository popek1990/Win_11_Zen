# Win11Zen: safe Windows 11 debloat, privacy tweaks and a dock-style taskbar

**Debloat Windows 11 without breaking it.** Win11Zen turns off ads, tips, "suggestions" and personalisation tracking, cleans up the taskbar and Start menu, and can give you a clean, dock-style taskbar with Windhawk. No app removal, no admin rights, a backup before every change, and one-click undo.

<img width="1911" height="971" alt="image" src="https://github.com/user-attachments/assets/029a423c-a1ff-4206-a682-8b27f2e340e1" />


**Quick start:** click **Code > Download ZIP**, extract it, double-click **`Start.cmd`**, and type `Y`. To undo, double-click **`Undo.cmd`**.

Works the same on **Windows 11 Home and Pro**, in any display language and in any country.

The project has three parts:

- **`Win11Zen.ps1`**: a small script that flips privacy, declutter and look switches for your user account (for example, it hides the taskbar search box and puts the real "This PC" icon on the desktop). It makes a backup first and can undo everything.
- **Windhawk (optional)**: a dock-style taskbar and a restyled Start menu. `Start.cmd` can install it for you after asking; you then pick the look in Windhawk with a few clicks.
- **Manual steps**: a few more things worth doing by hand in Settings, such as pinning your favourite apps.

The easiest way is to [double-click `Start.cmd`](#the-easy-way-double-click-startcmd). You can also let an AI agent (Claude Code or Codex) walk you through it, or type the commands yourself.

## Safety first

**What the script does**

- It changes only **your own user account's settings**, and only switches you can also find yourself in **Settings** or **File Explorer options**. There is [one clearly marked, optional exception](#the-one-exception-silent-app-installs). The [full list is below](#what-the-script-changes).
- It runs **without administrator rights** and refuses to run as administrator. It therefore cannot change Windows itself, other accounts, or anything outside your user settings.
- It **saves the old values before changing anything**. `-Mode Restore` puts them back exactly as they were.
- `Preview` (the default) only reads your settings and changes nothing.
- A built-in `SelfTest` runs the whole Apply/Restore cycle on a temporary test key, checks the result and deletes the key. Your real settings are not used.
- **It installs nothing on its own.** Only `Start.cmd`, as its very last step, offers to install Windhawk, and only after you type `Y`. It uses winget, Windows' official package manager, which checks the installer's checksum.

**What this project never does**, neither the script nor the guide:

- turn off or change your antivirus, Microsoft Defender or the firewall
- disable services or scheduled tasks, edit system files or remove drivers
- pause or block Windows Update
- change power, sleep or battery settings
- change your time zone, clock, languages or keyboard layouts
- uninstall apps, including Microsoft Store and Edge WebView2
- touch BitLocker or device encryption, Secure Boot, TPM or BIOS/UEFI
- use Group Policy (Home doesn't have it), so Home and Pro behave the same

**Honest limits**

- This is **not "zero telemetry"**. Windows still sends the required diagnostic data. Only the Enterprise and Education editions can go lower, and this project doesn't pretend otherwise.
- Settings has no switch that removes **web results from Start search** on home PCs. This project doesn't use unsupported hacks for it.
- Big Windows updates sometimes switch suggestions back on. Run the preview again after an update ([details below](#after-big-windows-updates)).
- Windhawk is third-party software. It's optional and covered in [its own section](#optional-windhawk-dock-style-taskbar-and-restyled-start).

## Does it work on my PC?

| Your PC | Supported? |
|---|---|
| Windows 11 Home or Pro, personal computer | Yes |
| Windows 11 in S mode | Only the manual steps. S mode blocks PowerShell scripts. |
| Work or school computer (company domain or Microsoft Entra ID) | No. The script stops. Ask your IT department. |
| Windows 10 | No |

To check your version, press `Win+R`, type `winver` and press Enter.

## The easy way: double-click `Start.cmd`

1. Download this repository: green **Code** button, then **Download ZIP**, then extract it.
2. Double-click **`Start.cmd`**. If Windows warns you that the file came from the internet, choose **Run** (or **More info**, then **Run anyway**). Don't use "Run as administrator"; the script refuses to run elevated.
3. The script tests itself on a temporary test key and shows the list of what will change. Then it asks you **once**: type `Y` and press Enter to apply. Anything else cancels, and then nothing is changed.
4. At the end it asks whether to install **Windhawk** for the dock-style taskbar. Type `Y` to install it (Windows asks for administrator approval for the installer), or anything else to skip. If you install it, Windhawk opens and the script shows which three mods to click ([details](#optional-windhawk-dock-style-taskbar-and-restyled-start)).
5. Read the summary, then sign out and back in so every change shows up.

To undo everything later, double-click **`Undo.cmd`** and answer `Y`. Windhawk, if you installed it, is removed separately in Settings > Apps > Installed apps.

`Start.cmd` applies the [recommended set](#recommended-applied-by-default). For optional settings, use option A or B below.

## Option A: with Claude Code or Codex

1. Download this repository: green **Code** button, then **Download ZIP**, then extract it. `git clone` also works.
2. Open the extracted folder, right-click an empty area and choose **Open in Terminal**.
3. Start `claude` or `codex` and type:

   ```text
   Read AGENTS.md and help me set up this project on my PC.
   ```

The agent follows the rules in [AGENTS.md](AGENTS.md). It runs the self-test, shows you the preview in plain words and asks what you want. It then applies only that and tells you how to undo it. It never uses administrator rights, never goes beyond the script, and won't install anything for you.

## Option B: run the script yourself

1. Download and extract this repository (as above).
2. Open the folder, right-click an empty area and choose **Open in Terminal**. It opens with normal rights. Do not use "Run as administrator".
3. Run the commands you need:

| What | Command |
|---|---|
| Test that it works on this PC (uses a temporary test key only) | `powershell.exe -NoProfile -ExecutionPolicy Bypass -File Win11Zen.ps1 -Mode SelfTest` |
| **Preview** (changes nothing) | `powershell.exe -NoProfile -ExecutionPolicy Bypass -File Win11Zen.ps1` |
| Preview, plus where each switch is in Settings | `powershell.exe -NoProfile -ExecutionPolicy Bypass -File Win11Zen.ps1 -Details` |
| Apply the recommended settings | `powershell.exe -NoProfile -ExecutionPolicy Bypass -File Win11Zen.ps1 -Mode Apply` |
| Apply recommended settings plus chosen optional ones | `powershell.exe -NoProfile -ExecutionPolicy Bypass -File Win11Zen.ps1 -Mode Apply -Only "recommended,start-recent-files,taskbar-end-task"` |
| Apply only specific settings | `powershell.exe -NoProfile -ExecutionPolicy Bypass -File Win11Zen.ps1 -Mode Apply -Only "advertising-id,tips-and-suggestions"` |
| Undo the last Apply | `powershell.exe -NoProfile -ExecutionPolicy Bypass -File Win11Zen.ps1 -Mode Restore` |
| Undo everything this script has ever changed | `powershell.exe -NoProfile -ExecutionPolicy Bypass -File Win11Zen.ps1 -Mode Restore -All` |

When it finishes, the script prints what it did: what it changed now, what was already set, anything it skipped and why, where the backup is and how to undo it. After applying, **sign out and back in** (or restart) so every change shows up.

`-ExecutionPolicy Bypass` applies only to that single PowerShell run. It does not change your PC's script settings.

Exit codes: `0` done, `1` stopped before changing anything, `2` finished but some settings were not changed (the output says which).

## What the script changes

Every item is a switch for **your user account** that you can also change in Settings or in File Explorer options (only `silent-app-installs` is an exception, [explained below](#the-one-exception-silent-app-installs)). The paths below use the English Windows interface. In any language, open the page directly: press `Win+R`, paste the `ms-settings:` link (or `control folders` for File Explorer options) and press Enter.

### Recommended (applied by default)

| ID | Switch in Settings (turned **off** unless stated) | What you lose |
|---|---|---|
| `advertising-id` | Privacy & security > General > *Let apps show me personalized ads by using my advertising ID* (`ms-settings:privacy-general`) | Nothing noticeable. Ads are less targeted. |
| `website-language-list` | Privacy & security > General > *Let websites show me locally relevant content by accessing my language list* | Some sites may not pick your language automatically. |
| `app-launch-tracking` | Privacy & security > General > *Let Windows improve Start and search results by tracking app launches* | The "Most used" list in Start. |
| `settings-suggestions` | Privacy & security > General > *Show me suggested content in the Settings app* | Nothing. |
| `tailored-experiences` | Privacy & security > Diagnostics & feedback > *Tailored experiences* (`ms-settings:privacy-feedback`) | Fewer personalised tips and offers. |
| `inking-typing-improvement` | Privacy & security > Diagnostics & feedback > *Improve inking and typing* | Nothing. Your typing suggestions still work. |
| `search-cloud-content` | Privacy & security > Search permissions > *Cloud content search* (`ms-settings:search-permissions`) | Search stops showing OneDrive/Outlook account content. Files on the PC are still found. |
| `search-highlights` | Privacy & security > Search permissions > *Show search highlights* | Daily pictures and trending topics in search. |
| `start-recommendations` | Personalization > Start > *Show recommendations for tips, shortcuts, new apps, and more* (`ms-settings:personalization-start`) | Nothing. |
| `start-account-notifications` | Personalization > Start > *Show account-related notifications* | Account, backup and subscription reminders in Start. |
| `welcome-experience` | System > Notifications > Additional settings > *Show the Windows welcome experience...* (`ms-settings:notifications`) | "What's new" pages after updates. |
| `finish-setup-suggestions` | System > Notifications > Additional settings > *Suggest ways to get the most out of Windows...* | Nothing. |
| `tips-and-suggestions` | System > Notifications > Additional settings > *Get tips and suggestions when using Windows* | Pop-up tips. |
| `lock-screen-tips` | Personalization > Lock screen > *Get fun facts, tips, tricks, and more on your lock screen* (`ms-settings:lockscreen`) | Nothing. Only matters with a picture or slideshow lock screen. |
| `clipboard-cloud-sync` | System > Clipboard > *Clipboard across your devices* (`ms-settings:clipboard`) | Copy here, paste on another device. Local clipboard history (`Win+V`) still works. |
| `settings-app-notifications` | Privacy & security > General > *Show me notifications in the Settings app* | Nothing. |
| `suggested-notifications` | System > Notifications > *Notifications from apps and other senders* > *Suggested* | Nothing. |
| `feedback-frequency` | Privacy & security > Diagnostics & feedback > *Feedback frequency*: Never | Nothing. You can still send feedback yourself in the Feedback Hub app. |
| `explorer-sync-provider-ads` | File Explorer options > View > *Show sync provider notifications* (`control folders`) | Nothing. OneDrive keeps working; only its promotions in File Explorer go away. |
| `start-recently-added-apps` | Personalization > Start > *Show recently added apps* | Newly installed apps are no longer highlighted in Start. |
| `taskbar-search-box` | Personalization > Taskbar > *Search*: Hide (`ms-settings:taskbar`) | Nothing. Press the Windows key and type, or `Win+S`. |
| `taskbar-task-view` | Personalization > Taskbar > *Task view* | Nothing. `Win+Tab` still works. |
| `desktop-this-pc-icon` | Personalization > Themes > Desktop icon settings > *Computer*: **on** (`ms-settings:themes`) | Nothing. It adds the real "This PC" icon (no shortcut arrow). |
| `show-file-extensions` | File Explorer options > View > *Hide extensions for known file types*: unticked. **This one is for safety:** you can see that `invoice.pdf.exe` is a program, not a PDF. | File names show their ending (`.pdf`, `.exe`). Keep it when renaming; Windows warns you if you change it. |

### Optional (only when named with `-Only`)

| ID | Change | What you lose |
|---|---|---|
| `search-history` | Privacy & security > Search permissions > *Search history on this device*: off | Suggestions based on your earlier searches. |
| `start-recent-files` | Personalization > Start > *Show recommended files in Start, recent files in File Explorer, and items in Jump Lists*: off | Quick access to recently opened files. |
| `explorer-open-this-pc` | File Explorer options > General > *Open File Explorer to*: This PC | Recent files are no longer the first thing you, or someone watching your screen, see. |
| `taskbar-end-task` | System > Advanced (older versions: For developers) > *End task*: on (`ms-settings:developers`) | Nothing. Adds "End task" to the right-click menu of taskbar buttons. It closes the app at once, so unsaved work in it is lost. |
| `start-phone-link` | Personalization > Start > *Show mobile device in Start*: off | The phone panel next to Start. The Phone Link app still works. |
| `online-speech-recognition` | Privacy & security > Speech > *Online speech recognition*: off (`ms-settings:privacy-speech`) | Voice typing (`Win+H`) and other online speech features may stop working. |
| `silent-app-installs` | Not in Settings, [see below](#the-one-exception-silent-app-installs) | Nothing. Apps you install yourself are not affected. |

### The one exception: `silent-app-installs`

Windows sometimes installs promoted apps and games on its own. This optional setting tells it to stop (`SilentInstalledAppsEnabled = 0` for your user account). Settings has no switch for it, which is why it's the only item on this list that breaks the "only Settings switches" rule. It is still per-user, needs no administrator rights, is backed up and undone like everything else, and is never applied unless you name it with `-Only`.

## Manual steps (optional)

The script doesn't do these. Some affect every user of the PC, Windows protects some from scripts, and some are personal choices. Open each page with `Win+R` and the `ms-settings:` link.

1. **Optional diagnostic data**: `ms-settings:privacy-feedback`. Turn off *Send optional diagnostic data*. This affects all users of the PC.
2. **Widgets**: `ms-settings:taskbar`. Turn off *Widgets*. Recent Windows versions block scripts from changing this switch.
3. **Lock screen**: `ms-settings:lockscreen`. Choose *Picture* instead of *Windows spotlight* if you don't want rotating Microsoft content.
4. **Startup apps**: `ms-settings:startupapps`. Turn off apps you don't need right after sign-in; you can still open them yourself. **Leave on:** antivirus and security software, manufacturer tools for keys, touchpad, audio or battery, remote-access or backup tools you rely on.
5. **Uninstall apps you never use**: `ms-settings:appsfeatures`. Only remove apps you recognise; if unsure, leave the app. **Never remove:**
   - antivirus or security software
   - Microsoft Store and Microsoft Edge
   - Microsoft Edge WebView2 Runtime, Microsoft Visual C++ Redistributable, .NET
   - Xbox TCUI and Xbox Identity Provider (Microsoft Store, Photos and games use them)
   - Get Help (Windows troubleshooters use it)
   - drivers and manufacturer utilities (Intel, AMD, NVIDIA, Realtek, Lenovo, Dell, HP, Acer, ASUS...). These often control keys, fans or the battery charge limit.
   - anything named *Runtime*, *Framework* or *Driver*
6. **Taskbar pins**: open an app, right-click its taskbar icon and choose **Pin to taskbar**. To remove one, right-click it and choose **Unpin from taskbar**.
7. **App permissions**: `ms-settings:privacy-location`, `ms-settings:privacy-webcam`, `ms-settings:privacy-microphone`. Allow only the apps that need them. Keep location on if you use *Set time zone automatically* or *Find my device*.
8. **Recall** (only on Copilot+ PCs): Privacy & security > Recall & snapshots. Decide whether you want it.
9. **Your browser**: review its own privacy settings (tracking protection, third-party cookies). This project doesn't change browsers.
10. **Sharing updates with other PCs**: `ms-settings:delivery-optimization`. Turn off *Allow downloads from other PCs*. Updates still come from Microsoft as usual; your PC just stops uploading them to other computers over your connection.
11. **AI features in Notepad and Paint**: open the app, go to its settings (gear icon) and turn off Copilot/AI features if your version has that option.
12. **Wallpaper**: `ms-settings:personalization-background`.
13. **An extra keyboard layout**, for example Polish (Programmers): `ms-settings:regionlanguage`, then your language, then **Language options** and **Add a keyboard**. Adding a layout doesn't remove anything. Don't remove languages or layouts unless you're sure you don't need them.

**Time zone and clock:** this project doesn't change them. If your clock is wrong, open `ms-settings:dateandtime` and turn on *Set time zone automatically* (needs location), or pick your time zone manually.

## Optional: Windhawk (dock-style taskbar and restyled Start)

> **Read this first.** This is the only part of the project that isn't built into Windows. [Windhawk](https://windhawk.net/) is free, open-source third-party software that loads small "mods" into the taskbar and Start menu. It's popular and fully reversible, but it is not zero-risk: after a big Windows update a mod can look wrong or stop working until its author updates it. Skip this part on work PCs, in S mode, or if you'd rather not deal with that. Your AI agent won't install it for you.

**Install:** the easiest way is to answer `Y` to the Windhawk question at the end of `Start.cmd`. It installs the official package with winget (`winget install --id RamenSoftware.Windhawk --exact`) and opens Windhawk. You can also download it yourself, but only from [windhawk.net](https://windhawk.net/) (source code on [GitHub](https://github.com/ramensoftware/windhawk)). Either way, Windows asks for administrator approval because an app is being installed.

**Why the mods themselves are clicked, not scripted:** Windhawk has no official way to install mods or change their settings from a script. Doing it anyway would mean editing its internal settings with administrator rights, which could break with any Windhawk update.

**Mods:** in Windhawk, open **Explore**, search for each mod, click **Install**, then open its **Settings** tab, choose the option and click **Save**.

| Mod | Setting | Result |
|---|---|---|
| [Windows 11 Taskbar Styler](https://windhawk.net/mods/windows-11-taskbar-styler) | Theme: `DockLike` | Centred, floating, dock-style taskbar |
| [Windows 11 Start Menu Styler](https://windhawk.net/mods/windows-11-start-menu-styler) | Theme: `Fluent2Inspired` (recommended) | Rounded, translucent, clean Start menu that keeps your pinned apps. Works with both the redesigned Start menu (Windows 11 25H2) and the older one. Alternatives: `Fluid`, `OnlySearch` (see below). |
| [Taskbar tray system icon tweaks](https://windhawk.net/mods/taskbar-tray-system-icon-tweaks) | *Hide language bar*: on | Hides the language indicator (e.g. "ENG") next to the clock. Only useful with more than one keyboard layout. You can still switch layouts with `Win+Space`. |

Theme guides: [DockLike](https://github.com/ramensoftware/windows-11-taskbar-styling-guide/blob/main/Themes/DockLike/README.md), [Fluent2Inspired](https://github.com/ramensoftware/windows-11-start-menu-styling-guide/blob/main/Themes/Fluent2Inspired/README.md), [Fluid](https://github.com/ramensoftware/windows-11-start-menu-styling-guide/blob/main/Themes/Fluid/README.md), [OnlySearch](https://github.com/ramensoftware/windows-11-start-menu-styling-guide/blob/main/Themes/OnlySearch/README.md).

**Which Start theme?**

- **`Fluent2Inspired`** is the recommended one and was tested with this project. It works with both the redesigned Start menu (Windows 11 25H2) and the older one, in dark and light mode. It uses the Aptos font where available (installed with Microsoft 365); otherwise Windows shows its standard font.
- **`Fluid`** is only for the redesigned Start menu and is made for dark mode (its guide has one extra line for light mode).
- **`OnlySearch`** suits people who only ever type to search.

If a theme looks broken on your Windows version, try another one or set it to *None*. If nothing changes after saving, sign out and back in.

Start themes only change the look. They don't block web search or telemetry.

**Good companions for a clean Start menu** (switches in Settings > Personalization > Start, the first two are in the script's recommended set): turn off *Show recently added apps* and *Show recommendations for tips, shortcuts, new apps, and more*. Optionally also turn off *Show recommended files...* (`start-recent-files`); note that this also removes recent files from File Explorer and Jump Lists. Pinned apps always fill the grid in order, with no empty spaces; that's a Windows limitation that no mod changes. You can still reorder them by dragging, or drop one icon onto another to make a folder.

**If something goes wrong:**

1. Press `Ctrl+Shift+Esc` to open Task Manager. It works even if the taskbar is broken.
2. Click **Run new task**, type `C:\Program Files\Windhawk\windhawk.exe` and press Enter. Turn off the mod you changed last.
3. Or remove Windhawk completely: **Run new task**, then `appwiz.cpl`, then uninstall **Windhawk**.
4. Sign out and back in (`Ctrl+Alt+Del`, then **Sign out**). Windows is back to normal.

Never turn off your antivirus to "fix" a mod.

## Undo

| What | How |
|---|---|
| Script, everything, the easy way | Double-click `Undo.cmd` and answer `Y` |
| Script, last run | `powershell.exe -NoProfile -ExecutionPolicy Bypass -File Win11Zen.ps1 -Mode Restore` |
| Script, everything ever changed | `powershell.exe -NoProfile -ExecutionPolicy Bypass -File Win11Zen.ps1 -Mode Restore -All` |
| Manual steps | Flip the switch back in Settings |
| Windhawk | Turn off the mod, or uninstall Windhawk |
| An app you uninstalled | Reinstall it from Microsoft Store or the maker's website |

Backups are saved in `%LOCALAPPDATA%\MinimalWindows\backups`. They hold only the old values of the switches listed above (plain numbers, no personal data). Keep them: without them `Restore` has nothing to restore. Every Restore also saves a `pre-restore-*.json` file, so a Restore can be undone too, with `-Mode Restore -BackupFile <that file>`.

## After big Windows updates

Run the preview again. If some items show `to do` again, Windows switched them back on. Apply again, and a new backup is made.

## FAQ

**Why not disable telemetry services or scheduled tasks?** It can break Windows Update, diagnostics and troubleshooting. Home editions ignore many of the related policies, and Windows may undo it anyway. It doesn't fit this project's "nothing can break" rule.

**Will it make my PC faster?** Not noticeably. The goal is less noise and less data sharing, not speed.

**Home vs Pro?** Same switches, same result. The project doesn't use Group Policy, which Home doesn't have.

**Can I read what the script does?** Yes, and you should. All the settings are in one list (`$Catalog`) at the top of [Win11Zen.ps1](Win11Zen.ps1).

**How is this different from Win11Debloat?** [Win11Debloat](https://github.com/Raphire/Win11Debloat) is a popular, well-made tool that goes much further. It uses administrator rights and system-wide policies, removes many apps for all users, and also changes Windows Update, power and security-related settings. This project deliberately stays smaller: only your user account, no administrator rights, and an exact undo. Several items here were cross-checked against Win11Debloat's registry files.
