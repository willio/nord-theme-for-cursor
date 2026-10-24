#!/usr/bin/env python3
"""Read-only verification that the Nord glass theme is applied to Cursor.

Usage:
    python3 verify.py                    # live database + settings
    python3 verify.py --db /path/state.vscdb --settings /path/settings.json
"""
import argparse
import json
import sqlite3
import sys
from pathlib import Path

ap = argparse.ArgumentParser()
ap.add_argument("--db", default=str(Path.home() / "Library/Application Support/Cursor/User/globalStorage/state.vscdb"))
ap.add_argument("--settings", default=str(Path.home() / "Library/Application Support/Cursor/User/settings.json"))
ap.add_argument("--theme", default=str(Path(__file__).parent / "glass-theme.json"))
args = ap.parse_args()

ok = True

def check(label, cond, detail=""):
    global ok
    print(("PASS" if cond else "FAIL"), label, detail)
    ok = ok and cond

con = sqlite3.connect(f"file:{args.db}?mode=ro", uri=True)
cur = con.cursor()

def get(key):
    cur.execute("SELECT value FROM ItemTable WHERE key=?", (key,))
    row = cur.fetchone()
    return row[0] if row else None

check("glass.theme.settingsId is nord", get("glass.theme.settingsId") == "cursor-custom-theme:nord")
check("glass.theme.darkSettingsId is nord", get("glass.theme.darkSettingsId") == "cursor-custom-theme:nord")
check("tint hue 220", get("glass.theme.customTintHue") == "220",
      f"got {get('glass.theme.customTintHue')}")
check("tint intensity 0", get("glass.theme.customTintIntensity") == "0",
      f"got {get('glass.theme.customTintIntensity')}")

live = get("glass.theme.customThemesV1")
saved = json.loads(Path(args.theme).read_text())
check("customThemesV1 matches glass-theme.json",
      live is not None and json.loads(live) == saved)
if live:
    d = json.loads(live)["themes"]["nord"]["definition"]
    check("sidebar is #2e3440", d.get("sidebar") == "#2e3440", f"got {d.get('sidebar')}")
    check("elevated is #3b4252", d.get("elevated") == "#3b4252", f"got {d.get('elevated')}")
con.close()

settings = json.loads(Path(args.settings).read_text())
check("workbench.colorTheme is Nord", settings.get("workbench.colorTheme") == "Nord")
check("reduceTransparency is true", settings.get("cursor.general.reduceTransparency") is True)
check("autoDetectColorScheme is false", settings.get("window.autoDetectColorScheme") is False)

exts = list(Path.home().glob(".cursor/extensions/arcticicestudio.nord-visual-studio-code-*"))
check("Nord VS Code extension installed", bool(exts), exts[0].name if exts else "not found")

sys.exit(0 if ok else 1)
