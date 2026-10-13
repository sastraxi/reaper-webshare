-- Runs an export and, if enabled for this project, writes the Markdown export log next to it.
-- Shared by the panel and the headless action.

local render = require 'lib.render'
local changelog = require 'lib.changelog'
local layout = require 'lib.layout'

local M = {}

local SECTION = 'webshare'

function M.log_enabled()
  local _, v = reaper.GetProjExtState(0, SECTION, 'write_log')
  return v == '1'
end

function M.set_log_enabled(on)
  reaper.SetProjExtState(0, SECTION, 'write_log', on and '1' or '')
end

local SEP = package.config:sub(1, 1)

-- format_timestr_pos modes. -1 (project default) would make the log depend on the ruler setting.
local TIME_CLOCK = 0
local TIME_MEASURES = 2

-- Moves stem files into stems/. Returns ok, err.
local function apply_moves(dir, moves)
  if #moves == 0 then
    return true
  end
  reaper.RecursiveCreateDirectory(dir .. SEP .. layout.STEMS_DIR, 0)
  for _, m in ipairs(moves) do
    local ok, err = os.rename(m.from, m.to)
    if not ok then
      return false, err
    end
  end
  return true
end

local function write_log(result, files, plan, start, finish, notes)
  local md = changelog.markdown {
    project = render.project_name(),
    date = changelog.iso_date(os.time()),
    time_selection = {
      start = reaper.format_timestr_pos(start, '', TIME_CLOCK),
      finish = reaper.format_timestr_pos(finish, '', TIME_CLOCK),
      start_measure = reaper.format_timestr_pos(start, '', TIME_MEASURES),
      finish_measure = reaper.format_timestr_pos(finish, '', TIME_MEASURES),
      seconds = finish - start,
    },
    plan = plan,
    files = files,
    stats = result.stats,
    reaper_version = reaper.GetAppVersion(),
    notes = notes,
  }
  local path = result.dir .. SEP .. changelog.FILE_NAME
  local f, err = io.open(path, 'wb')
  if not f then
    return false, err
  end
  f:write(md)
  f:close()
  return true
end

-- Returns ok, message for the user. opts (optional, for dev tools): out_dir, write_log.
function M.run(tracks, plan, notes, opts)
  opts = opts or {}
  local start, finish = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
  local ok, result = render.export(tracks, plan, opts.out_dir)
  if not ok then
    return false, result
  end
  -- A cancelled render still returns normally; it just leaves no files behind.
  for _, path in ipairs(result.targets) do
    if not reaper.file_exists(path) then
      return false, 'Render was cancelled or failed (missing ' .. layout.basename(path) .. ').'
    end
  end

  local files = layout.plan(plan, result.targets, result.dir, SEP)
  local moved, move_err = apply_moves(result.dir, files.moves)
  if not moved then
    return false, 'Exported to ' .. result.dir .. ', but moving stems into '
      .. layout.STEMS_DIR .. '/ failed: ' .. tostring(move_err)
  end

  local log = opts.write_log
  if log == nil then
    log = M.log_enabled()
  end
  if log then
    local logged, err = write_log(result, files, plan, start, finish, notes)
    if not logged then
      return false, 'Exported to ' .. result.dir .. ', but writing the log failed: ' .. tostring(err)
    end
  end
  return true, 'Exported to ' .. result.dir
end

return M
