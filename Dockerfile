FROM redhat/ubi9-minimal:latest

# Install dependencies for vsftpd build
RUN microdnf install -y \
    ca-certificates \
    tar \
    gzip \
    make

# Install dependencies for pam
RUN microdnf install -y \
    pam

# Cleanup Microdnf
RUN microdnf clean all

# Install vsftpd from source
RUN curl --fail --location -o ./3.0.2.tar.gz https://github.com/dagwieers/vsftpd/archive/refs/tags/3.0.2.tar.gz \
    && tar -xzf 3.0.2.tar.gz #\
    && cd vsftpd-3.0.2 \
    && make \
    && make install \
    && rm -rf /vsftpd-3.0.2 /3.0.2.tar.gz

# download and install keycloak PAM module
RUN curl --fail --location -o /tmp/kc-ssh-pam_amd64.rpm https://github.com/kha7iq/kc-ssh-pam/releases/download/v0.1.4/kc-ssh-pam_amd64.rpm \
    && rpm -i /tmp/kc-ssh-pam_amd64.rpm \
    && rm -f /tmp/kc-ssh-pam_amd64.rpm

RUN ls /etc/pam.d

COPY ./config/vsftpd.conf /etc/vsftpd/vsftpd.conf
COPY ./config/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY ./config/config.toml /opt/kc-ssh-pam/config.toml
