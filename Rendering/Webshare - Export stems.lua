-- @description Webshare: Export stems
-- @author sastraxi
-- @version 0.2.0
-- @changelog
--   Readable action names: "Webshare - Export stems" (panel), "Webshare - Export stems now
--   (no window)", "Webshare - Toggle selected tracks for export". Replaces the old
--   webshare_* actions; re-add any toolbar buttons or shortcuts you made for them.
--   Panel: no more stray scrollbar; time selection shown as clock time and bars.
-- @link https://github.com/sastraxi/reaper-webshare
-- @about
--   # Webshare: Export stems
--
--   Export the time selection as individual stems plus one combined mix.
--   Top-level tracks are exported by default; toggle any track in the panel.
--   Optionally writes a Markdown export log (YAML front matter) next to the files.
--
--   **Requires ReaImGui** (ReaTeam Extensions repository). Restart REAPER after installing it.
--
--   ## How to use
--
--   1. Actions → Show action list..., filter `webshare`
--   2. Run **Script: Webshare - Export stems.lua** to open the panel
--   3. Make a time selection, check the ticks, click **Export**
--
--   Files go to `Exports/<project>/<date time>/` next to the project file.
--   Full documentation: https://github.com/sastraxi/reaper-webshare
-- @provides
--   [main] Webshare - Export stems now (no window).lua
--   [main] Webshare - Toggle selected tracks for export.lua
--   lib/*.lua

local dir = debug.getinfo(1, 'S').source:match('^@?(.*[/\\])')
package.path = dir .. '?.lua;' .. package.path

require('lib.ui').run()
