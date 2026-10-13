# AGENTS.md

Guidance for coding agents working in this repo. Human-oriented docs are in `README.md`.

## What this is

A REAPER ReaScript package (Lua 5.4 + ReaImGui, distributed via ReaPack) that renders the
**time selection** as one file per exported track ("stems") plus one **combined mix**, in a
single render pass. It must run unchanged on Windows, macOS and Linux.

## Product rules (agreed with the user; don't change without asking)

- **Which tracks export:** every top-level track (`GetTrackDepth == 0`) by default; nested
  tracks don't. One boolean per track, no tri-state modes. Users override either way.
- **Overrides** are stored in `P_EXT:webshare:stem` (`"1"`/`"0"`, absent = default).
  Store an override only when it differs from the default (`selection.override_for`), so
  tracks keep following the default until a user deviates.
- **Overlap is allowed:** a folder and a child of that folder may both be stems.
- **Stems skip master FX; the combined mix keeps them.** Stems include the track's own FX
  chain (including instrument plugins) and, for folders, all children. Sends to buses
  outside the track are *not* in its stem: single-pass for now, by user decision.
- **Excluded top-level tracks are left out of the combined mix.** Done by temporarily
  setting `B_MAINSEND = 0`, never by muting.
- **Mute is respected, files are always written.** Warn when a stem or any of its
  descendants is muted. Never warn about muted tracks that aren't rendered.
- **Export folder:** a *user* preference shared by all projects, not stored per project.
  It lives in `SetExtState('webshare', 'export_folder', …, persist)` and is edited at the
  top of the panel (text field + Browse). When empty (the default), exports go next to the
  project file instead. The folder picker is `GetUserFileName(3, …)` where available (it's
  not in 7.33), else `JS_Dialog_BrowseForFolder` (js_ReaScriptAPI), else typing or
  pasting only.
- **Output layout:** one folder per project, one per export. The project is the top
  level, and only the per-track files are called stems (`layout.output_dir`):
  ```
  <export folder>/<project name>/<YYYY-MM-DD HHMMSS>/     (export folder set)
  <project dir>/Exports/<project name>/<YYYY-MM-DD HHMMSS>/   (not set)
    export.md          (if the log is on)
    Master.<ext>       combined mix
    stems/<track>.<ext>
  ```
  REAPER renders flat, then `lib/export.lua` moves the stems as planned by `lib/layout.lua`.
  If the targets can't be matched to tracks, nothing is moved.
- **Export log (optional, per project, off by default):** when enabled, every export
  writes `export.md` into its folder. That file has YAML front matter (title, date,
  project, time selection, mix + stems with file names and loudness stats, muted
  descendants, excluded tracks, REAPER version) and the user's notes as the body. The
  first line of the notes becomes the title. It's meant to be consumed by an external
  static site (e.g. Eleventy); this repo doesn't build the site.

## Layout

```
Rendering/            ReaPack category folder (the name shows up in ReaPack and in install paths)
  Webshare - Export stems.lua                        ReaPack package file + panel action
  Webshare - Export stems now (no window).lua        headless export action
  Webshare - Toggle selected tracks for export.lua
  lib/selection.lua   pure logic: defaults, overrides, plan, warnings. NO reaper.* calls
  lib/layout.lua      pure logic: match render targets to tracks, plan moves into stems/
  lib/changelog.lua   pure logic: RENDER_STATS parsing, export.md generation. NO reaper.*
  lib/tracks.lua      reads project into snapshots; writes overrides (with undo)
  lib/render.lua      configures render, runs action 42230, restores state
  lib/export.lua      render, move stems, optional log; the entry point both actions use
  lib/ui.lua          ReaImGui panel (API pinned via require 'imgui' '0.9')
tests/*_test.lua           plain-Lua tests for the pure modules (tests/harness.lua)
tools/dev-link.{sh,ps1}    link Rendering/ into REAPER's Scripts/webshare-dev/
tools/probe_render.lua     run inside REAPER: real export into out/ + probe.log of what
                           REAPER reported. Use it to check assumptions against a real install
```

Entry scripts put their own directory on `package.path` and `require 'lib.x'`. Keep that
pattern, because REAPER runs each script with its own working directory and Lua state.

## Conventions

- Action names come from file names: REAPER shows `Script: <file>.lua`, and there's no
  API for a script to set its own name. Keep entry scripts named `Webshare - <Verb ...>.lua`.
  No `:` (invalid on Windows). Renaming the package file creates a new ReaPack package,
  and the old one shows as obsolete for existing users, so avoid it after 1.0.

- Keep decision logic in the pure modules (`selection`, `layout`, `changelog`) and test it there.
  REAPER-facing modules should stay thin adapters.
- No accidental globals (`tools/check-globals.sh`, also run in CI). A `local` declared
  below a function that uses it is a global *inside* that function.
- Code must run on Lua 5.4 (REAPER) *and* 5.5. For example, don't assign to `for` loop
  variables, which are constants in 5.5.
- Anything that changes project state temporarily (render settings, selection,
  `B_MAINSEND`) must be saved first and restored even on error (`pcall`), as `render.lua`
  does.
- User-visible track changes go through `tracks.apply` (one undo point per action).
  Scripts that change nothing call `reaper.defer(function() end)` so they don't create an
  empty undo point.
- Paths: build with `package.config:sub(1,1)` as the separator, or let REAPER resolve
  them. No shelling out, because it isn't portable.
- Preserve the user's unrelated `RENDER_SETTINGS` bits (format, metadata, 2nd pass).
  Only clear and set `SOURCE_BITS`.
- Match the existing style: 2-space indent, single quotes, short comments that explain
  *why*.

## Render API facts used

From the ReaScript docs (`GetSetProjectInfo`):
- `RENDER_SETTINGS`: `&1` stems+master mix, `&2` stems only, `&128` selected tracks
  *via master* (we must NOT set this one), `&8192` pre-fader stems.
- `RENDER_BOUNDSFLAG`: `2` = time selection. `RENDER_ADDTOPROJ`: `&1` add to project.
- `RENDER_FILE` = output directory, `RENDER_PATTERN` = file name pattern (`$track`).
- `RENDER_TARGETS` = `;`-separated paths that the current settings will write.
- `RENDER_STATS` (read after rendering) =
  `FILE:<path>;PEAK:..;LUFSMMAX:..;LUFSSMAX:..;LUFSI:..;LRA:..;FILE:...`.
  `RENDER_STATS_SUMMARY` came back empty, so parse the raw string.
- Action `42230`: render with the most recent settings, auto-closing the dialog.

The reference docs (https://reaper.fm/sdk/reascript/reascripthelp.html) were generated for
REAPER 7.82. The user develops on **7.33**, so check that any newer flag exists there.

## Verified with tools/probe_render.lua (REAPER 7.33, macOS arm64, 2026-10-12)

- `Main_OnCommand(42230)` blocks until the render finishes, and the files exist on return.
- With stems + master mix and `$track`, the mix is named `Master.<ext>`. `RENDER_TARGETS`
  lists it first, then one file per stem in track order. `lib/layout.match_files`
  relies on that order. A stem named "Master" would overwrite the mix file, so
  `selection.plan` reports it as a duplicate.
- `RENDER_STATS` holds peak/LUFS/LRA after an ordinary render, with no dry run needed.
  This was with the user's prefs (`renderclosewhendone=4`); other render-statistics
  prefs are untested.
- The file format follows the user's Render dialog (mp3 in that test).
- Full path end-to-end: render → stems moved into `stems/` → `export.md` with stats matched
  to the right files.
- `RENDER_STATS` still holds the *previous* render's stats until a new render finishes.
  This is harmless because each export goes into a new folder and stats are looked up by path.

## Not yet verified inside REAPER

Treat these as assumptions until someone confirms them by hand, and update this list:
- What `$track` produces for unnamed tracks (`selection.display_name` assumes "Track N").
- How `RENDER_TARGETS` looks with a secondary render format on. `match_files` then gives up:
  nothing moves into `stems/` and the log writes `file: null`.
- ReaImGui UI has been exercised by the user on 7.33/macOS (track list, footer sizing,
  export). Gotcha: `SetNextItemWidth(ctx, 0)` means *zero pixels*; use `-FLT_MIN`
  (`ImGui.NumericLimits_Float()`) to fill to the right edge. Before using a new ImGui
  function, confirm it exists in the installed `ReaImGui_Demo.lua` or the
  `reaper_imgui-*.dylib` symbols (`APIdef_ImGui_<Name>`).
  ReaImGui wasn't installed on the dev machine when this was written.
- Windows and Linux in general.

## Testing

- From the repo root: `for t in tests/*_test.lua; do lua "$t"; done`. Run them with Lua 5.4
  (REAPER's version: `brew install lua@5.4`, keg-only at `$(brew --prefix lua@5.4)/bin/lua`)
  as well as current Lua. Optional lint: `luacheck Rendering tests tools`.
- Everything else needs REAPER. Load the actions straight from the clone (README → Install,
  step 4), or have the user run `tools/probe_render.lua`, then test against a real project.
  Menu labels in the README were checked against the 7.33 binary (`strings`), so check new
  instructions the same way rather than writing them from memory. You can't
  drive REAPER from here, so state clearly what you couldn't verify.

## Releasing (ReaPack via GitHub Actions)

- Published at `https://github.com/sastraxi/reaper-webshare/raw/main/index.xml`. The ReaPack
  repository name is `webshare` (`.reapack-index.conf`), so installs land in
  `<resource>/Scripts/webshare/Rendering/`.
- The package file is `Rendering/Webshare - Export stems.lua`, and its header holds
  `@version`, `@changelog` and `@provides`. Every other `.lua` under `Rendering/` must
  start with `-- @noindex`, or reapack-index treats it as a separate package. `tests/`,
  `tools/` and `out/` are ignored via `.reapack-index.conf`.
- To release, bump `@version`, write `@changelog`, and push to `main`. `deploy.yml` runs
  `reapack-index --commit`, which scans commits since the one recorded in `index.xml` and
  commits the updated index back. Never edit `index.xml` by hand.
- `check.yml` runs the Lua 5.4 tests, `luac -p`, and `reapack-index --check` on every
  push and PR. Run it locally with Ruby ≥ 3 + `gem install reapack-index --pre` + pandoc;
  it needs the `origin` remote to build download URLs.
- ReaPack can't declare dependencies and has no API to install packages. The panel checks
  for ReaImGui at runtime and offers `ReaPack_BrowsePackages('ReaImGui')`.
