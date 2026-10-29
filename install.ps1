# Frey installer for Windows (AD116), Windows PowerShell 5.1 or PowerShell 7:
#
#   irm https://raw.githubusercontent.com/lannerk/frey-releases/main/install.ps1 | iex
#
# Reads manifests/frey.json, downloads the Windows package, checks its SHA-256 (and its minisign signature
# when minisign is installed), puts frey.exe in %LOCALAPPDATA%\Programs\Frey and adds that folder to YOUR
# PATH (HKCU: no administrator; the value keeps its %VARIABLES% and its type), for new windows and this one.
# Running it again upgrades (a frey.exe running now is moved aside, not overwritten). Nothing changes on
# the machine until the download checks out.
#
#   $env:FREY_VERSION = "0.9.2"          this version instead of the newest
#   $env:FREY_INSTALL_DIR = "D:\tools"   another folder
#   $env:HTTPS_PROXY = "http://..."      a proxy (otherwise the system's proxy settings)
#
# Uninstall: irm https://raw.githubusercontent.com/lannerk/frey-releases/main/uninstall.ps1 | iex
# (or `frey uninstall`). Keys and models are not asked here: the first `frey` opens its setup panel.

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

function Get-FreyFile([string]$Url, [string]$To) {
    if ($Url -notmatch '^https?://') {
        # A local file (the release workflow's test).
        if (-not (Test-Path -LiteralPath $Url)) { throw "$Url`: no such file" }
        Copy-Item -LiteralPath $Url -Destination $To
        return
    }
    $options = @{ Uri = $Url; OutFile = $To; UseBasicParsing = $true }
    if ($env:HTTPS_PROXY) { $options.Proxy = $env:HTTPS_PROXY }
    try {
        Invoke-WebRequest @options
    } catch {
        $response = $_.Exception.Response
        if ($response -and $response.StatusCode) {
            throw "$Url`: HTTP $([int]$response.StatusCode)"
        }
        throw "no answer from $Url ($($_.Exception.Message)); check the network or HTTPS_PROXY"
    }
}

function Install-Frey {
    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'SilentlyContinue'
    # Windows PowerShell 5.1 may not offer TLS 1.2 by itself; GitHub needs it.
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $repo = 'https://github.com/lannerk/frey-releases'
    $manifestUrl = 'https://raw.githubusercontent.com/lannerk/frey-releases/main/manifests/frey.json'
    if ($env:FREY_INSTALL_REPO) { $repo = $env:FREY_INSTALL_REPO }
    if ($env:FREY_INSTALL_MANIFEST) { $manifestUrl = $env:FREY_INSTALL_MANIFEST }
    # keys/frey.pub, second line (the release signing key).
    $publicKey = 'RWQ2XW3PfirV24ha44zy9+pE4RgJvsrci2wp7Jy//zSPy6Y35D8WQ3J+'
    $dir = Join-Path $env:LOCALAPPDATA 'Programs\Frey'
    if ($env:FREY_INSTALL_DIR) { $dir = [Environment]::ExpandEnvironmentVariables($env:FREY_INSTALL_DIR) }
    $platform = 'windows-x86_64'
    $arch = if ($env:PROCESSOR_ARCHITEW6432) { $env:PROCESSOR_ARCHITEW6432 } else { $env:PROCESSOR_ARCHITECTURE }
    if ($arch -eq 'ARM64') {
        Write-Host 'This is Windows on Arm: the x86_64 build runs under its emulation.'
    } elseif ($arch -ne 'AMD64') {
        throw "this machine is $arch; Frey for Windows is built for x86_64"
    }

    $tmp = Join-Path ([IO.Path]::GetTempPath()) ('frey-install-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmp | Out-Null
    try {
        Get-FreyFile $manifestUrl (Join-Path $tmp 'frey.json')
        $manifest = Get-Content -Raw -Encoding UTF8 (Join-Path $tmp 'frey.json') | ConvertFrom-Json
        if (-not $manifest.version) { throw 'the manifest has no version (not manifests/frey.json?)' }
        $want = if ($env:FREY_VERSION) { $env:FREY_VERSION.TrimStart('v') } else { $manifest.version }
        $minisig = $null
        if ($want -eq $manifest.version) {
            $entry = $manifest.platforms.$platform
            if (-not $entry -or -not $entry.url) { throw "frey $($manifest.version) has no package for $platform" }
            if ($entry.version) { Write-Host "frey $($manifest.version) has no $platform package; installing $($entry.version), the newest one for $platform" }
            $url = $entry.url
            $sum = $entry.sha256
            $minisig = $entry.minisig
        } else {
            # Another release: its package and SHA256SUMS from its Release page.
            $name = "frey-$want-$platform.zip"
            $url = "$repo/releases/download/v$want/$name"
            Get-FreyFile "$repo/releases/download/v$want/SHA256SUMS" (Join-Path $tmp 'SHA256SUMS')
            $line = Get-Content (Join-Path $tmp 'SHA256SUMS') | Where-Object { $_ -match "  $([regex]::Escape($name))$" } | Select-Object -First 1
            if (-not $line) { throw "frey $want has no package for $platform" }
            $sum = ($line -split ' ')[0]
        }
        $name = Split-Path -Leaf $url
        $zip = Join-Path $tmp $name
        Write-Host "Downloading $name"
        Get-FreyFile $url $zip
        $got = (Get-FileHash -Algorithm SHA256 -LiteralPath $zip).Hash.ToLowerInvariant()
        if ($got -ne $sum.ToLowerInvariant()) {
            throw "$name does not match its SHA-256 (expected $sum, got $got); nothing was installed"
        }
        $minisign = Get-Command minisign -ErrorAction SilentlyContinue
        if ($minisign) {
            $sig = "$zip.minisig"
            if ($minisig) {
                [IO.File]::WriteAllText($sig, $minisig)
            } elseif ($url -match '^https?://') {
                Get-FreyFile "$url.minisig" $sig
            } elseif (Test-Path -LiteralPath "$url.minisig") {
                Copy-Item -LiteralPath "$url.minisig" $sig
            }
            if (Test-Path -LiteralPath $sig) {
                & $minisign.Source -V -q -P $publicKey -m $zip -x $sig | Out-Null
                if ($LASTEXITCODE -ne 0) { throw "$name`: the signature does not check against the Frey release key; nothing was installed" }
                Write-Host 'Signature checked (minisign).'
            }
        }
        $unpacked = Join-Path $tmp 'x'
        Expand-Archive -LiteralPath $zip -DestinationPath $unpacked
        if (-not (Test-Path -LiteralPath (Join-Path $unpacked 'frey.exe'))) { throw "$name holds no frey.exe" }

        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        $exe = Join-Path $dir 'frey.exe'
        if (Test-Path -LiteralPath $exe) {
            # A running frey.exe cannot be overwritten, but it can be renamed; frey removes frey.old.exe
            # when it next starts (as after `frey update`).
            $old = Join-Path $dir 'frey.old.exe'
            Remove-Item -LiteralPath $old -Force -ErrorAction SilentlyContinue
            if (Test-Path -LiteralPath $old) { $old = Join-Path $dir ('frey.old.' + [guid]::NewGuid().ToString('N') + '.exe') }
            Move-Item -LiteralPath $exe -Destination $old
        }
        Get-ChildItem -LiteralPath $unpacked | Copy-Item -Destination $dir -Force
        $version = (& $exe --version | Select-Object -First 1) -as [string]
        if ($version -notlike 'frey *') { throw "$exe does not start: $version" }
        Write-Host "Installed $version"
        Write-Host "  -> $exe"

        $path = Update-FreyUserPath 'add' $dir
        if ($path -eq 'added') {
            # Remembered next to frey.exe, so the uninstaller removes only what this added.
            [IO.File]::WriteAllText((Join-Path $dir '.frey-path-added'), "$dir`n")
        }
        $here = @($env:Path -split ';' | Where-Object { $_.TrimEnd('\') -ieq $dir.TrimEnd('\') }).Count -gt 0
        if (-not $here) { $env:Path = "$dir;$env:Path" }
        Write-Host ''
        if ($path -eq 'added') {
            Write-Host "Added $dir to your PATH (new windows, and this one)."
        } else {
            Write-Host "$dir is on your PATH."
        }
        Write-Host 'Run: frey'
        Write-Host 'The first run asks for a provider and its API key.'
    } finally {
        Remove-Item -Recurse -Force -LiteralPath $tmp -ErrorAction SilentlyContinue
    }
}

# `irm | iex` runs this in your own PowerShell: a failure is reported, never `exit` (it would close the
# window). Run as a file (`-File install.ps1`, the tests), a failure is exit code 1.
try {
    Install-Frey
} catch {
    Write-Host "frey install: $($_.Exception.Message)" -ForegroundColor Red
    if ($MyInvocation.MyCommand.Path) { exit 1 }
}
