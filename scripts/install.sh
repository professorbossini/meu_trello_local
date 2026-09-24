#!/usr/bin/env bash
# Builds Minhas Tarefas in release mode and installs it for the current
# user, adding it to the application menu. The app itself sets up starting
# hidden in the tray on login (toggle it from the tray menu).
#
# Usage: scripts/install.sh [--no-build]
#   --no-build   install the existing release build without rebuilding
set -euo pipefail

readonly APP_ID="io.github.professorbossini.minhas_tarefas"
readonly ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
readonly INSTALL_DIR="$HOME/.local/opt/minhas_tarefas"
readonly BIN_LINK="$HOME/.local/bin/minhas-tarefas"

build=true
for arg in "$@"; do
  case "$arg" in
    --no-build) build=false ;;
    -h|--help) sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

case "$(uname -m)" in
  x86_64) arch=x64 ;;
  aarch64|arm64) arch=arm64 ;;
  *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac
readonly BUNDLE="$ROOT/build/linux/$arch/release/bundle"

cd "$ROOT"
if $build; then
  flutter build linux --release
fi
if [[ ! -x "$BUNDLE/minhas_tarefas" ]]; then
  echo "Release bundle not found at $BUNDLE; run without --no-build." >&2
  exit 1
fi

echo "Installing to $INSTALL_DIR"
rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR" "$(dirname "$BIN_LINK")"
cp -r "$BUNDLE/." "$INSTALL_DIR"
ln -sfn "$INSTALL_DIR/minhas_tarefas" "$BIN_LINK"

mkdir -p "$DATA_HOME/icons" "$DATA_HOME/applications"
cp -r "$ROOT/linux/packaging/icons/." "$DATA_HOME/icons/"

desktop_template="$ROOT/linux/packaging/$APP_ID.desktop"
sed "s|@EXEC@|$INSTALL_DIR/minhas_tarefas|" "$desktop_template" \
  > "$DATA_HOME/applications/$APP_ID.desktop"

# Refresh caches when the tools exist; failures here are harmless.
update-desktop-database "$DATA_HOME/applications" >/dev/null 2>&1 || true
gtk-update-icon-cache -q "$DATA_HOME/icons/hicolor" >/dev/null 2>&1 || true

echo "Done. Launch \"Minhas Tarefas\" from the application menu or run: $BIN_LINK"
