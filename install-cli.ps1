$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$ReleaseRepo = "easypanel-io/cli"
$Version = if ($env:EASYPANEL_CLI_VERSION) {
    $env:EASYPANEL_CLI_VERSION.TrimStart("v")
} else {
    "latest"
}

$Architecture = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
switch ($Architecture) {
    "X64" { $Arch = "x86_64" }
    "Arm64" { $Arch = "arm64" }
    default { throw "Unsupported Windows architecture: $Architecture" }
}

$Asset = "easypanel_Windows_$Arch.zip"
$DownloadBase = if ($Version -eq "latest") {
    "https://github.com/$ReleaseRepo/releases/latest/download"
} else {
    "https://github.com/$ReleaseRepo/releases/download/v$Version"
}
if ($env:EASYPANEL_CLI_DOWNLOAD_BASE) {
    $DownloadBase = $env:EASYPANEL_CLI_DOWNLOAD_BASE.TrimEnd("/")
}

$TempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("easypanel-cli-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $TempDir | Out-Null

try {
    $ArchivePath = Join-Path $TempDir $Asset
    $ChecksumsPath = Join-Path $TempDir "checksums.txt"

    Write-Host "Downloading Easypanel CLI $Version for Windows/$Arch..."
    Invoke-WebRequest -UseBasicParsing -Uri "$DownloadBase/$Asset" -OutFile $ArchivePath
    Invoke-WebRequest -UseBasicParsing -Uri "$DownloadBase/checksums.txt" -OutFile $ChecksumsPath

    $ChecksumLine = Get-Content $ChecksumsPath | Where-Object {
        $_ -match ("\s+" + [regex]::Escape($Asset) + "$")
    } | Select-Object -First 1
    if (-not $ChecksumLine) {
        throw "Checksum for $Asset is missing"
    }

    $ExpectedHash = ($ChecksumLine -split "\s+")[0].ToLowerInvariant()
    $ActualHash = (Get-FileHash -Algorithm SHA256 $ArchivePath).Hash.ToLowerInvariant()
    if ($ActualHash -ne $ExpectedHash) {
        throw "Checksum verification failed for $Asset"
    }

    $ExtractDir = Join-Path $TempDir "archive"
    Expand-Archive -Path $ArchivePath -DestinationPath $ExtractDir

    $InstallDir = if ($env:EASYPANEL_CLI_INSTALL_DIR) {
        $env:EASYPANEL_CLI_INSTALL_DIR
    } else {
        Join-Path $env:LOCALAPPDATA "Easypanel\bin"
    }
    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

    Copy-Item (Join-Path $ExtractDir "easypanel.exe") (Join-Path $InstallDir "easypanel.exe") -Force
    Copy-Item (Join-Path $ExtractDir "ep.exe") (Join-Path $InstallDir "ep.exe") -Force

    $UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $PathEntries = if ($UserPath) { $UserPath -split ";" } else { @() }
    if ($PathEntries -notcontains $InstallDir) {
        $NewUserPath = (@($PathEntries) + $InstallDir | Where-Object { $_ }) -join ";"
        [Environment]::SetEnvironmentVariable("Path", $NewUserPath, "User")
        Write-Host "Added $InstallDir to your user PATH. Open a new terminal to use it."
    }

    Write-Host "Installed easypanel.exe and ep.exe in $InstallDir"
    & (Join-Path $InstallDir "easypanel.exe") version
} finally {
    Remove-Item -Recurse -Force $TempDir -ErrorAction SilentlyContinue
}
