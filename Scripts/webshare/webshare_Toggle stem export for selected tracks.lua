-- @noindex
-- If any selected track is off, turn all selected tracks on; otherwise turn them all off.

local dir = debug.getinfo(1, 'S').source:match('^@?(.*[/\\])')
package.path = dir .. '?.lua;' .. package.path

local selection = require 'lib.selection'
local tracks_mod = require 'lib.tracks'

local targets, any_off = {}, false
for _, t in ipairs(tracks_mod.snapshot()) do
  if t.selected then
    targets[#targets + 1] = t
    any_off = any_off or not selection.is_exported(t)
  end
end

if #targets == 0 then
  reaper.defer(function() end)
  return
end

local changes = {}
for _, t in ipairs(targets) do
  changes[#changes + 1] = { track = t, exported = any_off }
end
tracks_mod.apply(changes, any_off and 'Stem export: include selected tracks' or 'Stem export: exclude selected tracks')
