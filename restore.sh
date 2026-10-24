#!/bin/bash
# Reverts to the pre-Nord state by restoring the newest apply.sh backups.
# Cursor MUST be fully quit first.
#
# Env overrides (used by tests to operate on copies):
#   CURSOR_DB       path to state.vscdb
#   CURSOR_SETTINGS path to settings.json
set -euo pipefail

DB="${CURSOR_DB:-$HOME/Library/Application Support/Cursor/User/globalStorage/state.vscdb}"
SETTINGS="${CURSOR_SETTINGS:-$HOME/Library/Application Support/Cursor/User/settings.json}"

[ -f "$DB" ] || { echo "ERROR: state.vscdb not found at $DB"; exit 1; }

if [ -z "${CURSOR_DB:-}${CURSOR_SETTINGS:-}" ]; then
  if pgrep -x Cursor > /dev/null; then
    echo "ERROR: Cursor is running. Fully quit it (Cmd+Q) first."
    exit 1
  fi
fi

LATEST_DB="$(ls -t "$DB".backup-* 2>/dev/null | head -1 || true)"
LATEST_SETTINGS="$(ls -t "$SETTINGS".backup-* 2>/dev/null | head -1 || true)"

if [ -z "$LATEST_DB" ]; then
  echo "no state.vscdb backups found next to $DB — nothing to restore."
  exit 1
fi

cp "$LATEST_DB" "$DB"
echo "restored $DB from $LATEST_DB"
if [ -n "$LATEST_SETTINGS" ]; then
  cp "$LATEST_SETTINGS" "$SETTINGS"
  echo "restored $SETTINGS from $LATEST_SETTINGS"
fi

echo "done — reopen Cursor (theme is back to whatever the backup predates)."
