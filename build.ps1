<#
.SYNOPSIS
    Builds the Battlefield 1942 & Expansions installer.

.DESCRIPTION
    1. Creates config.json from config.example.json on first run and gives it a unique AppId.
    2. Downloads every component listed in components.json from its official source into
       build\cache and checks its SHA-256.
    3. Stages the components in build\deps (downloads + the tracked files in components\).
    4. Detects the optional files you placed in extras\ (Punkbuster42, fonts, ...).
    5. Compiles the VulkanCheck helper and writes build\generated.iss.
    6. Runs Inno Setup and writes the installer to output\.

.PARAMETER GameDir
    Folder that contains BF1942.exe. Overrides "gameDir" in config.json.

.PARAMETER Config
    Path to the configuration file. Default: config.json in the repository root.

.PARAMETER DownloadOnly
    Download and stage the components, then stop (no Inno Setup compile).

.PARAMETER Quick
    Compile without the game files - a fast check that the script and components are OK.

.PARAMETER Force
    Download every component again, even if it is already in build\cache.

.PARAMETER InstallInnoSetup
    Install Inno Setup 6 with winget if it is not found.

.EXAMPLE
    .\build.ps1 -GameDir "C:\EA Games\Battlefield 1942"

.EXAMPLE
    .\build.ps1 -Quick
#>
[CmdletBinding()]
param(
    [string]$GameDir,
    [string]$Config,
    [switch]$DownloadOnly,
    [switch]$Quick,
    [switch]$Force,
    [switch]$InstallInnoSetup
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'   # Invoke-WebRequest is very slow with the progress bar on
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$Root     = $PSScriptRoot
# (Windows PowerShell 5.1 does not set $PSScriptRoot yet while evaluating param() defaults)
if (-not $Config) { $Config = Join-Path $Root 'config.json' }
$BuildDir = Join-Path $Root 'build'
$CacheDir = Join-Path $BuildDir 'cache'
$DepsDir  = Join-Path $BuildDir 'deps'
$Extras   = Join-Path $Root 'extras'
$MinInno  = [version]'6.4.0'   # ExecAndCaptureOutput and array literals in [Code]

function Write-Step([string]$Text) { Write-Host "`n==> $Text" -ForegroundColor Cyan }
function Write-Info([string]$Text) { Write-Host "    $Text" }
function Write-Good([string]$Text) { Write-Host "    $Text" -ForegroundColor Green }
function Write-Note([string]$Text) { Write-Host "    WARNING: $Text" -ForegroundColor Yellow }
function Stop-Build([string]$Text) { Write-Host "`nERROR: $Text" -ForegroundColor Red; exit 1 }

# ---------------------------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------------------------

# Value of a config.json setting, or $Default when it is missing or empty
function Get-Setting([string]$Name, $Default) {
    $p = $script:Cfg.PSObject.Properties[$Name]
    if ($p -and $null -ne $p.Value -and "$($p.Value)" -ne '') { return $p.Value }
    return $Default
}

# Text for an ISPP string literal: no double quotes, and no single quotes (the text is also used in Pascal strings)
function ConvertTo-IssText([string]$Text) {
    return $Text.Replace('"', [string][char]0x201D).Replace("'", [string][char]0x2019)
}

# SHA-256 of a file. Antivirus scanners can hold a file open for a while after it is written, so retry.
function Get-Sha256([string]$Path) {
    for ($i = 1; $i -le 30; $i++) {
        try { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash } catch { Start-Sleep -Seconds 1 }
    }
    return $null
}

function Get-BytesSha256([byte[]]$Bytes) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-', '') } finally { $sha.Dispose() }
}

# Reads a file, retrying while an antivirus scanner still holds it open
function Read-AllBytes([string]$Path) {
    for ($i = 1; $i -le 30; $i++) {
        try { return , [IO.File]::ReadAllBytes($Path) } catch { Start-Sleep -Seconds 1 }
    }
    return , [IO.File]::ReadAllBytes($Path)
}

# Returns the bytes of a download, verified against its SHA-256. Downloads are handled in memory so
# that an antivirus scan of the cached copy cannot block the build; build\cache is only a speed-up.
# NoCache: never write the archive to disk (some antivirus products flag files inside the dgVoodoo2 zip).
function Get-Download([string]$Url, [string]$FileName, [string]$Sha256, [bool]$NoCache) {
    $path = Join-Path $CacheDir $FileName
    $want = $null
    if ($Sha256) { $want = $Sha256.ToUpper() }
    if (-not $NoCache -and (Test-Path -LiteralPath $path) -and -not $Force) {
        $bytes = $null
        try { $bytes = Read-AllBytes $path } catch { }
        if ($bytes -and (-not $want -or (Get-BytesSha256 $bytes) -eq $want)) { return , $bytes }
        Write-Note "$FileName in build\cache is unreadable or out of date - downloading it again"
    }
    Write-Info "Downloading $FileName"
    try {
        $client = New-Object Net.WebClient
        $client.Headers['User-Agent'] = 'BF1942-Installer-build'
        $bytes = $client.DownloadData($Url)
    } catch {
        Stop-Build "Download failed: $Url`n       $($_.Exception.Message)"
    }
    if ($want) {
        $actual = Get-BytesSha256 $bytes
        if ($actual -ne $want) {
            Stop-Build "SHA-256 mismatch for $FileName`n       expected $want`n       got      $actual`n       The file on the server changed. Check the project page before updating components.json."
        }
    }
    if (-not $NoCache) {
        try { [IO.File]::WriteAllBytes($path, $bytes) } catch { Write-Note "Could not cache $FileName ($($_.Exception.Message))" }
    }
    return , $bytes
}

function Expand-ZipEntries([byte[]]$Bytes, [string]$Name, $Map, [string]$Dest) {
    Add-Type -AssemblyName System.IO.Compression
    $zip = New-Object IO.Compression.ZipArchive (New-Object IO.MemoryStream (, $Bytes))
    try {
        foreach ($pair in $Map.PSObject.Properties) {
            $entry = $zip.GetEntry($pair.Name)
            if (-not $entry) { Stop-Build "'$($pair.Name)' was not found in $Name" }
            $in = $entry.Open()
            $fs = [IO.File]::Create((Join-Path $Dest $pair.Value))
            try { $in.CopyTo($fs) } finally { $fs.Dispose(); $in.Dispose() }
        }
    } finally { $zip.Dispose() }
}

function New-TempDir {
    $tmp = Join-Path $BuildDir ('tmp-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmp | Out-Null
    return $tmp
}

function Expand-TarEntries([byte[]]$Bytes, [string]$Name, $Map, [string]$Dest) {
    $tar = Join-Path $env:SystemRoot 'System32\tar.exe'
    if (-not (Test-Path $tar)) { Stop-Build 'tar.exe was not found (it ships with Windows 10 1803 and newer).' }
    $tmp = New-TempDir
    try {
        $archive = Join-Path $tmp $Name
        [IO.File]::WriteAllBytes($archive, $Bytes)
        $names = @($Map.PSObject.Properties | ForEach-Object { $_.Name })
        & $tar -xzf $archive -C $tmp @names
        if ($LASTEXITCODE -ne 0) { Stop-Build "tar could not extract $Name" }
        foreach ($pair in $Map.PSObject.Properties) {
            Copy-Item -LiteralPath (Join-Path $tmp $pair.Name) -Destination (Join-Path $Dest $pair.Value)
        }
    } finally { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }
}

# The June 2010 DirectX redistributable is a self-extracting archive
function Expand-DirectXSfx([byte[]]$Bytes, [string]$Name, [string]$Dest) {
    $tmp = New-TempDir
    try {
        $sfx = Join-Path $tmp $Name
        [IO.File]::WriteAllBytes($sfx, $Bytes)
        $p = Start-Process -FilePath $sfx -ArgumentList @('/Q', ('/T:"' + $Dest + '"')) -Wait -PassThru
        if ($p.ExitCode -ne 0 -or -not (Test-Path (Join-Path $Dest 'DXSETUP.exe'))) {
            Stop-Build "Could not extract $Name (exit code $($p.ExitCode))"
        }
    } finally { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }
}

function Find-Iscc {
    $candidates = New-Object System.Collections.Generic.List[string]
    $cmd = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    if ($cmd) { $candidates.Add($cmd.Source) }
    foreach ($key in 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Inno Setup 6_is1',
                     'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Inno Setup 6_is1',
                     'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Inno Setup 6_is1') {
        if (Test-Path $key) {
            $loc = (Get-ItemProperty $key).PSObject.Properties['InstallLocation']
            if ($loc -and $loc.Value) { $candidates.Add((Join-Path $loc.Value 'ISCC.exe')) }
        }
    }
    $candidates.Add((Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe'))
    if (${env:ProgramFiles(x86)}) { $candidates.Add((Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe')) }
    $candidates.Add((Join-Path $env:ProgramFiles 'Inno Setup 6\ISCC.exe'))
    foreach ($c in $candidates) { if ($c -and (Test-Path -LiteralPath $c)) { return $c } }
    return $null
}

# ---------------------------------------------------------------------------------------------
# 1. Configuration
# ---------------------------------------------------------------------------------------------
Write-Step 'Configuration'
if (-not (Test-Path -LiteralPath $Config)) {
    Copy-Item -LiteralPath (Join-Path $Root 'config.example.json') -Destination $Config
    Write-Good "Created $(Split-Path $Config -Leaf) from config.example.json - edit it to customise your installer."
}
try { $script:Cfg = Get-Content -LiteralPath $Config -Raw | ConvertFrom-Json }
catch { Stop-Build "$(Split-Path $Config -Leaf) is not valid JSON: $($_.Exception.Message)" }

# Every installer needs its own AppId, otherwise it would upgrade/uninstall someone else's install
$appId = "$(Get-Setting 'appId' '')".Trim('{', '}', ' ')
$parsed = [guid]::Empty
if (-not [guid]::TryParse($appId, [ref]$parsed)) {
    $appId = [guid]::NewGuid().ToString().ToUpper()
    $json = Get-Content -LiteralPath $Config -Raw
    if ($json -match '"appId"\s*:\s*"[^"]*"') {
        $json = $json -replace '"appId"\s*:\s*"[^"]*"', ('"appId": "' + $appId + '"')
    } else {
        $json = $json -replace '^\s*\{', ("{`r`n  `"appId`": `"$appId`",")
    }
    [IO.File]::WriteAllText($Config, $json)
    Write-Good "Generated a unique AppId for your installer: $appId (saved in config.json)"
}
$appId = $appId.ToUpper()

$exclude = @(Get-Setting 'exclude' @()) | ForEach-Object { "$_".ToLower() }

if (-not $GameDir) { $GameDir = Get-Setting 'gameDir' 'game' }
if (-not [IO.Path]::IsPathRooted($GameDir)) { $GameDir = Join-Path $Root $GameDir }
$GameDir = [IO.Path]::GetFullPath($GameDir)
$hasGame = Test-Path -LiteralPath (Join-Path $GameDir 'BF1942.exe')
if (-not $hasGame -and -not $Quick -and -not $DownloadOnly) {
    Stop-Build "BF1942.exe was not found in '$GameDir'.`n       Copy your Battlefield 1942 folder to 'game\' in the repository, set ""gameDir"" in config.json,`n       or run: .\build.ps1 -GameDir ""C:\path\to\Battlefield 1942"""
}
if ($hasGame) {
    Write-Info "Game folder: $GameDir"
    foreach ($xp in 'xpack1', 'xpack2') {
        if (-not (Test-Path -LiteralPath (Join-Path $GameDir "Mods\$xp"))) {
            Write-Note "Mods\$xp is missing - The Road to Rome (xpack1) / Secret Weapons of WWII (xpack2) will not be included"
        }
    }
}

# ---------------------------------------------------------------------------------------------
# 2. Inno Setup
# ---------------------------------------------------------------------------------------------
Write-Step 'Inno Setup'
$iscc = Find-Iscc
if (-not $iscc -and $InstallInnoSetup) {
    Write-Info 'Installing Inno Setup 6 with winget...'
    winget install --id JRSoftware.InnoSetup --exact --accept-package-agreements --accept-source-agreements
    $iscc = Find-Iscc
}
if (-not $iscc -and -not $DownloadOnly) {
    Stop-Build "Inno Setup 6 was not found. Install it with:`n         winget install JRSoftware.InnoSetup`n       or run .\build.ps1 -InstallInnoSetup, or download it from https://jrsoftware.org/isdl.php"
}
if ($iscc) {
    # ISCC.exe has no version resource - read the installed version from Apps & features when available
    # (the Inno Setup script also refuses to compile on versions older than 6.4)
    $innoVersion = $null
    foreach ($key in 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Inno Setup 6_is1',
                     'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Inno Setup 6_is1',
                     'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Inno Setup 6_is1') {
        if (-not $innoVersion -and (Test-Path $key)) {
            $dv = (Get-ItemProperty $key).PSObject.Properties['DisplayVersion']
            if ($dv -and $dv.Value) { try { $innoVersion = [version]$dv.Value } catch { } }
        }
    }
    if ($innoVersion -and $innoVersion -lt $MinInno) { Stop-Build "Inno Setup $innoVersion is too old - version $MinInno or newer is required." }
    Write-Info "Found Inno Setup $(if ($innoVersion) { $innoVersion } else { '6' }) ($iscc)"
}

# ---------------------------------------------------------------------------------------------
# 3. Components (downloaded)
# ---------------------------------------------------------------------------------------------
Write-Step 'Components'
$manifest = Get-Content -LiteralPath (Join-Path $Root 'components.json') -Raw | ConvertFrom-Json
New-Item -ItemType Directory -Force -Path $CacheDir, $DepsDir | Out-Null

# DXVK 2.7.1 is the newest release that works with Battlefield 1942 - never build with another version
$DxvkVersion = '2.7.1'
$dxvk = @($manifest.components | Where-Object { $_.id -eq 'dxvk' })
if ($dxvk.Count -ne 1 -or $dxvk[0].version.TrimStart('v') -ne $DxvkVersion -or
    @($dxvk[0].downloads | Where-Object { $_.url -notlike "*/v$DxvkVersion/*" }).Count -gt 0) {
    Stop-Build "components.json must use DXVK $DxvkVersion - newer DXVK releases do not work with Battlefield 1942."
}

$included = @{}
foreach ($c in $manifest.components) {
    $dest = Join-Path $DepsDir $c.id
    if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Recurse -Force }
    if ($exclude -contains $c.id.ToLower()) {
        if ($c.required) { Stop-Build "'$($c.id)' is required and cannot be excluded in config.json." }
        Write-Info "- $($c.name): excluded in config.json"
        continue
    }
    New-Item -ItemType Directory -Path $dest | Out-Null
    foreach ($d in @($c.downloads)) {
        $noCache = $false
        $cacheSetting = $d.PSObject.Properties['cache']
        if ($cacheSetting -and $cacheSetting.Value -eq $false) { $noCache = $true }
        $bytes = Get-Download $d.url $d.fileName $d.sha256 $noCache
        switch ($d.type) {
            'file' {
                $out = Join-Path $dest $d.fileName
                [IO.File]::WriteAllBytes($out, $bytes)
                # Unpinned downloads (e.g. the latest VC++ redistributable) must carry a valid signature instead
                $signer = $d.PSObject.Properties['signedBy']
                if ($signer -and $signer.Value) {
                    $sig = Get-AuthenticodeSignature -LiteralPath $out
                    if ($sig.Status -ne 'Valid' -or $sig.SignerCertificate.Subject -notlike "CN=$($signer.Value),*") {
                        Remove-Item -LiteralPath (Join-Path $CacheDir $d.fileName) -Force -ErrorAction SilentlyContinue
                        Stop-Build "$($d.fileName) is not validly signed by $($signer.Value) (status: $($sig.Status))."
                    }
                }
            }
            'zip'         { Expand-ZipEntries $bytes $d.fileName $d.extract $dest }
            'tar.gz'      { Expand-TarEntries $bytes $d.fileName $d.extract $dest }
            'directx-sfx' { Expand-DirectXSfx $bytes $d.fileName $dest }
            default       { Stop-Build "Unknown download type '$($d.type)' for $($c.id) in components.json" }
        }
    }
    # Tracked files for this component (configs, bundled LGPL binaries) - components\<id>\
    $overlay = Join-Path $Root "components\$($c.id)"
    if (Test-Path -LiteralPath $overlay) { Copy-Item -Path (Join-Path $overlay '*') -Destination $dest -Recurse -Force }
    $included[$c.id] = $c
    $pin = ''
    if (@($c.downloads).Count -gt 0 -and -not (@($c.downloads) | Where-Object { $_.sha256 })) { $pin = ' (not pinned - signature verified)' }
    Write-Good "+ $($c.name) $($c.version)$pin"
}
foreach ($c in $included.Values) {
    foreach ($r in @($c.PSObject.Properties['requires'] | ForEach-Object { $_.Value })) {
        if ($r -and -not $included.ContainsKey($r)) { Stop-Build "'$($c.id)' needs '$r', which is excluded in config.json." }
    }
}

# ---------------------------------------------------------------------------------------------
# 4. Extras (optional files with no official download, kept in extras)
# ---------------------------------------------------------------------------------------------
Write-Step 'Extras (optional, from the extras\ folder)'
$extrasFound = @{}
foreach ($e in $manifest.extras) {
    $path = Join-Path $Extras $e.path
    if ($exclude -contains $e.id.ToLower()) { Write-Info "- $($e.name): excluded in config.json"; continue }
    if (-not (Test-Path -LiteralPath $path)) { Write-Info "- $($e.name): not found (extras\$($e.path))"; continue }
    $extrasFound[$e.id] = $e
    if ($e.sha256 -and (Get-Sha256 $path) -ne $e.sha256.ToUpper()) {
        Write-Note "$($e.name): extras\$($e.path) is not the tested version (SHA-256 differs) - it will still be included"
    } else {
        Write-Good "+ $($e.name)"
    }
}

# ---------------------------------------------------------------------------------------------
# 5. VulkanCheck helper
# ---------------------------------------------------------------------------------------------
Write-Step 'VulkanCheck helper'
$vkSrc = Join-Path $Root 'installer\VulkanCheck.cs'
$vkExe = Join-Path $BuildDir 'VulkanCheck.exe'
if (-not (Test-Path -LiteralPath $vkExe) -or (Get-Item $vkSrc).LastWriteTimeUtc -gt (Get-Item $vkExe).LastWriteTimeUtc) {
    $csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe'
    if (-not (Test-Path $csc)) { Stop-Build ".NET Framework 4 compiler not found: $csc" }
    & $csc /nologo /optimize+ /platform:x86 /target:exe "/out:$vkExe" $vkSrc
    if ($LASTEXITCODE -ne 0) { Stop-Build 'VulkanCheck.cs failed to compile.' }
    Write-Good 'Compiled build\VulkanCheck.exe'
} else {
    Write-Info 'build\VulkanCheck.exe is up to date'
}

# ---------------------------------------------------------------------------------------------
# 6. build\generated.iss (settings + versions for the Inno Setup script)
# ---------------------------------------------------------------------------------------------
Write-Step 'Writing build\generated.iss'
$serverAddress = "$(Get-Setting 'serverAddress' '')".Trim()
$serverName = ConvertTo-IssText (Get-Setting 'serverShortcutName' 'Battlefield 1942 - Join Server')
$serverName = ($serverName -replace '[\\/:*?"<>|]', '').Trim()
$outputDir = Join-Path $Root 'output'

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add('; Generated by build.ps1 - do not edit. Change config.json / components.json instead.')
function Add-Define([string]$Name, $Value) {
    if ($Value -is [bool]) { $Value = [int]$Value }
    if ($Value -is [int]) { $lines.Add("#define $Name $Value") } else { $lines.Add("#define $Name ""$Value""") }
}
Add-Define 'GameDir'         $GameDir
Add-Define 'Deps'            $DepsDir
Add-Define 'Extras'          $Extras
Add-Define 'BuildDir'        $BuildDir
Add-Define 'OutputDir'       $outputDir
Add-Define 'AppIdGuid'       $appId
Add-Define 'AppName'         (ConvertTo-IssText (Get-Setting 'appName' 'Battlefield 1942 & Expansions'))
Add-Define 'InstallerTitle'  (ConvertTo-IssText (Get-Setting 'installerTitle' 'BF1942 & Expansions Installer'))
Add-Define 'CreatedBy'       (ConvertTo-IssText (Get-Setting 'createdBy' ''))
Add-Define 'AppPublisher'    (ConvertTo-IssText (Get-Setting 'appPublisher' 'BF1942 Community'))
Add-Define 'OutputBase'      ((Get-Setting 'outputBaseFilename' 'BF1942_Expansions_Setup') -replace '[\\/:*?"<>|]', '_')
Add-Define 'DefaultDir'      (ConvertTo-IssText (Get-Setting 'defaultInstallDir' '{sd}\EA Games\Battlefield 1942'))
Add-Define 'AppendEAGames'   ([bool](Get-Setting 'appendEAGamesFolder' $true))
Add-Define 'GenerateSerial'  ([bool](Get-Setting 'generateSerial' $true))
Add-Define 'StateKey'        (ConvertTo-IssText (Get-Setting 'registryStateKey' 'SOFTWARE\BF1942 Installer'))
Add-Define 'Compression'     (Get-Setting 'compression' 'lzma2/ultra64')
Add-Define 'ServerAddress'   $serverAddress
Add-Define 'ServerName'      $serverName
$icon = Join-Path $GameDir 'bf1942.ico'
if (Test-Path -LiteralPath $icon) { Add-Define 'GameIcon' $icon } else { Add-Define 'GameIcon' '' }

# Welcome/Finish page artwork: branding\WizardImage100.bmp (+ optional 125..250 for high DPI)
$images = @(100, 125, 150, 175, 200, 225, 250 | ForEach-Object { Join-Path $Root "branding\WizardImage$_.bmp" } | Where-Object { Test-Path -LiteralPath $_ })
Add-Define 'WizardImages' ($images -join ',')
if ($images.Count) { Write-Info "Using $($images.Count) wizard image(s) from branding\" }

foreach ($c in $manifest.components) {
    $id = $c.id
    Add-Define "Has_$id" ([bool]$included.ContainsKey($id))
    Add-Define "Ver_$id" $c.version
    Add-Define "Url_$id" $c.homepage
    $first = @($c.downloads) | Where-Object { $_.type -eq 'file' } | Select-Object -First 1
    if ($first) { Add-Define "File_$id" $first.fileName } else { Add-Define "File_$id" '' }
}
foreach ($e in $manifest.extras) { Add-Define "Has_$($e.id)" ([bool]$extrasFound.ContainsKey($e.id)) }

$generated = Join-Path $BuildDir 'generated.iss'
[IO.File]::WriteAllLines($generated, $lines, (New-Object Text.UTF8Encoding $true))
Write-Good 'Done'

if ($DownloadOnly) {
    Write-Host "`nComponents are ready in build\deps. Run .\build.ps1 again without -DownloadOnly to compile." -ForegroundColor Green
    exit 0
}

# ---------------------------------------------------------------------------------------------
# 7. Compile
# ---------------------------------------------------------------------------------------------
Write-Step 'Compiling the installer (this takes a few minutes for a full build)'
$isccArgs = @()
if ($Quick) { $isccArgs += '/DQUICK' }
$isccArgs += (Join-Path $Root 'installer\BF1942-Installer.iss')
$started = Get-Date

# Progress is measured in bytes: ISCC prints "Compressing: <file>" as it starts each file, so every
# file listed before the current one is done. The total is the size of everything the script can pack.
$sizes = @{}
$sources = @($DepsDir) + @($extrasFound.Values | ForEach-Object { Join-Path $Extras $_.path })
if (-not $Quick) {
    $sources += @(Get-ChildItem -LiteralPath $GameDir -Force | Where-Object { $_.Name -ne 'Tools' } | ForEach-Object { $_.FullName })
}
foreach ($f in Get-ChildItem -LiteralPath $sources -Recurse -File -Force -ErrorAction SilentlyContinue) { $sizes[$f.FullName] = $f.Length }
$totalBytes = [math]::Max([double]1, [double]($sizes.Values | Measure-Object -Sum).Sum)

$ProgressPreference = 'Continue'
$activity = 'Compiling the installer'
$doneBytes = 0
$lastBytes = 0
$lastDraw = [DateTime]::MinValue
$log = New-Object System.Collections.Generic.List[string]
Write-Progress -Activity $activity -Status 'Preparing the script...' -PercentComplete 0
# ISCC writes errors to stderr - with 'Stop', Windows PowerShell would turn the first one into an exception
$ErrorActionPreference = 'Continue'
& $iscc @isccArgs 2>&1 | ForEach-Object {
    $line = "$_"
    $log.Add($line)
    if ($line -match '^\s*Compressing: (.+?)(\s{3}\(.*\))?$') {
        $doneBytes += $lastBytes
        $file = $Matches[1]
        $lastBytes = $sizes[$file]
        if (-not $lastBytes) { $lastBytes = 0 }
        if (((Get-Date) - $lastDraw).TotalMilliseconds -ge 250) {
            $pct = [math]::Min(99, [int](100 * $doneBytes / $totalBytes))
            $elapsed = ((Get-Date) - $started).ToString('mm\:ss')
            Write-Progress -Activity $activity -Status "$pct% - $elapsed elapsed - $(Split-Path $file -Leaf)" -PercentComplete $pct
            $lastDraw = Get-Date
        }
    } elseif ($line -match '^\s*Compressing Setup program executable') {
        Write-Progress -Activity $activity -Status 'Finishing Setup.exe...' -PercentComplete 99
    } elseif ($line -match '^\s*Warning:') {
        Write-Note ($line.Trim() -replace '^Warning:\s*', '')
    }
}
$exitCode = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
Write-Progress -Activity $activity -Completed
$ProgressPreference = 'SilentlyContinue'
if ($exitCode -ne 0) {
    $log | Select-Object -Last 25 | ForEach-Object { Write-Host "    $_" }
    Stop-Build "Inno Setup failed (exit code $exitCode). See the messages above."
}

$setup = Join-Path $outputDir ((Get-Setting 'outputBaseFilename' 'BF1942_Expansions_Setup') -replace '[\\/:*?"<>|]', '_')
$setup = "$setup.exe"
$item = Get-Item -LiteralPath $setup
Write-Host ''
Write-Good ("Built {0} in {1:N1} minutes" -f $item.Name, ((Get-Date) - $started).TotalMinutes)
Write-Info ("Size:    {0:N0} bytes ({1:N0} MB below the 2 GB single-file limit)" -f $item.Length, ((2147483648 - $item.Length) / 1MB))
Write-Info ("SHA-256: {0}" -f (Get-Sha256 $setup))
if ($Quick) { Write-Note 'This was a -Quick build without the game files - do not distribute it.' }
