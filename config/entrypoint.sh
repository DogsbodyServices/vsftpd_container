#!/bin/bash
set -e

echo "[INFO] Starting SFTP (OpenSSH) and FTP (vsftpd) services..."

# ---- Prepare SSHD (SFTP) ----
mkdir -p /var/run/sshd

if [ ! -f /etc/ssh/sshd_config ]; then
    echo "[ERROR] /etc/ssh/sshd_config not found!"
    exit 1
fi

# ---- Set perms on /etc/ssh/* machine keys ----
chmod 644 /etc/ssh/*key*

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
/usr/local/sbin/vsftpd /etc/vsftpd/vsftpd.conf

# Verify vsftpd started
sleep 1
if ! ss -tln | grep -q ':21'; then
    echo "[ERROR] vsftpd failed to start on port 21."
    exit 1
fi
echo "[INFO] vsftpd is running on port 21."

# ---- Wait for both processes ----
echo "[INFO] All services started. Container is now ready."
wait -n
