-- Dev probe: runs the real export against the open project and records what REAPER reports.
-- Run in REAPER via Actions → "ReaScript: Run ReaScript (EEL2 or lua)..." and pick this file.
-- Writes everything to <repo>/out/probe-<time>/ (gitignored), including probe.log.

local sep = package.config:sub(1, 1)
local tools_dir = debug.getinfo(1, 'S').source:match('^@?(.*[/\\])')
local repo = tools_dir:gsub('[/\\]tools[/\\]$', '')
package.path = repo .. sep .. 'Scripts' .. sep .. 'webshare' .. sep .. '?.lua;' .. package.path

local selection = require 'lib.selection'
local tracks_mod = require 'lib.tracks'
local export = require 'lib.export'

local out_dir = repo .. sep .. 'out' .. sep .. 'probe-' .. os.date('%Y%m%d-%H%M%S')
reaper.RecursiveCreateDirectory(out_dir, 0)
local log_lines = {}
local function log(...)
  local parts = {}
  for i = 1, select('#', ...) do parts[#parts + 1] = tostring(select(i, ...)) end
  log_lines[#log_lines + 1] = table.concat(parts, ' ')
end
local function proj_str(key)
  local _, v = reaper.GetSetProjectInfo_String(0, key, '', false)
  return v
end
local function exists(path)
  local f = io.open(path, 'rb')
  if f then f:close() return true end
  return false
end

log('REAPER', reaper.GetAppVersion(), 'OS', reaper.GetOS())
log('ini renderclosewhendone', select(2, reaper.get_config_var_string('renderclosewhendone')))
log('RENDER_STATS before', proj_str('RENDER_STATS'))

-- Use the existing time selection, or the first 5 s (restored afterwards).
local start, finish = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
local had_selection = finish > start
if not had_selection then
  reaper.GetSet_LoopTimeRange2(0, true, false, 0, 5, false)
end

local tracks = tracks_mod.snapshot()
for _, t in ipairs(tracks) do
  log(('track %d name=%q depth=%d muted=%s exported=%s'):format(
    t.index, t.name, t.depth, tostring(t.muted), tostring(selection.is_exported(t))))
end
local plan = selection.plan(tracks)

-- Hook the render call so we can see the configured state right before and after it.
local real = reaper.Main_OnCommand
local targets = {}
reaper.Main_OnCommand = function(id, flag)
  local tgt = proj_str('RENDER_TARGETS')
  log('RENDER_TARGETS', tgt)
  for f in tgt:gmatch('[^;]+') do targets[#targets + 1] = f end
  log('RENDER_SETTINGS', reaper.GetSetProjectInfo(0, 'RENDER_SETTINGS', 0, false))
  local t0 = reaper.time_precise()
  real(id, flag)
  log(('render call returned after %.3fs'):format(reaper.time_precise() - t0))
  for _, f in ipairs(targets) do
    log('exists immediately after return:', exists(f), f)
  end
  log('RENDER_STATS after', proj_str('RENDER_STATS'))
  log('RENDER_STATS_SUMMARY after', proj_str('RENDER_STATS_SUMMARY'))
end
local ok, msg = export.run(tracks, plan, '# Probe export\n\nWritten by tools/probe_render.lua.',
  { out_dir = out_dir, write_log = true })
reaper.Main_OnCommand = real
log('export returned', ok, msg)

if not had_selection then
  reaper.GetSet_LoopTimeRange2(0, true, false, start, finish, false)
end

local f = assert(io.open(out_dir .. sep .. 'probe.log', 'w'))
f:write(table.concat(log_lines, '\n'), '\n')
f:close()
reaper.ShowConsoleMsg('Probe written to ' .. out_dir .. sep .. 'probe.log\n')
reaper.defer(function() end)
