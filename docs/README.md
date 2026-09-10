# SEO Panel - Deployment Documentation

> Deployment of **SEO Panel** (v6.0.0) on Ubuntu 22.04 VPS with aaPanel, PHP 8.4, and MySQL 8.
> Target domain: `seo.amarisstock.com`
> Target path: `/www/wwwroot/seo.amarisstock.com`

---

## Documentation Index

| Document                          | Description                                              |
|-----------------------------------|----------------------------------------------------------|
| [01-environment-discovery.md](01-environment-discovery.md) | aaPanel paths, PHP/MySQL locations, existing site config, DB discovery, config file mapping |
| [02-dependency-analysis.md](02-dependency-analysis.md)     | Project type, PHP extensions, php.ini mods, Composer/Node analysis, Nginx requirements |
| [03-deployment-plan.md](03-deployment-plan.md)             | Step-by-step deployment execution plan (15 steps)         |
| [04-security-networking.md](04-security-networking.md)     | TCP/UDP ports, UFW commands, SSL, application security, FTP credentials |
| [deploy.sh](deploy.sh)                                     | Automated bash deployment script                          |

---

## Quick Start

```bash
# Review the plan first (dry run)
sudo bash /www/wwwroot/seo.amarisstock.com/docs/deploy.sh --dry-run

# Execute the full deployment
sudo bash /www/wwwroot/seo.amarisstock.com/docs/deploy.sh
```

After deployment, visit `https://seo.amarisstock.com/login.php` and login with:
- Username: `spadmin`
- Password: `spadmin`

**Change the admin password immediately after first login.**

---

## Key Findings Summary

1. **No Composer/Node.js required** -- SEO Panel is a traditional PHP app with bundled libraries
2. **All PHP extensions already loaded** -- curl, mysqli, gd, mbstring, intl, etc.
3. **Database already exists** -- `sql_seo_amarisstock_com` created via aaPanel, empty and ready
4. **Nginx vhost already configured** -- PHP 8.4 FPM, SSL, sensitive file blocking all in place
5. **No custom Nginx rewrite needed** -- app uses direct PHP entry points
6. **SMTP stored in database** -- not in `.env`; configured via SQL UPDATE on `settings` table
7. **Timezone** -- server set to `Africa/Nairobi`, app timezone set in DB `settings` table
8. **SSL** -- already issued via aaPanel Let's Encrypt, auto-renewal handled by panel
