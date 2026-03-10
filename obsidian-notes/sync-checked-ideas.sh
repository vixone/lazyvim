#!/bin/bash
# Sync checked tasks from Unchecked-Ideas.md back to their source daily notes

VAULT_DIR="$HOME/obsidian-notes"
IDEAS_NOTE="$VAULT_DIR/Unchecked-Ideas.md"
DAILY_NOTES_DIR="$VAULT_DIR/daily-notes"

# Exit if ideas note doesn't exist
if [ ! -f "$IDEAS_NOTE" ]; then
  exit 0
fi

# Find all CHECKED tasks in ideas note (- [x] ... → [[note-name]])
grep -E '^[[:space:]]*-[[:space:]]*\[x\][[:space:]]+.*→[[:space:]]*\[\[.*\]\]' "$IDEAS_NOTE" | while IFS= read -r line; do
  # Extract task text (everything between [x] and →)
  # Remove leading "- [x] " and everything after " → "
  task_text=$(echo "$line" | sed 's/^[[:space:]]*-[[:space:]]*\[x\][[:space:]]*//; s/[[:space:]]*→.*$//')

  # Extract source note name (between [[ and ]])
  note_name=$(echo "$line" | sed -E 's/.*\[\[([^]]+)\]\].*/\1/')

  # Find the source note file
  source_note=$(find "$DAILY_NOTES_DIR" -type f -name "${note_name}.md" | head -1)

  if [ -n "$source_note" ] && [ -f "$source_note" ]; then
    # Escape special regex characters in task text for sed
    escaped_task=$(echo "$task_text" | sed 's/[]\/$*.^[]/\\&/g')

    # Update the source note: change - [ ] task_text to - [x] task_text
    # Use a temp file to avoid sed platform differences
    sed "s/^\([[:space:]]*-[[:space:]]*\)\[[[:space:]]\]\([[:space:]]*${escaped_task}\)/\1[x]\2/" "$source_note" > "${source_note}.tmp"

    # Only update if changes were made
    if ! cmp -s "$source_note" "${source_note}.tmp"; then
      mv "${source_note}.tmp" "$source_note"
      echo "✓ Updated: $note_name (checked: $task_text)"
    else
      rm "${source_note}.tmp"
    fi
  fi
done
