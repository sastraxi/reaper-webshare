-- @noindex
-- Adapter between the REAPER project and the plain snapshots used by lib/selection.lua.

local selection = require 'lib.selection'

local M = {}

-- Per-track extension data, saved in the .rpp. "1" = export, "0" = don't,
-- absent = follow the default (see selection.default_for).
M.OVERRIDE_KEY = 'P_EXT:webshare:stem'

local function read_override(tr)
  local _, value = reaper.GetSetMediaTrackInfo_String(tr, M.OVERRIDE_KEY, '', false)
  if value == '1' then
    return true
  elseif value == '0' then
    return false
  end
  return nil
end

function M.snapshot(proj)
  proj = proj or 0
  local out = {}
  for i = 0, reaper.CountTracks(proj) - 1 do
    local tr = reaper.GetTrack(proj, i)
    local _, name = reaper.GetSetMediaTrackInfo_String(tr, 'P_NAME', '', false)
    out[#out + 1] = {
      track = tr, -- MediaTrack*, not used by selection.lua
      index = i + 1,
      guid = reaper.GetTrackGUID(tr),
      name = name,
      depth = reaper.GetTrackDepth(tr),
      muted = reaper.GetMediaTrackInfo_Value(tr, 'B_MUTE') == 1,
      selected = reaper.IsTrackSelected(tr),
      override = read_override(tr),
    }
  end
  return out
end

local function write_override(tr, value)
  local str = ''
  if value == true then
    str = '1'
  elseif value == false then
    str = '0'
  end
  reaper.GetSetMediaTrackInfo_String(tr, M.OVERRIDE_KEY, str, true)
end

-- Applies a list of { track = snapshot track, exported = bool, or nil to reset to
-- the default } as one undo point.
function M.apply(changes, undo_desc)
  reaper.Undo_BeginBlock2(0)
  for _, c in ipairs(changes) do
    if c.exported == nil then
      write_override(c.track.track, nil)
    else
      write_override(c.track.track, selection.override_for(c.track, c.exported))
    end
  end
  reaper.Undo_EndBlock2(0, undo_desc, 1) -- 1 = UNDO_STATE_TRACKCFG
end

return M
