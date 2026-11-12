[CmdletBinding()]
param(
  [string]$Version = 'latest',
  [string]$InstallDir = (Join-Path $env:LOCALAPPDATA 'Programs\DartStylizer')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repository = 'nguyenthang1597/dart_stylizer'
$asset = 'dart_stylizer-windows-X64.exe'

if ($Version -ne 'latest' -and $Version -notmatch '^v[0-9]+\.[0-9]+\.[0-9]+$') {
  throw 'Version must be latest or a stable tag such as v0.2.0.'
}
if ($env:PROCESSOR_ARCHITECTURE -ne 'AMD64') {
  throw "No prebuilt Windows release is available for $env:PROCESSOR_ARCHITECTURE."
}
if ([string]::IsNullOrWhiteSpace($InstallDir)) {
  throw 'InstallDir cannot be empty.'
}

if ($Version -eq 'latest') {
  $downloadBase = "https://github.com/$repository/releases/latest/download"
} else {
  $downloadBase = "https://github.com/$repository/releases/download/$Version"
}

$tempDir = Join-Path ([IO.Path]::GetTempPath()) "dart-stylizer-$([guid]::NewGuid().ToString('N'))"
$stagedPath = $null
try {
  New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
  New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null

  Invoke-WebRequest -Uri "$downloadBase/$asset" -OutFile (Join-Path $tempDir $asset)
  Invoke-WebRequest -Uri "$downloadBase/SHA256SUMS" -OutFile (Join-Path $tempDir 'SHA256SUMS')

  $expectedChecksum = $null
  foreach ($line in Get-Content (Join-Path $tempDir 'SHA256SUMS')) {
    $parts = $line -split '\s+', 2
    if ($parts.Count -eq 2 -and $parts[1].TrimStart('*') -ceq $asset) {
      $expectedChecksum = $parts[0]
      break
    }
  }
  if ([string]::IsNullOrWhiteSpace($expectedChecksum)) {
    throw "Checksum entry not found for $asset."
  }

  $downloadPath = Join-Path $tempDir $asset
  $actualChecksum = (Get-FileHash -Path $downloadPath -Algorithm SHA256).Hash
  if ($actualChecksum -ne $expectedChecksum) {
    throw "Checksum verification failed for $asset."
  }

  $stagedPath = Join-Path $InstallDir ".dart_stylizer-$([guid]::NewGuid().ToString('N')).tmp"
  Copy-Item -Path $downloadPath -Destination $stagedPath
  $targetPath = Join-Path $InstallDir 'dart_stylizer.exe'
  Move-Item -Path $stagedPath -Destination $targetPath -Force
  $stagedPath = $null

  Write-Output "Installed Dart Stylizer ($Version) to $targetPath"
  Write-Output 'Run this script again to update to a newer release.'
} finally {
  if ($stagedPath -and (Test-Path $stagedPath)) {
    Remove-Item -Path $stagedPath -Force
  }
  if (Test-Path $tempDir) {
    Remove-Item -Path $tempDir -Recurse -Force
  }
}
