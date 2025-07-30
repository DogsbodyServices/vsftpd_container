FROM redhat/ubi9-minimal:latest

# Install dependencies for vsftpd build
RUN microdnf install -y \
    ca-certificates \
    tar \
    gzip \
    make \
    libcap-devel \
    gcc \
    rsyslog

# Install dependencies for pam
RUN microdnf install -y \
    pam

# Cleanup Microdnf
RUN microdnf clean all

# Install vsftpd from source
RUN curl --fail --location -o ./3.0.2.tar.gz https://github.com/dagwieers/vsftpd/archive/refs/tags/3.0.2.tar.gz
RUN tar -xzf ./3.0.2.tar.gz
RUN cd vsftpd-3.0.2 \
    && make CFLAGS="-O2 -fPIE -Wno-error=enum-conversion" \
    && make install
RUN rm -rf /vsftpd-3.0.2 /3.0.2.tar.gz

# download and install keycloak PAM module
#RUN curl --fail --location -o /tmp/kc-ssh-pam_amd64.rpm https://github.com/kha7iq/kc-ssh-pam/releases/download/v0.1.4/kc-ssh-pam_amd64.rpm \
#    && rpm -i /tmp/kc-ssh-pam_amd64.rpm \
#    && rm -f /tmp/kc-ssh-pam_amd64.rpm

#RUN ls /etc/pam.d

COPY ./config/vsftpd.conf /etc/vsftpd/vsftpd.conf
COPY ./config/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY ./config/vsftpd.banner /etc/vsftpd/vsftpd.banner
RUN chmod +x /usr/local/bin/entrypoint.sh
RUN echo "ftpuser" > /etc/vsftpd.user_list
#COPY ./config/config.toml /opt/kc-ssh-pam/config.toml

# Install Google Fuse Client for GCS mounting
COPY ./config/gcsfuse.repo /etc/yum.repos.d/gcsfuse.repo
RUN microdnf install -y gcsfuse

RUN useradd test && echo "test:password" | chpasswd

RUN touch /var/log/vsftpd.log /var/log/vsftpd_verbose.log && chmod 666 /var/log/vsftpd*.log

EXPOSE 21/tcp
EXPOSE 22/tcp

CMD ["/usr/local/bin/entrypoint.sh"]
