# 06 - Next Steps & Action Items

> Post-deployment action items to fully configure SEO Panel for 100% free and open source SEO task management.
> Complete these steps after the deployment is live and the free configuration (doc 05) has been applied.

---

## Phase 1: Security (Do Immediately)

### 1.1 Change the Default Admin Password

The default credentials are `spadmin` / `spadmin`. Change them before doing anything else.

1. Visit `https://seo.amarisstock.com/login.php`
2. Login with `spadmin` / `spadmin`
3. Click the **Profile** link (top right)
4. Enter a new strong password and save

### 1.2 Verify Sensitive Files Are Blocked

Open these URLs in a browser -- each should return **404 Not Found**:

- `https://seo.amarisstock.com/.env`
- `https://seo.amarisstock.com/.git/`
- `https://seo.amarisstock.com/config/sp-config.php`

If any return content, check the Nginx vhost at `/www/server/panel/vhost/nginx/seo.amarisstock.com.conf`.

### 1.3 Verify Install Directory Is Removed

- `https://seo.amarisstock.com/install/` should return 404
- If it loads, run: `rm -rf /www/wwwroot/seo.amarisstock.com/install`

### 1.4 Restrict aaPanel UI Access (Recommended)

The aaPanel web UI on port 888 is currently open to the public. Restrict it to your IP:

```bash
# Replace 1.2.3.4 with your admin IP
ufw delete allow 888/tcp
ufw allow from 1.2.3.4 to any port 888
ufw reload
```

---

## Phase 2: Obtain Free API Keys

These are required to activate the Google-integrated tools. All are 100% free.

### 2.1 Google API Key (PageSpeed Insights)

**Purpose:** Powers the PageSpeed Insights tool (desktop + mobile speed scores).

**Cost:** Free -- 25,000 queries/day, 240 queries/minute.

**Steps:**
1. Go to https://console.cloud.google.com/
2. Sign in with a Google account
3. Click **Select a project** -> **New Project**
4. Name it (e.g., "SEO Panel") and click **Create**
5. In the left sidebar, go to **APIs & Services** -> **Library**
6. Search for **PageSpeed Insights API**
7. Click it and press **Enable**
8. Go to **APIs & Services** -> **Credentials**
9. Click **Create Credentials** -> **API Key**
10. Copy the generated API key
11. (Recommended) Restrict the key to the PageSpeed Insights API only

**Where to enter it in SEO Panel:**
- Admin Panel -> System Settings -> Google Settings -> **Google API Key**
- Or via SQL:
  ```sql
  UPDATE settings SET set_val='YOUR_API_KEY_HERE' WHERE set_name='SP_GOOGLE_API_KEY';
  ```

### 2.2 Google OAuth Credentials (Webmaster Tools + Analytics)

**Purpose:** Powers Webmaster Tools (Google Search Console data) and Website Analytics (GA4 data). Both use the same OAuth credentials.

**Cost:** Free -- Google Search Console API and Google Analytics Data API are free.

**Steps:**
1. In the same Google Cloud Console project as above:
2. Go to **APIs & Services** -> **Library**
3. Search for and **Enable** each of these:
   - **Google Search Console API**
   - **Google Analytics Data API**
4. Go to **APIs & Services** -> **OAuth consent screen**
5. Choose **External** user type and click **Create**
6. Fill in the app name (e.g., "SEO Panel"), support email, and developer email
7. Add scopes: `../auth/webmasters.readonly`, `../auth/analytics.readonly`
8. Add yourself as a test user (if in testing mode)
9. Go to **APIs & Services** -> **Credentials**
10. Click **Create Credentials** -> **OAuth client ID**
11. Application type: **Web application**
12. Name: "SEO Panel OAuth"
13. Under **Authorized redirect URIs**, add:
    ```
    https://seo.amarisstock.com/admin-panel.php?sec=connections&action=connect_return&category=google
    ```
14. Click **Create**
15. Copy the **Client ID** and **Client Secret**

**Where to enter it in SEO Panel:**
- Admin Panel -> System Settings -> Google Settings -> **Google API Client ID** and **Google API Client Secret**
- Or via SQL:
  ```sql
  UPDATE settings SET set_val='YOUR_CLIENT_ID' WHERE set_name='SP_GOOGLE_API_CLIENT_ID';
  UPDATE settings SET set_val='YOUR_CLIENT_SECRET' WHERE set_name='SP_GOOGLE_API_CLIENT_SECRET';
  ```

**After entering credentials:**
- Go to Admin Panel -> Connections
- Click **Connect** next to Google
- Authorize access in the Google popup
- This connects your Google Search Console and Analytics accounts

### 2.3 MOZ API Token (Optional -- Free Tier)

**Purpose:** Powers Rank Checker (MOZ metrics) and Backlinks Checker. Without this, both tools return 0 results for MOZ-specific metrics.

**Cost:** Free tier -- 50 rows/month, 1 request per 10 seconds. Requires a credit card on file but is not charged.

**Steps:**
1. Go to https://moz.com/checkout/moz-api/plan/api_free
2. Create a MOZ account
3. Enter credit card details (required by MOZ, not charged on free tier)
4. Navigate to the API dashboard
5. Generate an API token

**Where to enter it in SEO Panel:**
- Admin Panel -> System Settings -> MOZ Settings -> **Moz API Access ID**
- Or via SQL:
  ```sql
  UPDATE settings SET set_val='YOUR_MOZ_TOKEN' WHERE set_name='SP_MOZ_API_ACCESS_ID';
  ```

**Limitation:** 50 rows/month is enough for ~1-2 websites checked once per month. For more frequent checks, you would need a paid MOZ plan. If you skip this, the Keyword Position Checker, Site Auditor, Saturation Checker, and Social Media Checker all still work fully free without MOZ.

---

## Phase 3: Add Websites and Keywords

### 3.1 Add Your First Website

1. Login to SEO Panel at `https://seo.amarisstock.com/login.php`
2. Go to **Websites** -> **Add Website**
3. Enter:
   - **Name:** Your website name
   - **URL:** `https://yourdomain.com`
   - **Status:** Active
4. Click **Save**

### 3.2 Add Keywords to Track

1. Go to **Keywords** -> **Add Keyword**
2. Select the website
3. Enter keywords you want to track (e.g., "seo panel", "free seo tools")
4. Click **Save**
5. Repeat for each keyword

### 3.3 Run a Manual Keyword Position Check

1. Go to **SEO Tools** -> **Keyword Position Checker**
2. Select your website
3. Click **Check Position**
4. Verify results appear for Google, Bing, and Yahoo

If results don't appear, check:
- **Admin Panel -> Crawl Log** for error messages
- The crawl delay setting (`SP_CRAWL_DELAY = 5` seconds) may need increasing if Google blocks requests
- The user agent string (`SP_USER_AGENT`) should be a modern browser string

### 3.4 Run a Site Auditor Crawl

1. Go to **SEO Tools** -> **Site Auditor**
2. Create an auditor project for your website
3. Start the crawl
4. Review the report for SEO issues (title length, meta tags, broken links, etc.)

### 3.5 Run a Saturation Check

1. Go to **SEO Tools** -> **Search Engine Saturation**
2. Select your website
3. Click **Check Saturation**
4. Verify indexed page counts appear for Google and Bing

---

## Phase 4: Configure Cron Job Monitoring

### 4.1 Verify Cron Jobs Are Running

```bash
crontab -l | grep seopanel
```

Expected output:
```
# SEO Panel cron jobs - managed by deploy.sh
0 */6 * * * /www/server/php/84/bin/php /www/wwwroot/seo.amarisstock.com/cron.php
0 2 * * * /www/server/php/84/bin/php /www/wwwroot/seo.amarisstock.com/directorycheckercron.php
0 3 * * * /www/server/php/84/bin/php /www/wwwroot/seo.amarisstock.com/siteauditorcron.php
0 4 * * * /www/server/php/84/bin/php /www/wwwroot/seo.amarisstock.com/proxycheckercron.php
# End SEO Panel cron jobs
```

### 4.2 Test Cron Jobs Manually

```bash
# Test main cron (keyword position checking)
/www/server/php/84/bin/php /www/wwwroot/seo.amarisstock.com/cron.php

# Test site auditor cron
/www/server/php/84/bin/php /www/wwwroot/seo.amarisstock.com/siteauditorcron.php

# Test proxy checker cron
/www/server/php/84/bin/php /www/wwwroot/seo.amarisstock.com/proxycheckercron.php

# Test directory checker cron
/www/server/php/84/bin/php /www/wwwroot/seo.amarisstock.com/directorycheckercron.php
```

Check the output for errors. If successful, results will appear in the respective tool dashboards.

### 4.3 Monitor Crawl Logs

1. Go to Admin Panel -> **Crawl Log**
2. Review entries for any errors (crawl_status = 0 means failure)
3. Common issues:
   - Google blocking requests (increase `SP_CRAWL_DELAY`)
   - CURL not working (check PHP curl extension)
   - Memory limits (increase `memory_limit` in php.ini)

---

## Phase 5: Configure Email Notifications

### 5.1 Verify SMTP Settings

SMTP is already configured with Mailtrap Sandbox. To verify:

1. Go to Admin Panel -> System Settings -> **Mail Settings**
2. Verify:
   - SMTP Enabled: Yes
   - SMTP Host: `sandbox.smtp.mailtrap.io`
   - SMTP Port: `2525`
   - SMTP Username: `be6e87f82be3a7`
   - SMTP Password: `2b1dadf3db173f`
   - Mail Encryption: (empty)

### 5.2 Test Email Delivery

**Note:** Mailtrap Sandbox is a testing service -- emails are captured but not actually delivered. For production email delivery, replace with a real SMTP provider:

- **Free option:** Gmail SMTP (limit 500 emails/day)
- **Free option:** Brevo/Sendinblue (free tier: 300 emails/day)
- **Paid option:** SendGrid, Amazon SES, Postmark

To switch to a production SMTP provider, update the settings:

```sql
UPDATE settings SET set_val='smtp.gmail.com' WHERE set_name='SP_SMTP_HOST';
UPDATE settings SET set_val='587' WHERE set_name='SP_SMTP_PORT';
UPDATE settings SET set_val='your@gmail.com' WHERE set_name='SP_SMTP_USERNAME';
UPDATE settings SET set_val='your_app_password' WHERE set_name='SP_SMTP_PASSWORD';
UPDATE settings SET set_val='tls' WHERE set_name='SP_MAIL_ENCRYPTION';
```

### 5.3 Enable Report Email Notifications

1. Go to Admin Panel -> System Settings -> **Report Settings**
2. Verify **Enable report email notification** is set to Yes (`SP_REPORT_EMAIL_NOTIFICATION = 1`)
3. This sends email notifications when cron-generated reports are ready

---

## Phase 6: Install Free Plugins (Optional)

### 6.1 Seo Diary (Free)

**Purpose:** Store SEO tasks, TODOs, and website information. Track SEO work done for each website.

**Installation:**
1. Download from https://www.seopanel.org/plugins/ (free download)
2. Admin Panel -> **SEO Plugins Manager** -> **Install Plugin**
3. Upload the plugin zip file
4. Activate the plugin

### 6.2 Quick Web Proxy (Free)

**Purpose:** Create a web proxy server to solve CAPTCHA issues when Google blocks crawl requests. Allows manual CAPTCHA solving through a proxy interface.

**Note:** This plugin is registered in the database (status=1) but the plugin files are not present in this deployment. Download and install it if you encounter CAPTCHA blocking issues.

**Installation:**
1. Download from https://www.seopanel.org/plugins/ (free download)
2. Admin Panel -> **SEO Plugins Manager** -> **Install Plugin**
3. Upload the plugin zip file

---

## Phase 7: Set Up Backups

### 7.1 Database Backups via aaPanel

1. Go to aaPanel -> **Cron**
2. Add a new cron job:
   - **Type:** Shell script
   - **Name:** SEO Panel DB Backup
   - **Execution cycle:** Every day at 01:00
   - **Script content:**
     ```bash
     /www/server/mysql/bin/mysqldump -usql_seo_amarisstock_com -p3c7d9c6bd1633 sql_seo_amarisstock_com | gzip > /www/backup/sql_seo_amarisstock_com_$(date +\%Y\%m\%d).sql.gz
     find /www/backup/ -name "sql_seo_amarisstock_com_*.sql.gz" -mtime +30 -delete
     ```
3. This creates daily compressed backups and deletes backups older than 30 days

### 7.2 Site File Backups

1. Go to aaPanel -> **Website** -> seo.amarisstock.com -> **Backup**
2. Set up a scheduled backup of the site files
3. Or add a cron job:
   ```bash
   tar -czf /www/backup/seo_site_$(date +\%Y\%m\%d).tar.gz -C /www/wwwroot seo.amarisstock.com
   find /www/backup/ -name "seo_site_*.tar.gz" -mtime +30 -delete
   ```

---

## Phase 8: Ongoing Maintenance

### 8.1 Update SEO Panel

When a new version is released:

1. Backup the database and site files (see Phase 7)
2. Go to Admin Panel -> **System Settings** -> check for version updates
3. Or manually: clone the new version, copy files, run `install/upgrade.php`
4. Remove the `install/` directory after upgrading

### 8.2 Monitor Disk Space

```bash
df -h /www
```

The `tmp/` directory and crawl logs can grow over time. Clean periodically:

```bash
# Clean old crawl logs (older than 90 days, per SP_CRAWL_LOG_CLEAR_TIME)
# This is handled automatically by the cron, but verify:
ls -la /www/wwwroot/seo.amarisstock.com/tmp/
```

### 8.3 Monitor MySQL Performance

```bash
/www/server/mysql/bin/mysql -uroot -p"$(sqlite3 /www/server/panel/data/default.db 'SELECT mysql_root FROM config LIMIT 1;')" -e "SHOW PROCESSLIST; SHOW STATUS LIKE 'Threads_connected';"
```

### 8.4 Review SSL Certificate

1. Go to aaPanel -> **Website** -> seo.amarisstock.com -> **SSL**
2. Verify the certificate is valid and not expiring soon
3. aaPanel auto-renews Let's Encrypt certificates, but verify periodically

### 8.5 Review Crawl Logs Weekly

1. Login to SEO Panel admin
2. Go to **Crawl Log**
3. Look for repeated failures (crawl_status = 0)
4. If Google is blocking, increase `SP_CRAWL_DELAY` or consider using a proxy

---

## Quick Reference: All Settings to Configure

| Setting | Where | Value | Priority |
|---------|-------|-------|----------|
| Admin password | Profile page | Strong password | Immediate |
| Google API Key | System Settings -> Google | Your free key | Phase 2 |
| Google OAuth Client ID | System Settings -> Google | Your free client ID | Phase 2 |
| Google OAuth Client Secret | System Settings -> Google | Your free secret | Phase 2 |
| MOZ API Token | System Settings -> MOZ | Your free token (optional) | Phase 2 |
| SMTP (production) | System Settings -> Mail | Real SMTP provider | Phase 5 |
| Report email notification | System Settings -> Report | Enabled (already set) | Already done |
| Timezone | System Settings | Africa/Nairobi (already set) | Already done |
| Crawl delay | System Settings -> Report | 5 seconds (already set) | Already done |
| User agent | System Settings -> Report | Modern Chrome UA (already set) | Already done |

---

## Quick Reference: All URLs

| Resource | URL |
|----------|-----|
| SEO Panel Login | `https://seo.amarisstock.com/login.php` |
| SEO Panel Admin | `https://seo.amarisstock.com/admin-panel.php` |
| SEO Tools | `https://seo.amarisstock.com/seo-tools.php` |
| Websites Manager | `https://seo.amarisstock.com/websites.php` |
| Keywords Manager | `https://seo.amarisstock.com/keywords.php` |
| Site Auditor | `https://seo.amarisstock.com/siteauditor.php` |
| Reports | `https://seo.amarisstock.com/reports.php` |
| Settings | `https://seo.amarisstock.com/settings.php` |
| Connections (Google OAuth) | `https://seo.amarisstock.com/connections.php` |
| SEO Plugins Manager | `https://seo.amarisstock.com/seo-plugins-manager.php` |
| aaPanel UI | `http://YOUR_SERVER_IP:888` |
| Google Cloud Console | `https://console.cloud.google.com/` |
| MOZ API Signup | `https://moz.com/checkout/moz-api/plan/api_free` |
| SEO Panel Plugins | `https://www.seopanel.org/plugins/` |
