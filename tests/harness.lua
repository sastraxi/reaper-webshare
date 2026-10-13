-- Minimal test harness: tests run in order, failures are printed, exit code reflects result.
local H = { failures = 0, count = 0 }

function H.test(name, fn)
  H.count = H.count + 1
  local ok, err = pcall(fn)
  if not ok then
    H.failures = H.failures + 1
    print('FAIL ' .. name .. '\n  ' .. tostring(err))
  end
end

function H.eq(actual, expected, what)
  if actual ~= expected then
    error(('%s: expected %s, got %s'):format(what or 'value', tostring(expected), tostring(actual)), 2)
  end
end

function H.contains(haystack, needle)
  if not haystack:find(needle, 1, true) then
    error(('expected to find %q in:\n%s'):format(needle, haystack), 2)
  end
end

function H.finish()
  print(('%s: %d/%d passed'):format(arg and arg[0] or '?', H.count - H.failures, H.count))
  os.exit(H.failures == 0 and 0 or 1)
end

return H
