#!/bin/bash
set -euo pipefail

CONFIG_PATH="/etc/vsftpd/users.json"
GROUP="simpleftp"
BASE_DIR="/data"

echo "[INFO] Updating users from: $CONFIG_PATH"

if [[ ! -f "$CONFIG_PATH" ]]; then
  echo "[ERROR] User config not found: $CONFIG_PATH"
  exit 1
fi

for user in $(jq -r 'keys[]' "$CONFIG_PATH"); do
  hash=$(jq -r --arg u "$user" '.[$u]' "$CONFIG_PATH")

  if id "$user" &>/dev/null; then
    echo "[INFO] User $user already exists."
    continue
  fi

  echo "[INFO] Creating user: $user"
  useradd -m -d "$BASE_DIR/$user" -s /sbin/nologin -g "$GROUP" "$user"
  sed -i "s|^$user:[^:]*:|$user:$hash:|" /etc/shadow

  mkdir -p "$BASE_DIR/$user/upload"
  chown root:root "$BASE_DIR/$user"
  chmod 755 "$BASE_DIR/$user"
  chown $user:$GROUP "$BASE_DIR/$user/upload"
done

echo "[INFO] User sync complete."
