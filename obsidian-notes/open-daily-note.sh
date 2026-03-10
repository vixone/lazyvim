#!/bin/bash
# Quick-capture daily note opener for WezTerm + Neovim
# Creates today's daily note from template if it doesn't exist, then opens in nvim

# Ensure homebrew PATH is available (WezTerm spawns with minimal macOS PATH)
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"

VAULT_DIR="$HOME/obsidian-notes"
TEMPLATE="$VAULT_DIR/templates/daily-note.md"

# Date components
YEAR=$(date +%Y)
DAY=$(date +%d)
MONTH_LOWER=$(date +%B | tr '[:upper:]' '[:lower:]')
DAY_NAME=$(date +%A)
FULL_DATE=$(date +%Y-%m-%d)

# Path: ~/obsidian-notes/daily-notes/2026/09-march.md
NOTE_DIR="$VAULT_DIR/daily-notes/$YEAR"
NOTE_FILE="$NOTE_DIR/${DAY}-${MONTH_LOWER}.md"

mkdir -p "$NOTE_DIR"

# Create from template if note doesn't exist
if [ ! -f "$NOTE_FILE" ]; then
  sed -e "s/{{DATE}}/$FULL_DATE/g" \
      -e "s/{{DAY}}/$DAY_NAME/g" \
      "$TEMPLATE" > "$NOTE_FILE"
fi

# Open in nvim at the vault root (so markdown-oxide can find the vault)
cd "$VAULT_DIR"
exec nvim "$NOTE_FILE"
