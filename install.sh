#!/usr/bin/env bash
# One-line installer:
#   curl -fsSL https://raw.githubusercontent.com/second-state/omarchy-remote/main/install.sh | bash
set -euo pipefail

REPO="${OMARCHY_REMOTE_REPO:-https://github.com/second-state/omarchy-remote}"
REF="${OMARCHY_REMOTE_REF:-main}"
SRC="${XDG_DATA_HOME:-$HOME/.local/share}/omarchy-remote/src"
BIN="$HOME/.local/bin"

[[ $EUID -ne 0 ]] || { echo "Run as your desktop user, not root." >&2; exit 1; }
command -v git >/dev/null || sudo pacman -S --needed --noconfirm git

if [[ -d "$SRC/.git" ]]; then
  git -C "$SRC" fetch -q --depth 1 origin "$REF"
  git -C "$SRC" checkout -q -B "$REF" FETCH_HEAD
else
  mkdir -p "$(dirname "$SRC")"
  git clone -q --depth 1 --branch "$REF" "$REPO" "$SRC"
fi

mkdir -p "$BIN"
ln -sf "$SRC/bin/omarchy-remote" "$BIN/omarchy-remote"
case ":$PATH:" in *":$BIN:"*) ;; *) echo "Note: add $BIN to your PATH" ;; esac

exec "$SRC/bin/omarchy-remote" setup
