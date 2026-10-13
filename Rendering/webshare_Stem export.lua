-- @description Stem export
-- @author sastraxi
-- @version 0.1.0
-- @changelog
--   Initial release.
-- @link https://github.com/sastraxi/reaper-webshare
-- @about
--   Export the time selection as individual stems plus one combined mix.
--   Top-level tracks are exported by default; toggle any track in the panel.
--   Optionally writes a Markdown export log (YAML front matter) next to the files.
--   Requires ReaImGui (ReaTeam Extensions repository).
-- @provides
--   [main] webshare_Export stems.lua
--   [main] webshare_Toggle stem export for selected tracks.lua
--   lib/*.lua

local dir = debug.getinfo(1, 'S').source:match('^@?(.*[/\\])')
package.path = dir .. '?.lua;' .. package.path

require('lib.ui').run()
