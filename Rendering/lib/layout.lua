-- @noindex
-- Decides the on-disk layout of an export. Pure Lua, no reaper.* calls.
--
--   <export dir>/
--     export.md        (optional log)
--     Master.<ext>     combined mix
--     stems/<track>.<ext>
--
-- REAPER renders everything flat into <export dir>; the stem files are moved afterwards.

local M = {}

M.STEMS_DIR = 'stems'

-- Where an export goes. With an export folder set (a user preference shared by all
-- projects), projects are told apart by name:
--   <export folder>/<project name>/<timestamp>
-- Without one, next to the project file:
--   <project dir>/Exports/<project name>/<timestamp>
function M.output_dir(export_folder, project_dir, project_name, timestamp, sep)
  local folder = project_name:gsub('[\\/:*?"<>|]', '_')
  if export_folder and export_folder ~= '' then
    local root = export_folder:gsub('[/\\]+$', '')
    return table.concat({ root, folder, timestamp }, sep)
  end
  return table.concat({ project_dir, 'Exports', folder, timestamp }, sep)
end

function M.basename(path)
  return path:match('[^/\\]+$') or path
end

-- Pairs render targets with what produced them. With stems + master mix, REAPER 7.33 lists
-- the master first, then one file per stem in track order. If the count doesn't match
-- (e.g. a secondary render format is on) we don't guess: returns nil, {}.
function M.match_files(plan, targets)
  if #targets ~= #plan.stems + 1 then
    return nil, {}
  end
  local stems = {}
  for i, t in ipairs(plan.stems) do
    stems[t] = targets[i + 1]
  end
  return targets[1], stems
end

-- Returns {
--   moves = { { from = path, to = path } },
--   mix   = { rel = 'Master.mp3', rendered = path } or nil,
--   stems = { [stem track] = { rel = 'stems/Drums.mp3', rendered = path } },
-- }
-- `rel` paths always use '/', since they end up in Markdown and URLs. `rendered` is the
-- path REAPER wrote (and keys RENDER_STATS).
function M.plan(plan, targets, dir, sep)
  local mix_path, stem_paths = M.match_files(plan, targets)
  local out = { moves = {}, stems = {} }
  if not mix_path then
    return out
  end
  out.mix = { rel = M.basename(mix_path), rendered = mix_path }
  for _, t in ipairs(plan.stems) do
    local path = stem_paths[t]
    local name = M.basename(path)
    out.moves[#out.moves + 1] = { from = path, to = dir .. sep .. M.STEMS_DIR .. sep .. name }
    out.stems[t] = { rel = M.STEMS_DIR .. '/' .. name, rendered = path }
  end
  return out
end

return M
