# 03 - Deployment Execution Plan

> Step-by-step deployment plan for SEO Panel on aaPanel (Ubuntu 22.04, PHP 8.4, MySQL 8).
> Target: `/www/wwwroot/seo.amarisstock.com`
> The deployment script `deploy.sh` automates steps 3-12 below.

---

## Pre-Requisites (Already Satisfied)

1. aaPanel is installed with PHP 8.4, MySQL 8, and Nginx
2. The site `seo.amarisstock.com` is created in aaPanel with an Nginx vhost
3. SSL certificates are issued via aaPanel's Let's Encrypt
4. Database `sql_seo_amarisstock_com` and user exist (empty, ready for install)
5. SSH key has access to `git@github.com:wagura-maurice/Seo-Panel.git`

---

## Step 1: Set Server Timezone to Africa/Nairobi

The server is currently set to `Europe/Berlin`. Change to `Africa/Nairobi` (UTC+3, EAT):

```bash
sudo timedatectl set-timezone Africa/Nairobi
```

Verify:
```bash
timedatectl | grep "Time zone"
# Expected: Time zone: Africa/Nairobi (EAT, +0300)
```

This ensures cron jobs, logs, and PHP `date()` calls use the correct timezone.

---

## Step 2: Backup Existing Site Files

The target directory currently contains aaPanel default files (`index.html`, `404.html`, `502.html`, `.user.ini`, `.well-known/`). Back them up before deploying:

```bash
cp -a /www/wwwroot/seo.amarisstock.com /www/wwwroot/seo.amarisstock.com.bak.$(date +%Y%m%d%H%M%S)
```

**Preserve these aaPanel-managed files** during deployment:
- `.user.ini` -- open_basedir restriction (aaPanel-managed)
- `.well-known/` -- SSL certificate verification directory
- `404.html`, `502.html` -- aaPanel error pages (optional, can be replaced by app)

---

## Step 3: Clone the Repository (No Nested Sub-Directory)

Clone the repository so that files land **directly in the site root** without creating a `Seo-Panel/` sub-directory:

```bash
# Clone to a temporary location
git clone git@github.com:wagura-maurice/Seo-Panel.git /tmp/seo-panel-deploy

# Move all files (including hidden) into the target, preserving aaPanel files
rsync -a --exclude='.git' \
  --exclude='.user.ini' \
  --exclude='.well-known' \
  /tmp/seo-panel-deploy/ \
  /www/wwwroot/seo.amarisstock.com/

# Clean up
rm -rf /tmp/seo-panel-deploy
```

**Why rsync instead of `git clone .`?**
- The target directory is non-empty (aaPanel files exist)
- `git clone` fails on non-empty directories
- rsync allows us to exclude aaPanel-managed files and merge cleanly

---

## Step 4: Generate `config/sp-config.php`

Create the main configuration file from the sample, populated with the deployment credentials:

```php
<?php
# The web path or url to access seo panel through browser.
define('SP_WEBPATH', 'https://seo.amarisstock.com');

# DB settings
define('DB_NAME', 'sql_seo_amarisstock_com');
define('DB_USER', 'sql_seo_amarisstock_com');
define('DB_PASSWORD', '3c7d9c6bd1633');
define('DB_HOST', 'localhost');
define('DB_ENGINE', 'mysql');

# The version of seo panel installed
define('SP_INSTALLED', '6.0.0');

# The DB debug mode
define('SP_DEBUG', 0);

# The seo panel seconds for session timeout
define('SP_TIMEOUT', 18000);
?>
```

**Note:** `SP_WEBPATH` is set to `https://seo.amarisstock.com` (with HTTPS, no trailing path) since SSL is already configured.

---

## Step 5: Create `.env` and `.env.example` Files

Although SEO Panel's runtime uses `config/sp-config.php` (not `.env`), the `.env` file is created for:
1. Docker compatibility (if ever needed)
2. Installer `getenv()` fallback during web-based installation

### `.env` (from `sample_env`)

```env
MYSQL_DB_HOST=localhost
MYSQL_DATABASE=sql_seo_amarisstock_com
MYSQL_USER=sql_seo_amarisstock_com
MYSQL_PASSWORD=3c7d9c6bd1633
MYSQL_ROOT_PASSWORD=d1632a6a5f803e6a

# SMTP (Mailtrap Sandbox)
MAIL_MAILER=smtp
MAIL_HOST=sandbox.smtp.mailtrap.io
MAIL_PORT=2525
MAIL_USERNAME=be6e87f82be3a7
MAIL_PASSWORD=2b1dadf3db173f
```

### `.env.example` (template, no real secrets)

```env
MYSQL_DB_HOST=localhost
MYSQL_DATABASE=seopanel
MYSQL_USER=seopanel
MYSQL_PASSWORD=seopanelpass
MYSQL_ROOT_PASSWORD=rootpass

# SMTP Configuration
MAIL_MAILER=smtp
MAIL_HOST=your-smtp-host
MAIL_PORT=2525
MAIL_USERNAME=your-username
MAIL_PASSWORD=your-password
```

**Security:** The Nginx vhost already blocks access to `.env` files (`return 404` for `\.env`).

---

## Step 6: Import the Database Schema

Import the SQL data files into the empty database:

```bash
MYSQL_BIN=/www/server/mysql/bin/mysql
DB_USER=sql_seo_amarisstock_com
DB_PASS=3c7d9c6bd1633
DB_NAME=sql_seo_amarisstock_com
SITE_ROOT=/www/wwwroot/seo.amarisstock.com

# Main schema and seed data
$MYSQL_BIN -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" < "$SITE_ROOT/install/data/seopanel.sql"

# Language texts
$MYSQL_BIN -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" < "$SITE_ROOT/install/data/textlang.sql"
```

This creates all tables, seed data (search engines, directories, settings, etc.), and the default admin user (`spadmin`/`spadmin`).

---

## Step 7: Configure SMTP Settings in Database

After importing the schema, update the `settings` table with the Mailtrap SMTP credentials:

```sql
UPDATE settings SET set_val='1'   WHERE set_name='SP_SMTP_MAIL';
UPDATE settings SET set_val='sandbox.smtp.mailtrap.io' WHERE set_name='SP_SMTP_HOST';
UPDATE settings SET set_val='be6e87f82be3a7'  WHERE set_name='SP_SMTP_USERNAME';
UPDATE settings SET set_val='2b1dadf3db173f'  WHERE set_name='SP_SMTP_PASSWORD';
UPDATE settings SET set_val='2525'            WHERE set_name='SP_SMTP_PORT';
UPDATE settings SET set_val=''                WHERE set_name='SP_MAIL_ENCRYPTION';
```

**Note:** Mailtrap sandbox on port 2525 uses plain SMTP (no TLS/SSL encryption), so `SP_MAIL_ENCRYPTION` is left empty.

---

## Step 8: Set Application Timezone in Database

```sql
UPDATE settings SET set_val='Africa/Nairobi' WHERE set_name='SP_TIME_ZONE';
```

SEO Panel reads this setting at runtime and applies it via `date_default_timezone_set()` and MySQL `SET time_zone`.

---

## Step 9: Set File Permissions

```bash
SITE_ROOT=/www/wwwroot/seo.amarisstock.com
WEB_USER=www

# Set ownership
chown -R $WEB_USER:$WEB_USER "$SITE_ROOT"

# Directories: 755, Files: 644
find "$SITE_ROOT" -type d -exec chmod 755 {} \;
find "$SITE_ROOT" -type f -exec chmod 644 {} \;

# tmp directory must be writable by all (777)
chmod 777 "$SITE_ROOT/tmp"

# config/sp-config.php: 644 (read-only after install)
chmod 644 "$SITE_ROOT/config/sp-config.php"
```

---

## Step 10: Apply php.ini Optimizations

Modify `/www/server/php/84/etc/php.ini` (FPM) and `/www/server/php/84/etc/php-cli.ini` (CLI) with targeted settings:

```bash
PHP_INI=/www/server/php/84/etc/php.ini
PHP_CLI_INI=/www/server/php/84/etc/php-cli.ini

# Function to set or append a directive
set_php_ini() {
    local file=$1 key=$2 val=$3
    if grep -q "^${key}" "$file"; then
        sed -i "s|^${key}\s*=.*|${key} = ${val}|" "$file"
    else
        echo "${key} = ${val}" >> "$file"
    fi
}

# Apply to both ini files
for ini in "$PHP_INI" "$PHP_CLI_INI"; do
    set_php_ini "$ini" "memory_limit" "256M"
    set_php_ini "$ini" "max_execution_time" "300"
    set_php_ini "$ini" "max_input_time" "300"
    set_php_ini "$ini" "upload_max_filesize" "64M"
    set_php_ini "$ini" "post_max_size" "64M"
    set_php_ini "$ini" "max_input_vars" "3000"
    set_php_ini "$ini" "date.timezone" "Africa/Nairobi"
    set_php_ini "$ini" "session.gc_maxlifetime" "18000"
    set_php_ini "$ini" "display_errors" "Off"
done

# Reload PHP-FPM
/etc/init.d/php-fpm-84 reload
```

---

## Step 11: Remove the Install Directory

After the database is imported and configuration is complete, remove the `install/` directory for security:

```bash
rm -rf /www/wwwroot/seo.amarisstock.com/install
```

---

## Step 12: Reload Nginx and Verify

```bash
# Test Nginx config
/www/server/nginx/sbin/nginx -t

# Reload Nginx
/www/server/nginx/sbin/nginx -s reload

# Reload PHP-FPM
/etc/init.d/php-fpm-84 reload
```

Verify the site loads at `https://seo.amarisstock.com` -- should redirect to `login.php`.

---

## Step 13: Set Up Cron Jobs

SEO Panel requires cron jobs for automated SEO tasks. Add the following to the system crontab (or via aaPanel's Cron UI):

```bash
# Main SEO cron -- runs every 6 hours (keyword rank checking, reports)
0 */6 * * * /www/server/php/84/bin/php /www/wwwroot/seo.amarisstock.com/cron.php

# Directory submission checker -- daily at 02:00
0 2 * * * /www/server/php/84/bin/php /www/wwwroot/seo.amarisstock.com/directorycheckercron.php

# Site auditor -- daily at 03:00
0 3 * * * /www/server/php/84/bin/php /www/wwwroot/seo.amarisstock.com/siteauditorcron.php

# Proxy checker -- daily at 04:00
0 4 * * * /www/server/php/84/bin/php /www/wwwroot/seo.amarisstock.com/proxycheckercron.php
```

**Important:** Use the full path to PHP 8.4 (`/www/server/php/84/bin/php`) to ensure the correct version and extensions are loaded.

### Via aaPanel UI (Alternative)

1. Go to aaPanel -> Cron
2. Add each job as a "Shell script" task
3. Set the shell command to the full PHP CLI command above
4. Set the schedule as specified

---

## Step 14: SSL Certificate Management

SSL is **already configured** via aaPanel's built-in Let's Encrypt mechanism. The certificates are at:

```
Certificate: /www/server/panel/vhost/cert/seo.amarisstock.com/fullchain.pem
Private Key: /www/server/panel/vhost/cert/seo.amarisstock.com/privkey.pem
```

### Renewal

aaPanel automatically handles Let's Encrypt certificate renewal. To verify or manage:

1. Go to aaPanel -> Website -> seo.amarisstock.com -> SSL
2. Verify the certificate status and expiry date
3. aaPanel sets up a automatic renewal cron job

### Manual Renewal (if needed)

```bash
# aaPanel uses its own Let's Encrypt integration
# Renewal is handled automatically via the panel's cron
# To force renewal, use the aaPanel SSL UI
```

---

## Step 15: Post-Deployment Security Checklist

1. **Change admin password:** Log in with `spadmin`/`spadmin` at `https://seo.amarisstock.com/login.php`, then change the password immediately via Profile.
2. **Verify `.env` is blocked:** Access `https://seo.amarisstock.com/.env` in a browser -- should return 404.
3. **Verify `.git` is blocked:** Access `https://seo.amarisstock.com/.git/` -- should return 404.
4. **Verify `install/` is removed:** Access `https://seo.amarisstock.com/install/` -- should return 404.
5. **Test SMTP:** In admin panel, test email functionality via System Settings.
6. **Set MOZ API key:** Go to Admin Panel -> System Settings -> MOZ Settings and add your API key.
7. **Review user registration:** By default, user registration is disabled (`SP_USER_REGISTRATION=0`). Enable only if needed.

---

## Default Admin Credentials

| Field    | Value      |
|----------|------------|
| URL      | `https://seo.amarisstock.com/login.php` |
| Username | `spadmin`  |
| Password | `spadmin`  |

**Change the password immediately after first login.**
