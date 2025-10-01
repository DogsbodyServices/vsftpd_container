#!/bin/bash
set -euo pipefail

CONFIG_PATH="/etc/vsftpd/users.json"
GROUP="simpleftp"
BASE_DIR="/data"

echo "[INFO] Updating users from: $CONFIG_PATH"

if [[ -f "/etc/vsftpd/users.json" ]]; then
  echo "[INFO] User config found at /etc/vsftpd/users.json. Bootstrapping users..."
  for user in $(jq -r 'keys[]' "/etc/vsftpd/users.json"); do
    hash=$(jq -r --arg u "$user" '.[$u]' "/etc/vsftpd/users.json")

    if ! id "$user" &>/dev/null; then
      echo "[INFO] Creating user: $user"
      useradd -m -d /data/$user -s /sbin/nologin -g simpleftp "$user"

    else
      echo "[INFO] User $user already exists."
    fi

    sed -i "s|^$user:[^:]*:|$user:$hash:|" /etc/shadow

    echo "[INFO] User $user created with home directory /data/$user."

    # Set root folder permissions to be unwritable by user
    chown root:root /data/$user
    chmod 755 /data/$user

    # Create user in/out folders in Directory if they do not exist
    for dir in in out; do
      if [[ ! -d /data/$user/$dir ]]; then
        mkdir -p /data/$user/$dir
        chown "$user" /data/$user/$dir
        chmod 700 /data/$user/$dir
        echo "[INFO] Created $dir directory for user $user."
      else
        echo "[INFO] $dir directory for user $user already exists."
      fi
    done
  done
else
  echo "[WARN] No user JSON found at /etc/vsftpd/users.json — skipping user bootstrap."
fi
