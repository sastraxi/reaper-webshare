-- Single-pass render: stems (pre-master-FX) + combined master mix, over the time selection.
-- Temporarily changes render settings, track selection and master sends, and always restores them.

local M = {}

-- "File: Render project, using the most recent render settings, auto-close render dialog"
local ACTION_RENDER_MOST_RECENT = 42230

-- RENDER_SETTINGS bits that choose what gets rendered. Everything else (embed metadata,
-- 2nd pass, etc.) is the user's preference and is preserved.
local SOURCE_BITS = 1 | 2 | 4 | 8 | 32 | 64 | 128 | 4096 | 8192 | 16384
local STEMS_AND_MASTER = 1 -- with no "via master" bit: stems skip master FX
local BOUNDS_TIME_SELECTION = 2

local NUM_KEYS = { 'RENDER_SETTINGS', 'RENDER_BOUNDSFLAG', 'RENDER_ADDTOPROJ' }
local STR_KEYS = { 'RENDER_FILE', 'RENDER_PATTERN' }

local function project_dir()
  local _, path = reaper.EnumProjects(-1)
  local dir = path and path:match('^(.*)[/\\]')
  return dir or reaper.GetProjectPath()
end

function M.project_name()
  local name = reaper.GetProjectName(0):gsub('%.[Rr][Pp][Pp]$', '')
  if name == '' then
    return 'Untitled'
  end
  return name
end

-- Exports/<project>/<date time>/ next to the project file, so each project and each export
-- gets its own folder. (lib/layout.lua describes what goes inside.)
function M.default_output_dir()
  local sep = package.config:sub(1, 1)
  local folder = M.project_name():gsub('[\\/:*?"<>|]', '_')
  return table.concat({ project_dir(), 'Exports', folder, os.date('%Y-%m-%d %H%M%S') }, sep)
end

local function save_state(tracks)
  local s = { num = {}, str = {}, selected = {}, mainsend = {} }
  for _, k in ipairs(NUM_KEYS) do
    s.num[k] = reaper.GetSetProjectInfo(0, k, 0, false)
  end
  for _, k in ipairs(STR_KEYS) do
    local _, v = reaper.GetSetProjectInfo_String(0, k, '', false)
    s.str[k] = v
  end
  for _, t in ipairs(tracks) do
    s.selected[t.track] = reaper.IsTrackSelected(t.track)
    s.mainsend[t.track] = reaper.GetMediaTrackInfo_Value(t.track, 'B_MAINSEND')
  end
  return s
end

local function restore_state(s)
  for k, v in pairs(s.num) do
    reaper.GetSetProjectInfo(0, k, v, true)
  end
  for k, v in pairs(s.str) do
    reaper.GetSetProjectInfo_String(0, k, v, true)
  end
  for tr, sel in pairs(s.selected) do
    if reaper.ValidatePtr2(0, tr, 'MediaTrack*') then
      reaper.SetTrackSelected(tr, sel)
      reaper.SetMediaTrackInfo_Value(tr, 'B_MAINSEND', s.mainsend[tr])
    end
  end
end

local function configure(tracks, plan, out_dir)
  for _, t in ipairs(tracks) do
    reaper.SetTrackSelected(t.track, false)
  end
  for _, t in ipairs(plan.stems) do
    reaper.SetTrackSelected(t.track, true)
  end
  -- Leave excluded top-level tracks out of the combined mix without touching their
  -- mute state: stop them feeding the master instead.
  for _, t in ipairs(plan.excluded_from_mix) do
    reaper.SetMediaTrackInfo_Value(t.track, 'B_MAINSEND', 0)
  end

  local settings = reaper.GetSetProjectInfo(0, 'RENDER_SETTINGS', 0, false)
  settings = (math.tointeger(settings) & ~SOURCE_BITS) | STEMS_AND_MASTER
  reaper.GetSetProjectInfo(0, 'RENDER_SETTINGS', settings, true)
  reaper.GetSetProjectInfo(0, 'RENDER_BOUNDSFLAG', BOUNDS_TIME_SELECTION, true)
  reaper.GetSetProjectInfo(0, 'RENDER_ADDTOPROJ', 0, true)
  reaper.GetSetProjectInfo_String(0, 'RENDER_FILE', out_dir, true)
  reaper.GetSetProjectInfo_String(0, 'RENDER_PATTERN', '$track', true)
end

-- Returns true, { dir, targets = { file paths, master mix first }, stats = raw RENDER_STATS }
-- on success, or false, message.
function M.export(tracks, plan, out_dir)
  local start, finish = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
  if finish <= start then
    return false, 'Make a time selection first.'
  end
  if #plan.stems == 0 then
    return false, 'No tracks are marked for export.'
  end
  out_dir = out_dir or M.default_output_dir()

  local state = save_state(tracks)
  reaper.PreventUIRefresh(1)
  local ok, err = pcall(configure, tracks, plan, out_dir)
  reaper.PreventUIRefresh(-1)
  local result = { dir = out_dir, targets = {} }
  if ok then
    local _, targets = reaper.GetSetProjectInfo_String(0, 'RENDER_TARGETS', '', false)
    for f in targets:gmatch('[^;]+') do
      result.targets[#result.targets + 1] = f
    end
    -- Blocks until the render finishes (verified on 7.33).
    ok, err = pcall(reaper.Main_OnCommand, ACTION_RENDER_MOST_RECENT, 0)
    _, result.stats = reaper.GetSetProjectInfo_String(0, 'RENDER_STATS', '', false)
  end

  reaper.PreventUIRefresh(1)
  restore_state(state)
  reaper.PreventUIRefresh(-1)
  reaper.TrackList_AdjustWindows(false)

  if not ok then
    return false, 'Export failed: ' .. tostring(err)
  end
  return true, result
end

return M
