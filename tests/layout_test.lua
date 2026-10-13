-- Run from the repo root: lua tests/layout_test.lua
package.path = 'Rendering/?.lua;' .. package.path
local selection = require 'lib.selection'
local layout = require 'lib.layout'
local h = dofile('tests/harness.lua')
local test, eq = h.test, h.eq

local function plan()
  return selection.plan {
    { index = 1, guid = 'g1', name = 'Drums', depth = 0, muted = false },
    { index = 2, guid = 'g2', name = 'Bass', depth = 0, muted = false },
  }
end

test('mix stays at the top, stems move into stems/', function()
  local p = plan()
  local l = layout.plan(p, { '/e/Master.wav', '/e/Drums.wav', '/e/Bass.wav' }, '/e', '/')
  eq(l.mix.rel, 'Master.wav')
  eq(l.mix.rendered, '/e/Master.wav')
  eq(#l.moves, 2)
  eq(l.moves[1].from, '/e/Drums.wav')
  eq(l.moves[1].to, '/e/stems/Drums.wav')
  eq(l.stems[p.stems[2]].rel, 'stems/Bass.wav')
  eq(l.stems[p.stems[2]].rendered, '/e/Bass.wav')
end)

test('Windows paths: moves use the native separator, rel paths use /', function()
  local p = plan()
  local l = layout.plan(p, { [[C:\e\Master.wav]], [[C:\e\Drums.wav]], [[C:\e\Bass.wav]] }, [[C:\e]], '\\')
  eq(l.moves[1].to, [[C:\e\stems\Drums.wav]])
  eq(l.stems[p.stems[1]].rel, 'stems/Drums.wav')
end)

test('unexpected target count (e.g. secondary format): no moves, no guesses', function()
  local targets = { '/e/Master.wav', '/e/Master.mp3', '/e/Drums.wav', '/e/Drums.mp3', '/e/Bass.wav', '/e/Bass.mp3' }
  local l = layout.plan(plan(), targets, '/e', '/')
  eq(l.mix, nil)
  eq(#l.moves, 0)
  eq(next(l.stems), nil)
end)

test('output_dir: next to the project when no export folder is set', function()
  eq(layout.output_dir('', '/p/Song', 'Song', '2026-10-12 233921', '/'), '/p/Song/Exports/Song/2026-10-12 233921')
  eq(layout.output_dir(nil, '/p/Song', 'Song', 't', '/'), '/p/Song/Exports/Song/t')
end)

test('output_dir: shared export folder, one subfolder per project', function()
  eq(layout.output_dir('/Volumes/Share/Exports/', '/p/Song', 'Song', 't', '/'), '/Volumes/Share/Exports/Song/t')
  eq(layout.output_dir([[D:\Exports]], [[C:\p]], 'A/B: "C"', 't', '\\'), [[D:\Exports\A_B_ _C_\t]])
end)

h.finish()
