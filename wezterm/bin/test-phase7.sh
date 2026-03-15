#!/usr/bin/env bash
# Phase 7 test - Validate delete mode in picker.lua

set -e

echo "=== Phase 7: Delete Mode Test ==="

# Test 1: Pattern checks for delete mode implementation
echo "✓ Test 1: Checking picker.lua for delete mode patterns..."

PICKER_FILE="/Users/t026chirv/.config/wezterm/lua/session/picker.lua"

if ! [ -f "$PICKER_FILE" ]; then
  echo "  ✗ picker.lua not found"
  exit 1
fi

# Check for key patterns
patterns=(
  "Sessions \[DELETE\]"
  "__delete_mode__"
  "__back__"
  "delete_session"
  "PromptInputLine"
)

for pattern in "${patterns[@]}"; do
  if grep -q "$pattern" "$PICKER_FILE"; then
    echo "  ✓ Found pattern: $pattern"
  else
    echo "  ✗ Missing pattern: $pattern"
    exit 1
  fi
done

echo ""
echo "=== All tests passed ==="
