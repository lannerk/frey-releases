# Frey uninstaller for Windows (AD116), Windows PowerShell 5.1 or PowerShell 7:
#
#   irm https://raw.githubusercontent.com/lannerk/frey-releases/main/uninstall.ps1 | iex
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/lannerk/frey-releases/main/uninstall.ps1))) -Purge
#
# Removes frey.exe and the files installed with it, the PATH entry the installer (or frey's /settings)
# added - only that one, and only when it added it - and %USERPROFILE%\.frey\updates (the old versions
# `frey update` kept). %USERPROFILE%\.frey itself - API keys, sessions, configuration - stays unless you
# say so: it asks once, and -Purge (or $env:FREY_PURGE = "1") deletes it without asking. `frey uninstall`
# does the same without the network.
#
#   $env:FREY_INSTALL_DIR = "D:\tools"   where frey was installed, when not the default and not on PATH

# --- frey path begin (the same text in install.ps1, uninstall.ps1 and frey's winpath.ps1; tools/install_test.py checks)
function Update-FreyUserPath([string]$Action, [string]$Dir) {
    # The user's PATH as Windows keeps it (HKCU\Environment): read without expanding %VARIABLES%, written
    # back with the same type (REG_EXPAND_SZ or REG_SZ), every other entry left as it was. $env:FREY_PATH_KEY names
    # another key under HKCU (the tests).
    $sub = if ($env:FREY_PATH_KEY) { $env:FREY_PATH_KEY } else { 'Environment' }
    $norm = { param([string]$p) [Environment]::ExpandEnvironmentVariables($p).Trim().TrimEnd('\').ToLowerInvariant() }
    $want = & $norm $Dir
    $key = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($sub)
    try {
        $exists = $key.GetValueNames() -contains 'Path'
        $raw = ''
        $kind = [Microsoft.Win32.RegistryValueKind]::ExpandString
        if ($exists) {
            $raw = [string]$key.GetValue('Path', '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
            $kind = $key.GetValueKind('Path')
        }
        $parts = @($raw -split ';')
        $found = @($parts | Where-Object { $_ -ne '' -and (& $norm $_) -eq $want }).Count -gt 0
        if ($Action -eq 'query') { if ($found) { return 'present' } else { return 'absent' } }
        if ($Action -eq 'add') {
            if ($found) { return 'present' }
            # Appended in the value's own style: after a trailing `;` it gets one too, so taking it out again
            # gives back exactly what was there.
            if ($raw -eq '') { $new = $Dir } elseif ($raw.EndsWith(';')) { $new = $raw + $Dir + ';' } else { $new = $raw + ';' + $Dir }
        } elseif ($Action -eq 'remove') {
            if (-not $found) { return 'absent' }
            $new = (@($parts | Where-Object { $_ -eq '' -or (& $norm $_) -ne $want })) -join ';'
        } else {
            throw "Update-FreyUserPath: unknown action $Action"
        }
        # The value keeps its type (REG_SZ stays REG_SZ, REG_EXPAND_SZ stays REG_EXPAND_SZ): what was
        # there means what it meant, and taking the entry out gives back the very same value.
        if ($kind -ne [Microsoft.Win32.RegistryValueKind]::String) { $kind = [Microsoft.Win32.RegistryValueKind]::ExpandString }
        $key.SetValue('Path', $new, $kind)
    } finally {
        $key.Close()
    }
    if ($sub -eq 'Environment') {
        # WM_SETTINGCHANGE "Environment": Explorer reloads it, so windows opened from now on have the new PATH.
        if (-not ('Frey.EnvBroadcast' -as [type])) {
            Add-Type -Namespace Frey -Name EnvBroadcast -MemberDefinition '[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern System.IntPtr SendMessageTimeout(System.IntPtr hWnd, uint Msg, System.UIntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out System.UIntPtr lpdwResult);'
        }
        $result = [UIntPtr]::Zero
        [void][Frey.EnvBroadcast]::SendMessageTimeout([IntPtr]0xffff, 0x1A, [UIntPtr]::Zero, 'Environment', 2, 5000, [ref]$result)
    }
    if ($Action -eq 'add') { 'added' } else { 'removed' }
}
# --- frey path end

function Uninstall-Frey([bool]$Purge) {
    $ErrorActionPreference = 'Stop'
    $default = Join-Path $env:LOCALAPPDATA 'Programs\Frey'
    if ($env:FREY_INSTALL_DIR) {
        $dir = [Environment]::ExpandEnvironmentVariables($env:FREY_INSTALL_DIR)
    } elseif (Test-Path -LiteralPath (Join-Path $default 'frey.exe')) {
        $dir = $default
    } else {
        $found = Get-Command frey.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        $dir = if ($found) { Split-Path -Parent $found.Source } else { $default }
    }
    $exe = Join-Path $dir 'frey.exe'
    $running = @(Get-Process frey -ErrorAction SilentlyContinue | Where-Object { $_.Path -and ($_.Path -ieq $exe) })
    if ($running.Count) {
        throw "frey is running from $exe (process $($running[0].Id)); close it, then run this again"
    }
    if (Test-Path -LiteralPath $exe) {
        Remove-Item -LiteralPath $exe -Force
        Write-Host "Removed $exe"
    } else {
        Write-Host "No frey.exe in $dir (if it is elsewhere, set FREY_INSTALL_DIR)"
    }
    foreach ($leftover in 'frey.old.exe', 'frey.new.exe', 'VERSION', 'EULA.md', 'THIRD-PARTY-NOTICES') {
        Remove-Item -LiteralPath (Join-Path $dir $leftover) -Force -ErrorAction SilentlyContinue
    }
    Get-ChildItem -LiteralPath $dir -Filter 'frey.old.*.exe' -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue

    $marker = Join-Path $dir '.frey-path-added'
    if (Test-Path -LiteralPath $marker) {
        $added = ([string](Get-Content -LiteralPath $marker -Encoding UTF8 | Select-Object -First 1)).TrimStart([char]0xFEFF).Trim()
        if (-not $added) { $added = $dir }
        if ((Update-FreyUserPath 'remove' $added) -eq 'removed') { Write-Host "Removed $added from your PATH" }
        Remove-Item -LiteralPath $marker -Force
        $env:Path = (@($env:Path -split ';' | Where-Object { $_.TrimEnd('\') -ine $added.TrimEnd('\') })) -join ';'
    } else {
        Write-Host 'PATH not changed (frey did not add an entry to it)'
    }
    if ((Test-Path -LiteralPath $dir) -and -not (Get-ChildItem -LiteralPath $dir -Force)) {
        Remove-Item -LiteralPath $dir -Force
        Write-Host "Removed $dir"
    }

    $data = Join-Path $env:USERPROFILE '.frey'
    $updates = Join-Path $data 'updates'
    if (Test-Path -LiteralPath $updates) {
        Remove-Item -Recurse -Force -LiteralPath $updates
        Write-Host "Removed $updates"
    }
    if (Test-Path -LiteralPath $data) {
        if (-not $Purge -and [Environment]::UserInteractive -and -not [Console]::IsInputRedirected) {
            $answer = Read-Host "Also delete $data (API keys, sessions, configuration)? [y/N]"
            if ($answer -match '^(y|yes)$') { $Purge = $true }
        }
        if ($Purge) {
            Remove-Item -Recurse -Force -LiteralPath $data
            Write-Host "Removed $data"
        } else {
            Write-Host "Kept $data (API keys, sessions, configuration); -Purge deletes it too"
        }
    }
    Write-Host 'frey is uninstalled.'
}

# `irm | iex` runs this in your own PowerShell: a failure is reported, never `exit` (it would close the
# window). Run as a file (`-File uninstall.ps1 -Purge`, the tests), a failure is exit code 1.
try {
    Uninstall-Frey (($args -contains '-Purge') -or ($env:FREY_PURGE -eq '1'))
} catch {
    Write-Host "frey uninstall: $($_.Exception.Message)" -ForegroundColor Red
    if ($MyInvocation.MyCommand.Path) { exit 1 }
}
