#!/usr/bin/env bash
# Builds Meu Trello Local in release mode and installs it for the current
# user, adding it to the application menu.
#
# Usage: scripts/install.sh [--autostart] [--no-build]
#   --autostart  also start the app hidden in the tray when you log in
#   --no-build   install the existing release build without rebuilding
set -euo pipefail

readonly APP_ID="io.github.professorbossini.meu_trello_local"
readonly ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
readonly CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
readonly INSTALL_DIR="$HOME/.local/opt/meu_trello_local"
readonly BIN_LINK="$HOME/.local/bin/meu-trello-local"

autostart=false
build=true
for arg in "$@"; do
  case "$arg" in
    --autostart) autostart=true ;;
    --no-build) build=false ;;
    -h|--help) sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
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
if [[ ! -x "$BUNDLE/meu_trello_local" ]]; then
  echo "Release bundle not found at $BUNDLE; run without --no-build." >&2
  exit 1
fi

echo "Installing to $INSTALL_DIR"
rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR" "$(dirname "$BIN_LINK")"
cp -r "$BUNDLE/." "$INSTALL_DIR"
ln -sfn "$INSTALL_DIR/meu_trello_local" "$BIN_LINK"

mkdir -p "$DATA_HOME/icons" "$DATA_HOME/applications"
cp -r "$ROOT/linux/packaging/icons/." "$DATA_HOME/icons/"

desktop_template="$ROOT/linux/packaging/$APP_ID.desktop"
sed "s|@EXEC@|$INSTALL_DIR/meu_trello_local|" "$desktop_template" \
  > "$DATA_HOME/applications/$APP_ID.desktop"

autostart_file="$CONFIG_HOME/autostart/$APP_ID.desktop"
if $autostart; then
  mkdir -p "$(dirname "$autostart_file")"
  sed "s|@EXEC@|$INSTALL_DIR/meu_trello_local --hidden|" "$desktop_template" \
    > "$autostart_file"
  echo "Autostart enabled: $autostart_file"
fi

# Refresh caches when the tools exist; failures here are harmless.
update-desktop-database "$DATA_HOME/applications" >/dev/null 2>&1 || true
gtk-update-icon-cache -q "$DATA_HOME/icons/hicolor" >/dev/null 2>&1 || true

echo "Done. Launch \"Meu Trello Local\" from the application menu or run: $BIN_LINK"
