# Stage 1: Build vsftpd
FROM redhat/ubi9-minimal AS builder

RUN microdnf install -y \
    ca-certificates tar gzip make gcc libcap-devel \
    && curl -LO https://github.com/dagwieers/vsftpd/archive/refs/tags/3.0.2.tar.gz \
    && tar -xzf 3.0.2.tar.gz \
    && cd vsftpd-3.0.2 && make CFLAGS="-O2 -fPIE -Wno-error=enum-conversion" && make install

# Stage 2: Runtime image
FROM redhat/ubi9-minimal

# Copy config files
COPY ./config/vsftpd.conf /etc/vsftpd/vsftpd.conf
COPY ./config/10-sftp_config.conf /etc/ssh/sshd_config.d/10-sftp_config.conf
COPY ./config/vsftpd.banner /etc/vsftpd/vsftpd.banner
COPY ./config/00-stdout.conf /etc/rsyslog.d/00-stdout.conf
COPY ./scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY ./scripts/update_users.sh /usr/local/bin/update_users.sh
COPY ./config/machine_keys/* /etc/ssh/
RUN echo "{}" /etc/vsftpd/users.json && \
    chmod +x /usr/local/bin/entrypoint.sh && \
    chmod +x /usr/local/bin/update_users.sh && \
    echo "ftpuser" > /etc/vsftpd.user_list

# Install only runtime deps
RUN microdnf install -y openssh-server iproute shadow-utils jq rsyslog cronie procps-ng && microdnf clean all

# Disable imjournal module in default rsyslog config to prevent journal errors in containers
RUN sed -i '/^module(load="imjournal"/,/^[[:space:]]*StateFile="imjournal.state")/s/^/#/' /etc/rsyslog.conf

# Copy vsftpd binary and config from builder
COPY --from=builder /usr/local/sbin/vsftpd /usr/local/sbin/vsftpd

# Setup SSH and users
RUN mkdir -p /var/run/sshd /data /var/run/rsyslog/dev /etc/vsftpd/ssh_keys && \
    groupadd simpleftp && \
    chmod 755 /var/run/rsyslog

# Setup cron job to update users every 30 minutes
RUN echo "*/30 * * * * /usr/local/bin/update_users.sh >> /var/log/user_updates.log 2>&1" | crontab -

# Create log files and permissions
RUN touch /var/log/vsftpd.log /var/log/vsftpd_verbose.log /var/log/secure /var/log/user_updates.log && \
    chmod 666 /var/log/vsftpd.log /var/log/vsftpd_verbose.log /var/log/user_updates.log && chmod 644 /var/log/secure

# Healthcheck to ensure vsftpd and SSH are running
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s \
    CMD ss -tln | grep -qE ':21|:22' || exit 1

# Start the entrypoint
CMD ["/usr/local/bin/entrypoint.sh"]
