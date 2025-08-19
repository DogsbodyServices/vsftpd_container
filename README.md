# VSFTPD + SFTP Container

This project provides a secure, containerized FTP/SFTP server based on `vsftpd` and OpenSSH. It supports user-based access with chrooted home directories, dynamic user provisioning via a JSON file.

---

## 🔧 Features

- **FTP over `vsftpd`**
- **SFTP over OpenSSH**
- **Dynamic user creation from JSON**
- **Chrooted upload directories**
- **Customizable via environment variables**
- **Healthchecks for container orchestration**
- **Passive address resolution from provided domain name**

---

## 🚀 Quick Start

### Build the image

```bash
docker build -t vsftpd_container .
```

### Run with Docker Compose

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
```

---

## 📁 Directory Structure

```
├── config/
│   ├── vsftpd.conf                # FTP server config
│   ├── 10-sftp_config.conf        # SSHD/SFTP match rules
│   ├── vsftpd.banner              # FTP login banner
│   ├── user_list                  # Allowed FTP users
│   ├── ftpusers                   # Deprecated; may be removed
│   └── machine_keys/              # Static SSH host keys
├── scripts/
│   ├── entrypoint.sh              # Entrypoint script
│   └── update_users.sh            # JSON -> user sync script
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

To retrieve a list of user and their crypted passwords from an existing server run ./scripts/user_export.sh.  
The generated file is your users.json

### Sync behavior

- At container **startup**, `entrypoint.sh` reads the JSON and creates users.
- Periodic updates can be enabled by running `update_users.sh` on a schedule (e.g., with `cron` or an external orchestrator).
- Users are assigned to group `simpleftp` and chrooted to `/data/<username>/`.

---

## 🔐 Security Notes

- SSH host keys are **static** for container identity consistency.
- Passwords are stored **hashed**; no plaintext is handled.
- `users.json` should be managed securely — **do not commit to version control** unless encrypted.
- Future enhancements may include:
  - PAM-based login with Keycloak
  - GCS bucket sync via `gcsfuse`

---

## 🔍 Healthchecks

The container reports readiness if both vsftpd and SSHD are listening:

```dockerfile
HEALTHCHECK CMD ss -tln | grep -qE ':21|:22' || exit 1
```

---

## 📦 Image Size

- Optimized UBI 9 Minimal base
- Multi-stage build keeps only runtime dependencies
- Current size ~**230MB**

---

## 🔄 CI/CD Integration

### Azure Pipelines

The file `azure-pipelines.yml` is provided to automate builds and optionally push to Azure Container Registry.

Ensure secrets for registry login are securely managed in Azure DevOps.

---

## 🗂 Roadmap

- [ ] Replace JSON file with secure secret management (Vault/KMS)

---

## 🧾 License

MIT or internal license based on organization requirements.
