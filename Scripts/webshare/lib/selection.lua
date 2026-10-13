-- Pure export-planning logic over a track snapshot.
-- No reaper.* calls in this file, so it can be tested with plain Lua (see tests/).
--
-- A snapshot is an array of tracks in project order. Each track is a table:
--   { index = 1-based, guid = string, name = string, depth = 0 for top level,
--     muted = bool, override = true | false | nil }

local M = {}

-- Top-level tracks export by default; nested tracks don't.
function M.default_for(track)
  return track.depth == 0
end

function M.is_exported(track)
  if track.override ~= nil then
    return track.override
  end
  return M.default_for(track)
end

-- The override to store so that `track` ends up with `exported`: nil when that
-- matches the default, so tracks keep following the default until a user deviates.
function M.override_for(track, exported)
  if exported == M.default_for(track) then
    return nil
  end
  return exported
end

function M.display_name(track)
  if track.name ~= '' then
    return track.name
  end
  return 'Track ' .. track.index
end

-- Tracks after position i that are nested (at any level) under tracks[i].
function M.descendants(tracks, i)
  local out = {}
  local depth = tracks[i].depth
  for j = i + 1, #tracks do
    if tracks[j].depth <= depth then
      break
    end
    out[#out + 1] = tracks[j]
  end
  return out
end

-- Returns {
--   stems             = tracks rendered as individual stems,
--   excluded_from_mix = top-level tracks left out of the combined mix,
--   mute_warnings     = { { track = t, muted = { tracks } } } for stems whose own
--                       or a descendant's mute will affect the output,
--   duplicate_names   = { name } shared by more than one stem, or by a stem and the
--                       combined mix (would collide on disk),
-- }
function M.plan(tracks)
  local stems, excluded, mute_warnings = {}, {}, {}

  for i, t in ipairs(tracks) do
    if M.is_exported(t) then
      stems[#stems + 1] = t

      local muted = {}
      if t.muted then
        muted[#muted + 1] = t
      end
      for _, d in ipairs(M.descendants(tracks, i)) do
        if d.muted then
          muted[#muted + 1] = d
        end
      end
      if #muted > 0 then
        mute_warnings[#mute_warnings + 1] = { track = t, muted = muted }
      end
    elseif t.depth == 0 then
      excluded[#excluded + 1] = t
    end
  end

  -- Case-insensitive, since macOS and Windows filesystems are. The combined mix renders
  -- as "Master", so a stem with that name would collide with it.
  local seen, duplicate_names = { master = 1 }, {}
  for _, t in ipairs(stems) do
    local key = M.display_name(t):lower()
    seen[key] = (seen[key] or 0) + 1
    if seen[key] == 2 then
      duplicate_names[#duplicate_names + 1] = M.display_name(t)
    end
  end

  return {
    stems = stems,
    excluded_from_mix = excluded,
    mute_warnings = mute_warnings,
    duplicate_names = duplicate_names,
  }
end

return M
