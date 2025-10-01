# VSFTPD + SFTP Container

This project provides a secure, containerized FTP/SFTP server based on `vsftpd` and OpenSSH. It supports user-based access with chrooted home directories, dynamic user provisioning via a JSON file.

---

## 🔧 Features

- **FTP over `vsftpd`** - Secure FTP server with customizable configuration
- **SFTP over OpenSSH** - SSH File Transfer Protocol support
- **Dynamic user creation from JSON** - Automated user provisioning at startup
- **Chrooted upload directories** - Users restricted to their home directories with secure in/out folders
- **Containerized logging** - Optimized rsyslog configuration for container environments
- **User export utilities** - Scripts to export existing users for migration
- **Customizable via environment variables** - Runtime configuration for passive ports and addresses
- **Healthchecks for container orchestration** - Built-in health monitoring
- **Passive address resolution from provided domain name** - Dynamic IP resolution for NAT environments
- **Multi-stage Docker build** - Optimized image size with separate build and runtime stages
- **SSL/TLS support** - Ready for FTPS configuration (currently disabled by default)

---

## 🚀 Quick Start

### Build the image

```bash
docker build -t vsftpd_container .
```

### Run with Docker Compose

Ensure you have a users.json exported from any existing FTP servers, or created for this, format is shown below with a username and a hashed value for the password, hashed values can gbe generated usin ```openssl passwd -6 -salt xyz <yourpass>```. 

If you dont provide this there will be no users in the container.  

```
{
  "aaron": "$y$j9T$QGcBtB4.9NtptjoDgOGB51$hcIe4Ei4nM39rW.6pYBcVQjBHBRv0Jh4UdpeJA5C0x5",
  "plainftp": "$6$BWZe/CFWGwBT4QTL$jB7eibRC0F99aIIf2dZJhut9xmTwrNkzqpx41nRLgFIY9ISkiCD8Y5457qTLoRzCLGKGUp9dEok1NCsd.2Ty0/",
  "sftp": "$6$BWZe/CFWGwBT4QTL$jB7eibRC0F99aIIf2dZJhut9xmTwrNkzqpx41nRLgFIY9ISkiCD8Y5457qTLoRzCLGKGUp9dEok1NCsd.2Ty0/"
}
```

```bash
docker compose up -d
```

Compose example:

```yaml
services:
  cw_ftp:
    #image: dogsbody.azurecr.io/vsftpd_container:latest
    image: ftp_container:latest
    container_name: ftp_container
    ports:
      - "21:21"
      - "2222:22"
      - "10000-10250:10000-10250"
    environment:
      PASV_MIN_PORT: "10000"
      PASV_MAX_PORT: "10250"
      PASV_ADDRESS: "ftp.server.com"
    volumes:
      - ${PWD}/config/users.json:/etc/vsftpd/users.json:ro
      - ${PWD}/data:/data
      - ${PWD}/certs:/etc/vsftpd/certs:ro  # FTPS certificates (optional)
```

---

## 📁 Directory Structure

```
├── config/
│   ├── vsftpd.conf                # FTP server configuration
│   ├── 10-sftp_config.conf        # SSHD/SFTP match rules
│   ├── 00-stdout.conf             # Rsyslog configuration for container logging
│   ├── vsftpd.banner              # FTP login banner
│   ├── user_list                  # Allowed FTP users
│   ├── users.json                 # User definitions (created at runtime)
│   ├── ftpusers                   # System users denied FTP access
│   └── machine_keys/              # Static SSH host keys for container identity
├── scripts/
│   ├── entrypoint.sh              # Main container startup script
│   ├── update_users.sh            # JSON -> user sync script
│   ├── user_export.sh             # Export FTP/SFTP users from /data/* homes
│   └── user_export_all.sh         # Export all users with UID >= 1000
├── docker-compose.yml
├── Dockerfile
└── azure-pipelines.yml
```

---

## 🧑‍💻 User Management

### Format: `users.json`

```json
{
  "sftpuser1": "$6$hashed_password",
  "ftpuser2": "$6$another_hash"
}
```

Passwords must be hashed using SHA-512 (`crypt.crypt()` in Python).

### User Export Scripts

Two scripts are available to export existing users:

- **`user_export.sh`** - Exports users with UID ≥ 1000 and home directories in `/data/*` (FTP/SFTP specific)
- **`user_export_all.sh`** - Exports all users with UID ≥ 1000 regardless of home directory location

```bash
# Export FTP/SFTP users only
./scripts/user_export.sh

# Export all non-system users
./scripts/user_export_all.sh
```

Both scripts generate a JSON file compatible with the container's user provisioning system.

### Directory Structure per User

Each user gets a secure directory structure:

```
/data/<username>/
├── in/          # Upload directory (writable by user)
└── out/         # Download directory (writable by user)
└── .ssh/        # If user is using key auth for SFTP, authorixed_keys file will be here owned by user (0600)

```

Root directory `/data/<username>/` is owned by root and read-only to prevent privilege escalation.

### Sync Behavior

- At container **startup**, `entrypoint.sh` reads `/etc/vsftpd/users.json` and creates users
- Users are assigned to group `simpleftp` and chrooted to `/data/<username>/`
- SSH shell is set to `/sbin/nologin` for security
- **Automatic periodic sync**: A cron job runs `update_users.sh` every 30 minutes to sync user changes
- Manual sync can be triggered by running `/usr/local/bin/update_users.sh` inside the container

---

## 🔐 Security Notes

- **SSH host keys are static** for container identity consistency across restarts
- **Passwords are stored hashed** using SHA-512; no plaintext is handled
- **Users are chrooted** to their home directories with restricted shell access
- **Directory permissions** are carefully controlled (root-owned parent, user-owned subdirectories)
- **Container-optimized logging** prevents systemd journal errors in containerized environments
- **`users.json` should be managed securely** — do not commit to version control unless encrypted
- **SSL/TLS support available** but disabled by default (can be enabled via configuration)

---

## 🔍 Healthchecks

The container includes built-in health monitoring:

```dockerfile
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s \
    CMD ss -tln | grep -qE ':21|:22' || exit 1
```

This verifies that both FTP (port 21) and SSH/SFTP (port 22) services are listening and ready to accept connections.

---

## 📦 Technical Details

### Base Image & Size
- **Base**: Red Hat UBI 9 Minimal for security and compliance
- **Multi-stage build** separates compile-time and runtime dependencies
- **Optimized size**: ~230MB with all features included

### Logging Configuration
- **Container-optimized rsyslog** with `imjournal` module disabled
- **Stdout logging** for proper container log aggregation
- **Prevents journal errors** common in containerized environments

### Build Process
- **Stage 1**: Compiles vsftpd from source with security optimizations
- **Stage 2**: Runtime image with only necessary dependencies
- **Static SSH keys** maintained for consistent container identity

### Automated User Sync
- **Cron daemon** runs automatically on container startup
- **30-minute intervals** for checking and applying user configuration changes
- **Logging** of sync operations to `/var/log/user_updates.log`

---

## 🔄 CI/CD Integration

### Azure Pipelines

The file `azure-pipelines.yml` is provided to automate builds and optionally push to Azure Container Registry.

Ensure secrets for registry login are securely managed in Azure DevOps.

---

## ⚙️ Configuration Options

### Environment Variables

The container supports the following environment variables for runtime configuration:

#### FTP Passive Mode Configuration
| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `PASV_MIN_PORT` | Minimum port for passive FTP connections | `10000` | `10000` |
| `PASV_MAX_PORT` | Maximum port for passive FTP connections | `10250` | `10250` |
| `PASV_ADDRESS` | External IP address or domain name for passive connections | `127.0.0.1` | `ftp.example.com` |

#### SSL/TLS Configuration
| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `ENABLE_FTPS` | Enable FTPS (FTP over SSL/TLS) | `NO` | `YES` |

#### Usage Examples

**Basic FTP with custom passive ports:**
```yaml
environment:
  PASV_MIN_PORT: "21000"
  PASV_MAX_PORT: "21050"
  PASV_ADDRESS: "192.168.1.100"
```

**Enable FTPS with certificates:**
```yaml
environment:
  PASV_MIN_PORT: "10000"
  PASV_MAX_PORT: "10250" 
  PASV_ADDRESS: "ftp.example.com"
  ENABLE_FTPS: "YES"
volumes:
  - ./certs:/etc/vsftpd/certs:ro
```

**Notes:**
- If `PASV_MIN_PORT` and `PASV_MAX_PORT` are not set, defaults to 10000-10250
- `PASV_ADDRESS` should be set to your server's external IP or domain for proper passive mode operation
- When `ENABLE_FTPS=YES`, ensure certificates are mounted and paths configured correctly

### SSL/TLS Configuration
The container includes FTPS support (currently disabled by default):
- Set `ssl_enable=YES` in `vsftpd.conf` to enable
- Mount certificates to `/etc/vsftpd/certs/` and update paths in `vsftpd.conf`:
  - `rsa_cert_file=/etc/vsftpd/certs/ftps-cert.pem`
  - `rsa_private_key_file=/etc/vsftpd/certs/ftps-cert.key`
- Supports TLSv1+ with strong cipher suites
- Certificates can be mapped via volume: `./certs:/etc/vsftpd/certs:ro`

---

## 🗂 Roadmap

- [ ] Replace JSON file with secure secret management (Vault/KMS)
- [ ] Enhanced monitoring and metrics export
- [ ] Work out Certificate Auth

---

## 🧾 License

MIT or internal license based on organization requirements.
