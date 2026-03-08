#!/bin/zsh
# paste_screenshot.sh — Extract clipboard image and inject path into active Kitty window
# Spec: 004-claude-screenshot-paste
# Bound to: ctrl+period in keybindings.conf

# Prevent multiple simultaneous runs (keybinding fires on all windows)
LOCK="/tmp/paste_screenshot.lock"
[[ -e "$LOCK" ]] && exit 0
touch "$LOCK"
trap "rm -f $LOCK" EXIT

TMPFILE="/tmp/screenshot_$(date +%s).png"

if /opt/homebrew/bin/pngpaste "$TMPFILE" 2>/dev/null; then
    SOCKET="unix:$(ls /tmp/kitty-* 2>/dev/null | head -1)"
    kitten @ --to "$SOCKET" send-text --match "recent:0" "$TMPFILE"
fi
