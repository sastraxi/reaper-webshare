# Stem Export for REAPER

Export your time selection as a set of individual stems **plus** one combined mix, all in a
single render. Works on Windows, macOS and Linux.

- Every **top-level track** (not inside a folder) is exported by default. A folder exports
  as one stem containing everything inside it.
- Tick or untick any track, including tracks nested inside folders, to change what's exported.
- **Stems are rendered without master-track FX.** The combined mix gets them as normal.
- Tracks you untick are also left out of the combined mix.
- Mutes are respected. If a stem (or anything inside it) is muted, the panel warns you,
  since the file may not be what you expect.
- Optionally write an **export log**: an `export.md` next to the files with your notes and
  the details of the export (see [Export log](#export-log)).

> Status: early (0.1.0). The export has been checked in REAPER 7.33 on macOS; the panel
> and Windows/Linux are still untested.

## Requirements

- [REAPER](https://www.reaper.fm) 7.x (developed on 7.33)
- [ReaPack](https://reapack.com) with **ReaImGui** installed from the default
  *ReaTeam Extensions* repository (*Extensions → ReaPack → Browse packages*, search "ReaImGui")

## Getting started (development)

1. **Clone** the repo anywhere.
2. **Link the scripts into REAPER** so your edits show up immediately:
   - macOS / Linux: `tools/dev-link.sh`
   - Windows (PowerShell): `tools\dev-link.ps1`

   If you use a portable REAPER install, set `REAPER_RESOURCE_PATH` first. REAPER shows
   its path under *Options → Show REAPER resource path*.
3. **Register the actions:** in REAPER, open *Actions → Show action list → New action →
   Load ReaScript…*, go to `Scripts/webshare/` in the resource folder, and load all three
   `webshare_*.lua` files.
4. **Try it:** run **Stem export** from the action list. Make a time selection, check the
   track list, and click **Export**. Files go to
   `Exports/<project name>/<date time>/` next to your project: the combined mix and
   log at the top, the per-track files in `stems/`.

After the first load you don't need to reload anything. Edits to the `.lua` files apply
the next time you run the action.

## Actions

| Action | What it does |
|---|---|
| **Stem export** | Opens the dockable panel: track tree with checkboxes, mute warnings, Export button |
| **Export stems** | Exports immediately using the current ticks, with no panel |
| **Toggle stem export for selected tracks** | If any selected track is off, turns them all on; otherwise turns them all off |

You can bind these to keys, add them to a toolbar, or add **Toggle** to the track
right-click menu (*Options → Customize menus/toolbars → Track control panel context*).

## How it works

Each track's choice is saved in the project file. Tracks you haven't touched follow the
default (top-level on, nested off), so new tracks just work.

Export temporarily sets REAPER's render options to *stems + master mix* over the time
selection, selects the exported tracks, and stops unticked top-level tracks from feeding
the master. It then renders once and puts everything back the way it was. Your format,
sample rate, dither and normalization settings come from REAPER's normal Render dialog.

**Good to know:** a stem contains the track's own FX (including instrument plugins), but
not effects it reaches through a send to another track (for example a shared reverb bus).
Those show up in the bus's own stem, if that bus is exported.

## Export log

Tick **Write export log** in the panel (remembered per project) and every export also
writes `export.md` into its folder. Whatever you type in **Notes** becomes the body, and
its first line becomes the title. Notes are cleared after each export, like a commit
message.

```markdown
---
title: "Chorus rework"
date: 2026-10-12T23:03:15-04:00
project: "Song A"
timeSelection:
  start: "1:12.000"
  end: "1:48.500"
  startMeasure: "37.1.00"
  endMeasure: "55.3.00"
  seconds: 36.5
mix:
  file: "Master.wav"
  peak: -6.29
  lufsI: -20.34
  lufsSMax: -18.51
  lufsMMax: -15.79
  lra: 2.7
stems:
  - track: "Drums"
    file: "stems/Drums.wav"
    peak: -11.09
    lufsI: -21.23
    lufsSMax: -19.53
    lufsMMax: -18.66
    lra: 2.1
    mutedTracks: ["Kick In"]
excludedFromMix: ["Scratch Vox"]
reaperVersion: "7.33/macOS-arm64"
tags: [stemExport]
---

# Chorus rework

Tightened the chorus drums, new bass line in bar 3.
```

Loudness numbers come from REAPER's own render statistics (peak in dBFS, LUFS
integrated / short-term max / momentary max, loudness range in LU), so logging adds no
extra render time.

The front matter is plain YAML, so a static site generator like
[Eleventy](https://www.11ty.dev) can read it directly. For example, point a collection at
`Exports/*/*/export.md`. The `file` paths in the log (`Master.wav`, `stems/Drums.wav`)
are relative to the log and always use `/`, so they work directly as links.

## Running tests

The track-selection and export-log logic is plain Lua and is tested outside REAPER:

```sh
brew install lua@5.4    # REAPER's Lua version; or: apt install lua5.4 / scoop install lua
for t in tests/*_test.lua; do "$(brew --prefix lua@5.4)/bin/lua" "$t"; done
```

## Project layout

```
Scripts/webshare/     the ReaPack package (entry scripts + lib/)
tests/                plain-Lua tests
tools/                dev helpers (dev-link scripts, probe_render.lua for testing inside REAPER)
AGENTS.md             notes for coding agents (design rules, API facts, open questions)
```
