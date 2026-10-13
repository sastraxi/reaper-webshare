-- @noindex
-- Builds the export log: Markdown with YAML front matter (readable by Eleventy and friends).
-- Pure Lua, no reaper.* calls, so it can be tested outside REAPER.

local selection = require 'lib.selection'

local M = {}

M.FILE_NAME = 'export.md'

-- RENDER_STATS keys -> front matter keys, in output order.
local STAT_KEYS = {
  { 'PEAK', 'peak' },
  { 'LUFSI', 'lufsI' },
  { 'LUFSSMAX', 'lufsSMax' },
  { 'LUFSMMAX', 'lufsMMax' },
  { 'LRA', 'lra' },
}

-- "FILE:a;PEAK:-6.2;...;FILE:b;..." -> { [path] = { PEAK = -6.2, ... } }
function M.parse_stats(str)
  local by_file, current = {}, nil
  for field in (str or ''):gmatch('[^;]+') do
    local k, v = field:match('^([^:]+):(.*)$')
    if k == 'FILE' then
      current = {}
      by_file[v] = current
    elseif k and current then
      current[k] = tonumber(v) or v
    end
  end
  return by_file
end

-- Local time as ISO 8601 with UTC offset. os.date('%z') isn't portable (Windows gives a name).
function M.iso_date(now)
  local utc = os.date('!*t', now)
  utc.isdst = os.date('*t', now).isdst
  local offset = math.floor(os.difftime(now, os.time(utc)) / 60)
  local sign = offset < 0 and '-' or '+'
  offset = math.abs(offset)
  return os.date('%Y-%m-%dT%H:%M:%S', now) .. ('%s%02d:%02d'):format(sign, offset // 60, offset % 60)
end

local function q(s)
  s = tostring(s):gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\r?\n', '\\n'):gsub('\t', '\\t')
  return '"' .. s .. '"'
end

local function num(n)
  return ('%.2f'):format(n):gsub('0+$', ''):gsub('%.$', '')
end

local function inline_list(items)
  local out = {}
  for i, s in ipairs(items) do
    out[i] = q(s)
  end
  return '[' .. table.concat(out, ', ') .. ']'
end

local function first_line(text)
  for raw in (text or ''):gmatch('[^\r\n]+') do
    local line = raw:gsub('^%s*#*%s*', ''):gsub('%s+$', '')
    if line ~= '' then
      return line
    end
  end
  return nil
end

local function emit_stats(lines, indent, stats)
  if not stats then
    return
  end
  for _, k in ipairs(STAT_KEYS) do
    local v = stats[k[1]]
    if type(v) == 'number' then
      lines[#lines + 1] = indent .. k[2] .. ': ' .. num(v)
    end
  end
end

-- info = { project, date, time_selection = { start, finish, start_measure?, finish_measure?,
--          seconds }, plan,
--          files (from layout.plan), stats (raw RENDER_STATS string), reaper_version, notes }
function M.markdown(info)
  local plan = info.plan
  local stats = M.parse_stats(info.stats)
  local files = info.files
  local muted_by_track = {}
  for _, w in ipairs(plan.mute_warnings) do
    muted_by_track[w.track] = w.muted
  end

  local notes = info.notes or ''
  local title = first_line(notes) or (info.project .. ' export')

  local L = { '---' }
  L[#L + 1] = 'title: ' .. q(title)
  L[#L + 1] = 'date: ' .. info.date
  L[#L + 1] = 'project: ' .. q(info.project)
  L[#L + 1] = 'timeSelection:'
  L[#L + 1] = '  start: ' .. q(info.time_selection.start)
  L[#L + 1] = '  end: ' .. q(info.time_selection.finish)
  if info.time_selection.start_measure then
    L[#L + 1] = '  startMeasure: ' .. q(info.time_selection.start_measure)
    L[#L + 1] = '  endMeasure: ' .. q(info.time_selection.finish_measure)
  end
  L[#L + 1] = '  seconds: ' .. num(info.time_selection.seconds)

  L[#L + 1] = 'mix:'
  if files.mix then
    L[#L + 1] = '  file: ' .. q(files.mix.rel)
    emit_stats(L, '  ', stats[files.mix.rendered])
  else
    L[#L + 1] = '  file: null'
  end

  L[#L + 1] = 'stems:'
  for _, t in ipairs(plan.stems) do
    L[#L + 1] = '  - track: ' .. q(selection.display_name(t))
    local file = files.stems[t]
    L[#L + 1] = '    file: ' .. (file and q(file.rel) or 'null')
    if file then
      emit_stats(L, '    ', stats[file.rendered])
    end
    if muted_by_track[t] then
      local names = {}
      for i, m in ipairs(muted_by_track[t]) do
        names[i] = selection.display_name(m)
      end
      L[#L + 1] = '    mutedTracks: ' .. inline_list(names)
    end
  end

  local excluded = {}
  for i, t in ipairs(plan.excluded_from_mix) do
    excluded[i] = selection.display_name(t)
  end
  L[#L + 1] = 'excludedFromMix: ' .. inline_list(excluded)
  L[#L + 1] = 'reaperVersion: ' .. q(info.reaper_version)
  L[#L + 1] = 'tags: [stemExport]'
  L[#L + 1] = '---'
  L[#L + 1] = ''
  if notes ~= '' then
    L[#L + 1] = (notes:gsub('%s+$', ''))
    L[#L + 1] = ''
  end
  return table.concat(L, '\n')
end

return M
