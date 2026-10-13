#!/usr/bin/env sh
# Symlink Rendering/ into REAPER's Scripts folder as webshare-dev/ so edits are live (macOS/Linux).
# Uses a different folder than a ReaPack install (Scripts/webshare/) so both can coexist.
# Override the resource path with REAPER_RESOURCE_PATH (e.g. for portable installs).
set -eu
repo="$(cd "$(dirname "$0")/.." && pwd)"
case "$(uname -s)" in
  Darwin) default="$HOME/Library/Application Support/REAPER" ;;
  *) default="${XDG_CONFIG_HOME:-$HOME/.config}/REAPER" ;;
esac
res="${REAPER_RESOURCE_PATH:-$default}"
dest="$res/Scripts/webshare-dev"

if [ -e "$dest" ] && [ ! -L "$dest" ]; then
  echo "error: $dest exists and is not a symlink; not touching it" >&2
  exit 1
fi
mkdir -p "$res/Scripts"
ln -sfn "$repo/Rendering" "$dest"
echo "Linked $dest -> $repo/Rendering"
