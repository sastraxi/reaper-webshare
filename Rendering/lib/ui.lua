-- @noindex
-- Dockable ReaImGui panel: track tree with export checkboxes, mute warnings, Export button.

local selection = require 'lib.selection'
local tracks_mod = require 'lib.tracks'
local export = require 'lib.export'
local render = require 'lib.render'

local M = {}

local TITLE = 'Webshare: Export stems'
local INDENT = 16
local COLOR_WARN = 0xF0A030FF
local NOTES_HEIGHT = 64

local function load_imgui()
  if not reaper.ImGui_GetBuiltinPath then
    return nil
  end
  package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
  return require 'imgui' '0.9'
end

-- REAPER extensions the panel needs, all installed through ReaPack (ReaTeam Extensions).
-- ReaPack can't declare dependencies, so we check at startup.
local DEPENDENCIES = {
  { name = 'ReaImGui', why = 'draws this window', present = function() return reaper.ImGui_GetBuiltinPath end },
  { name = 'js_ReaScriptAPI', why = 'the export folder picker',
    present = function() return reaper.JS_Dialog_BrowseForFolder end },
}

-- Returns true if everything is installed; otherwise explains what's missing and offers to
-- open ReaPack's browser on it (the closest thing to installing it for the user).
local function check_dependencies()
  local missing = {}
  for _, d in ipairs(DEPENDENCIES) do
    if not d.present() then
      missing[#missing + 1] = d
    end
  end
  if #missing == 0 then
    return true
  end

  local lines = {}
  for i, d in ipairs(missing) do
    lines[i] = ('  • %s (%s)'):format(d.name, d.why)
  end
  local msg = 'This script needs these REAPER extensions, which aren\'t installed:\n\n'
    .. table.concat(lines, '\n') .. '\n\n'
  if not reaper.ReaPack_BrowsePackages then
    reaper.MB(msg .. 'They\'re installed through ReaPack. Install ReaPack from https://reapack.com '
      .. 'first, then run this again.', TITLE, 0)
    return false
  end

  -- ReaPack's browser takes a single filter, so open it on the first one.
  local how = 'Open ReaPack to install it? Right-click it → Install, click OK, then restart REAPER.'
  if #missing > 1 then
    how = ('Open ReaPack to install them? It opens on %s: right-click it → Install. Then '
      .. 'search for %s and do the same, click OK, and restart REAPER.')
      :format(missing[1].name, missing[2].name)
  end
  if reaper.MB(msg .. how, TITLE, 4) == 6 then -- 4 = Yes/No, 6 = Yes
    reaper.ReaPack_BrowsePackages(missing[1].name)
  end
  return false
end

local function browse_folder(initial)
  local rv, path = reaper.JS_Dialog_BrowseForFolder('Choose export folder', initial)
  if rv == 1 and path ~= '' then
    return path
  end
end

local function names(list)
  local out = {}
  for _, t in ipairs(list) do
    out[#out + 1] = selection.display_name(t)
  end
  return table.concat(out, '\n')
end

function M.run()
  if not check_dependencies() then
    return
  end
  local ImGui = load_imgui()

  local ctx = ImGui.CreateContext(TITLE)
  local FLT_MIN = ImGui.NumericLimits_Float()
  local status
  local notes = ''
  -- Height of everything below the track list, measured on the previous frame, so the list
  -- fills exactly the space left over. (Estimating it always left a stray scrollbar.)
  local footer_h
  local folder_buf = export.export_folder()
  local export_requested = false

  local function draw_track(t, warning)
    ImGui.PushID(ctx, t.guid)
    if t.depth > 0 then
      ImGui.Indent(ctx, t.depth * INDENT)
    end

    local changed, exported = ImGui.Checkbox(ctx, selection.display_name(t), selection.is_exported(t))
    if changed then
      tracks_mod.apply({ { track = t, exported = exported } }, 'Stem export: toggle track')
    end

    if t.override ~= nil then
      ImGui.SameLine(ctx)
      if ImGui.SmallButton(ctx, 'reset') then
        tracks_mod.apply({ { track = t, exported = nil } }, 'Stem export: reset track')
      end
      if ImGui.IsItemHovered(ctx) then
        ImGui.SetTooltip(ctx, 'Return to the default (top-level tracks export, nested tracks don\'t)')
      end
    end

    if warning then
      ImGui.SameLine(ctx)
      ImGui.TextColored(ctx, COLOR_WARN, '(muted)')
      if ImGui.IsItemHovered(ctx) then
        ImGui.SetTooltip(ctx, 'Muted tracks will affect this stem:\n' .. names(warning.muted))
      end
    end

    if t.depth > 0 then
      ImGui.Unindent(ctx, t.depth * INDENT)
    end
    ImGui.PopID(ctx)
  end

  local function draw_header()
    ImGui.Text(ctx, 'Export folder (all projects):')
    local browse_w = ImGui.CalcTextSize(ctx, 'Browse...') + 16
    local clear_w = folder_buf ~= '' and ImGui.CalcTextSize(ctx, 'Clear') + 16 or 0
    local spacing_x = ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemSpacing)
    local buttons_w = 0
    for _, w in ipairs({ browse_w, clear_w }) do
      if w > 0 then
        buttons_w = buttons_w + w + spacing_x
      end
    end

    -- Negative widths align to the right edge. An explicit 0 means zero pixels, not "default",
    -- so with no buttons use -FLT_MIN (ImGui's idiom for "fill to the right edge").
    ImGui.SetNextItemWidth(ctx, buttons_w > 0 and -buttons_w or -FLT_MIN)
    local _
    _, folder_buf = ImGui.InputTextWithHint(ctx, '##export_folder',
      'Not set: next to each project, in Exports/', folder_buf)
    if ImGui.IsItemDeactivatedAfterEdit(ctx) then
      export.set_export_folder(folder_buf)
    end
    if ImGui.IsItemHovered(ctx) then
      ImGui.SetTooltip(ctx, 'Each export goes into <export folder>/<project name>/<date time>/.')
    end

    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, 'Browse...') then
      local path = browse_folder(folder_buf ~= '' and folder_buf or render.project_dir())
      if path then
        folder_buf = path
        export.set_export_folder(path)
      end
    end
    if folder_buf ~= '' then
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, 'Clear') then
        folder_buf = ''
        export.set_export_folder('')
      end
    end
    ImGui.Separator(ctx)
  end

  local function draw_footer(plan)
    ImGui.Separator(ctx)

    local start, finish = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
    if finish > start then
      ImGui.Text(ctx, ('Time selection: %s – %s  (bars %s – %s)'):format(
        reaper.format_timestr_pos(start, '', 0), reaper.format_timestr_pos(finish, '', 0),
        reaper.format_timestr_pos(start, '', 2), reaper.format_timestr_pos(finish, '', 2)))
    else
      ImGui.TextColored(ctx, COLOR_WARN, 'No time selection')
    end

    ImGui.Text(ctx, ('%d stem(s) + combined mix'):format(#plan.stems))
    if #plan.duplicate_names > 0 then
      ImGui.SameLine(ctx)
      ImGui.TextColored(ctx, COLOR_WARN, '(duplicate names)')
      if ImGui.IsItemHovered(ctx) then
        ImGui.SetTooltip(ctx, 'These stems share a name and will overwrite each other:\n'
          .. table.concat(plan.duplicate_names, '\n'))
      end
    end

    local log_changed, log_on = ImGui.Checkbox(ctx, 'Write export log (export.md)', export.log_enabled())
    if log_changed then
      export.set_log_enabled(log_on)
    end
    if log_on then
      ImGui.TextDisabled(ctx, 'Notes (first line becomes the title):')
      notes = select(2, ImGui.InputTextMultiline(ctx, '##notes', notes, -1, NOTES_HEIGHT))
    end

    if ImGui.Button(ctx, 'Export') then
      export_requested = true
    end
    if status then
      ImGui.SameLine(ctx)
      ImGui.TextWrapped(ctx, status)
    end
  end

  local function frame()
    local tracks = tracks_mod.snapshot()
    local plan = selection.plan(tracks)
    local warnings = {}
    for _, w in ipairs(plan.mute_warnings) do
      warnings[w.track.guid] = w
    end

    ImGui.SetNextWindowSize(ctx, 420, 480, ImGui.Cond_FirstUseEver)
    local visible, open = ImGui.Begin(ctx, TITLE, true)
    if visible then
      draw_header()
      local _, avail_h = ImGui.GetContentRegionAvail(ctx)
      local min_h = ImGui.GetFrameHeightWithSpacing(ctx) * 2
      local list_h = math.max(min_h, avail_h - (footer_h or min_h * 4))
      local top = ImGui.GetCursorPosY(ctx)
      if ImGui.BeginChild(ctx, 'tracks', 0, list_h) then
        if #tracks == 0 then
          ImGui.TextDisabled(ctx, 'No tracks in this project.')
        end
        for _, t in ipairs(tracks) do
          draw_track(t, warnings[t.guid])
        end
        ImGui.EndChild(ctx)
      end
      draw_footer(plan)
      -- The cursor sits one item-spacing below the last widget; that gap isn't content.
      local _, spacing_y = ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemSpacing)
      footer_h = ImGui.GetCursorPosY(ctx) - spacing_y - top - list_h
      ImGui.End(ctx)
    end

    -- Render outside of Begin/End: it's modal and blocks for its whole duration.
    if export_requested then
      export_requested = false
      local ok
      ok, status = export.run(tracks, plan, notes)
      if ok then
        notes = '' -- like a commit message: one per export
      end
    end

    if open then
      reaper.defer(frame)
    end
  end

  reaper.defer(frame)
end

return M
