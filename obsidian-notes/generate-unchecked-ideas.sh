#!/bin/bash
# Generate a note with all unchecked tasks from daily notes
# Links back to source notes for easy navigation

VAULT_DIR="$HOME/obsidian-notes"
OUTPUT_NOTE="$VAULT_DIR/Unchecked-Ideas.md"
DAILY_NOTES_DIR="$VAULT_DIR/daily-notes"

# Start fresh note
cat > "$OUTPUT_NOTE" <<'HEADER'
# Unchecked Ideas & Todos

All unchecked tasks from your daily notes. Click the note link to jump to the original.

---

HEADER

# Temporary files for organizing by section
todos_temp=$(mktemp)
ideas_temp=$(mktemp)

# Process all daily notes
while IFS= read -r -d '' note_file; do
  note_name=$(basename "$note_file" .md)

  # Track current section
  current_section=""

  while IFS= read -r line; do
    # Detect section headers
    if [[ "$line" =~ ^##[[:space:]]+Todo ]]; then
      current_section="todo"
      continue
    elif [[ "$line" =~ ^##[[:space:]]+Quick[[:space:]]Ideas ]]; then
      current_section="ideas"
      continue
    elif [[ "$line" =~ ^## ]]; then
      current_section=""
      continue
    fi

    # Extract unchecked tasks based on current section
    if [[ "$line" =~ ^[[:space:]]*-[[:space:]]\[[[:space:]]\][[:space:]](.+) ]]; then
      task_text="${BASH_REMATCH[1]}"
      formatted_task="- [ ] $task_text → [[$note_name]]"

      if [[ "$current_section" == "todo" ]]; then
        echo "$formatted_task" >> "$todos_temp"
      elif [[ "$current_section" == "ideas" ]]; then
        echo "$formatted_task" >> "$ideas_temp"
      fi
    fi
  done < "$note_file"
done < <(find "$DAILY_NOTES_DIR" -type f -name "*.md" -print0 | sort -z)

# Add Todos section
echo "## Todo" >> "$OUTPUT_NOTE"
echo "" >> "$OUTPUT_NOTE"
if [ -s "$todos_temp" ]; then
  cat "$todos_temp" >> "$OUTPUT_NOTE"
else
  echo "*No unchecked todos*" >> "$OUTPUT_NOTE"
fi

echo "" >> "$OUTPUT_NOTE"

# Add Quick Ideas section
echo "## Quick Ideas" >> "$OUTPUT_NOTE"
echo "" >> "$OUTPUT_NOTE"
if [ -s "$ideas_temp" ]; then
  cat "$ideas_temp" >> "$OUTPUT_NOTE"
else
  echo "*No unchecked ideas*" >> "$OUTPUT_NOTE"
fi

# Cleanup temp files
rm -f "$todos_temp" "$ideas_temp"

# Add footer with generation timestamp
echo "" >> "$OUTPUT_NOTE"
echo "---" >> "$OUTPUT_NOTE"
echo "*Generated: $(date '+%Y-%m-%d %H:%M')*" >> "$OUTPUT_NOTE"

echo "✅ Generated: $OUTPUT_NOTE"
