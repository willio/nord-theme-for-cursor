#!/bin/bash
# Applies the Nord glass theme to Cursor.
# Cursor MUST be fully quit first — a window reload can flush the in-memory
# theme back over the database file. Run ./verify.py afterwards to confirm.
#
# Env overrides (used by tests to operate on copies):
#   CURSOR_DB       path to state.vscdb
#   CURSOR_SETTINGS path to settings.json
set -euo pipefail

DB="${CURSOR_DB:-$HOME/Library/Application Support/Cursor/User/globalStorage/state.vscdb}"
SETTINGS="${CURSOR_SETTINGS:-$HOME/Library/Application Support/Cursor/User/settings.json}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
THEME_JSON="$SCRIPT_DIR/glass-theme.json"

[ -f "$DB" ] || { echo "ERROR: state.vscdb not found at $DB"; exit 1; }
[ -f "$SETTINGS" ] || { echo "ERROR: settings.json not found at $SETTINGS"; exit 1; }
[ -f "$THEME_JSON" ] || { echo "ERROR: glass-theme.json missing next to apply.sh"; exit 1; }

# skip the running-check when pointed at test copies
if [ -z "${CURSOR_DB:-}${CURSOR_SETTINGS:-}" ]; then
  if pgrep -x Cursor > /dev/null; then
    echo "ERROR: Cursor is running. Fully quit it (Cmd+Q) first — a reload would overwrite the theme write."
    exit 1
  fi
fi

command -v python3 > /dev/null || { echo "ERROR: python3 not found"; exit 1; }

STAMP="$(date +%Y%m%d-%H%M%S)"
cp "$DB" "$DB.backup-$STAMP"
cp "$SETTINGS" "$SETTINGS.backup-$STAMP"
echo "backups: $DB.backup-$STAMP, $SETTINGS.backup-$STAMP"

python3 - "$DB" "$SETTINGS" "$THEME_JSON" <<'PY'
import json, sqlite3, sys

db_path, settings_path, theme_path = sys.argv[1:4]

theme = json.load(open(theme_path))
assert "nord" in theme["themes"], "glass-theme.json has no nord theme"

values = {
    "glass.theme.settingsId": "cursor-custom-theme:nord",
    "glass.theme.darkSettingsId": "cursor-custom-theme:nord",
    "glass.theme.customTintHue": "220",
    "glass.theme.customTintIntensity": "0",
    "glass.theme.detectColorScheme": "false",
    "cursor.themeSync.enabled": "true",
    "glass.theme.customThemesV1": json.dumps(theme, separators=(",", ":")),
}

con = sqlite3.connect(db_path)
cur = con.cursor()
for key, value in values.items():
    cur.execute("INSERT INTO ItemTable (key, value) VALUES (?, ?) "
                "ON CONFLICT(key) DO UPDATE SET value=excluded.value", (key, value))
con.commit()
con.close()
print("glass theme keys written:", ", ".join(values))

settings = json.load(open(settings_path))
settings["workbench.colorTheme"] = "Nord"
settings["cursor.general.reduceTransparency"] = True
settings["window.autoDetectColorScheme"] = False
with open(settings_path, "w") as f:
    json.dump(settings, f, indent=4)
    f.write("\n")
print("settings.json updated (workbench.colorTheme: Nord)")
PY

if ! ls -d "$HOME"/.cursor/extensions/arcticicestudio.nord-visual-studio-code-* > /dev/null 2>&1; then
  cat <<'EOF'
WARNING: the Nord VS Code extension is not installed in ~/.cursor/extensions.
The glass chrome will be Nord without it, but editor syntax colors need it:
  Cursor: Extensions panel -> search "nord" -> install "Nord Visual Studio Code" (arcticicestudio)
  or:     cursor --install-extension arcticicestudio.nord-visual-studio-code
EOF
fi

echo "done — open Cursor and check Settings -> Appearance (theme should show as Nord)."
echo "then run: python3 verify.py"
