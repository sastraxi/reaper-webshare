# Link Scripts\webshare into REAPER's Scripts folder so edits are live (Windows).
# Uses a directory junction, which needs no admin rights or Developer Mode.
# Override the resource path with $env:REAPER_RESOURCE_PATH (e.g. for portable installs).
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$res = if ($env:REAPER_RESOURCE_PATH) { $env:REAPER_RESOURCE_PATH } else { Join-Path $env:APPDATA 'REAPER' }
$dest = Join-Path $res 'Scripts\webshare'
$target = Join-Path $repo 'Scripts\webshare'

if (Test-Path $dest) {
  $item = Get-Item $dest -Force
  if (-not ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
    throw "$dest exists and is not a link; not touching it"
  }
  $item.Delete()
}
New-Item -ItemType Directory -Force (Join-Path $res 'Scripts') | Out-Null
New-Item -ItemType Junction -Path $dest -Target $target | Out-Null
Write-Host "Linked $dest -> $target"
