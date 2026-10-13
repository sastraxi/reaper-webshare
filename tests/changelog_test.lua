-- Run from the repo root: lua tests/changelog_test.lua
package.path = 'Scripts/webshare/?.lua;' .. package.path
local selection = require 'lib.selection'
local changelog = require 'lib.changelog'
local layout = require 'lib.layout'
local h = dofile('tests/harness.lua')
local test, eq, contains = h.test, h.eq, h.contains

-- Captured from a real render on REAPER 7.33 (tools/probe_render.lua).
local DIR = '/x/Exports/Song/2026-10-12 230315/'
local STATS = 'FILE:' .. DIR .. 'Master.mp3;PEAK:-6.293150;LUFSMMAX:-15.792920;LUFSSMAX:-18.510027;'
  .. 'LUFSI:-20.336862;LRA:2.700000;FILE:' .. DIR .. 'Drums.mp3;PEAK:-11.086312;LUFSMMAX:-18.656129;'
  .. 'LUFSSMAX:-19.533569;LUFSI:-21.233324;LRA:2.100000;FILE:' .. DIR .. 'Bass.mp3;PEAK:-11.098283;'
  .. 'LUFSMMAX:-19.691678;LUFSSMAX:-24.054188;LUFSI:-27.237846;LRA:13.300000'

local function tracks()
  return {
    { index = 1, guid = 'g1', name = 'Drums', depth = 0, muted = false },
    { index = 2, guid = 'g2', name = 'Kick "In"', depth = 1, muted = true },
    { index = 3, guid = 'g3', name = 'Bass', depth = 0, muted = false },
    { index = 4, guid = 'g4', name = 'Scratch', depth = 0, muted = false, override = false },
  }
end

local TARGETS = { DIR .. 'Master.mp3', DIR .. 'Drums.mp3', DIR .. 'Bass.mp3' }

local function info(overrides, targets)
  local plan = selection.plan(tracks())
  local i = {
    project = 'Song',
    date = '2026-10-12T23:03:15-04:00',
    time_selection = { start = '1:52.500', finish = '2:30.500', start_measure = '89.1.00',
      finish_measure = '108.1.00', seconds = 38 },
    plan = plan,
    files = layout.plan(plan, targets or TARGETS, DIR:sub(1, -2), '/'),
    stats = STATS,
    reaper_version = '7.33/macOS-arm64',
    notes = '',
  }
  for k, v in pairs(overrides or {}) do i[k] = v end
  return i
end

test('parse_stats groups values by file', function()
  local s = changelog.parse_stats(STATS)
  eq(s[DIR .. 'Master.mp3'].LUFSI, -20.336862)
  eq(s[DIR .. 'Bass.mp3'].LRA, 13.3)
  eq(next(changelog.parse_stats('')), nil)
end)

test('front matter lists mix, stems with stats, mutes and exclusions', function()
  local md = changelog.markdown(info())
  contains(md, '---\ntitle: "Song export"\ndate: 2026-10-12T23:03:15-04:00\n')
  contains(md, 'mix:\n  file: "Master.mp3"\n  peak: -6.29\n  lufsI: -20.34\n')
  contains(md, '  - track: "Drums"\n    file: "stems/Drums.mp3"\n    peak: -11.09\n')
  contains(md, '    lra: 2.1\n    mutedTracks: ["Kick \\"In\\""]\n')
  contains(md, '  - track: "Bass"\n    file: "stems/Bass.mp3"\n')
  contains(md, 'excludedFromMix: ["Scratch"]\n')
  contains(md, 'timeSelection:\n  start: "1:52.500"\n  end: "2:30.500"\n'
    .. '  startMeasure: "89.1.00"\n  endMeasure: "108.1.00"\n  seconds: 38\n')
end)

test('notes become the body and their first line the title', function()
  local md = changelog.markdown(info { notes = '# Chorus rework\n\nNew bass line.\n\n' })
  contains(md, 'title: "Chorus rework"\n')
  eq(md:sub(-#'---\n\n# Chorus rework\n\nNew bass line.\n'), '---\n\n# Chorus rework\n\nNew bass line.\n')
end)

test('unexpected target count leaves files null rather than guessing', function()
  local md = changelog.markdown(info({}, { DIR .. 'Master.mp3' }))
  contains(md, 'mix:\n  file: null\n')
  contains(md, '    file: null\n')
end)

test('iso_date has a numeric UTC offset', function()
  local d = changelog.iso_date(os.time())
  eq(d:match('^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%d[+-]%d%d:%d%d$') ~= nil, true, d)
end)

h.finish()
