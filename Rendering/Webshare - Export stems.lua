-- @description Webshare: Export stems
-- @author sastraxi
-- @version 0.3.1
-- @changelog
--   Fix: the export folder field was invisible when there was no Browse button.
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
--   Files go to `<export folder>/<project>/<date time>/`. Set the export folder at the top
--   of the panel; if it's empty, they go to `Exports/` next to the project file.
--   Full documentation: https://github.com/sastraxi/reaper-webshare
-- @provides
--   [main] Webshare - Export stems now (no window).lua
--   [main] Webshare - Toggle selected tracks for export.lua
--   lib/*.lua

local dir = debug.getinfo(1, 'S').source:match('^@?(.*[/\\])')
package.path = dir .. '?.lua;' .. package.path

require('lib.ui').run()
