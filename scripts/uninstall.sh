#!/usr/bin/env bash
# Removes Minhas Tarefas from the current user's session.
#
# Usage: scripts/uninstall.sh [--purge]
#   --purge  also delete the saved board
set -euo pipefail

readonly APP_ID="io.github.professorbossini.minhas_tarefas"
readonly DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
readonly CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

purge=false
for arg in "$@"; do
  case "$arg" in
    --purge) purge=true ;;
    -h|--help) sed -n '2,5p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

rm -rf "$HOME/.local/opt/minhas_tarefas"
rm -f "$HOME/.local/bin/minhas-tarefas" \
  "$DATA_HOME/applications/$APP_ID.desktop" \
  "$CONFIG_HOME/autostart/$APP_ID.desktop"
find "$DATA_HOME/icons/hicolor" -name "$APP_ID.png" -delete 2>/dev/null || true

if $purge; then
  rm -rf "${DATA_HOME:?}/$APP_ID"
  echo "Board data deleted."
else
  echo "Board data kept in $DATA_HOME/$APP_ID (use --purge to delete it)."
fi
echo "Minhas Tarefas was uninstalled."
