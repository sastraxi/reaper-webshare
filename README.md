# Webshare: Export stems (for REAPER)

Export your time selection as a set of individual stems **plus** one combined mix, all in a
single render. Works on Windows, macOS and Linux.

**ReaPack repository URL:**

```
https://github.com/sastraxi/reaper-webshare/raw/main/index.xml
```

Already use ReaPack? Paste that into **Extensions → ReaPack → Import repositories...**,
install **Webshare: Export stems** and **ReaImGui** from *Browse packages*, and restart REAPER. Then
run **Script: Webshare - Export stems.lua** from **Actions → Show action list...**. New to
ReaPack? Follow [Install](#install) below.

- Every **top-level track** (not inside a folder) is exported by default. A folder exports
  as one stem containing everything inside it.
- Tick or untick any track, including tracks nested inside folders, to change what's exported.
- **Stems are rendered without master-track FX.** The combined mix gets them as normal.
- Tracks you untick are also left out of the combined mix.
- Mutes are respected. If a stem (or anything inside it) is muted, the panel warns you,
  since the file may not be what you expect.
- Optionally write an **export log**: an `export.md` next to the files with your notes and
  the details of the export (see [Export log](#export-log)).

> Status: early (0.1.0). The export has been checked in REAPER 7.33 on macOS. The panel
> and Windows/Linux are still untested.

## Install

You need REAPER 7 (developed on 7.33). This is installed and updated through ReaPack,
REAPER's package manager. If *Extensions → ReaPack* already exists in REAPER's menu bar,
skip to step 2.

### 1. Install ReaPack (REAPER's package manager)

1. Go to [reapack.com](https://reapack.com) and download the file that matches **your
   REAPER**:
   - macOS on Apple Silicon: *ARM 64-bit* (`.dylib`); Intel Mac: *x86 64-bit* (`.dylib`)
   - Windows: *x86 64-bit* (`.dll`)
   - Linux: *x86 64-bit* or *ARM 64-bit* (`.so`)

   Not sure? *Help → About REAPER* shows the version and build (e.g. `7.33/macOS-arm64`).
2. In REAPER, choose **Options → Show REAPER resource path in explorer/finder...**. A
   Finder/Explorer window opens on REAPER's settings folder.
3. Put the downloaded file into the **`UserPlugins`** folder inside it.
4. Quit and reopen REAPER. An **Extensions** menu with **ReaPack** in it now appears.
   - **macOS blocks it** ("can't be opened" / not verified, or there's simply no
     Extensions menu): ReaPack isn't notarized by Apple, so macOS quarantines the download.
     Either:
     - run this in Terminal (it trusts just this one file), then reopen REAPER:
       ```sh
       xattr -d com.apple.quarantine ~/Library/Application\ Support/REAPER/UserPlugins/reaper_reapack-*.dylib
       ```
     - or open *System Settings → Privacy & Security*, scroll to *Security*, click
       **Open Anyway** (older macOS: **Allow Anyway**) next to the ReaPack message, and
       reopen REAPER. If that button never appears, use the Terminal command.

### 2. Add this repository and install

1. **Extensions → ReaPack → Import repositories...**
2. Paste this URL and click **OK**:
   ```
   https://github.com/sastraxi/reaper-webshare/raw/main/index.xml
   ```
3. **Extensions → ReaPack → Browse packages...**, type `webshare` in the *Filter* box,
   right-click **Webshare: Export stems** → **Install v…**.
4. In the same window, clear the filter and type `ReaImGui`. If its status column is empty
   (not installed), right-click **ReaImGui: ReaScript binding for Dear ImGui** →
   **Install v…**. ReaImGui draws the panel; ReaPack can't install it for us automatically.
5. Click **OK** to download, then **quit and reopen REAPER**. Extensions like ReaImGui
   only load at startup.

Nothing appears in REAPER's menus after installing. A script package adds **actions**
(commands) to REAPER's action list, and you run it from there. See the next step.

### 3. Open the panel

1. In REAPER's menu bar choose **Actions → Show action list...** (shortcut: **?**).
2. In the **Filter** box at the top, type `webshare`. You'll see three actions:
   - **Script: Webshare - Export stems.lua**: opens the panel. This is the main one.
   - **Script: Webshare - Export stems now (no window).lua**: exports straight away
     with the current ticks. Handy on a toolbar button once your ticks are set up.
   - **Script: Webshare - Toggle selected tracks for export.lua**: ticks or unticks the
     selected tracks. Handy in the track right-click menu.
3. Click **Script: Webshare - Export stems.lua**, then click **Run** at the bottom right.
   The *Webshare: Export stems* window opens, listing your tracks.

REAPER always shows scripts as `Script: <file name>.lua`; scripts can't choose a
prettier action name.

To skip the action list next time, give it a toolbar button or keyboard shortcut (see
[Making it quicker to reach](#making-it-quicker-to-reach-optional)).

### 4. Export

1. **Choose an export folder** (optional, once). At the top of the window, click
   **Browse...** and pick a folder, or type or paste a path. This is remembered for all
   projects. Leave it empty to export next to each project file instead.
2. Make a **time selection**: drag across the timeline ruler at the top of the arrange
   view so a range is highlighted. Only that range is exported.
3. In the *Webshare: Export stems* window, check the ticks. Every top-level track is ticked by
   default; tick or untick any track to change that.
4. Click **Export**. REAPER's render window appears briefly while it renders.
5. The files are in a new folder:
   ```
   <export folder>/<project name>/<date time>/     (or <project folder>/Exports/<project name>/<date time>/)
     Master.wav          the combined mix
     stems/Drums.wav     one file per ticked track
     export.md           only if "Write export log" is ticked
   ```

**No Browse button?** REAPER 7.33 has no built-in folder picker for scripts; newer
versions do. Either type or paste the path, or install **js_ReaScriptAPI** (*Extensions →
ReaPack → Browse packages...*, filter `js_ReaScriptAPI`) and restart REAPER.

**Format:** the file format, sample rate, bit depth, dither and normalization come from
REAPER's own **File → Render...** dialog. Set them there once; the export doesn't change them.

### Making it quicker to reach (optional)

- **Toolbar button:** right-click an empty spot on a toolbar → **Customize toolbar...** →
  **Add...** → choose the action → **OK**.
- **Keyboard shortcut:** in the action list, select the action, click **Add...** under
  *Shortcuts for selected action*, and press the key combination you want.
- **Track right-click menu:** **Options → Customize menus/toolbars...** → choose
  **Track control panel context** from the dropdown → **Add...** → choose
  *Webshare - Toggle selected tracks for export.lua*.

### Updating and removing

- **Update:** **Extensions → ReaPack → Synchronize packages** (ReaPack also does this on
  its own schedule).
- **Remove:** **Extensions → ReaPack → Browse packages...**, right-click **Webshare: Export stems** →
  **Uninstall**, then **OK**. Projects keep their tick choices in the `.rpp`; without the
  scripts installed, those choices just do nothing.

### Troubleshooting

| What you see | What to do |
|---|---|
| *"This script needs ReaImGui"* | Click **Yes** to open ReaPack on ReaImGui, install it, then restart REAPER. |
| **Webshare: Export stems** isn't in *Browse packages* | Check the repository was imported (*Extensions → ReaPack → Manage repositories...* should list **webshare**), then *Synchronize packages*. |
| No **Extensions** menu | ReaPack isn't loaded. Check the file is in `UserPlugins` (not a subfolder) and matches your REAPER build (arm64 vs x86_64), then restart. |
| *"Make a time selection first."* | Drag across the timeline ruler so a range is highlighted, then export again. |
| I installed it but can't find it anywhere | It doesn't add a menu. Use **Actions → Show action list...**, filter `webshare` (see [Open the panel](#3-open-the-panel)). |
| Dragging the window to a REAPER docker makes the docker flicker and it won't dock | A ReaImGui bug with empty (collapsed) dockers. Drag it onto a docker that's already open, e.g. one holding the Mixer, instead. |
| *"Render was cancelled or failed"* | You (or REAPER) stopped the render. No files were written, so just export again. |

## The panel

- **Export folder** at the top is shared by every project. Hover over it to see where
  exports will go.
- **reset** appears next to tracks you've changed. It puts them back to the default
  (top-level ticked, nested unticked).
- **(muted)** in orange means something inside that stem is muted, so the file may not
  sound how you expect. Hover over it to see which tracks.
- **(duplicate names)** means two ticked tracks, or a track and the combined mix
  ("Master"), would produce the same file name. Rename one of them.

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
`<export folder>/*/*/export.md`. The `file` paths in the log (`Master.wav`, `stems/Drums.wav`)
are relative to the log and always use `/`, so they work directly as links.

## Development

To run your working copy instead of the ReaPack release:

1. **Actions → Show action list... → New action... → Load ReaScript...**
2. Select the three `Webshare - *.lua` files in this repo's `Rendering/` folder (Cmd-/Ctrl-click).
   In the macOS file dialog, **Cmd-Shift-G** lets you paste a path.

Edits are picked up the next time an action runs. If the ReaPack version is installed
too, both sets of actions show up with the same names. Uninstall the package, or check the
path in the action list, to tell them apart.

`tools/dev-link.sh` (macOS/Linux) and `tools\dev-link.ps1` (Windows) link `Rendering/`
into REAPER's `Scripts/webshare-dev/` folder, if you prefer loading from there. For
portable installs, set `REAPER_RESOURCE_PATH` first.

### Releasing

1. Bump `@version` (and write `@changelog`) in `Rendering/Webshare - Export stems.lua`.
2. Push to `main`. The **deploy** workflow runs `reapack-index`, which adds the new version
   to `index.xml` and commits it. ReaPack users get it on their next sync.

Pushes that don't change `@version` publish nothing. The **check** workflow runs the tests
and `reapack-index --check` on every push and pull request.

`tools/probe_render.lua` runs a real export into `out/` and logs what REAPER reported. Run
it with **Actions → Show action list...** → search `Run ReaScript` →
**ReaScript: Run ReaScript (EEL2 or Lua)...** → pick the file.

### Running tests

The track-selection, layout and export-log logic is plain Lua and is tested outside REAPER:

```sh
brew install lua@5.4    # REAPER's Lua version; or: apt install lua5.4 / scoop install lua
for t in tests/*_test.lua; do "$(brew --prefix lua@5.4)/bin/lua" "$t"; done
```

## Project layout

```
Rendering/            the ReaPack package (entry scripts + lib/); the folder name is its category
index.xml             generated by CI for ReaPack, don't edit by hand
.github/workflows/    check (tests + package validation) and deploy (index.xml)
tests/                plain-Lua tests
tools/                dev helpers (dev-link scripts, probe_render.lua for testing inside REAPER)
AGENTS.md             notes for coding agents (design rules, API facts, open questions)
```
