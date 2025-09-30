#!/bin/bash
set -e

################################################
# Bootstrap FTP/SFTP Users from file
################################################

# add nologin to shells to allow vsftd login
grep -qxF "/sbin/nologin" /etc/shells || echo "/sbin/nologin" >> /etc/shells

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

    # Create user in/out folders in Directory
    mkdir -p /data/$user/in /data/$user/out
    chown "$user" /data/$user/in /data/$user/out
    chmod 700 /data/$user/in /data/$user/out
    echo "[INFO] Created in/out directories for user $user."

    # Create bind mount points for in/out directories
    mkdir -p /data/$user/in /data/$user/out

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
  echo "[INFO] Setting PASV port range: $PASV_MIN_PORT-$PASV_MAX_PORT, PASV address: $PASV_ADDRESS"
  sed "s/^pasv_min_port=.*/pasv_min_port=${PASV_MIN_PORT}/" -i /etc/vsftpd/vsftpd.conf
  sed "s/^pasv_max_port=.*/pasv_max_port=${PASV_MAX_PORT}/" -i /etc/vsftpd/vsftpd.conf
  sed "s/^pasv_address=.*/pasv_address=${PASV_ADDRESS}/" -i /etc/vsftpd/vsftpd.conf
else
  echo "[WARN] PASV port range not set. Defaulting to 10000-10250."
fi

################################################
# Enable TLS if options are set
################################################
if [ "$ENABLE_FTPS" == "YES" ] then
  sed "s/^ssl_enable=.*/ssl_enable=YES/" -i /etc/vsftpd/vsftpd.conf
  echo "[INFO] FTPS enabled."
else
  echo "[INFO] FTPS not enabled."
fi

################################################
# Start services
################################################
# Prepare socket dir and link it to /dev/log so all daemons find it
mkdir -p /var/run/rsyslog/dev
ln -sf /var/run/rsyslog/dev/log /dev/log

# Start rsyslog in foreground (background it with & so the script continues)
rsyslogd -n &

# Give it a moment to create the socket
sleep 0.3

# Sanity check (optional): should now exist
if [ ! -S /dev/log ]; then
  echo "[ERROR] /dev/log not created by rsyslog; logging will be broken."
fi


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
