#!/usr/bin/env bash
# Captures all README screenshots for Clicker.
#
# Prereq (one-time):
#   System Settings → Privacy & Security → Screen Recording → enable for Terminal/iTerm.
#   Then restart your terminal.
#
# Usage:
#   ./scripts/capture_screenshots.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/Build/Products/Release/Clicker.app"
OUT="$ROOT/docs/screenshots"
mkdir -p "$OUT"

if [[ ! -d "$APP" ]]; then
  echo "Clicker.app not found at $APP — build it first (xcodebuild or ⌘B in Xcode)." >&2
  exit 1
fi

# Quit any stale instance, then launch fresh
osascript -e 'tell application "Clicker" to quit' 2>/dev/null || true
sleep 0.3
open -a "$APP"
sleep 2
osascript -e 'tell application "Clicker" to activate' || true
sleep 0.5

# Locate the window via CGWindowListCopyWindowInfo
read -r WID X Y W H < <(swift - <<'SWIFT'
import CoreGraphics
import Foundation
let opts: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
let wins = (CGWindowListCopyWindowInfo(opts, kCGNullWindowID) as? [[String: Any]]) ?? []
for w in wins {
    let owner = w[kCGWindowOwnerName as String] as? String ?? ""
    guard owner == "Clicker" else { continue }
    let id = w[kCGWindowNumber as String] as? Int ?? 0
    let b = w[kCGWindowBounds as String] as? [String: CGFloat] ?? [:]
    let x = Int(b["X"] ?? 0), y = Int(b["Y"] ?? 0)
    let cw = Int(b["Width"] ?? 0), ch = Int(b["Height"] ?? 0)
    guard cw > 100, ch > 100 else { continue } // skip menu-bar widgets
    print("\(id) \(x) \(y) \(cw) \(ch)")
    exit(0)
}
FileHandle.standardError.write(Data("Clicker window not found\n".utf8))
exit(2)
SWIFT
)

echo "→ Clicker window: id=$WID  rect=${X},${Y}  ${W}x${H}"

shot() {
  local name="$1"
  echo "  · $name.png"
  # -l <wid> captures the window only, including shadow (-o disables shadow)
  screencapture -l "$WID" -o "$OUT/$name.png"
}

# 1) Main window (idle, default state on first launch)
shot main-window
cp "$OUT/main-window.png" "$OUT/hero.png"  # reuse as hero by default

# Optional follow-up shots — uncomment / add interactions as needed.
# After clicking buttons via UI Scripting, re-shoot.
#   shot playback-controls
#   shot save-macro
#   shot macro-list
#   shot permissions

echo ""
echo "Done. Files in $OUT/"
echo "If images look black, grant Screen Recording to your terminal in"
echo "System Settings → Privacy & Security → Screen Recording, then restart the terminal."
