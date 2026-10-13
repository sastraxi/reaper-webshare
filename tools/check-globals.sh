#!/usr/bin/env sh
# Fails if any script reads or writes a global other than REAPER's API and Lua's standard
# library. Catches typos and locals used before they're declared (which silently become
# globals in Lua). Usage: tools/check-globals.sh [luac]
set -eu
LUAC="${1:-luac}"
ALLOWED='reaper|require|package|ipairs|pairs|table|string|math|os|io|tostring|tonumber|type|select|next|pcall|error|debug|assert|print'
status=0
for f in Rendering/*.lua Rendering/lib/*.lua; do
  bad=$("$LUAC" -p -l "$f" | grep -oE '[GS]ETTABUP.*_ENV "[^"]+"' | grep -oE '"[^"]+"$' \
    | tr -d '"' | sort -u | grep -vxE "$ALLOWED" || true)
  if [ -n "$bad" ]; then
    echo "$f: unexpected globals: $bad"
    status=1
  fi
done
exit $status
