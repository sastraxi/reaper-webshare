-- @noindex
-- Export without opening the panel, using each track's current export state.

local dir = debug.getinfo(1, 'S').source:match('^@?(.*[/\\])')
package.path = dir .. '?.lua;' .. package.path

local selection = require 'lib.selection'
local tracks_mod = require 'lib.tracks'
local export = require 'lib.export'

local tracks = tracks_mod.snapshot()
local plan = selection.plan(tracks)
local ok, result = export.run(tracks, plan, '')
if not ok then
  reaper.MB(result, 'Stem export', 0)
end
reaper.defer(function() end) -- no undo point
