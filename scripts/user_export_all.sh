#!/bin/bash

# Export all users above UID 1000 to a JSON file
# This includes all non-system users regardless of home directory location

OUTPUT_FILE="users_all.json"
echo "{" > "$OUTPUT_FILE"

first=1
while IFS=: read -r username _ uid gid _ home shell; do
  # Export all users with UID >= 1000 (non-system users)
  if [[ "$uid" -ge 1000 ]]; then
    hash=$(grep "^$username:" /etc/shadow | cut -d: -f2)
    if [[ $first -eq 0 ]]; then
      echo "," >> "$OUTPUT_FILE"
    fi
    echo "  \"$username\": \"$hash\"" >> "$OUTPUT_FILE"
    first=0
  fi
done < /etc/passwd

echo "" >> "$OUTPUT_FILE"
echo "}" >> "$OUTPUT_FILE"

echo "[INFO] Exported $(grep -c '":' "$OUTPUT_FILE") users to $OUTPUT_FILE"
