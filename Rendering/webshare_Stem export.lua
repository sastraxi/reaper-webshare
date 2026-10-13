-- @description Stem export
-- @author sastraxi
-- @version 0.1.0
-- @changelog
--   Initial release.
-- @link https://github.com/sastraxi/reaper-webshare
-- @about
--   # Stem export
--
--   Export the time selection as individual stems plus one combined mix.
--   Top-level tracks are exported by default; toggle any track in the panel.
--   Optionally writes a Markdown export log (YAML front matter) next to the files.
--
--   **Requires ReaImGui** (ReaTeam Extensions repository). Restart REAPER after installing it.
--
--   ## How to use
--
--   1. Actions → Show action list..., filter `stem`
--   2. Run **Script: webshare_Stem export.lua** to open the panel
--   3. Make a time selection, check the ticks, click **Export**
--
--   Files go to `Exports/<project>/<date time>/` next to the project file.
--   Full documentation: https://github.com/sastraxi/reaper-webshare
-- @provides
--   [main] webshare_Export stems.lua
--   [main] webshare_Toggle stem export for selected tracks.lua
--   lib/*.lua

local dir = debug.getinfo(1, 'S').source:match('^@?(.*[/\\])')
package.path = dir .. '?.lua;' .. package.path

require('lib.ui').run()
