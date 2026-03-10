#!/bin/bash
# Open Unchecked Ideas note in nvim (auto-generates first if needed)

# Ensure homebrew PATH is available (WezTerm spawns with minimal macOS PATH)
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"

VAULT_DIR="$HOME/obsidian-notes"
IDEAS_NOTE="$VAULT_DIR/Unchecked-Ideas.md"

# Regenerate the ideas note first (so it's always fresh)
"$VAULT_DIR/generate-unchecked-ideas.sh"

# Open in nvim at the vault root (so markdown-oxide can find the vault)
cd "$VAULT_DIR"
exec nvim "$IDEAS_NOTE"
