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

  # Create user folder in GCS bucket
  mkdir /data/$user
  chown root:root /data/$user
  chmod 755 /data/$user
  echo "[INFO] User $user created with home directory /data/$user."

  # Create in/out directories
  mkdir -p /data/$user/in /data/$user/out
  chown "$user:$user" /data/$user/in /data/$user/out
  chmod 700 /data/$user/in /data/$user/out

  # Symlink in and out directories to GCS bucket
  ln -sf /mnt/gcs/$user/in /data/$user/in
  ln -sf /mnt/gcs/$user/out /data/$user/out
done

echo "[INFO] User sync complete."
