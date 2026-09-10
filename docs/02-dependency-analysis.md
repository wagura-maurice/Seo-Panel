# 02 - Dependency & Runtime Analysis

> Repository: `git@github.com:wagura-maurice/Seo-Panel.git`
> Analysis performed by cloning the repository to a temporary inspection directory.

---

## 1. Project Type & Architecture

SEO Panel is a **traditional custom PHP application** (version 6.0.0) following an MVC-like pattern. It is **not** a Laravel, Symfony, or Composer-based project.

Key architectural facts:
- **No `composer.json`** -- all third-party libraries are bundled directly in `libs/`
- **No `package.json`** -- no Node.js build step or frontend asset compilation required
- **No Composer or Node.js required** for deployment

### Bundled Libraries (in `libs/`)

| Library                  | Path                              | Purpose                        |
|--------------------------|-----------------------------------|--------------------------------|
| PHPMailer                | `libs/phpmailer.class.php`        | Email sending                  |
| SMTP                     | `libs/smtp.class.php`             | SMTP transport                 |
| SendGrid                 | `libs/sendgrid-php/`              | SendGrid email API             |
| mPDF                     | `libs/mpdf_lib/`                  | PDF report generation          |
| Google API Client        | `libs/google-api-php-client/`     | Analytics & Search Console     |
| DataForSEO               | `libs/dataforseo/`                | SEO data API                   |
| pChart                   | `libs/pchart.class.php`           | Chart generation               |
| Parsedown                | `libs/Parsedown.php`              | Markdown parsing               |
| Custom Database class    | `libs/database.class.php`         | DB abstraction (MySQLi)        |

---

## 2. Required PHP Extensions

SEO Panel requires the following PHP extensions. All are **already loaded** in the aaPanel PHP 8.4 installation:

| Extension    | Required For                  | Status    |
|--------------|-------------------------------|-----------|
| `curl`       | Web crawling, API calls      | Loaded    |
| `mysqli`     | Database connectivity         | Loaded    |
| `mysqlnd`    | MySQL native driver          | Loaded    |
| `pdo_mysql`  | PDO MySQL (if used)          | Loaded    |
| `gd`         | Image/chart processing        | Loaded    |
| `mbstring`   | Multi-byte string handling   | Loaded    |
| `intl`       | Internationalization          | Loaded    |
| `json`       | JSON encoding/decoding        | Loaded    |
| `xml`        | XML parsing (sitemaps, etc.)  | Loaded    |
| `SimpleXML`  | Simple XML parsing            | Loaded    |
| `zip`        | Archive handling              | Loaded    |
| `openssl`    | SSL/TLS, encryption          | Loaded    |
| `soap`       | SOAP API calls                | Loaded    |
| `sockets`    | Network communication         | Loaded    |
| `session`    | Session management            | Loaded    |
| `bcmath`     | Arbitrary precision math      | Loaded    |
| `gettext`    | Translation (if used)         | Loaded    |

**Result: No additional PHP extensions need to be installed.**

---

## 3. php.ini Modifications

The following `php.ini` modifications optimize the environment for SEO Panel while preserving aaPanel's operational logic. These are applied to `/www/server/php/84/etc/php.ini` (the FPM ini) and `/www/server/php/84/etc/php-cli.ini` (the CLI ini, used by cron jobs).

### Recommended Settings

| Directive                | Recommended Value | Default    | Reason                                        |
|--------------------------|-------------------|------------|-----------------------------------------------|
| `memory_limit`           | `256M`            | 128M       | mPDF PDF generation and crawling need memory  |
| `max_execution_time`     | `300`             | 30         | Cron jobs (rank checking, crawling) run long  |
| `max_input_time`         | `300`             | 60         | Long-running form submissions                 |
| `upload_max_filesize`    | `64M`             | 2M         | Allow larger file uploads (imports, etc.)     |
| `post_max_size`          | `64M`             | 8M         | Match upload_max_filesize                     |
| `max_input_vars`         | `3000`            | 1000       | Large forms (settings pages)                  |
| `date.timezone`          | `Africa/Nairobi`  | UTC        | Server timezone alignment                     |
| `curl.cainfo`            | (auto)            | —          | Let system CA bundle handle TLS                |
| `openssl.cafile`         | (auto)            | —          | Let system CA bundle handle TLS                |
| `session.gc_maxlifetime` | `18000`           | 1440       | Match SP_TIMEOUT (5 hours)                    |
| `display_errors`         | `Off`             | On         | Security: hide errors in production           |
| `error_reporting`        | `E_ALL & ~E_DEPRECATED & ~E_STRICT` | E_ALL | Production-appropriate error level  |

### How to Apply (preserving aaPanel logic)

aaPanel manages PHP settings through its own UI, but direct `php.ini` edits are preserved as long as you don't overwrite the entire file. The deployment script uses **targeted `sed` replacements** to modify only the specific directives, leaving all other aaPanel-managed settings intact.

After modifying `php.ini`, PHP-FPM must be reloaded:
```bash
/etc/init.d/php-fpm-84 reload
```

---

## 4. Composer & Node.js

### Composer

- **Installed version:** 2.0.14 (at `/usr/bin/composer`)
- **Status:** Produces PHP 8.4 deprecation warnings (outdated)
- **Required by SEO Panel:** **No** -- the project has no `composer.json`
- **Action:** None required. If Composer is needed for other projects on this server, consider upgrading to Composer 2.7+ to fix PHP 8.4 compatibility.

### Node.js

- **Installed:** No
- **Required by SEO Panel:** **No** -- the project has no `package.json` and no build step
- **Action:** None required.

---

## 5. Nginx Server Block Configuration

### Custom Config Required? **No.**

The existing aaPanel Nginx vhost at `/www/server/panel/vhost/nginx/seo.amarisstock.com.conf` is **fully sufficient** for SEO Panel:

1. **Document root** is correctly set to `/www/wwwroot/seo.amarisstock.com`
2. **PHP 8.4 FPM** is already enabled via `include enable-php-84.conf`
3. **`index` directive** already includes `index.php` as the first priority
4. **SSL** is already configured with Let's Encrypt certificates
5. **Sensitive file protection** already blocks `.env`, `.git`, `.htaccess`
6. **URL rewriting** is not needed (SEO Panel uses direct PHP file entry points)
7. **Static asset caching** rules already in place for images, JS, CSS

### Optional Nginx Hardening

The deployment script does **not** modify the aaPanel Nginx config to avoid breaking panel-managed settings. However, the following optional improvements could be applied manually via the aaPanel UI if desired:

- Increase `client_max_body_size` to `64m` (match upload limits) -- add in aaPanel site config
- Add `fastcgi_read_timeout 300;` for long-running PHP requests
- Enable gzip compression (may already be enabled globally)

---

## 6. System-Level Dependencies

| Dependency       | Required          | Status           |
|------------------|-------------------|------------------|
| `git`            | Yes (for clone)   | Installed        |
| `curl`           | Yes (system)      | Installed        |
| `ca-certificates`| Yes (TLS)         | Installed        |
| `unzip`          | No (no zip deps)  | N/A              |
| `sendmail/MTA`   | No (uses SMTP)    | Not needed       |

SEO Panel sends email via SMTP (PHPMailer + SMTP class) directly to the configured SMTP server (Mailtrap). No local MTA (sendmail/postfix) is required.

---

## 7. File Permission Requirements

| Path                  | Required Permissions | Owner   |
|-----------------------|----------------------|---------|
| `config/sp-config.php`| `644` (after install)| `www`   |
| `tmp/`                | `777` (writable)     | `www`   |
| All other files       | `644`                | `www`   |
| All directories       | `755`                | `www`   |

The deployment script sets these permissions using the `www` user (aaPanel's default web user).
