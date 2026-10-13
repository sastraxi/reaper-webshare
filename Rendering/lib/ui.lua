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

-- Folder picker: REAPER's own (GetUserFileName mode 3, newer REAPER versions), else
-- js_ReaScriptAPI's, else nil (the path can still be typed or pasted).
local function folder_picker()
  if reaper.GetUserFileName then
    return function(initial)
      local ok, path = reaper.GetUserFileName(3, 'Choose export folder', initial, '')
      return ok and path or nil
    end
  elseif reaper.JS_Dialog_BrowseForFolder then
    return function(initial)
      local rv, path = reaper.JS_Dialog_BrowseForFolder('Choose export folder', initial)
      return rv == 1 and path or nil
    end
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
  local ImGui = load_imgui()
  if not ImGui then
    -- ReaPack can't declare dependencies or install from a script, but it can open its
    -- browser pre-filtered so installing ReaImGui is one right-click away.
    if reaper.ReaPack_BrowsePackages then
      local answer = reaper.MB('This script needs ReaImGui, which isn\'t installed.\n\n'
        .. 'Open ReaPack to install it? (Right-click it → Install, then OK, then restart REAPER.)',
        TITLE, 4) -- 4 = Yes/No
      if answer == 6 then -- 6 = Yes
        reaper.ReaPack_BrowsePackages('ReaImGui')
      end
    else
      reaper.MB('This script needs ReaImGui, which is installed through ReaPack.\n\n'
        .. 'Install ReaPack from https://reapack.com first, then run this again.', TITLE, 0)
    end
    return
  end

  local ctx = ImGui.CreateContext(TITLE)
  local FLT_MIN = ImGui.NumericLimits_Float()
  local status
  local notes = ''
  -- Height of everything below the track list, measured on the previous frame, so the list
  -- fills exactly the space left over. (Estimating it always left a stray scrollbar.)
  local footer_h
  local pick_folder = folder_picker()
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
    local browse_w = pick_folder and ImGui.CalcTextSize(ctx, 'Browse...') + 16 or 0
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
      local tip = 'Each export goes into <export folder>/<project name>/<date time>/.'
      if not pick_folder then
        tip = tip .. '\n\nType or paste a path. For a Browse button, update REAPER or install'
          .. '\njs_ReaScriptAPI (ReaPack, ReaTeam Extensions).'
      end
      ImGui.SetTooltip(ctx, tip)
    end

    if pick_folder then
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, 'Browse...') then
        local path = pick_folder(folder_buf ~= '' and folder_buf or render.project_dir())
        if path and path ~= '' then
          folder_buf = path
          export.set_export_folder(path)
        end
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
