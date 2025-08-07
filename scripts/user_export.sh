#!/bin/bash

# Export FTP/SFTP users on a nexisting server to a JSON file

OUTPUT_FILE="users.json"
echo "{" > "$OUTPUT_FILE"

first=1
while IFS=: read -r username _ uid gid _ home shell; do
  if [[ "$uid" -ge 1000 && "$home" == /data/* ]]; then
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

echo "[INFO] Exported users to $OUTPUT_FILE"
