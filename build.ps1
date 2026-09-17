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

.PARAMETER Span
    Always split the installer into Setup.exe + .bin data files. Without -Span the build makes a
    single Setup.exe, and only splits it when that does not fit under Inno Setup's single-file limit
    (4,200,000,000 bytes). When the previous build shows that the files will clearly not fit, it
    builds the split version straight away.

.PARAMETER Smallest
    Compress everything as one stream with a 1 GB dictionary (needs an lzma or lzma2 "compression"
    setting). A full build is about 100 MB (5%) smaller, but takes about 16 minutes instead of 2-3 and
    needs about 12 GB of free RAM. Use it for release builds.

.PARAMETER NoInnoUpdate
    Do not install or update Inno Setup 7 with winget - use the installed version as it is.
    Without this switch, every build installs Inno Setup 7 if it is missing and updates it to the
    latest 7.x release.

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
    [switch]$Span,
    [switch]$Smallest,
    [switch]$NoInnoUpdate
)

$ErrorActionPreference = 'Stop'
$buildStart = Get-Date
$ProgressPreference = 'SilentlyContinue'   # Invoke-WebRequest is very slow with the progress bar on
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$Root     = $PSScriptRoot
# (Windows PowerShell 5.1 does not set $PSScriptRoot yet while evaluating param() defaults)
if (-not $Config) { $Config = Join-Path $Root 'config.json' }
$BuildDir = Join-Path $Root 'build'
$CacheDir = Join-Path $BuildDir 'cache'
$DepsDir  = Join-Path $BuildDir 'deps'
$Extras   = Join-Path $Root 'extras'
# Builds always use the latest Inno Setup 7.x (installed/updated with winget). winget lists each major
# version as its own package, so moving to Inno Setup 8 means changing these lines (and the check in the .iss).
$InnoMajor    = 7
$InnoWingetId = 'JRSoftware.InnoSetup.7'
$MinInno      = [version]'7.0.0'
# Largest single Setup.exe. Inno Setup 6.5.2+ allows up to 4,200,000,000 bytes without disk spanning; keep some headroom.
$SetupLimit = 4200000000
$MaxSetup   = $SetupLimit - 64MB

# Everything the script prints is also written to build\build.log (replaced on every run), with the time of each
# line. Each write opens and closes the file, so no handle is left open when the script stops early.
$LogFile  = Join-Path $BuildDir 'build.log'
$Steps    = [ordered]@{}   # Step name -> seconds, saved with the build stats
$stepName = $null
$stepStart = Get-Date
function Write-Log([string[]]$Lines) {
    $stamp = (Get-Date).ToString('HH:mm:ss')
    try { [IO.File]::AppendAllLines($script:LogFile, [string[]]@($Lines | ForEach-Object { "$stamp $_" })) } catch { }
}
function Complete-Step {
    if ($script:stepName) { $script:Steps[$script:stepName] = [math]::Round(((Get-Date) - $script:stepStart).TotalSeconds, 1) }
    $script:stepName = $null
}
function Write-Step([string]$Text) {
    Complete-Step
    $script:stepName = $Text -replace '\s*\(.*$', ''
    $script:stepStart = Get-Date
    Write-Host "`n==> $Text" -ForegroundColor Cyan
    Write-Log @('', "==> $Text")
}
function Write-Info([string]$Text) { Write-Host "    $Text"; Write-Log "    $Text" }
function Write-Good([string]$Text) { Write-Host "    $Text" -ForegroundColor Green; Write-Log "    $Text" }
function Write-Note([string]$Text) { Write-Host "    WARNING: $Text" -ForegroundColor Yellow; Write-Log "    WARNING: $Text" }
function Stop-Build([string]$Text) {
    Write-Host "`nERROR: $Text" -ForegroundColor Red
    Write-Host "       Full log: build\build.log" -ForegroundColor Red
    Write-Log @('', "ERROR: $Text")
    exit 1
}

New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null
try {
    $argText = foreach ($a in $PSBoundParameters.GetEnumerator()) {
        if ($a.Value -is [switch]) { '-' + $a.Key } else { '-{0} "{1}"' -f $a.Key, $a.Value }
    }
    $header = @(
        "BF1942-Installer build - $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))",
        "PowerShell $($PSVersionTable.PSVersion) on $([Environment]::OSVersion.VersionString)",
        "Arguments: $($argText -join ' ')"
    )
    [IO.File]::WriteAllLines($LogFile, [string[]]$header)
} catch { Write-Host "    WARNING: Could not create build\build.log ($($_.Exception.Message))" -ForegroundColor Yellow }

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

# Deletes a file, retrying while an antivirus scanner or Explorer still holds it open (the finished
# installer is often still being scanned when the next build starts)
function Remove-WithRetry([string]$Path) {
    for ($i = 1; $i -le 10; $i++) {
        if (-not (Test-Path -LiteralPath $Path)) { return }
        try { Remove-Item -LiteralPath $Path -Force -ErrorAction Stop; return } catch { }
        if ($i -eq 1) { Write-Info "Waiting for $(Split-Path $Path -Leaf) to be released (antivirus scan?)..." }
        Start-Sleep -Seconds 1
    }
    # Still locked: a scanner can keep an installer open for a long time but still allow a rename,
    # so move it out of the way and delete it later (at the start of this or the next build).
    $aside = "$Path.old-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
    try { Rename-Item -LiteralPath $Path -NewName (Split-Path $aside -Leaf) -Force -ErrorAction Stop } catch {
        Stop-Build "Could not replace $Path - close anything using it (antivirus scan, Explorer preview) and run the build again."
    }
    Write-Note "$(Split-Path $Path -Leaf) was still locked - renamed the old file to $(Split-Path $aside -Leaf); it is deleted once it is released"
    try { Remove-Item -LiteralPath $aside -Force -ErrorAction Stop } catch { }
}

# Deletes leftovers of an earlier build that were still locked back then
function Clear-OldOutput([string]$Dir) {
    foreach ($f in Get-ChildItem -LiteralPath $Dir -Filter '*.old-*' -File -ErrorAction SilentlyContinue) {
        try { Remove-Item -LiteralPath $f.FullName -Force -ErrorAction Stop } catch { }
    }
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

# Uninstall keys of the Inno Setup major version this build uses (per-user and per-machine installs)
function Get-InnoKeys {
    $name = "Inno Setup $($script:InnoMajor)_is1"
    return @("HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$name",
             "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$name",
             "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\$name")
}

# Installed version from Apps & features (ISCC.exe has no version resource), or $null
function Get-InnoVersion {
    foreach ($key in Get-InnoKeys) {
        if (Test-Path $key) {
            $dv = (Get-ItemProperty $key).PSObject.Properties['DisplayVersion']
            if ($dv -and $dv.Value) { try { return [version]$dv.Value } catch { } }
        }
    }
    return $null
}

# ISCC.exe of the right major version. One found on PATH is only used when its banner shows that version.
function Find-Iscc {
    $candidates = New-Object System.Collections.Generic.List[string]
    foreach ($key in Get-InnoKeys) {
        if (Test-Path $key) {
            $loc = (Get-ItemProperty $key).PSObject.Properties['InstallLocation']
            if ($loc -and $loc.Value) { $candidates.Add((Join-Path $loc.Value 'ISCC.exe')) }
        }
    }
    $folder = "Inno Setup $($script:InnoMajor)\ISCC.exe"
    $candidates.Add((Join-Path $env:LOCALAPPDATA "Programs\$folder"))
    $candidates.Add((Join-Path $env:ProgramFiles $folder))
    if (${env:ProgramFiles(x86)}) { $candidates.Add((Join-Path ${env:ProgramFiles(x86)} $folder)) }
    foreach ($c in $candidates) { if ($c -and (Test-Path -LiteralPath $c)) { return $c } }
    $cmd = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    if ($cmd -and ((& $cmd.Source '/?' 2>&1 | Select-Object -First 1) -match "Inno Setup $($script:InnoMajor) ")) { return $cmd.Source }
    return $null
}

# Installs Inno Setup with winget, or updates it to the latest release of the same major version.
# Returns $false when winget is missing or fails; the build then uses whatever is installed.
function Update-InnoSetup([bool]$Installed) {
    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
        Write-Note 'winget was not found - cannot install or update Inno Setup automatically'
        return $false
    }
    $verb = if ($Installed) { 'upgrade' } else { 'install' }
    Write-Info "$(if ($Installed) { 'Checking for an Inno Setup update' } else { 'Installing Inno Setup' }) with winget ($InnoWingetId)..."
    $ErrorActionPreference = 'Continue'
    $out = & winget $verb --id $InnoWingetId --exact --accept-package-agreements --accept-source-agreements --disable-interactivity 2>&1
    $code = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    Write-Log (@("    --- winget $verb output ---") + @($out | ForEach-Object { "    | $_" }) + @("    --- exit code $code ---"))
    # 0x8A15002B: no newer version available. 0x8A15002C: no applicable upgrade (e.g. a pinned package).
    if ($code -eq 0 -or $code -eq -1978335189 -or $code -eq -1978335188) { return $true }
    Write-Note "winget $verb failed (exit code $code) - see build\build.log"
    return $false
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
$before = Get-InnoVersion
if (-not $NoInnoUpdate -and -not ($DownloadOnly -and -not $iscc)) {
    if (Update-InnoSetup ([bool]$iscc)) {
        $iscc = Find-Iscc
        $after = Get-InnoVersion
        if ($after -and $before -and $after -ne $before) { Write-Good "Updated Inno Setup $before to $after" }
        elseif ($after -and -not $before) { Write-Good "Installed Inno Setup $after" }
    }
}
if (-not $iscc -and -not $DownloadOnly) {
    Stop-Build "Inno Setup $InnoMajor was not found. Install it with:`n         winget install --id $InnoWingetId --exact`n       or download it from https://jrsoftware.org/isdl.php"
}
if ($iscc) {
    # (the Inno Setup script also refuses to compile on versions older than 7.0)
    $innoVersion = Get-InnoVersion
    if ($innoVersion -and $innoVersion -lt $MinInno) { Stop-Build "Inno Setup $innoVersion is too old - version $MinInno or newer is required." }
    Write-Info "Using Inno Setup $(if ($innoVersion) { $innoVersion } else { $InnoMajor }) ($iscc)"
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
Clear-OldOutput $outputDir

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
$compression = Get-Setting 'compression' 'lzma2/ultra64'
Add-Define 'Compression'     $compression
# LZMA2 compresses 256 MB blocks in parallel; each block thread uses 2 CPU threads and about 1.3 GB of RAM.
# -Smallest compresses one stream with a 1 GB dictionary instead (the most a 32-bit Setup supports).
$freeGB = [math]::Floor((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory * 1KB / 1GB)
if ($Smallest -and $compression -notmatch '^lzma') { Stop-Build "-Smallest needs an lzma or lzma2 compression setting (config.json has ""$compression"")." }
if ($Smallest) {
    $lzmaThreads = 1
    $lzmaDict = 1048576
    $compressionInfo = 'one stream with a 1 GB dictionary (-Smallest, about 16 minutes for a full build)'
    if ($freeGB -lt 12) { Write-Note "-Smallest needs about 12 GB of free RAM ($freeGB GB free) - the build may run out of memory" }
} else {
    $lzmaThreads = [int][math]::Max(1, [math]::Min([math]::Min([Environment]::ProcessorCount, [math]::Floor($freeGB / 1.5)), 32))
    $lzmaDict = 0
    $compressionInfo = "$lzmaThreads parallel blocks ($([Environment]::ProcessorCount) CPU threads, $freeGB GB RAM free)"
}
Add-Define 'LzmaThreads'     $lzmaThreads
Add-Define 'LzmaDict'        $lzmaDict
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
    Write-Log @('', 'Components are ready in build\deps (-DownloadOnly).')
    exit 0
}

# ---------------------------------------------------------------------------------------------
# 7. Compile
# ---------------------------------------------------------------------------------------------
Write-Step 'Compiling the installer (this takes a few minutes for a full build)'
Write-Info "Compression: $compression, $compressionInfo"
$outputBase = (Get-Setting 'outputBaseFilename' 'BF1942_Expansions_Setup') -replace '[\\/:*?"<>|]', '_'
$setup = Join-Path $outputDir "$outputBase.exe"
$started = Get-Date

# Progress is measured in bytes: ISCC prints "Compressing: <file>" as it starts each file, so every
# file listed before the current one is done. The total is the size of everything the script can pack.
$sizes = @{}
$sources = @($DepsDir) + @($extrasFound.Values | ForEach-Object { Join-Path $Extras $_.path })
if (-not $Quick) {
    $sources += @(Get-ChildItem -LiteralPath $GameDir -Force | Where-Object { $_.Name -ne 'Tools' } | ForEach-Object { $_.FullName })
}
foreach ($f in Get-ChildItem -LiteralPath $sources -Recurse -File -Force -ErrorAction SilentlyContinue) { $sizes[$f.FullName] = $f.Length }
# The game's own Font.rfa is excluded in the .iss (the font comes from the font option instead)
$sizes.Remove((Join-Path $GameDir 'Mods\bf1942\Archives\Font.rfa'))
$totalBytes = [math]::Max([double]1, [double]($sizes.Values | Measure-Object -Sum).Sum)

# The bar is redrawn in place on the line below the step header (Write-Progress would draw at the top of the window)
$barLive = -not [Console]::IsOutputRedirected
$barWidth = 30
$barText = ''
function Write-Bar([int]$Pct, [string]$Status) {
    if (-not $script:barLive) { return }
    $filled = [int]($script:barWidth * $Pct / 100)
    $text = '    [{0}{1}] {2,3}% {3}' -f ('#' * $filled), ('.' * ($script:barWidth - $filled)), $Pct, $Status
    $max = 119
    try { $max = [Console]::WindowWidth - 1 } catch { }
    if ($text.Length -gt $max) { $text = $text.Substring(0, $max) }
    Write-Host ("`r" + $text.PadRight($script:barText.Length)) -NoNewline
    $script:barText = $text
}
function Clear-Bar {
    if (-not $script:barLive -or -not $script:barText) { return }
    Write-Host ("`r" + (' ' * $script:barText.Length) + "`r") -NoNewline
    $script:barText = ''
}

# Output files of this build: Setup.exe, plus <OutputBase>-1.bin, -2.bin, ... when it is split
function Get-SliceFiles {
    return @(Get-ChildItem -LiteralPath $outputDir -Filter "$outputBase-*.bin" -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match ('^' + [regex]::Escape($outputBase) + '-\d+\.bin$') } | Sort-Object Name)
}

# Runs ISCC once and returns its exit code. SpanBuild defines SPAN (Setup.exe + .bin files).
function Invoke-Iscc([bool]$SpanBuild) {
    # Remove the output of an earlier build, so no stale .bin files are left next to the new Setup.exe
    Remove-WithRetry $setup
    foreach ($old in Get-SliceFiles) { Remove-WithRetry $old.FullName }
    $isccArgs = @()
    if ($Quick) { $isccArgs += '/DQUICK' }
    if ($SpanBuild) { $isccArgs += '/DSPAN' }
    $isccArgs += (Join-Path $Root 'installer\BF1942-Installer.iss')
    $attempt = Get-Date
    $doneBytes = 0
    $lastBytes = 0
    $lastDraw = [DateTime]::MinValue
    $lastPct = 0
    $script:log = New-Object System.Collections.Generic.List[string]
    Write-Bar 0 'Preparing the script...'
    # ISCC writes errors to stderr - with 'Stop', Windows PowerShell would turn the first one into an exception
    $ErrorActionPreference = 'Continue'
    & $iscc @isccArgs 2>&1 | ForEach-Object {
        $line = "$_"
        $script:log.Add($line)
        if ($line -match '^\s*Compressing: (.+?)(\s{3}\(.*\))?$') {
            $doneBytes += $lastBytes
            # Inno Setup 7 prints extended-length paths (\\?\C:\..., \\?\UNC\server\share\...)
            $file = $Matches[1] -replace '^\\\\\?\\UNC\\', '\\' -replace '^\\\\\?\\', ''
            $lastBytes = $sizes[$file]
            if (-not $lastBytes) { $lastBytes = 0 }
            if (((Get-Date) - $lastDraw).TotalMilliseconds -ge 250) {
                $lastPct = [math]::Min(99, [int](100 * $doneBytes / $totalBytes))
                $elapsed = ((Get-Date) - $attempt).ToString('mm\:ss')
                Write-Bar $lastPct "$elapsed - $(Split-Path $file -Leaf)"
                $lastDraw = Get-Date
            }
        } elseif ($line -match '^\s*Compressing Setup program executable') {
            Write-Bar 99 'Finishing Setup.exe...'
        } elseif ($line -match '^\s*Warning:') {
            # Print the warning on its own line, then redraw the bar below it
            $keep = $script:barText
            Clear-Bar
            Write-Note ($line.Trim() -replace '^Warning:\s*', '')
            if ($keep) { Write-Bar $lastPct ($keep -replace '^.*?%\s*', '') }
        }
    }
    $code = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    $label = "Compile attempt ($(if ($SpanBuild) { 'split' } else { 'single Setup.exe' }))"
    $seconds = [math]::Round(((Get-Date) - $attempt).TotalSeconds, 1)
    $script:Steps[$label] = $seconds + [double]$script:Steps[$label]
    Write-Log (@("    --- $label output ---") + @($script:log | ForEach-Object { "    | $_" }) + @("    --- exit code $code after $seconds s ---"))
    if ($code -eq 0) { Write-Bar 100 'Done' }
    if ($script:barLive) { Write-Host '' }
    $script:barText = ''
    return $code
}

# Decide between a single Setup.exe and a split build before compiling. The compressed size is only known
# afterwards, so it is predicted from how well the previous build with the same settings compressed.
$historyFile = Join-Path $BuildDir 'size-history.json'
$historyKey = "$(if ($Quick) { 'quick' } else { 'full' })|$compression$(if ($Smallest) { '|smallest' })"
$history = @{}
if (Test-Path -LiteralPath $historyFile) {
    try {
        foreach ($prop in (Get-Content -LiteralPath $historyFile -Raw | ConvertFrom-Json).PSObject.Properties) { $history[$prop.Name] = $prop.Value }
    } catch { Write-Note 'build\size-history.json is unreadable - ignoring it' }
}
# Until this machine has built with these settings, fall back to the typical ratio committed in size-seed.json
$ratio = $null
if ($history.ContainsKey($historyKey) -and $history[$historyKey].inputBytes -gt 0) {
    $ratio = $history[$historyKey].outputBytes / $history[$historyKey].inputBytes
    $ratioSource = 'the last build with these settings'
} else {
    try {
        $seed = (Get-Content -LiteralPath (Join-Path $Root 'size-seed.json') -Raw -ErrorAction Stop | ConvertFrom-Json).$historyKey
        if ($seed.ratio -gt 0) { $ratio = [double]$seed.ratio; $ratioSource = 'the typical compression in size-seed.json (measured on the MoonGamers build)' }
    } catch { }
}
$split = [bool]$Span
if ($Span) {
    Write-Info 'Building Setup.exe + .bin files (-Span)'
} elseif ($totalBytes + 16MB -le $MaxSetup) {
    Write-Info ('{0:N0} MB to pack - fits in a single Setup.exe' -f ($totalBytes / 1MB))
} elseif ($ratio) {
    $predicted = $totalBytes * $ratio
    Write-Info ('{0:N0} MB to pack - predicted installer size {1:N0} MB (from {2})' -f ($totalBytes / 1MB), ($predicted / 1MB), $ratioSource)
    # Only skip the single-file attempt when the prediction is clearly over the limit
    if ($predicted -gt $MaxSetup * 1.02) {
        Write-Note 'That does not fit in a single Setup.exe - building Setup.exe + .bin files'
        $split = $true
    }
} else {
    Write-Info ('{0:N0} MB to pack - trying a single Setup.exe (no earlier build or size-seed.json entry to predict the compressed size from)' -f ($totalBytes / 1MB))
}

# If a single Setup.exe turns out not to fit, build it again split into .bin files.
$exitCode = Invoke-Iscc $split
if (-not $split) {
    $tooLarge = $false
    if ($exitCode -ne 0) {
        $tooLarge = [bool]($log | Where-Object { $_ -match 'too large|exceed|DiskSpanning' })
    } elseif ((Get-Item -LiteralPath $setup).Length -gt $MaxSetup) {
        $tooLarge = $true
    }
    if ($tooLarge) {
        Write-Note 'The installer does not fit in a single Setup.exe - building it again as Setup.exe + .bin files'
        $exitCode = Invoke-Iscc $true
    }
}
if ($exitCode -ne 0) {
    $log | Select-Object -Last 25 | ForEach-Object { Write-Host "    $_" }
    Stop-Build "Inno Setup failed (exit code $exitCode). See the messages above, or the full Inno Setup output in the log."
}

$item = Get-Item -LiteralPath $setup
$slices = Get-SliceFiles
$outputBytes = $item.Length + [double](($slices | Measure-Object Length -Sum).Sum)
Complete-Step
$history[$historyKey] = [pscustomobject]@{
    inputBytes   = $totalBytes
    outputBytes  = $outputBytes
    date         = (Get-Date).ToString('s')
    split        = [bool]$slices.Count
    totalSeconds = [math]::Round(((Get-Date) - $script:buildStart).TotalSeconds, 1)
    stepSeconds  = [pscustomobject]$Steps
}
try { [pscustomobject]$history | ConvertTo-Json | Set-Content -LiteralPath $historyFile -Encoding UTF8 } catch { Write-Note "Could not save build\size-history.json ($($_.Exception.Message))" }
Write-Host ''
Write-Good ("Built {0} in {1:N1} minutes" -f $item.Name, ((Get-Date) - $started).TotalMinutes)
if ($slices.Count) {
    $total = $outputBytes
    Write-Info ("Split into {0} + {1} .bin file(s), {2:N0} bytes in total. Players need all of them in the same folder." -f $item.Name, $slices.Count, $total)
    foreach ($f in @($item) + $slices) {
        Write-Info ("{0}  {1:N0} bytes  SHA-256: {2}" -f $f.Name, $f.Length, (Get-Sha256 $f.FullName))
    }
} else {
    Write-Info ("Size:    {0:N0} bytes ({1:N0} MB below the single-file limit of {2:N0} bytes)" -f $item.Length, (($SetupLimit - $item.Length) / 1e6), $SetupLimit)
    Write-Info ("SHA-256: {0}" -f (Get-Sha256 $setup))
}
if ($Quick) { Write-Note 'This was a -Quick build without the game files - do not distribute it.' }
