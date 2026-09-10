# 01 - Environment Discovery & Mapping

> Deployment target: **SEO-PANEL** on Ubuntu 22.04 VPS running aaPanel with PHP 8.4 and MySQL 8.
> Target directory: `/www/wwwroot/seo.amarisstock.com`
> Date: 2026-09-10

---

## 1. aaPanel Installation Paths

aaPanel installs all services under `/www/server/`. The following were discovered on this VPS:

| Component   | Binary / Path                              | Version       | Notes                                   |
|-------------|--------------------------------------------|---------------|------------------------------------------|
| aaPanel     | `/www/server/panel/`                       | —             | Web UI on port 888                       |
| PHP 8.4     | `/www/server/php/84/bin/php`               | 8.4.24 (NTS)  | Only PHP version installed               |
| MySQL 8     | `/www/server/mysql/bin/mysql`              | 8.0.45        | Community Server (GPL)                   |
| Nginx       | `/www/server/nginx/sbin/nginx`             | —             | With HTTP/2, HTTP/3 (QUIC), SSL support  |
| Pure-FTPd   | `/www/server/pure-ftpd/`                   | —             | FTP service                              |
| phpMyAdmin  | `/www/server/phpmyadmin/`                  | —             | DB management UI                         |
| Node.js     | `/www/server/nodejs/`                      | Not installed | Not required by SEO Panel                |

### PHP 8.4 Details

```
Binary:       /www/server/php/84/bin/php
php.ini:      /www/server/php/84/etc/php.ini
php-cli.ini:  /www/server/php/84/etc/php-cli.ini
FPM config:   /www/server/php/84/etc/php-fpm.conf
FPM socket:   /tmp/php-cgi-84.sock
```

### MySQL 8 Details

```
Binary:   /www/server/mysql/bin/mysql
Config:   /etc/my.cnf
Socket:   /tmp/mysql.sock
Datadir:  /www/server/data
Port:     3306 (localhost only)
```

---

## 2. Existing Site Configuration

The site `seo.amarisstock.com` is **already created** in aaPanel with:

### Nginx Vhost

**File:** `/www/server/panel/vhost/nginx/seo.amarisstock.com.conf`

Key settings already in place:
- `root /www/wwwroot/seo.amarisstock.com;`
- `server_name seo.amarisstock.com;`
- Listens on ports 80 (HTTP) and 443 (SSL + QUIC/HTTP3)
- PHP handled via `include enable-php-84.conf;` -> FastCGI to `/tmp/php-cgi-84.sock`
- SSL certificate already configured at `/www/server/panel/vhost/cert/seo.amarisstock.com/`
- Sensitive files (`.env`, `.git`, `.htaccess`) already blocked with `return 404`
- `.well-known` directory allowed for SSL certificate verification
- Access/error logs at `/www/wwwlogs/seo.amarisstock.com.log`

### Nginx PHP FastCGI Config

**File:** `/www/server/nginx/conf/enable-php-84.conf`

```nginx
location ~ [^/]\.php(/|$) {
    try_files $uri =404;
    fastcgi_pass  unix:/tmp/php-cgi-84.sock;
    fastcgi_index index.php;
    include fastcgi.conf;
    include pathinfo.conf;
}
```

### URL Rewrite Config

**File:** `/www/server/panel/vhost/rewrite/seo.amarisstock.com.conf`

Currently **empty**. SEO Panel does **not** require URL rewriting -- it uses direct PHP entry points (e.g., `login.php`, `websites.php`, `rank.php`). No custom rewrite rules are needed.

### open_basedir Restriction

**File:** `/www/wwwroot/seo.amarisstock.com/.user.ini`

```
open_basedir=/www/wwwroot/seo.amarisstock.com/:/tmp/
```

This restricts PHP file access to the site directory and `/tmp/`. This is compatible with SEO Panel since all application files reside within the site root. The `tmp/` directory used by the app is at `/www/wwwroot/seo.amarisstock.com/tmp/` (inside the open_basedir).

---

## 3. Database Discovery

### MySQL Root Access

The MySQL root password is stored in aaPanel's internal SQLite database:

```
File: /www/server/panel/data/default.db
Table: config
Column: mysql_root
```

### Pre-existing Database & User

The database and user were **already created** via aaPanel:

| Property     | Value                        |
|--------------|------------------------------|
| Database     | `sql_seo_amarisstock_com`    |
| Username     | `sql_seo_amarisstock_com`    |
| Password     | `3c7d9c6bd1633`              |
| Host         | `localhost` (127.0.0.1)      |
| Privileges   | Full privileges on the DB    |
| Tables       | **None** (empty, ready for install) |

The user exists for both `localhost` and `127.0.0.1` hosts.

---

## 4. Configuration Files Required by SEO Panel

SEO Panel is a **traditional PHP application** (not Laravel/Symfony). It does **not** use a `.env` file at runtime. The configuration files are:

### Primary Config: `config/sp-config.php`

This is the main configuration file holding database credentials and core settings. Generated from `config/sp-config-sample.php` during installation. Defines:

| Constant        | Description                          | Value for this deployment              |
|-----------------|--------------------------------------|----------------------------------------|
| `SP_WEBPATH`    | Web URL to access SEO Panel          | `https://seo.amarisstock.com`          |
| `DB_NAME`       | Database name                        | `sql_seo_amarisstock_com`              |
| `DB_USER`       | Database username                    | `sql_seo_amarisstock_com`              |
| `DB_PASSWORD`   | Database password                    | `3c7d9c6bd1633`                        |
| `DB_HOST`       | Database host                        | `localhost`                            |
| `DB_ENGINE`     | Database engine                      | `mysql`                                |
| `SP_INSTALLED`  | Installed version                    | `6.0.0`                                |
| `SP_DEBUG`      | Debug mode (0 = off)                 | `0`                                    |
| `SP_TIMEOUT`    | Session timeout in seconds           | `18000`                                |

### Extra Config: `config/sp-config-extra.php`

Pre-populated in the repository. Defines plugin paths, API settings, pagination defaults, security flags, etc. **No changes needed.**

### SMTP / Mail Settings: stored in MySQL `settings` table

SMTP configuration is **not** in a file -- it is stored in the database `settings` table and managed via the admin panel (Admin -> System Settings). The relevant rows:

| Setting Name          | Description          | Value for this deployment             |
|-----------------------|----------------------|---------------------------------------|
| `SP_SMTP_MAIL`        | Enable SMTP          | `1`                                   |
| `SP_SMTP_HOST`        | SMTP host            | `sandbox.smtp.mailtrap.io`            |
| `SP_SMTP_USERNAME`    | SMTP username        | `be6e87f82be3a7`                       |
| `SP_SMTP_PASSWORD`    | SMTP password        | `2b1dadf3db173f`                       |
| `SP_SMTP_PORT`        | SMTP port            | `2525`                                 |
| `SP_MAIL_ENCRYPTION`  | Mail encryption      | (none -- Mailtrap sandbox uses plain) |

### Timezone: stored in MySQL `settings` table

| Setting Name    | Description    | Value for this deployment |
|-----------------|----------------|---------------------------|
| `SP_TIME_ZONE`  | Application TZ | `Africa/Nairobi`          |

### `.env` File (Docker-only, created for reference)

The repository includes a `sample_env` file used **only** by the Docker deployment (`docker-compose.yml` with `env_file: .env`). The web installer also reads these as `getenv()` fallbacks. For the native aaPanel deployment, the `.env` file is created for reference and potential installer fallback, but the **authoritative configuration is `config/sp-config.php`** and the database `settings` table.

---

## 5. FTP Credentials (Reference Only)

| Property   | Value                          |
|------------|--------------------------------|
| FTP User   | `ftp_seo_amarisstock_com`      |
| FTP Pass   | `9b4392797c9c68`               |

These credentials are managed by aaPanel's Pure-FTPd service. FTP is **not required** for this deployment (we deploy via SSH/git). Provided for reference only.
