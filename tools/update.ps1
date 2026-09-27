# Installs or updates Rheizor from github.com/jaimesares/rheizor-ui-releases.
# Started by "Update Rheizor.bat", which must be inside Interface\AddOns.
# Only the Rheizor-* folders are replaced: other addons and your settings
# (the WTF folder) are never touched.
param(
    [Parameter(Mandatory)][string]$AddOns,
    [switch]$Force
)
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$base = "https://raw.githubusercontent.com/jaimesares/rheizor-ui-releases/main"

function Say($text, $color = 'Gray') { Write-Host $text -ForegroundColor $color }
function Stop-Update($text) { Say ""; Say $text Red; exit 1 }

$AddOns = $AddOns.Trim().TrimEnd('\')
if ((Split-Path -Leaf $AddOns) -ne 'AddOns' -or (Split-Path -Leaf (Split-Path -Parent $AddOns)) -ne 'Interface') {
    Stop-Update "Put this .bat inside the game's Interface\AddOns folder and run it again.`nIt is currently in: $AddOns"
}
# The development copy (a git repo) is never updated this way
if (Test-Path -LiteralPath (Join-Path $AddOns '.git')) {
    Stop-Update "This AddOns folder is a git repository (the development copy). It is not updated with the .bat."
}

# Installed version
$installed = $null
$toc = Join-Path $AddOns 'Rheizor-Core\Rheizor-Core.toc'
if (Test-Path -LiteralPath $toc) {
    $line = Get-Content -LiteralPath $toc -Encoding UTF8 | Where-Object { $_ -match '^##\s*Version:\s*(\S+)' } | Select-Object -First 1
    if ($line -match '^##\s*Version:\s*(\S+)') { $installed = $Matches[1] }
}

# Latest published version. latest.txt: the version on the first line and,
# optionally, the zip's SHA-256 on the second (a build republished with the
# same version number is still installed)
try {
    $lines = @((Invoke-WebRequest -UseBasicParsing "$base/latest.txt?t=$([DateTime]::UtcNow.Ticks)").Content -split "`r?`n" |
        ForEach-Object { $_.Trim() } | Where-Object { $_ })
} catch {
    Stop-Update "Could not check the latest version. Are you connected to the internet?`n$($_.Exception.Message)"
}
$latest = $lines[0]
$latestHash = if ($lines.Count -gt 1) { $lines[1].ToLower() } else { $null }
if ($latest -notmatch '^\d+\.\d+\.\d+([-.][0-9A-Za-z.]+)?$') { Stop-Update "The published version is not valid: '$latest'" }

# The build this .bat installed last time (written into Rheizor-Core)
$buildFile = Join-Path $AddOns 'Rheizor-Core\build.txt'
$installedHash = $null
if (Test-Path -LiteralPath $buildFile) { $installedHash = (Get-Content -LiteralPath $buildFile -Raw).Trim().ToLower() }

Say ""
Say "Installed Rheizor: $(if ($installed) { $installed } else { '(none)' })"
Say "Latest version:    $latest" White

$sameBuild = -not $latestHash -or $installedHash -eq $latestHash
if ($installed -eq $latest -and $sameBuild -and -not $Force) {
    Say ""
    Say "You already have the latest version. Nothing to do." Green
    exit 0
}

# Download and unzip into a temporary folder
$work = Join-Path $env:TEMP ("rheizor-update-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force $work | Out-Null
try {
    $zip = Join-Path $work "Rheizor-$latest.zip"
    Say ""
    Say "Downloading Rheizor $latest..."
    try {
        Invoke-WebRequest -UseBasicParsing "$base/releases/Rheizor-$latest.zip" -OutFile $zip
    } catch {
        Stop-Update "Could not download the zip.`n$($_.Exception.Message)"
    }
    $hash = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLower()
    if ($latestHash -and $hash -ne $latestHash) { Stop-Update "The downloaded zip is damaged (its checksum doesn't match). Nothing was changed. Try again later." }
    $unzipped = Join-Path $work 'files'
    Expand-Archive -LiteralPath $zip -DestinationPath $unzipped -Force
    $folders = @(Get-ChildItem -LiteralPath $unzipped -Directory | Where-Object { $_.Name -like 'Rheizor-*' })
    if (-not ($folders | Where-Object { $_.Name -eq 'Rheizor-Core' })) { Stop-Update "The downloaded zip has no Rheizor-Core. Nothing was changed." }

    # Replace each folder as a whole (so files that are no longer used go away)
    foreach ($f in $folders) {
        $dest = Join-Path $AddOns $f.Name
        if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Recurse -Force }
        Move-Item -LiteralPath $f.FullName -Destination $dest
    }
    [IO.File]::WriteAllText($buildFile, "$hash`n")
    Say ""
    Say "Rheizor $latest installed ($($folders.Count) addons)." Green
} finally {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}

if (Get-Process -Name 'Wow*' -ErrorAction SilentlyContinue) {
    Say ""
    Say "The game is running: close it completely and log in again to load the new version (/reload is not enough when there are new addons)." Yellow
} else {
    Say "Log in and type /rz."
}
Say "What's new: https://github.com/jaimesares/rheizor-ui-releases/blob/main/CHANGELOG.md"
