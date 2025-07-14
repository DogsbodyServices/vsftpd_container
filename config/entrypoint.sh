#!/bin/bash
set -e

# Set config file path here
MOUNTED_CONF="/tmp/vsftpd.conf"
FINAL_CONF="/etc/vsftpd/vsftpd.conf"

# Use mounted config if present, otherwise fallback to image default
if [ -f "$MOUNTED_CONF" ]; then
    echo "[INFO] Using mounted vsftpd.conf"
    cp "$MOUNTED_CONF" "$FINAL_CONF"
else
    echo "[INFO] Using default vsftpd.conf from image"
fi

# Ensure correct permissions (even for default)
chown root:root "$FINAL_CONF"
chmod 644 "$FINAL_CONF"

# Start vsftpd
echo "[INFO] Starting vsftpd..."

# Start vsftpd in the background
/usr/sbin/vsftpd -obackground=YES /etc/vsftpd/vsftpd.conf &

# Wait a bit for vsftpd to start and log file to be ready
sleep 1

# Tail the log so Docker captures it
tail -F /var/log/vsftpd.log