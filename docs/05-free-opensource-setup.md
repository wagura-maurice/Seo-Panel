# 05 - Free & Open Source SEO Task Configuration Guide

> Complete guide to configuring SEO Panel for 100% free and open source operation.
> No paid plugins, no paid APIs (beyond free tiers), no proprietary services required.

---

## Overview

SEO Panel ships with **11 built-in SEO tools** and supports plugins. This document identifies which tools work for free out of the box, which need free-tier API keys, which settings to toggle, and which plugins are free vs paid.

### Key Principle

SEO Panel has a **3-tier priority system** for SERP data:
1. **DataForSEO (paid)** -- highest priority, overrides everything
2. **SP API (paid)** -- overrides crawl
3. **Crawl / Scraping (FREE)** -- default, scrapes Google/Bing/Yahoo directly

By disabling the paid tiers (DFS and SP API), the system falls back to the **free crawl method** for all rank checking.

---

## 1. Built-in SEO Tools -- Current Status & Free Configuration

All 11 tools are **open source** (GPL-licensed). The question is whether they need a paid API or can run free.

| # | Tool | Free? | API Dependency | Action Needed |
|---|------|-------|---------------|---------------|
| 1 | Keyword Position Checker | YES (crawl mode) | None if using crawl | Disable paid APIs |
| 2 | Site Auditor | YES | None | Ready to use |
| 3 | Rank Checker (MOZ) | FREE TIER | MOZ API (50 rows/mo) | Get free MOZ token |
| 4 | Backlinks Checker | FREE TIER | MOZ API (50 rows/mo) | Get free MOZ token |
| 5 | Directory Submission | YES | None | Ready to use |
| 6 | Search Engine Saturation | YES | None (scrapes Google/Bing) | Ready to use |
| 7 | PageSpeed Insights | YES | Google API key (free, 25K/day) | Get free Google API key |
| 8 | Webmaster Tools | YES | Google OAuth (free) | Get free Google OAuth creds |
| 9 | Social Media Checker | YES | None (scrapes pages) | Ready to use |
| 10 | Website Analytics | YES | Google OAuth (free) | Get free Google OAuth creds |
| 11 | Review Manager | YES (scrape mode) | None if using scraping | Disable DFS for reviews |

---

## 2. Database Settings to Change for 100% Free Operation

Several settings currently enable paid API paths. These must be disabled to ensure the free crawl/scrape methods are used.

### Settings to Disable (Paid Services)

```sql
-- Disable DataForSEO (paid API for SERP, backlinks, reviews)
UPDATE settings SET set_val='0' WHERE set_name='SP_ENABLE_DFS';
UPDATE settings SET set_val='0' WHERE set_name='SP_ENABLE_DFS_SERP';
UPDATE settings SET set_val='0' WHERE set_name='SP_ENABLE_DFS_BACK_SATU';
UPDATE settings SET set_val='0' WHERE set_name='SP_ENABLE_DFS_REVIEW';

-- Disable SEO Panel API (paid SERP service)
UPDATE settings SET set_val='0' WHERE set_name='SP_ENABLE_SPAPI_SERP';

-- Ensure sample/fake data is OFF (use real data only)
UPDATE settings SET set_val='0' WHERE set_name='SP_USE_SAMPLE_API_DATA';
```

### Settings Already Correct (No Change Needed)

```sql
-- SP API not registered (no paid key)
SP_SPAPI_REGISTERED = 0  -- already set

-- DataForSEO credentials empty (no paid key)
SP_DFS_API_LOGIN = ''    -- already empty
SP_DFS_API_PASSWORD = '' -- already empty

-- Proxy disabled (not needed for free operation)
SP_ENABLE_PROXY = 0      -- already set
```

### Settings to Configure (Free API Keys)

```sql
-- Google API Key (for PageSpeed Insights -- FREE, 25,000 queries/day)
UPDATE settings SET set_val='YOUR_GOOGLE_API_KEY' WHERE set_name='SP_GOOGLE_API_KEY';

-- Google OAuth Credentials (for Webmaster Tools + Analytics -- FREE)
UPDATE settings SET set_val='YOUR_CLIENT_ID' WHERE set_name='SP_GOOGLE_API_CLIENT_ID';
UPDATE settings SET set_val='YOUR_CLIENT_SECRET' WHERE set_name='SP_GOOGLE_API_CLIENT_SECRET';

-- MOZ API Token (free tier: 50 rows/month, 1 req/10 sec -- requires credit card but $0)
UPDATE settings SET set_val='YOUR_MOZ_API_TOKEN' WHERE set_name='SP_MOZ_API_ACCESS_ID';
```

---

## 3. Free API Keys to Obtain

### 3.1 Google API Key (PageSpeed Insights) -- FREE

- **Cost:** $0 (25,000 queries/day, 240 queries/minute)
- **Purpose:** Powers the PageSpeed Insights tool
- **How to get:**
  1. Go to https://console.cloud.google.com/
  2. Create a new project (or use existing)
  3. Navigate to APIs & Services -> Library
  4. Search for "PageSpeed Insights API" and Enable it
  5. Go to Credentials -> Create Credentials -> API Key
  6. Copy the API key
- **Where to set:** Admin Panel -> System Settings -> Google Settings -> Google API Key
- **Or via SQL:**
  ```sql
  UPDATE settings SET set_val='YOUR_KEY' WHERE set_name='SP_GOOGLE_API_KEY';
  ```

### 3.2 Google OAuth Credentials (Webmaster Tools + Analytics) -- FREE

- **Cost:** $0 (Google Search Console API and Google Analytics API are free)
- **Purpose:** Powers Webmaster Tools (Search Console) and Website Analytics (GA4)
- **How to get:**
  1. Go to https://console.cloud.google.com/
  2. Navigate to APIs & Services -> Library
  3. Enable "Google Search Console API"
  4. Enable "Google Analytics Data API"
  5. Go to Credentials -> Create Credentials -> OAuth client ID
  6. Application type: Web application
  7. Authorized redirect URI: `https://seo.amarisstock.com/admin-panel.php?sec=connections&action=connect_return&category=google`
  8. Copy the Client ID and Client Secret
- **Where to set:** Admin Panel -> System Settings -> Google Settings -> Google API Client ID / Secret
- **Or via SQL:**
  ```sql
  UPDATE settings SET set_val='YOUR_CLIENT_ID' WHERE set_name='SP_GOOGLE_API_CLIENT_ID';
  UPDATE settings SET set_val='YOUR_CLIENT_SECRET' WHERE set_name='SP_GOOGLE_API_CLIENT_SECRET';
  ```

### 3.3 MOZ API Token (Free Tier) -- FREE ($0, credit card required)

- **Cost:** $0/month (50 rows/month, 1 request per 10 seconds)
- **Purpose:** Powers Rank Checker (MOZ) and Backlinks Checker
- **Limitations:** 50 rows per month is very limited -- sufficient for occasional checks of a few websites, not bulk operations
- **How to get:**
  1. Go to https://moz.com/checkout/moz-api/plan/api_free
  2. Create a MOZ account
  3. Add a credit card (required but not charged on free tier)
  4. Navigate to API dashboard and generate an API token
- **Where to set:** Admin Panel -> System Settings -> MOZ Settings -> Moz API Access ID
- **Or via SQL:**
  ```sql
  UPDATE settings SET set_val='YOUR_MOZ_TOKEN' WHERE set_name='SP_MOZ_API_ACCESS_ID';
  ```
- **Note:** If you don't want to use MOZ at all, leave the token empty. The Backlinks Checker and Rank Checker will return 0 results for MOZ-specific metrics, but the Keyword Position Checker (crawl-based) and Search Engine Saturation will still work fully free.

---

## 4. Tool-by-Tool Free Configuration Details

### 4.1 Keyword Position Checker -- 100% FREE (Crawl Mode)

This is the core SEO tool. It checks keyword rankings on Google, Bing, and Yahoo by directly scraping search engine results pages (SERPs).

**How it works (free):**
- The `Spider` class crawls Google/Bing/Yahoo search results
- Parses HTML using regex patterns stored in the `searchengines` table
- Matches your website URL against the results
- 3 search engines are pre-configured: Google, Bing, Yahoo

**Current state:** 3 search engines active and synced.

**To ensure free operation:**
```sql
-- These disable the paid API paths, forcing crawl mode
UPDATE settings SET set_val='0' WHERE set_name='SP_ENABLE_SPAPI_SERP';
UPDATE settings SET set_val='0' WHERE set_name='SP_ENABLE_DFS';
UPDATE settings SET set_val='0' WHERE set_name='SP_ENABLE_DFS_SERP';
```

**Limitations of crawl mode:**
- Google may rate-limit or block if too many requests are made
- Use a proxy (SP_ENABLE_PROXY) if you encounter CAPTCHAs (but proxies cost money)
- The crawl delay setting (`SP_CRAWL_DELAY = 5` seconds) helps avoid blocking
- Only 1 keyword is checked per cron execution (`SP_NUMBER_KEYWORDS_CRON = 1`)

### 4.2 Site Auditor -- 100% FREE

Crawls your website and audits SEO factors: page titles, meta descriptions, meta keywords, links, page authority, broken links, etc.

**No API key needed.** Uses the built-in `Spider` class to crawl your site.

**Configuration (already optimal):**
- `SA_MAX_NO_PAGES = 500` -- max pages to audit per site
- `SA_CRAWL_DELAY_TIME = 10` -- delay between crawls (seconds)
- `SA_TITLE_MAX_LENGTH = 80`, `SA_TITLE_MIN_LENGTH = 50`
- `SA_DES_MAX_LENGTH = 200`, `SA_DES_MIN_LENGTH = 120`

**Cron:** Runs via `siteauditorcron.php` (daily at 03:00)

### 4.3 Rank Checker (MOZ) -- FREE TIER (50 rows/month)

Checks MOZ metrics: domain authority, page authority, spam score, backlink counts.

**Without MOZ API key:** Returns 0 for all MOZ metrics.
**With free MOZ API key:** 50 rows/month (enough for ~1-2 websites checked monthly).

### 4.4 Backlinks Checker -- FREE TIER (50 rows/month)

Uses MOZ API to check backlink counts. Same limitation as Rank Checker.

**Without MOZ API key:** Returns 0 backlinks.
**With free MOZ API key:** 50 rows/month.

**Alternative:** The saturation checker (tool #6) provides a free alternative by scraping `site:yourdomain.com` results from Google/Bing.

### 4.5 Directory Submission -- 100% FREE

Submits your website to web directories. 142 directories are pre-loaded (21 currently working).

**No API key needed.** Submits directly to directory websites.

**Note:** Many pre-loaded directories may be outdated. The Directory Importer plugin (paid, $29) can import fresh directories, but the base tool works free.

### 4.6 Search Engine Saturation -- 100% FREE

Checks how many pages of your site are indexed by Google and Bing by scraping `site:yourdomain.com` search results.

**No API key needed.** Uses the `Spider` class to scrape Google/Bing directly.

### 4.7 PageSpeed Insights -- FREE (25,000 queries/day)

Checks Google PageSpeed scores (desktop and mobile) for your websites.

**Requires:** Google API Key (free)
**Without API key:** The tool will not function (returns error).

### 4.8 Webmaster Tools (Google Search Console) -- FREE

Integrates with Google Search Console to show search analytics, sitemaps, keywords, and indexing status.

**Requires:** Google OAuth Client ID and Secret (free)
**Without credentials:** Tool shows an alert to configure credentials.

### 4.9 Social Media Checker -- 100% FREE

Checks social media metrics (likes, followers) for Facebook, Twitter, etc. by scraping social media pages.

**No API key needed.** Uses the `Spider` class to scrape social media pages directly.

### 4.10 Website Analytics (Google Analytics GA4) -- FREE

Integrates with Google Analytics 4 to show traffic data, sources, user metrics.

**Requires:** Google OAuth Client ID and Secret (same as Webmaster Tools)
**Without credentials:** Tool shows an alert to configure credentials.

### 4.11 Review Manager -- FREE (Scrape Mode)

Checks reviews on Google, Yelp, Trustpilot, TripAdvisor.

**Free mode (scraping):** Scrapes review pages directly. Supports Yelp natively.
**Paid mode (DataForSEO):** Uses DataForSEO API for Google, Trustpilot, TripAdvisor.

**To ensure free operation:**
```sql
UPDATE settings SET set_val='0' WHERE set_name='SP_ENABLE_DFS_REVIEW';
```

With DFS disabled, all review platforms use the scraping method (free).

---

## 5. Free Plugins (Open Source, No Cost)

### Already Installed

| Plugin | Status | Price | Description |
|--------|--------|-------|-------------|
| Meta Tag Generator | Active (status=1) | FREE | Generate meta tags for web pages |
| Quick Web Proxy | Active in DB (status=1) | FREE | Web proxy server using your hosting |
| Test Plugin | Inactive (status=0) | FREE | Demo plugin for development reference |

**Note:** Quick Web Proxy is registered in the database but the plugin directory is not present in this deployment. To install it, download from https://www.seopanel.org/plugins/ (free download).

### Available for Free Download

| Plugin | Price | Description |
|--------|-------|-------------|
| Seo Diary | FREE | Store SEO tasks, TODOs, and website information |
| Quick Web Proxy | FREE | Web proxy server (solve CAPTCHA manually) |

### Paid Plugins (NOT Free -- Listed for Reference)

| Plugin | Price | Description |
|--------|-------|-------------|
| Local Search Engines Package | $10 | Add local Google/Bing/Yahoo domains (google.de, etc.) |
| Link Diagnosis | $30 | Detailed backlink analysis |
| Directory Importer | $29 | Import custom directories + 1000 active directories |
| Blog Community | $25 | Auto-submit comments to blogs |
| Social Bookmarker | $10 | Submit links to 120+ social sites |
| Yandex Search Engine Package | $10 | Track keywords on Yandex (Russia) |
| Baidu Search Engine Package | $10 | Track keywords on Baidu (China) |
| Seznam Search Engine Package | $10 | Track keywords on Seznam (Czech) |
| Newsletter Plugin | $30 | Send newsletters to subscribers |
| Social Media Manager | $59 | Schedule social media posts |
| Bulk Keyword Rank Checker | $25 | Check many links per keyword in one request |
| Membership Subscription | $75 | User subscription management with PayPal/Stripe |
| Seo Panel Customizer | $99 | Customize logo, site name, home page |
| Article Submitter & Spinner | Paid | Create and submit articles to directories |

---

## 6. Recommended Free Setup Configuration Script

Run this SQL to configure all settings for 100% free operation:

```sql
-- ============================================================
-- SEO Panel: 100% Free & Open Source Configuration
-- ============================================================

-- Disable paid API services
UPDATE settings SET set_val='0' WHERE set_name='SP_ENABLE_DFS';
UPDATE settings SET set_val='0' WHERE set_name='SP_ENABLE_DFS_SERP';
UPDATE settings SET set_val='0' WHERE set_name='SP_ENABLE_DFS_BACK_SATU';
UPDATE settings SET set_val='0' WHERE set_name='SP_ENABLE_DFS_REVIEW';
UPDATE settings SET set_val='0' WHERE set_name='SP_ENABLE_SPAPI_SERP';
UPDATE settings SET set_val='0' WHERE set_name='SP_USE_SAMPLE_API_DATA';

-- Enable free Google API key for PageSpeed (replace with your key)
-- UPDATE settings SET set_val='YOUR_GOOGLE_API_KEY' WHERE set_name='SP_GOOGLE_API_KEY';

-- Enable free Google OAuth for Webmaster Tools + Analytics (replace with your creds)
-- UPDATE settings SET set_val='YOUR_CLIENT_ID' WHERE set_name='SP_GOOGLE_API_CLIENT_ID';
-- UPDATE settings SET set_val='YOUR_CLIENT_SECRET' WHERE set_name='SP_GOOGLE_API_CLIENT_SECRET';

-- Enable free MOZ API token (replace with your token, optional)
-- UPDATE settings SET set_val='YOUR_MOZ_TOKEN' WHERE set_name='SP_MOZ_API_ACCESS_ID';

-- Optimize crawl settings for free operation
UPDATE settings SET set_val='5' WHERE set_name='SP_CRAWL_DELAY';
UPDATE settings SET set_val='1' WHERE set_name='SP_NUMBER_KEYWORDS_CRON';
UPDATE settings SET set_val='1' WHERE set_name='SP_NUMBER_WEBSITES_CRON';

-- Keep user agent updated (helps avoid blocking)
UPDATE settings SET set_val='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36' WHERE set_name='SP_USER_AGENT';
```

---

## 7. Summary: What Works Free vs What Needs a Key

### Works Immediately (No Configuration Needed)

1. **Site Auditor** -- crawl and audit your website
2. **Search Engine Saturation** -- check indexed pages on Google/Bing
3. **Social Media Checker** -- check social media metrics
4. **Directory Submission** -- submit to web directories
5. **Keyword Position Checker** -- check keyword rankings (crawl mode)
6. **Review Manager** -- check reviews (scrape mode)
7. **Meta Tag Generator** plugin -- generate meta tags

### Needs a Free API Key (Still 100% Free)

8. **PageSpeed Insights** -- needs Google API key (free, 25K/day)
9. **Webmaster Tools** -- needs Google OAuth credentials (free)
10. **Website Analytics** -- needs Google OAuth credentials (free, same as above)

### Needs Free Tier API Key (Free Tier, Credit Card Required)

11. **Rank Checker (MOZ)** -- needs MOZ API token (50 rows/month free)
12. **Backlinks Checker** -- needs MOZ API token (same 50 rows/month)

### Not Available Free (Paid Plugins Only)

- Local search engine tracking (google.de, google.co.uk, etc.) -- $10
- Bulk keyword rank checking -- $25
- Link diagnosis (detailed backlinks) -- $30
- Social bookmarking -- $10
- Blog comment submission -- $25

---

## 8. Free Operation Limitations & Mitigations

| Limitation | Impact | Mitigation |
|------------|--------|------------|
| Google may block crawl after many requests | Keyword position checker stops working | Increase `SP_CRAWL_DELAY` to 10+ seconds; check fewer keywords per cron |
| MOZ free tier = 50 rows/month | Only ~1-2 website MOZ checks per month | Use saturation checker as a free alternative for indexing metrics |
| No local search engines (google.de, etc.) | Only global Google/Bing/Yahoo | Accept limitation or use proxy rotation |
| Directory submission has 21 working directories | Limited directory submissions | Manually find and submit to directories outside SEO Panel |
| No bulk rank checking | 1 keyword checked per cron execution | Increase `SP_NUMBER_KEYWORDS_CRON` cautiously (risk of blocking) |

---

## 9. Post-Configuration Checklist

After applying the free configuration:

- [ ] Run the SQL configuration script (section 6)
- [ ] Obtain a Google API key and set `SP_GOOGLE_API_KEY`
- [ ] Obtain Google OAuth credentials and set `SP_GOOGLE_API_CLIENT_ID` / `SP_GOOGLE_API_CLIENT_SECRET`
- [ ] (Optional) Obtain MOZ API token and set `SP_MOZ_API_ACCESS_ID`
- [ ] Add your website(s) in the admin panel
- [ ] Add keywords to track for each website
- [ ] Run a manual keyword position check to verify crawl mode works
- [ ] Run a site auditor crawl to verify it works
- [ ] Run a saturation check to verify it works
- [ ] Verify cron jobs are running (`crontab -l`)
- [ ] Check crawl logs in admin panel for errors
- [ ] Update the user agent string (older IE string may get blocked)
