# 04 - Security & Networking

> TCP/UDP port requirements and firewall configuration for SEO Panel on aaPanel.

---

## 1. Required TCP/UDP Ports

### Inbound Ports (must be open to the public)

| Port(s)      | Protocol | Service              | Required | Reason                                    |
|--------------|----------|----------------------|----------|-------------------------------------------|
| 22           | TCP      | SSH                  | Yes      | Server administration, deployment         |
| 80           | TCP      | HTTP (Nginx)         | Yes      | Web traffic, Let's Encrypt HTTP-01 challenge |
| 443          | TCP      | HTTPS (Nginx)       | Yes      | Encrypted web traffic (primary access)    |
| 443          | UDP      | HTTP/3 QUIC (Nginx)  | Optional | HTTP/3 support (already configured in vhost) |
| 888          | TCP      | aaPanel Web UI       | Yes      | Panel management (restrict if possible)   |
| 21           | TCP      | FTP Control          | Optional | FTP access (if needed)                    |
| 20           | TCP      | FTP Data             | Optional | FTP active mode data                      |
| 39000-40000  | TCP      | FTP Passive          | Optional | FTP passive mode data range (aaPanel default) |

### Inbound Ports (should NOT be open to the public)

| Port(s)      | Protocol | Service              | Reason                                          |
|--------------|----------|----------------------|-------------------------------------------------|
| 3306         | TCP      | MySQL                | Database should be localhost-only (security)    |
| 9000         | TCP      | PHP-FPM              | FastCGI -- bound to Unix socket, not TCP        |

### Outbound Ports (no inbound rule needed, outbound is allowed by default)

| Port(s)      | Protocol | Service              | Reason                                          |
|--------------|----------|----------------------|-------------------------------------------------|
| 2525         | TCP      | SMTP (Mailtrap)      | Outbound email to `sandbox.smtp.mailtrap.io`    |
| 443          | TCP      | HTTPS (outbound)     | API calls (Google, DataForSEO, MOZ, etc.)       |
| 80           | TCP      | HTTP (outbound)      | Web crawling (SEO spider)                       |
| 53           | TCP/UDP  | DNS                  | Domain name resolution                          |

---

## 2. Current UFW Status

The firewall (ufw) is **active** with the following rules already in place:

```
Status: active

To                         Action      From
--                         ------      ----
20/tcp                     ALLOW       Anywhere
21/tcp                     ALLOW       Anywhere
22/tcp                     ALLOW       Anywhere
80/tcp                     ALLOW       Anywhere
443/tcp                    ALLOW       Anywhere
888/tcp                    ALLOW       Anywhere
39000:40000/tcp            ALLOW       Anywhere
30096/tcp                  ALLOW       Anywhere
```

**All required ports are already open.** No additional firewall rules are needed for SEO Panel to function.

---

## 3. UFW Commands

### Verify Current Rules

```bash
sudo ufw status verbose
```

### Open Required Ports (if not already open)

```bash
# Web traffic (HTTP/HTTPS)
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 443/udp     # HTTP/3 QUIC (optional but recommended)

# SSH
sudo ufw allow 22/tcp

# aaPanel Web UI
sudo ufw allow 888/tcp

# FTP (only if needed)
sudo ufw allow 20/tcp
sudo ufw allow 21/tcp
sudo ufw allow 39000:40000/tcp
```

### Explicitly Deny MySQL from Public (Defense in Depth)

```bash
# Ensure MySQL is NOT accessible from the public internet
sudo ufw deny 3306/tcp
```

**Note:** MySQL is already bound to `localhost` in `/etc/my.cnf` (no `bind-address` = localhost only), so this ufw rule is defense-in-depth.

### Restrict aaPanel UI (Recommended Hardening)

For production, restrict the aaPanel UI (port 888) to specific IPs:

```bash
# Replace 1.2.3.4 with your admin IP
sudo ufw delete allow 888/tcp
sudo ufw allow from 1.2.3.4 to any port 888
```

### Reload Firewall After Changes

```bash
sudo ufw reload
```

---

## 4. Application-Level Security

### Nginx Vhost Protections (Already in Place)

The aaPanel-generated Nginx vhost already blocks access to sensitive files:

```nginx
# Blocked files/directories (return 404)
location ~ ^/(\.user.ini|\.htaccess|\.git|\.env|\.svn|\.project|LICENSE|README.md)
{
    return 404;
}
```

This protects:
- `.env` -- environment configuration
- `.git` -- repository metadata
- `.htaccess` -- Apache config
- `.user.ini` -- PHP config
- `LICENSE`, `README.md` -- informational files

### open_basedir Restriction

PHP is restricted to the site directory and `/tmp/`:

```
open_basedir=/www/wwwroot/seo.amarisstock.com/:/tmp/
```

This prevents PHP from accessing files outside the site root.

### SEO Panel Security Features

- SQL injection prevention (`SP_PREVENT_SQL_INJECTION = true`)
- Session-based authentication with timeout (`SP_TIMEOUT = 18000` = 5 hours)
- Admin role checking via `isAdmin()` and `checkAdminLoggedIn()`
- API authentication via user tokens

---

## 5. FTP Credentials (Reference Only)

| Property   | Value                          |
|------------|--------------------------------|
| FTP User   | `ftp_seo_amarisstock_com`      |
| FTP Pass   | `9b4392797c9c68`               |
| FTP Type   | Pure-FTPd (aaPanel managed)    |
| Passive    | 39000-40000 (already open)     |

FTP is **not required** for this deployment. The application is deployed via SSH and git. These credentials are provided for reference only -- use them if manual file upload via FTP is needed (e.g., for debugging or emergency patches).

---

## 6. SSL/TLS Configuration

SSL is already configured via aaPanel's Let's Encrypt integration:

- **Protocol:** TLS 1.1, 1.2, 1.3
- **Ciphers:** EECDH+CHACHA20, EECDH+AES128/256, with forward secrecy
- **HSTS:** `Strict-Transport-Security: max-age=31536000` (1 year)
- **HTTP/3:** QUIC enabled on port 443/UDP
- **Session caching:** Shared SSL session cache (10m)
- **Early data:** Enabled (0-RTT)

### Certificate Files

```
Certificate:  /www/server/panel/vhost/cert/seo.amarisstock.com/fullchain.pem
Private Key:  /www/server/panel/vhost/cert/seo.amarisstock.com/privkey.pem
```

### Renewal

aaPanel automatically renews Let's Encrypt certificates before expiry via its built-in cron job. No manual intervention needed.

---

## 7. Post-Deployment Security Hardening Checklist

- [ ] Change the default admin password (`spadmin` -> strong password)
- [ ] Verify `.env` returns 404 when accessed via browser
- [ ] Verify `.git/` returns 404 when accessed via browser
- [ ] Verify `install/` directory is removed
- [ ] Confirm MySQL port 3306 is NOT accessible from the public internet
- [ ] Consider restricting aaPanel UI (port 888) to admin IPs only
- [ ] Set up regular database backups via aaPanel's Cron + Backup feature
- [ ] Review and disable user registration if not needed (`SP_USER_REGISTRATION`)
- [ ] Configure MOZ API key (Admin -> System Settings -> MOZ Settings)
- [ ] Test SMTP email delivery (Admin -> System Settings -> Mail Settings)
