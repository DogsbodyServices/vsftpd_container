#!/bin/bash
set -e

################################################
# Mount GCS Bucket
################################################
if [ -z "$GCS_BUCKET_NAME" ] || [ -z "$GCS_MOUNT_PATH" ]; then
  echo "[ERROR] GCS configuration is incomplete. Please set GCS_BUCKET_NAME and GCS_MOUNT_PATH."
  exit 1
else
  echo "[INFO] Mounting GCS bucket: $GCS_BUCKET_NAME at $GCS_MOUNT_PATH"
  mkdir -p "$GCS_MOUNT_PATH"
  gcsfuse "$GCS_BUCKET_NAME" "$GCS_MOUNT_PATH"
  if [ $? -ne 0 ]; then
    echo "[ERROR] Failed to mount GCS bucket."
    exit 1
  fi
  echo "[INFO] GCS bucket mounted successfully."
fi

################################################
# Bootstrap FTP/SFTP Users from file
################################################

# add nologin to shells to allow vsftd login
echo "/sbin/nologin" >> /etc/shells

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

    # Create user folder in GCS bucket
    #mkdir /data/$user
    chown root:root /data/$user
    chmod 755 /data/$user
    echo "[INFO] User $user created with home directory /data/$user."

    # Create in/out directories
    mkdir -p /mnt/gcs/$user/in /mnt/gcs/$user/out
    chown "$user" /mnt/gcs/$user/in /mnt/gcs/$user/out
    chmod 700 /mnt/gcs/$user/in /mnt/gcs/$user/out
    echo "[INFO] Created in/out directories for user $user."

    # Symlink in and out directories to GCS bucket
    ln -s /mnt/gcs/$user/in /data/$user/in
    ln -s /mnt/gcs/$user/out /data/$user/out
    echo "[INFO] Symlinked in/out directories for user $user to GCS bucket."
  done
else
  echo "[WARN] No user JSON found at /etc/vsftpd/users.json — skipping user bootstrap."
fi

################################################
# Set Machine Key Permissions
################################################
chmod 600 /etc/ssh/*key*

################################################
# Set PASV port range if defined
################################################
if [ -n "$PASV_MIN_PORT" ] && [ -n "$PASV_MAX_PORT" ]; then
  echo "[INFO] Setting PASV port range: $PASV_MIN_PORT-$PASV_MAX_PORT"
  sed 's/^pasv_min_port=.*/pasv_min_port=$PASV_MIN_PORT/' -i /etc/vsftpd/vsftpd.conf
  sed 's/^pasv_max_port=.*/pasv_max_port=$PASV_MAX_PORT/' -i /etc/vsftpd/vsftpd.conf
else
  echo "[WARN] PASV port range not set. Defaulting to 10000-10250."
fi

################################################
# Start services
################################################
echo "[INFO] Starting SFTP (OpenSSH) and FTP (vsftpd) services..."

# ---- Prepare SSHD (SFTP) ----
mkdir -p /var/run/sshd

if [ ! -f /etc/ssh/sshd_config ]; then
    echo "[ERROR] /etc/ssh/sshd_config not found!"
    exit 1
fi

# Start SSH daemon (SFTP)
echo "[INFO] Starting OpenSSH server..."
/usr/sbin/sshd

# Verify SSHD started
sleep 1
if ! ss -tln | grep -q ':22'; then
    echo "[ERROR] sshd failed to start on port 22."
    exit 1
fi
echo "[INFO] SSHD is running on port 22."

# ---- Prepare vsftpd ----
if [ ! -f /etc/vsftpd/vsftpd.conf ]; then
    echo "[ERROR] /etc/vsftpd/vsftpd.conf not found!"
    exit 1
fi

# Ensure vsftpd log files exist
touch /var/log/vsftpd.log /var/log/vsftpd_verbose.log
chmod 666 /var/log/vsftpd.log /var/log/vsftpd_verbose.log

# Stream  logs to Docker logs
tail -F /var/log/vsftpd.log | sed 's/^/[vsftpd] /'  &
tail -F /var/log/vsftpd_verbose.log | sed 's/^/[vsftpd] /'  >&2 &
tail -F /var/log/secure | sed 's/^/[sshd] /' &

# Start vsftpd
echo "[INFO] Starting vsftpd..."
/usr/local/sbin/vsftpd /etc/vsftpd/vsftpd.conf &

# Verify vsftpd started
echo "[INFO] Waiting for vsftpd to start..."
sleep 1
if ! ss -tln | grep -q ':21'; then
    echo "[ERROR] vsftpd failed to start on port 21."
    exit 1
fi
echo "[INFO] vsftpd is running on port 21."

# ---- Wait for both processes ----
echo "[INFO] All services started. Container is now ready."
wait -n
