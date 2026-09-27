<#
.SYNOPSIS
    Win11Zen: safe Windows 11 debloat. Turns off ads, tips and some data sharing for the
    current user. Makes a backup first and can restore it exactly.

.DESCRIPTION
    Safety model
      * Runs without administrator rights and refuses to run elevated.
      * Writes only to HKEY_CURRENT_USER, and only the values listed in
        $Catalog below. Each one is a switch you can also flip yourself in
        Windows Settings or File Explorer options. The single exception,
        silent-app-installs, is optional and labelled as such.
      * Saves the previous values to a backup file before changing anything.
        -Mode Restore puts back exactly what was there, including removing
        values that did not exist before.
      * Never touches system files, services, scheduled tasks, drivers,
        antivirus or firewall, Windows Update, power, time zone, languages,
        installed apps or other user accounts.

    Modes
      Preview   (default) Shows the current state. Changes nothing.
      Apply     Backs up, then applies the recommended settings, or exactly
                the IDs passed with -Only.
      Restore   Undoes the newest Apply (or the file passed with -BackupFile).
                With -All it undoes every Apply ever made, newest first.
      SelfTest  Runs Apply and Restore against a temporary test key
                (HKCU\Software\MinimalWindows-SelfTest), checks the result and
                deletes the test key. Real settings are not touched.
      Guided    For people, not scripts (Start.cmd uses it): self-test, then a
                list of what will change, then one Y/N question, then Apply.
                At the end it offers (Y/N) to install Windhawk with winget and
                shows how to set up the dock-style taskbar. Nothing is installed
                without a Y.

    Exit codes
      0  Done.
      1  Stopped before changing anything (see the message).
      2  Finished, but some settings were not changed (see the output).
         Everything that was changed is in the backup.

.PARAMETER Mode
    Preview, Apply, Restore or SelfTest.

.PARAMETER Only
    Setting IDs to use instead of the recommended set, for example
    "recommended,taskbar-search-box". The words "recommended" and "all" work too.

.PARAMETER BackupFile
    Backup file for -Mode Restore. Defaults to the newest backup.

.PARAMETER All
    With -Mode Restore: undo every backup, newest first.

.PARAMETER Details
    With -Mode Preview: also show where each switch is in Settings.

.EXAMPLE
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File Win11Zen.ps1

.EXAMPLE
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File Win11Zen.ps1 -Mode Apply -Only "recommended,taskbar-search-box"

.EXAMPLE
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File Win11Zen.ps1 -Mode Restore -All
#>
[CmdletBinding()]
param(
    [ValidateSet('Preview', 'Apply', 'Restore', 'SelfTest', 'Guided')]
    [string]$Mode = 'Preview',

    [string[]]$Only,

    [string]$BackupFile,

    [switch]$All,

    [switch]$Details
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

# Internal names from before the project was called Win11Zen. Keep them unchanged:
# existing backups are identified by this tool name and stored in this folder.
$ToolName = 'minimal-windows'
$ToolVersion = '1.7.0'
$BackupDir = Join-Path $env:LOCALAPPDATA 'MinimalWindows\backups'
$SelfTestKey = 'Software\MinimalWindows-SelfTest'
$Command = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File Win11Zen.ps1'
$LineWidth = 96

# Registry paths below are relative to HKEY_CURRENT_USER. SelfTest moves them under $SelfTestKey.
$script:KeyPrefix = ''
$script:Quiet = $false
$script:Touched = $false

# ---------------------------------------------------------------------------
# Catalog: every value this script is allowed to write. All values are DWORDs.
# Note is shown under the setting in the preview; leave it empty when nothing is lost.
# ---------------------------------------------------------------------------

function New-RegValue([string]$Path, [string]$Name, [int]$Target) {
    [pscustomobject]@{ Path = $Path; Name = $Name; Target = $Target }
}

$Cdm = 'Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
$Advanced = 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
$SearchSettings = 'Software\Microsoft\Windows\CurrentVersion\SearchSettings'

$Catalog = @(
    [pscustomobject]@{
        Id          = 'advertising-id'
        Recommended = $true
        Title       = 'Turn off personalised ads (advertising ID)'
        Note        = ''
        Where       = 'Privacy & security > General > Let apps show me personalized ads by using my advertising ID'
        Page        = 'ms-settings:privacy-general'
        Values      = @(New-RegValue 'Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'Enabled' 0)
    }
    [pscustomobject]@{
        Id          = 'website-language-list'
        Recommended = $true
        Title       = 'Stop sharing your language list with websites'
        Note        = 'some sites may not pick your language automatically'
        Where       = 'Privacy & security > General > Let websites show me locally relevant content by accessing my language list'
        Page        = 'ms-settings:privacy-general'
        Values      = @(New-RegValue 'Control Panel\International\User Profile' 'HttpAcceptLanguageOptOut' 1)
    }
    [pscustomobject]@{
        Id          = 'app-launch-tracking'
        Recommended = $true
        Title       = 'Stop tracking app launches for Start and search'
        Note        = 'the "Most used" list in Start goes away'
        Where       = 'Privacy & security > General > Let Windows improve Start and search results by tracking app launches'
        Page        = 'ms-settings:privacy-general'
        Values      = @(New-RegValue $Advanced 'Start_TrackProgs' 0)
    }
    [pscustomobject]@{
        Id          = 'settings-suggestions'
        Recommended = $true
        Title       = 'Turn off suggested content in the Settings app'
        Note        = ''
        Where       = 'Privacy & security > General > Show me suggested content in the Settings app'
        Page        = 'ms-settings:privacy-general'
        Values      = @(
            New-RegValue $Cdm 'SubscribedContent-338393Enabled' 0
            New-RegValue $Cdm 'SubscribedContent-353694Enabled' 0
            New-RegValue $Cdm 'SubscribedContent-353696Enabled' 0
        )
    }
    [pscustomobject]@{
        Id          = 'tailored-experiences'
        Recommended = $true
        Title       = 'Turn off tailored experiences'
        Note        = ''
        Where       = 'Privacy & security > Diagnostics & feedback > Tailored experiences'
        Page        = 'ms-settings:privacy-feedback'
        Values      = @(New-RegValue 'Software\Microsoft\Windows\CurrentVersion\Privacy' 'TailoredExperiencesWithDiagnosticDataEnabled' 0)
    }
    [pscustomobject]@{
        Id          = 'inking-typing-improvement'
        Recommended = $true
        Title       = 'Stop sending inking and typing data to Microsoft'
        Note        = ''
        Where       = 'Privacy & security > Diagnostics & feedback > Improve inking and typing'
        Page        = 'ms-settings:privacy-feedback'
        Values      = @(New-RegValue 'Software\Microsoft\Input\TIPC' 'Enabled' 0)
    }
    [pscustomobject]@{
        Id          = 'search-cloud-content'
        Recommended = $true
        Title       = 'Turn off cloud content in Windows search'
        Note        = 'no OneDrive/Outlook results; files on this PC are still found'
        Where       = 'Privacy & security > Search permissions > Cloud content search (Microsoft account, Work or School account)'
        Page        = 'ms-settings:search-permissions'
        Values      = @(
            New-RegValue $SearchSettings 'IsMSACloudSearchEnabled' 0
            New-RegValue $SearchSettings 'IsAADCloudSearchEnabled' 0
        )
    }
    [pscustomobject]@{
        Id          = 'search-highlights'
        Recommended = $true
        Title       = 'Turn off search highlights'
        Note        = ''
        Where       = 'Privacy & security > Search permissions > Show search highlights'
        Page        = 'ms-settings:search-permissions'
        Values      = @(New-RegValue $SearchSettings 'IsDynamicSearchBoxEnabled' 0)
    }
    [pscustomobject]@{
        Id          = 'start-recommendations'
        Recommended = $true
        Title       = 'Turn off app and tip recommendations in Start'
        Note        = ''
        Where       = 'Personalization > Start > Show recommendations for tips, shortcuts, new apps, and more'
        Page        = 'ms-settings:personalization-start'
        Values      = @(New-RegValue $Advanced 'Start_IrisRecommendations' 0)
    }
    [pscustomobject]@{
        Id          = 'start-account-notifications'
        Recommended = $true
        Title       = 'Turn off account notifications in Start'
        Note        = ''
        Where       = 'Personalization > Start > Show account-related notifications'
        Page        = 'ms-settings:personalization-start'
        Values      = @(New-RegValue $Advanced 'Start_AccountNotifications' 0)
    }
    [pscustomobject]@{
        Id          = 'welcome-experience'
        Recommended = $true
        Title       = 'Turn off the "welcome experience" after updates'
        Note        = ''
        Where       = 'System > Notifications > Additional settings > Show the Windows welcome experience after updates and when signed in'
        Page        = 'ms-settings:notifications'
        Values      = @(New-RegValue $Cdm 'SubscribedContent-310093Enabled' 0)
    }
    [pscustomobject]@{
        Id          = 'finish-setup-suggestions'
        Recommended = $true
        Title       = 'Turn off "finish setting up your device" reminders'
        Note        = ''
        Where       = 'System > Notifications > Additional settings > Suggest ways to get the most out of Windows and finish setting up this device'
        Page        = 'ms-settings:notifications'
        Values      = @(New-RegValue 'Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement' 'ScoobeSystemSettingEnabled' 0)
    }
    [pscustomobject]@{
        Id          = 'tips-and-suggestions'
        Recommended = $true
        Title       = 'Turn off tips and suggestions notifications'
        Note        = ''
        Where       = 'System > Notifications > Additional settings > Get tips and suggestions when using Windows'
        Page        = 'ms-settings:notifications'
        Values      = @(New-RegValue $Cdm 'SubscribedContent-338389Enabled' 0)
    }
    [pscustomobject]@{
        Id          = 'lock-screen-tips'
        Recommended = $true
        Title       = 'Turn off fun facts and tips on the lock screen'
        Note        = ''
        Where       = 'Personalization > Lock screen > Get fun facts, tips, tricks, and more on your lock screen'
        Page        = 'ms-settings:lockscreen'
        Values      = @(
            New-RegValue $Cdm 'RotatingLockScreenOverlayEnabled' 0
            New-RegValue $Cdm 'SubscribedContent-338387Enabled' 0
        )
    }
    [pscustomobject]@{
        Id          = 'clipboard-cloud-sync'
        Recommended = $true
        Title       = 'Stop syncing the clipboard to your other devices'
        Note        = 'clipboard history on this PC (Win+V) still works'
        Where       = 'System > Clipboard > Clipboard across your devices'
        Page        = 'ms-settings:clipboard'
        Values      = @(New-RegValue 'Software\Microsoft\Clipboard' 'EnableCloudClipboard' 0)
    }
    [pscustomobject]@{
        Id          = 'settings-app-notifications'
        Recommended = $true
        Title       = 'Turn off notifications inside the Settings app'
        Note        = ''
        Where       = 'Privacy & security > General > Show me notifications in the Settings app'
        Page        = 'ms-settings:privacy-general'
        Values      = @(New-RegValue 'Software\Microsoft\Windows\CurrentVersion\SystemSettings\AccountNotifications' 'EnableAccountNotifications' 0)
    }
    [pscustomobject]@{
        Id          = 'suggested-notifications'
        Recommended = $true
        Title       = 'Turn off notifications from the "Suggested" sender'
        Note        = ''
        Where       = 'System > Notifications > Notifications from apps and other senders > Suggested'
        Page        = 'ms-settings:notifications'
        Values      = @(New-RegValue 'Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.Suggested' 'Enabled' 0)
    }
    [pscustomobject]@{
        Id          = 'feedback-frequency'
        Recommended = $true
        Title       = 'Stop Windows from asking for feedback'
        Note        = ''
        Where       = 'Privacy & security > Diagnostics & feedback > Feedback frequency > Never'
        Page        = 'ms-settings:privacy-feedback'
        Values      = @(New-RegValue 'Software\Microsoft\Siuf\Rules' 'NumberOfSIUFInPeriod' 0)
    }
    [pscustomobject]@{
        Id          = 'explorer-sync-provider-ads'
        Recommended = $true
        Title       = 'Turn off OneDrive/Microsoft 365 ads in File Explorer'
        Note        = ''
        Where       = 'File Explorer options > View > Show sync provider notifications'
        Page        = 'control folders'
        Values      = @(New-RegValue $Advanced 'ShowSyncProviderNotifications' 0)
    }
    [pscustomobject]@{
        Id          = 'start-recently-added-apps'
        Recommended = $true
        Title       = 'Hide recently added apps in Start'
        Note        = 'new apps are no longer highlighted in Start'
        Where       = 'Personalization > Start > Show recently added apps'
        Page        = 'ms-settings:personalization-start'
        Values      = @(New-RegValue 'Software\Microsoft\Windows\CurrentVersion\Start' 'ShowRecentList' 0)
    }
    [pscustomobject]@{
        Id          = 'search-history'
        Recommended = $false
        Title       = 'Turn off search history on this device'
        Note        = 'search no longer suggests your earlier searches'
        Where       = 'Privacy & security > Search permissions > Search history on this device'
        Page        = 'ms-settings:search-permissions'
        Values      = @(New-RegValue $SearchSettings 'IsDeviceSearchHistoryEnabled' 0)
    }
    [pscustomobject]@{
        Id          = 'start-recent-files'
        Recommended = $false
        Title       = 'Hide recent files in Start, File Explorer and Jump Lists'
        Note        = 'no quick access to recently opened files'
        Where       = 'Personalization > Start > Show recommended files in Start, recent files in File Explorer, and items in Jump Lists'
        Page        = 'ms-settings:personalization-start'
        Values      = @(New-RegValue $Advanced 'Start_TrackDocs' 0)
    }
    [pscustomobject]@{
        Id          = 'taskbar-search-box'
        Recommended = $true
        Title       = 'Hide the search box on the taskbar'
        Note        = 'to search, press the Windows key and type'
        Where       = 'Personalization > Taskbar > Search > Hide'
        Page        = 'ms-settings:taskbar'
        Values      = @(New-RegValue 'Software\Microsoft\Windows\CurrentVersion\Search' 'SearchboxTaskbarMode' 0)
    }
    [pscustomobject]@{
        Id          = 'taskbar-task-view'
        Recommended = $true
        Title       = 'Hide the Task view button on the taskbar'
        Note        = 'Win+Tab still opens Task view'
        Where       = 'Personalization > Taskbar > Task view'
        Page        = 'ms-settings:taskbar'
        Values      = @(New-RegValue $Advanced 'ShowTaskViewButton' 0)
    }
    [pscustomobject]@{
        Id          = 'desktop-this-pc-icon'
        Recommended = $true
        Title       = 'Show the "This PC" icon on the desktop'
        Note        = ''
        Where       = 'Personalization > Themes > Desktop icon settings > Computer'
        Page        = 'ms-settings:themes'
        Values      = @(New-RegValue 'Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel' '{20D04FE0-3AEA-1069-A2D8-08002B30309D}' 0)
    }
    [pscustomobject]@{
        Id          = 'show-file-extensions'
        Recommended = $true
        Title       = 'Show file name extensions (.pdf, .exe, ...)'
        Note        = 'safer - you can see that "invoice.pdf.exe" is a program'
        Where       = 'File Explorer options > View > Hide extensions for known file types (unticked)'
        Page        = 'control folders'
        Values      = @(New-RegValue $Advanced 'HideFileExt' 0)
    }
    [pscustomobject]@{
        Id          = 'explorer-open-this-pc'
        Recommended = $false
        Title       = 'Open File Explorer on "This PC" instead of Home'
        Note        = 'recent files stay one click away, under Home'
        Where       = 'File Explorer options > General > Open File Explorer to > This PC'
        Page        = 'control folders'
        Values      = @(New-RegValue $Advanced 'LaunchTo' 1)
    }
    [pscustomobject]@{
        Id          = 'taskbar-end-task'
        Recommended = $false
        Title       = 'Add "End task" to the taskbar right-click menu'
        Note        = 'closes an app at once; its unsaved work is lost'
        Where       = 'System > Advanced (older versions: For developers) > End task'
        Page        = 'ms-settings:developers'
        Values      = @(New-RegValue 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings' 'TaskbarEndTask' 1)
    }
    [pscustomobject]@{
        Id          = 'start-phone-link'
        Recommended = $false
        Title       = 'Hide your phone next to the Start menu'
        Note        = 'the Phone Link app itself keeps working'
        Where       = 'Personalization > Start > Show mobile device in Start'
        Page        = 'ms-settings:personalization-start'
        Values      = @(New-RegValue 'Software\Microsoft\Windows\CurrentVersion\Start\Companions\Microsoft.YourPhone_8wekyb3d8bbwe' 'IsEnabled' 0)
    }
    [pscustomobject]@{
        Id          = 'online-speech-recognition'
        Recommended = $false
        Title       = 'Turn off online speech recognition'
        Note        = 'voice typing (Win+H) may stop working'
        Where       = 'Privacy & security > Speech > Online speech recognition'
        Page        = 'ms-settings:privacy-speech'
        Values      = @(New-RegValue 'Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy' 'HasAccepted' 0)
    }
    [pscustomobject]@{
        Id          = 'silent-app-installs'
        Recommended = $false
        Title       = 'Stop silent installs of promoted apps'
        Note        = 'the only item with no switch in Settings; see README'
        Where       = 'No switch in Settings. The only exception in this list; see README.'
        Page        = ''
        Values      = @(New-RegValue $Cdm 'SilentInstalledAppsEnabled' 0)
    }
)

# Restore only ever writes values from this list, even if a backup file was edited by hand.
$AllowedValues = @{}
$CatalogById = @{}
foreach ($setting in $Catalog) {
    $CatalogById[$setting.Id] = $setting
    foreach ($value in $setting.Values) {
        $AllowedValues[('{0}|{1}' -f $value.Path, $value.Name).ToLowerInvariant()] = $true
    }
}

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

function Say([string]$Text = '', [string]$Color = '') {
    if ($script:Quiet) { return }
    if ($Color) { Write-Host $Text -ForegroundColor $Color } else { Write-Host $Text }
}

# Writes one line from coloured pieces: @('text', 'Color', 'more text', '', ...). An empty colour means default.
function Write-Parts([object[]]$Parts) {
    if ($script:Quiet) { return }
    for ($i = 0; $i -lt $Parts.Count; $i += 2) {
        $color = [string]$Parts[$i + 1]
        if ($color) { Write-Host $Parts[$i] -ForegroundColor $color -NoNewline }
        else { Write-Host $Parts[$i] -NoNewline }
    }
    Write-Host ''
}

function Write-Banner([string]$ModeName, [string]$PcDescription) {
    Say ''
    Say ('=' * $LineWidth) 'DarkCyan'
    Write-Parts @('  WIN11ZEN ', 'Cyan', $ToolVersion, 'DarkCyan', '   |   ', 'DarkGray', $ModeName, 'White')
    if ($PcDescription) { Say ('  ' + $PcDescription) 'Gray' }
    Say ('=' * $LineWidth) 'DarkCyan'
}

function Write-Section([string]$Title, [string]$Right = '') {
    Say ''
    $left = '  ' + $Title
    $gap = [Math]::Max(2, $LineWidth - $left.Length - $Right.Length)
    Write-Parts @($left, 'Cyan', (' ' * $gap), '', $Right, 'DarkGray')
    Say ('  ' + ('-' * ($LineWidth - 2))) 'DarkGray'
}

# One label/value line, e.g. "  Backup:  C:\...".
function Write-Field([string]$Label, [string]$Value, [string]$Color = '') {
    Write-Parts @(('  {0,-10}' -f $Label), 'DarkGray', $Value, $Color)
}

# One setting per line: symbol, title, and the setting ID in grey on the right.
function Write-SettingRow([string]$Symbol, [string]$SymbolColor, [object]$Item) {
    $title = [string]$Item.Title
    $gap = [Math]::Max(2, 62 - $title.Length)
    Write-Parts @(('  {0}  ' -f $Symbol), $SymbolColor, $title, '', (' ' * $gap), '', [string]$Item.Id, 'DarkGray')
    $reason = Get-Prop $Item 'Reason'
    if ($reason) { Say ('       reason: ' + $reason) 'Yellow' }
}

function Write-SettingList([string]$Heading, [object[]]$Items, [string]$Symbol, [string]$Color) {
    if ($Items.Count -eq 0) { return }
    Write-Section $Heading ('{0} setting(s)' -f $Items.Count)
    foreach ($item in $Items) { Write-SettingRow $Symbol $Color $item }
}

function Stop-Tool([string]$Message) {
    Write-Host ''
    Write-Host '  STOPPED' -ForegroundColor Red
    Write-Host ('  ' + $Message) -ForegroundColor Red
    Write-Host '  Nothing was changed.'
    Write-Host ''
    exit 1
}

function Get-Prop([object]$Object, [string]$Name) {
    if ($null -eq $Object) { return $null }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

# ---------------------------------------------------------------------------
# Registry access (HKEY_CURRENT_USER only, through .NET so nothing else is touched)
# ---------------------------------------------------------------------------

function Get-FullPath([string]$Path) {
    if ($script:KeyPrefix) { return $script:KeyPrefix + '\' + $Path }
    return $Path
}

function Read-RegValue([string]$Path, [string]$Name) {
    $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey((Get-FullPath $Path), $false)
    if ($null -eq $key) {
        return [pscustomobject]@{ KeyExisted = $false; Existed = $false; Kind = ''; Value = $null }
    }
    try {
        if (@($key.GetValueNames()) -notcontains $Name) {
            return [pscustomobject]@{ KeyExisted = $true; Existed = $false; Kind = ''; Value = $null }
        }
        $kind = $key.GetValueKind($Name).ToString()
        $value = $key.GetValue($Name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        return [pscustomobject]@{ KeyExisted = $true; Existed = $true; Kind = $kind; Value = $value }
    }
    finally {
        $key.Close()
    }
}

function Write-DwordValue([string]$Path, [string]$Name, [int]$Value) {
    # CreateSubKey opens the key if it exists and never removes anything in it.
    $key = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey((Get-FullPath $Path))
    try {
        $script:Touched = $true
        $key.SetValue($Name, $Value, [Microsoft.Win32.RegistryValueKind]::DWord)
    }
    finally {
        $key.Close()
    }
}

function Remove-RegValue([string]$Path, [string]$Name) {
    $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey((Get-FullPath $Path), $true)
    if ($null -eq $key) { return }
    try {
        $script:Touched = $true
        $key.DeleteValue($Name, $false)
    }
    finally {
        $key.Close()
    }
}

# Removes a key this script created, but only if nothing else has been put in it since.
function Remove-KeyIfEmpty([string]$Path) {
    $fullPath = Get-FullPath $Path
    $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($fullPath, $false)
    if ($null -eq $key) { return }
    $isEmpty = ($key.ValueCount -eq 0 -and $key.SubKeyCount -eq 0)
    $key.Close()
    if ($isEmpty) { [Microsoft.Win32.Registry]::CurrentUser.DeleteSubKey($fullPath, $false) }
}

function Test-DwordEquals([object]$State, [int]$Expected) {
    return ($State.Existed -and $State.Kind -eq 'DWord' -and [int]$State.Value -eq $Expected)
}

# ---------------------------------------------------------------------------
# State of the catalog settings
# ---------------------------------------------------------------------------

function Get-ValueState([object]$Value) {
    $state = Read-RegValue $Value.Path $Value.Name
    $status = 'Change'
    if ($state.Existed -and $state.Kind -ne 'DWord') { $status = 'Blocked' }
    elseif (Test-DwordEquals $state $Value.Target) { $status = 'Done' }
    return [pscustomobject]@{ Value = $Value; State = $state; Status = $status }
}

function Get-SettingState([object]$Setting) {
    $values = @($Setting.Values | ForEach-Object { Get-ValueState $_ })
    $status = 'Done'
    if (@($values | Where-Object { $_.Status -eq 'Blocked' }).Count -gt 0) { $status = 'Blocked' }
    elseif (@($values | Where-Object { $_.Status -eq 'Change' }).Count -gt 0) { $status = 'Change' }
    return [pscustomobject]@{ Setting = $Setting; Values = $values; Status = $status }
}

function Resolve-Selection([string[]]$Requested) {
    if (-not $Requested) { return @($Catalog | Where-Object { $_.Recommended }) }

    # "a,b" arrives as one string when the script is started with -File, so split it here.
    $ids = @($Requested | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim().ToLowerInvariant() } | Where-Object { $_ -ne '' })
    if ($ids.Count -eq 0) { Stop-Tool '-Only was given without any setting IDs.' }

    $known = @($Catalog | ForEach-Object { $_.Id })
    $unknown = @($ids | Where-Object { $_ -notin @('recommended', 'all') -and $known -notcontains $_ })
    if ($unknown.Count -gt 0) {
        Stop-Tool ('Unknown setting ID(s): {0}. Run "{1}" to see the list.' -f ($unknown -join ', '), $Command)
    }

    return @($Catalog | Where-Object {
        ($ids -contains 'all') -or (($ids -contains 'recommended') -and $_.Recommended) -or ($ids -contains $_.Id)
    })
}

# ---------------------------------------------------------------------------
# Backups
# ---------------------------------------------------------------------------

function New-BackupEntry([string]$Id, [string]$Path, [string]$Name, [object]$State) {
    $oldValue = $null
    if ($State.Existed) { $oldValue = [int]$State.Value }
    return [pscustomobject]@{
        Id         = $Id
        Path       = $Path
        Name       = $Name
        KeyExisted = [bool]$State.KeyExisted
        Existed    = [bool]$State.Existed
        Value      = $oldValue
    }
}

function Get-BackupFiles([string]$Dir) {
    if (-not (Test-Path -LiteralPath $Dir)) { return @() }
    return @(Get-ChildItem -LiteralPath $Dir -Filter 'backup-*.json' -File | Sort-Object Name)
}

function Read-Backup([string]$File) {
    if (-not (Test-Path -LiteralPath $File -PathType Leaf)) { throw "Backup file not found: $File" }
    $doc = Get-Content -LiteralPath $File -Raw -Encoding UTF8 | ConvertFrom-Json
    if ((Get-Prop $doc 'Tool') -ne $ToolName -or $null -eq $doc.PSObject.Properties['Entries']) {
        throw "Not a $ToolName backup file: $File"
    }

    $entries = @($doc.Entries)
    foreach ($entry in $entries) {
        foreach ($property in 'Id', 'Path', 'Name', 'KeyExisted', 'Existed', 'Value') {
            if ($null -eq $entry.PSObject.Properties[$property]) { throw "Backup file is damaged (missing '$property'): $File" }
        }
        $allowedKey = ('{0}|{1}' -f $entry.Path, $entry.Name).ToLowerInvariant()
        if (-not $AllowedValues.ContainsKey($allowedKey)) {
            throw ('Backup file contains a value this script does not manage ({0}\{1}): {2}' -f $entry.Path, $entry.Name, $File)
        }
        if ($entry.Existed) {
            $isInt = ($entry.Value -is [int]) -or ($entry.Value -is [long] -and $entry.Value -ge [int]::MinValue -and $entry.Value -le [int]::MaxValue)
            if (-not $isInt) { throw ('Backup file is damaged (bad value for {0}): {1}' -f $entry.Name, $File) }
        }
    }
    return $entries
}

function Save-Backup([object[]]$Entries, [string]$Dir, [string]$Kind) {
    [void][IO.Directory]::CreateDirectory($Dir)
    do {
        $file = Join-Path $Dir ('{0}-{1}.json' -f $Kind, (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
        if (Test-Path -LiteralPath $file) {
            Start-Sleep -Milliseconds 5
            $file = $null
        }
    } while (-not $file)

    $doc = [pscustomobject]@{
        Tool        = $ToolName
        ToolVersion = $ToolVersion
        Created     = (Get-Date).ToString('o')
        Entries     = @($Entries)
    }
    $json = ConvertTo-Json -InputObject $doc -Depth 4
    [IO.File]::WriteAllText($file, $json, (New-Object System.Text.UTF8Encoding($false)))

    # Read it back before anything is changed.
    if (@(Read-Backup $file).Count -ne @($Entries).Count) { throw "Could not verify the backup file $file." }
    return $file
}

# ---------------------------------------------------------------------------
# Modes
# ---------------------------------------------------------------------------

function Test-Preflight([bool]$CheckManaged) {
    if ($env:OS -ne 'Windows_NT') { Stop-Tool 'This script only runs on Windows 11.' }

    $currentVersion = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $build = 0
    [void][int]::TryParse([string](Get-Prop $currentVersion 'CurrentBuildNumber'), [ref]$build)
    if ($build -lt 22000) { Stop-Tool ('Windows 11 is required. This PC reports build {0}.' -f $build) }
    if ((Get-Prop $currentVersion 'InstallationType') -ne 'Client') { Stop-Tool 'Only Windows 11 for PCs is supported, not Windows Server.' }

    $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Stop-Tool 'PowerShell is running as administrator. This script only needs normal rights and refuses to run elevated. Open a normal PowerShell window (not "Run as administrator") and try again.'
    }

    if ($CheckManaged) {
        if ((Get-CimInstance -ClassName Win32_ComputerSystem).PartOfDomain) {
            Stop-Tool 'This PC is joined to a company domain. Settings on work computers belong to your IT department.'
        }
        $joinInfo = 'HKLM:\SYSTEM\CurrentControlSet\Control\CloudDomainJoin\JoinInfo'
        if ((Test-Path -LiteralPath $joinInfo) -and @(Get-ChildItem -LiteralPath $joinInfo).Count -gt 0) {
            Stop-Tool 'This PC is joined to a work or school organisation (Microsoft Entra ID). Settings on managed computers belong to that organisation.'
        }
    }

    $editions = @{
        Core                    = 'Home'
        CoreSingleLanguage      = 'Home Single Language'
        CoreCountrySpecific     = 'Home'
        Professional            = 'Pro'
        ProfessionalWorkstation = 'Pro for Workstations'
        ProfessionalEducation   = 'Pro Education'
        Education               = 'Education'
        Enterprise              = 'Enterprise'
    }
    $editionId = [string](Get-Prop $currentVersion 'EditionID')
    $edition = $editionId
    if ($editions.ContainsKey($editionId)) { $edition = $editions[$editionId] }
    $displayVersion = [string](Get-Prop $currentVersion 'DisplayVersion')
    $ubr = Get-Prop $currentVersion 'UBR'
    $buildText = [string]$build
    if ($null -ne $ubr) { $buildText = '{0}.{1}' -f $build, $ubr }
    return ('Windows 11 {0} {1}, build {2}' -f $edition, $displayVersion, $buildText) -replace '\s+', ' '
}

function Show-Preview([string]$PcDescription, [object[]]$Selected, [string[]]$Requested, [bool]$ShowDetails) {
    Write-Banner 'PREVIEW - nothing is changed' $PcDescription

    $selectedIds = @($Selected | ForEach-Object { $_.Id })
    $wouldChange = New-Object System.Collections.Generic.List[object]
    $groups = @(
        @{ Recommended = $true; Title = 'RECOMMENDED - applied by default' }
        @{ Recommended = $false; Title = 'OPTIONAL - applied only when you name them with -Only' }
    )

    foreach ($group in $groups) {
        $states = @($Catalog | Where-Object { $_.Recommended -eq $group.Recommended } | ForEach-Object { Get-SettingState $_ })
        $doneCount = @($states | Where-Object { $_.Status -eq 'Done' }).Count
        $todoCount = @($states | Where-Object { $_.Status -eq 'Change' }).Count
        $skipCount = @($states | Where-Object { $_.Status -eq 'Blocked' }).Count
        $counts = '{0} done, {1} to do' -f $doneCount, $todoCount
        if ($skipCount -gt 0) { $counts += (', {0} skipped' -f $skipCount) }
        Write-Section $group.Title $counts

        foreach ($state in $states) {
            $setting = $state.Setting
            switch ($state.Status) {
                'Done' { $label = 'done '; $color = 'Green' }
                'Change' { $label = 'TO DO'; $color = 'Yellow' }
                default { $label = 'SKIP '; $color = 'Red' }
            }
            Write-Parts @(('  {0}  ' -f $label), $color, ('{0,-28} ' -f $setting.Id), 'DarkGray', $setting.Title, '')
            $indent = ' ' * 38
            if ($setting.Note) { Say ($indent + 'note: ' + $setting.Note) 'DarkGray' }
            if ($state.Status -eq 'Blocked') { Say ($indent + 'an existing value has an unexpected type, so it is left alone') 'Red' }
            if ($ShowDetails) {
                Say ($indent + 'where: ' + $setting.Where) 'DarkGray'
                if ($setting.Page) { Say ($indent + 'open:  Win+R, then ' + $setting.Page) 'DarkGray' }
            }
            if ($state.Status -eq 'Change' -and $selectedIds -contains $setting.Id) { $wouldChange.Add($setting) }
        }
    }

    $applyCommand = '{0} -Mode Apply' -f $Command
    if ($Requested) { $applyCommand = '{0} -Mode Apply -Only "{1}"' -f $Command, ($Requested -join ',') }

    Write-Section 'NEXT STEP'
    if ($wouldChange.Count -eq 0) {
        Say '  Apply would change nothing: everything selected is already set.' 'Green'
        Say ''
    }
    elseif ($Requested) {
        Say ('  With your selection, Apply would change {0} setting(s):' -f $wouldChange.Count) 'White'
        foreach ($setting in $wouldChange) { Write-SettingRow '+' 'Yellow' $setting }
        Say ''
    }
    else {
        Say ('  Apply would change the {0} recommended setting(s) marked TO DO above.' -f $wouldChange.Count) 'White'
        Say ''
    }
    Write-Field 'Apply:' $applyCommand
    if (-not $Requested) { Write-Field 'Optional:' ('{0} -Mode Apply -Only "recommended,<id>,<id>"' -f $Command) }
    if (-not $ShowDetails) { Write-Field 'Details:' ('add -Details to see where each switch is in Settings') }
    Write-Field 'Backups:' ('{0} on this PC, in {1}' -f @(Get-BackupFiles $BackupDir).Count, $BackupDir)
    Say ''
}

function Invoke-Apply([object[]]$Settings, [string]$Dir) {
    $states = @($Settings | ForEach-Object { Get-SettingState $_ })
    $alreadySet = @($states | Where-Object { $_.Status -eq 'Done' } | ForEach-Object { $_.Setting })
    $skipped = @($states | Where-Object { $_.Status -eq 'Blocked' } | ForEach-Object {
        [pscustomobject]@{ Id = $_.Setting.Id; Title = $_.Setting.Title; Reason = 'an existing value has an unexpected type, so it was left untouched' }
    })
    $pending = @($states | Where-Object { $_.Status -eq 'Change' })
    $changed = New-Object System.Collections.Generic.List[object]
    $failed = New-Object System.Collections.Generic.List[object]
    $backupFile = $null

    if ($pending.Count -gt 0) {
        $entries = @(foreach ($state in $pending) {
            foreach ($valueState in $state.Values) {
                if ($valueState.Status -eq 'Change') {
                    New-BackupEntry $state.Setting.Id $valueState.Value.Path $valueState.Value.Name $valueState.State
                }
            }
        })
        $backupFile = Save-Backup $entries $Dir 'backup'

        foreach ($state in $pending) {
            try {
                foreach ($valueState in $state.Values) {
                    if ($valueState.Status -ne 'Change') { continue }
                    Write-DwordValue $valueState.Value.Path $valueState.Value.Name $valueState.Value.Target
                    if ((Get-ValueState $valueState.Value).Status -ne 'Done') { throw 'the new value did not stick' }
                }
                $changed.Add($state.Setting)
            }
            catch {
                $failed.Add([pscustomobject]@{ Id = $state.Setting.Id; Title = $state.Setting.Title; Reason = $_.Exception.Message })
            }
        }
    }

    Write-SettingList 'CHANGED NOW' $changed.ToArray() '+' 'Green'
    Write-SettingList 'ALREADY SET BEFORE - left as they were' $alreadySet '=' 'DarkGray'
    Write-SettingList 'SKIPPED' $skipped '!' 'Yellow'
    Write-SettingList 'NOT CHANGED - error' $failed.ToArray() 'x' 'Red'

    Write-Section 'SUMMARY'
    Write-Parts @(
        '  Changed now: ', 'DarkGray', ([string]$changed.Count), 'Green',
        '     Already set: ', 'DarkGray', ([string]$alreadySet.Count), 'White',
        '     Skipped: ', 'DarkGray', ([string]$skipped.Count), $(if ($skipped.Count) { 'Yellow' } else { 'White' }),
        '     Failed: ', 'DarkGray', ([string]$failed.Count), $(if ($failed.Count) { 'Red' } else { 'White' })
    )
    Say ''
    if ($backupFile) {
        Write-Field 'Backup:' $backupFile
        Write-Field 'Next:' 'sign out and back in (or restart) so every change shows up' 'White'
        Write-Field 'Undo:' 'double-click Undo.cmd (undoes everything this script has changed)'
        Write-Field '' ('or run: {0} -Mode Restore (undoes only this run)' -f $Command)
    }
    else {
        Write-Field 'Result:' 'nothing was changed' 'White'
    }
    Say ''
    if ($failed.Count -gt 0 -or $skipped.Count -gt 0) { return 2 }
    return 0
}

function Invoke-Restore([string]$File, [string]$Dir) {
    $entries = @(Read-Backup $File)
    Say ''
    Write-Field 'From:' $File
    if ($entries.Count -eq 0) {
        Say '  The backup is empty. Nothing to restore.'
        return 0
    }

    # Save the current state first, so a restore can itself be undone.
    $current = @(foreach ($entry in $entries) {
        $state = Read-RegValue $entry.Path $entry.Name
        if ($state.Existed -and $state.Kind -ne 'DWord') {
            throw ('{0}\{1} now has an unexpected type, so the restore was not started.' -f $entry.Path, $entry.Name)
        }
        New-BackupEntry $entry.Id $entry.Path $entry.Name $state
    })
    $preRestore = Save-Backup $current $Dir 'pre-restore'

    $failed = @{}
    foreach ($entry in $entries) {
        try {
            if ($entry.Existed) {
                Write-DwordValue $entry.Path $entry.Name ([int]$entry.Value)
                if (-not (Test-DwordEquals (Read-RegValue $entry.Path $entry.Name) ([int]$entry.Value))) { throw 'the old value did not stick' }
            }
            else {
                Remove-RegValue $entry.Path $entry.Name
                if (-not $entry.KeyExisted) { Remove-KeyIfEmpty $entry.Path }
                if ((Read-RegValue $entry.Path $entry.Name).Existed) { throw 'the value could not be removed' }
            }
        }
        catch {
            $failed[$entry.Id] = $_.Exception.Message
        }
    }

    $restored = New-Object System.Collections.Generic.List[object]
    $notRestored = New-Object System.Collections.Generic.List[object]
    foreach ($id in @($entries | ForEach-Object { $_.Id } | Select-Object -Unique)) {
        $title = $id
        if ($CatalogById.ContainsKey($id)) { $title = $CatalogById[$id].Title }
        if ($failed.ContainsKey($id)) { $notRestored.Add([pscustomobject]@{ Id = $id; Title = $title; Reason = $failed[$id] }) }
        else { $restored.Add([pscustomobject]@{ Id = $id; Title = $title }) }
    }

    Write-SettingList 'UNDONE - back to how they were before' $restored.ToArray() '<' 'Green'
    Write-SettingList 'NOT RESTORED - error' $notRestored.ToArray() 'x' 'Red'

    Write-Section 'SUMMARY'
    Write-Parts @(
        '  Undone: ', 'DarkGray', ([string]$restored.Count), 'Green',
        '     Failed: ', 'DarkGray', ([string]$notRestored.Count), $(if ($notRestored.Count) { 'Red' } else { 'White' })
    )
    Say ''
    Write-Field 'Saved:' $preRestore
    Write-Field '' '(the state before this restore, so this restore can be undone too)'
    Write-Field 'Next:' 'sign out and back in (or restart) so every change shows up' 'White'
    Say ''
    if ($notRestored.Count -gt 0) { return 2 }
    return 0
}

function Invoke-RestoreAll([string]$Dir) {
    $files = @(Get-BackupFiles $Dir | Sort-Object Name -Descending)
    if ($files.Count -eq 0) {
        Say ''
        Say '  No backups found. Nothing to restore.'
        Say ''
        return 0
    }
    # Check every file before changing anything.
    foreach ($file in $files) { [void](Read-Backup $file.FullName) }

    $code = 0
    foreach ($file in $files) {
        if ((Invoke-Restore $file.FullName $Dir) -ne 0) { $code = 2 }
    }
    return $code
}

function Get-Snapshot([object[]]$Items) {
    $snapshot = @{}
    foreach ($item in $Items) {
        $state = Read-RegValue $item.Path $item.Name
        $snapshot['{0}|{1}' -f $item.Path, $item.Name] = '{0}/{1}/{2}/{3}' -f $state.KeyExisted, $state.Existed, $state.Kind, $state.Value
    }
    return $snapshot
}

function Invoke-SelfTest {
    $problems = New-Object System.Collections.Generic.List[string]
    $dir = Join-Path ([IO.Path]::GetTempPath()) ('MinimalWindows-SelfTest-' + [guid]::NewGuid().ToString('N'))
    $savedPrefix = $script:KeyPrefix
    $savedQuiet = $script:Quiet
    $script:KeyPrefix = $SelfTestKey
    $script:Quiet = $true
    try {
        [Microsoft.Win32.Registry]::CurrentUser.DeleteSubKeyTree($SelfTestKey, $false)
        $items = @(foreach ($setting in $Catalog) { $setting.Values })
        $recommended = @($Catalog | Where-Object { $_.Recommended })

        # Seed the test key with a mix of states: missing, a different value, already set,
        # and one value of the wrong type that must be left alone.
        $wrongType = $items[0]
        $key = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey((Get-FullPath $wrongType.Path))
        $key.SetValue($wrongType.Name, 'test', [Microsoft.Win32.RegistryValueKind]::String)
        $key.Close()
        for ($i = 1; $i -lt $items.Count; $i++) {
            if ($i % 3 -eq 1) { Write-DwordValue $items[$i].Path $items[$i].Name ($items[$i].Target + 7) }
            elseif ($i % 3 -eq 2) { Write-DwordValue $items[$i].Path $items[$i].Name $items[$i].Target }
        }
        $original = Get-Snapshot $items

        # Two separate Apply runs: recommended first, then everything.
        if ((Invoke-Apply $recommended $dir) -ne 2) { $problems.Add('Apply (recommended) should report the wrong-type value as skipped.') }
        $afterFirstApply = Get-Snapshot $items
        if ((Invoke-Apply $Catalog $dir) -ne 2) { $problems.Add('Apply (all) should report the wrong-type value as skipped.') }

        foreach ($setting in $Catalog) {
            $status = (Get-SettingState $setting).Status
            $expected = 'Done'
            if ($setting.Values -contains $wrongType) { $expected = 'Blocked' }
            if ($status -ne $expected) { $problems.Add(('After Apply, {0} is {1} instead of {2}.' -f $setting.Id, $status, $expected)) }
        }

        # Restore undoes only the newest Apply; Restore -All undoes everything.
        $newest = @(Get-BackupFiles $dir)[-1].FullName
        if ((Invoke-Restore $newest $dir) -ne 0) { $problems.Add('Restore reported a failure.') }
        $afterRestore = Get-Snapshot $items
        foreach ($name in $afterFirstApply.Keys) {
            if ($afterFirstApply[$name] -ne $afterRestore[$name]) {
                $problems.Add(('Restore: {0} is {1}, expected {2}.' -f $name, $afterRestore[$name], $afterFirstApply[$name]))
            }
        }

        if ((Invoke-RestoreAll $dir) -ne 0) { $problems.Add('Restore -All reported a failure.') }
        $afterRestoreAll = Get-Snapshot $items
        foreach ($name in $original.Keys) {
            if ($original[$name] -ne $afterRestoreAll[$name]) {
                $problems.Add(('Restore -All: {0} is {1}, expected {2}.' -f $name, $afterRestoreAll[$name], $original[$name]))
            }
        }
    }
    catch {
        $problems.Add('Unexpected error: ' + $_.Exception.Message)
    }
    finally {
        # Put back the previous state. The test key path below is absolute, so the prefix does not affect it.
        $script:KeyPrefix = $savedPrefix
        $script:Quiet = $savedQuiet
        try { [Microsoft.Win32.Registry]::CurrentUser.DeleteSubKeyTree($SelfTestKey, $false) }
        catch { $problems.Add('Could not remove the test key HKCU\' + $SelfTestKey + ': ' + $_.Exception.Message) }
        if (Test-Path -LiteralPath $dir) { Remove-Item -LiteralPath $dir -Recurse -Force }
    }

    Write-Section 'SELF-TEST'
    if ($problems.Count -gt 0) {
        Say '  FAILED - do not use -Mode Apply on this PC.' 'Red'
        foreach ($problem in $problems) { Say ('  - ' + $problem) 'Red' }
        Say ''
        return 1
    }
    Say '  PASSED - Apply, Restore and Restore -All work on this PC.' 'Green'
    Say ('  Only the temporary test key HKCU\{0} was used, and it has been removed.' -f $SelfTestKey) 'Gray'
    Say '  Your real settings were not touched.' 'Gray'
    Say ''
    return 0
}

function Read-YesNo([string]$Question) {
    $answer = Read-Host $Question
    return ($null -ne $answer -and @('y', 'yes', 't', 'tak') -contains $answer.Trim().ToLowerInvariant())
}

# Start.cmd: self-test, apply the recommended set after one question, then offer Windhawk.
function Invoke-Guided {
    if ([Console]::IsInputRedirected) {
        Stop-Tool 'Guided mode needs a window where you can type. Scripts and AI agents should use -Mode Preview and -Mode Apply.'
    }

    if ((Invoke-SelfTest) -ne 0) { return 1 }

    $code = Invoke-GuidedSettings
    $windhawkCode = Invoke-WindhawkSetup
    if ($code -eq 0) { $code = $windhawkCode }
    return $code
}

function Invoke-GuidedSettings {
    $selected = @(Resolve-Selection $null)
    $states = @($selected | ForEach-Object { Get-SettingState $_ })
    $toDo = @($states | Where-Object { $_.Status -eq 'Change' } | ForEach-Object { $_.Setting })
    $alreadySet = @($states | Where-Object { $_.Status -eq 'Done' } | ForEach-Object { $_.Setting })

    if ($toDo.Count -gt 0) {
        Write-Section 'WHAT WILL CHANGE' ('{0} setting(s)' -f $toDo.Count)
        foreach ($setting in $toDo) {
            Write-SettingRow '+' 'Yellow' $setting
            if ($setting.Note) { Say ('       note: ' + $setting.Note) 'DarkGray' }
        }
    }
    Write-SettingList 'ALREADY SET - will be left as they are' $alreadySet '=' 'DarkGray'

    if ($toDo.Count -eq 0) {
        Write-Section 'RESULT'
        Say '  Everything recommended is already set. Nothing to do.' 'Green'
        Say ''
        return 0
    }

    Say ''
    Say '  The old values are saved first, and you can undo everything later with Undo.cmd.' 'Gray'
    if (-not (Read-YesNo ('  Apply these {0} change(s) now? Type Y and press Enter (anything else cancels)' -f $toDo.Count))) {
        Write-Section 'RESULT'
        Say '  Cancelled. No settings were changed.' 'White'
        Say ''
        return 0
    }

    return (Invoke-Apply $selected $BackupDir)
}

# Windhawk has no official way to install or configure mods from a script, so this step
# only installs the app itself (with winget, after a Y) and shows which mods to click.
function Invoke-WindhawkSetup {
    $exe = Join-Path $env:ProgramFiles 'Windhawk\windhawk.exe'
    Write-Section 'OPTIONAL: DOCK-STYLE TASKBAR AND RESTYLED START (WINDHAWK)'
    Say '  Windhawk is a free, open-source app (windhawk.net) that restyles the taskbar and Start menu.' 'Gray'
    Say '  It is the only part of this project that is not built into Windows. After a big Windows update' 'Gray'
    Say '  a style can look wrong until its author updates it. You can always turn it off or uninstall it.' 'Gray'
    Say ''

    if (Test-Path -LiteralPath $exe) {
        Say '  Windhawk is already installed.' 'Green'
        if (-not (Read-YesNo '  Open Windhawk and show the steps for the dock look? Type Y and press Enter (anything else skips)')) {
            Say '  Skipped.' 'White'
            Say ''
            return 0
        }
    }
    else {
        if (-not (Read-YesNo '  Install Windhawk now? Type Y and press Enter (anything else skips)')) {
            Say '  Skipped. Nothing was installed. You can do it later; see README.' 'White'
            Say ''
            return 0
        }
        $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
        if ($null -eq $winget) {
            Say '  winget (the Windows package manager) is not available on this PC. Nothing was installed.' 'Yellow'
            Say '  You can download Windhawk yourself from https://windhawk.net' 'Yellow'
            Say ''
            return 2
        }
        Say '  Installing the official Windhawk package with winget, which checks the installer''s checksum.' 'White'
        Say '  Windows will ask for administrator approval for the installer.' 'White'
        Say ''
        & $winget.Source install --id RamenSoftware.Windhawk --exact --source winget --accept-package-agreements --accept-source-agreements | Out-Host
        $wingetCode = $LASTEXITCODE
        Say ''
        if (-not (Test-Path -LiteralPath $exe)) {
            Say ('  Windhawk was not installed (winget exit code {0}). Nothing else was changed.' -f $wingetCode) 'Yellow'
            Say ''
            return 2
        }
        Say '  Windhawk is installed.' 'Green'
    }

    Say ''
    Say '  Set it up in the Windhawk window (about 2 minutes). Windows may ask for approval to open it.' 'White'
    Say '    1. Click "Explore", search for "Windows 11 Taskbar Styler", open it and click Install.'
    Say '       In its Settings tab choose the theme "DockLike" and save.'
    Say '    2. Search for "Windows 11 Start Menu Styler" and install it. In its Settings tab choose the'
    Say '       theme "Fluent2Inspired" (works with old and new Start menus) and save.'
    Say '       Other good themes: "Fluid" (new Start menu only) or "OnlySearch" (only the search box).'
    Say '    3. Only if you use more than one keyboard layout: search for "Taskbar tray system icon tweaks",'
    Say '       install it, tick "Hide language bar" in its Settings tab and save.'
    Say '    If nothing changes, sign out and back in.'
    Say ''
    Say '  If something looks wrong: open Windhawk, click the mod and disable it, or uninstall Windhawk' 'Gray'
    Say '  in Settings > Apps > Installed apps. Windows goes back to its normal look.' 'Gray'
    Say ''
    Start-Process -FilePath $exe
    return 0
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

try {
    if ($Only -and $Mode -notin @('Preview', 'Apply')) { Stop-Tool '-Only works with -Mode Preview and -Mode Apply.' }
    if ($All -and $Mode -ne 'Restore') { Stop-Tool '-All works only with -Mode Restore.' }
    if ($BackupFile -and $Mode -ne 'Restore') { Stop-Tool '-BackupFile works only with -Mode Restore.' }
    if ($All -and $BackupFile) { Stop-Tool 'Use either -All or -BackupFile, not both.' }
    if ($Details -and $Mode -ne 'Preview') { Stop-Tool '-Details works only with -Mode Preview.' }

    $pcDescription = Test-Preflight ($Mode -ne 'SelfTest')

    switch ($Mode) {
        'Preview' {
            Show-Preview $pcDescription (Resolve-Selection $Only) $Only $Details.IsPresent
            exit 0
        }
        'Apply' {
            $selected = @(Resolve-Selection $Only)
            Write-Banner ('APPLY - {0} setting(s) selected' -f $selected.Count) $pcDescription
            exit (Invoke-Apply $selected $BackupDir)
        }
        'Restore' {
            Write-Banner 'RESTORE' $pcDescription
            if ($All) { exit (Invoke-RestoreAll $BackupDir) }
            if (-not $BackupFile) {
                $backups = @(Get-BackupFiles $BackupDir)
                if ($backups.Count -eq 0) {
                    Say ''
                    Say '  No backups found. Nothing to restore.'
                    Say ''
                    exit 0
                }
                $BackupFile = $backups[-1].FullName
            }
            exit (Invoke-Restore $BackupFile $BackupDir)
        }
        'SelfTest' {
            Write-Banner 'SELF-TEST - uses a temporary test key only' $pcDescription
            exit (Invoke-SelfTest)
        }
        'Guided' {
            Write-Banner 'GUIDED SETUP' $pcDescription
            exit (Invoke-Guided)
        }
    }
}
catch {
    Write-Host ''
    Write-Host '  ERROR' -ForegroundColor Red
    Write-Host ('  ' + $_.Exception.Message) -ForegroundColor Red
    if ($script:Touched) {
        Write-Host ('  Some settings may already have been changed. They are in the backup; undo with: {0} -Mode Restore' -f $Command)
        Write-Host ''
        exit 2
    }
    Write-Host '  Nothing was changed.'
    Write-Host ''
    exit 1
}
