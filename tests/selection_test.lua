-- Run from the repo root: lua tests/selection_test.lua
package.path = 'Rendering/?.lua;' .. package.path
local selection = require 'lib.selection'

local h = dofile('tests/harness.lua')
local test, eq = h.test, h.eq
local function names(list)
  local out = {}
  for _, t in ipairs(list) do out[#out + 1] = selection.display_name(t) end
  return table.concat(out, ',')
end

-- Build a snapshot from { name, depth, muted?, override? } rows.
local function project(rows)
  local out = {}
  for i, r in ipairs(rows) do
    out[i] = { index = i, guid = 'g' .. i, name = r[1], depth = r[2], muted = r.muted or false, override = r.override }
  end
  return out
end

test('top-level tracks export by default, nested ones do not', function()
  local p = selection.plan(project { { 'Drums', 0 }, { 'Kick', 1 }, { 'Bass', 0 } })
  eq(names(p.stems), 'Drums,Bass')
  eq(#p.excluded_from_mix, 0)
end)

test('overrides win over the default', function()
  local p = selection.plan(project { { 'Drums', 0, override = false }, { 'Kick', 1, override = true }, { 'Bass', 0 } })
  eq(names(p.stems), 'Kick,Bass')
  eq(names(p.excluded_from_mix), 'Drums')
end)

test('excluded nested tracks are not listed as excluded from the mix', function()
  local p = selection.plan(project { { 'Drums', 0 }, { 'Kick', 1, override = false } })
  eq(#p.excluded_from_mix, 0)
end)

test('override_for stores nil when matching the default', function()
  local top, nested = { depth = 0 }, { depth = 2 }
  eq(selection.override_for(top, true), nil)
  eq(selection.override_for(top, false), false)
  eq(selection.override_for(nested, false), nil)
  eq(selection.override_for(nested, true), true)
end)

test('warns when a stem or any descendant is muted', function()
  local p = selection.plan(project {
    { 'Drums', 0 }, { 'Kicks', 1 }, { 'Kick In', 2, muted = true }, { 'Snare', 1 },
    { 'Bass', 0, muted = true },
    { 'Keys', 0 },
  })
  eq(#p.mute_warnings, 2)
  eq(p.mute_warnings[1].track.name, 'Drums')
  eq(names(p.mute_warnings[1].muted), 'Kick In')
  eq(p.mute_warnings[2].track.name, 'Bass')
end)

test('no warning for muted tracks that are not rendered', function()
  local p = selection.plan(project { { 'Scratch', 0, muted = true, override = false }, { 'Keys', 0 } })
  eq(#p.mute_warnings, 0)
end)

test('descendants stop at the next sibling or shallower track', function()
  local tracks = project { { 'A', 0 }, { 'A1', 1 }, { 'A1a', 2 }, { 'A2', 1 }, { 'B', 0 } }
  eq(names(selection.descendants(tracks, 1)), 'A1,A1a,A2')
  eq(names(selection.descendants(tracks, 2)), 'A1a')
  eq(names(selection.descendants(tracks, 5)), '')
end)

test('duplicate stem names are reported once, case-insensitively', function()
  local p = selection.plan(project { { 'Gtr', 0 }, { 'GTR', 0 }, { 'gtr', 0 }, { '', 0 } })
  eq(table.concat(p.duplicate_names, ','), 'GTR')
  eq(selection.display_name(p.stems[4]), 'Track 4')
end)

test('a stem named Master collides with the combined mix', function()
  local p = selection.plan(project { { 'master', 0 }, { 'Bass', 0 } })
  eq(table.concat(p.duplicate_names, ','), 'master')
end)

h.finish()
