# Link Rendering\ into REAPER's Scripts folder as webshare-dev\ so edits are live (Windows).
# Uses a different folder than a ReaPack install (Scripts\webshare\) so both can coexist.
# Uses a directory junction, which needs no admin rights or Developer Mode.
# Override the resource path with $env:REAPER_RESOURCE_PATH (e.g. for portable installs).
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$res = if ($env:REAPER_RESOURCE_PATH) { $env:REAPER_RESOURCE_PATH } else { Join-Path $env:APPDATA 'REAPER' }
$dest = Join-Path $res 'Scripts\webshare-dev'
$target = Join-Path $repo 'Rendering'

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
