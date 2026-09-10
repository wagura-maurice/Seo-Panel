#!/usr/bin/env bash
# =============================================================================
# SEO Panel - Automated Deployment Script for aaPanel (Ubuntu 22.04)
# =============================================================================
# Deploys the Seo-Panel application to /www/wwwroot/seo.amarisstock.com
# on an aaPanel VPS with PHP 8.4 and MySQL 8.
#
# Usage:
#   sudo bash deploy.sh           # Full deployment
#   sudo bash deploy.sh --dry-run # Show what would be done without executing
#
# Prerequisites:
#   - aaPanel installed with PHP 8.4, MySQL 8, Nginx
#   - Site seo.amarisstock.com created in aaPanel
#   - Database sql_seo_amarisstock_com and user already created
#   - SSH key has access to git@github.com:wagura-maurice/Seo-Panel.git
#   - Run as root (or with sudo)
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration Variables (edit these if needed)
# ---------------------------------------------------------------------------
SITE_DOMAIN="seo.amarisstock.com"
SITE_ROOT="/www/wwwroot/${SITE_DOMAIN}"
GIT_REPO="git@github.com:wagura-maurice/Seo-Panel.git"
GIT_BRANCH=""  # empty = default branch

# Database credentials
DB_NAME="sql_seo_amarisstock_com"
DB_USER="sql_seo_amarisstock_com"
DB_PASS="3c7d9c6bd1633"
DB_HOST="localhost"

# SMTP credentials (Mailtrap Sandbox)
SMTP_HOST="sandbox.smtp.mailtrap.io"
SMTP_PORT="2525"
SMTP_USER="be6e87f82be3a7"
SMTP_PASS="2b1dadf3db173f"

# Application settings
SP_WEBPATH="https://${SITE_DOMAIN}"
SP_INSTALLED="6.0.0"
SP_DEBUG="0"
SP_TIMEOUT="18000"
SP_TIMEZONE="Africa/Nairobi"

# System paths (aaPanel defaults)
PHP_BIN="/www/server/php/84/bin/php"
PHP_INI="/www/server/php/84/etc/php.ini"
PHP_CLI_INI="/www/server/php/84/etc/php-cli.ini"
PHP_FPM_INIT="/etc/init.d/php-fpm-84"
MYSQL_BIN="/www/server/mysql/bin/mysql"
NGINX_BIN="/www/server/nginx/sbin/nginx"
WEB_USER="www"
PANEL_DB="/www/server/panel/data/default.db"

# FTP credentials (reference only, not used by script)
FTP_USER="ftp_seo_amarisstock_com"
FTP_PASS="9b4392797c9c68"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Dry-run mode
DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
fi

# ---------------------------------------------------------------------------
# Helper Functions
# ---------------------------------------------------------------------------
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

run_cmd() {
    if $DRY_RUN; then
        echo -e "${YELLOW}[DRY-RUN]${NC} $1"
    else
        eval "$1"
    fi
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root."
        exit 1
    fi
}

check_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        log_error "Required command not found: $1"
        exit 1
    fi
}

# Set or append a php.ini directive (preserves all other aaPanel settings)
set_php_ini() {
    local file=$1 key=$2 val=$3
    if [[ ! -f "$file" ]]; then
        log_warn "php.ini not found: $file -- skipping"
        return
    fi
    if $DRY_RUN; then
        echo -e "${YELLOW}[DRY-RUN]${NC} Set $key = $val in $file"
        return
    fi
    # Escape special chars in value for sed
    local escaped_val
    escaped_val=$(printf '%s\n' "$val" | sed 's/[\/&]/\\&/g')
    if grep -qE "^\s*${key}\s*=" "$file"; then
        sed -i "s|^\s*${key}\s*=.*|${key} = ${val}|" "$file"
    else
        echo "${key} = ${val}" >> "$file"
    fi
}

# ---------------------------------------------------------------------------
# Step 0: Pre-flight Checks
# ---------------------------------------------------------------------------
preflight_checks() {
    log_info "Running pre-flight checks..."

    check_root

    # Check required binaries
    local required_bins=("git" "rsync" "find" "chmod" "chown" "sqlite3")
    for bin in "${required_bins[@]}"; do
        check_command "$bin"
    done

    # Check PHP 8.4
    if [[ ! -x "$PHP_BIN" ]]; then
        log_error "PHP 8.4 not found at $PHP_BIN"
        exit 1
    fi
    log_success "PHP 8.4 found: $($PHP_BIN -v 2>/dev/null | head -1)"

    # Check MySQL
    if [[ ! -x "$MYSQL_BIN" ]]; then
        log_error "MySQL not found at $MYSQL_BIN"
        exit 1
    fi
    log_success "MySQL found: $($MYSQL_BIN --version 2>/dev/null)"

    # Check Nginx
    if [[ ! -x "$NGINX_BIN" ]]; then
        log_error "Nginx not found at $NGINX_BIN"
        exit 1
    fi
    log_success "Nginx found"

    # Check site root exists
    if [[ ! -d "$SITE_ROOT" ]]; then
        log_error "Site root does not exist: $SITE_ROOT"
        log_error "Create the site in aaPanel first."
        exit 1
    fi
    log_success "Site root exists: $SITE_ROOT"

    # Check database connectivity
    log_info "Testing database connection..."
    if ! $MYSQL_BIN -u"$DB_USER" -p"$DB_PASS" -e "USE $DB_NAME; SELECT 1;" >/dev/null 2>&1; then
        log_error "Cannot connect to database '$DB_NAME' as user '$DB_USER'"
        log_error "Verify the database and user exist in aaPanel."
        exit 1
    fi
    log_success "Database connection successful"

    # Check if database already has tables (warn if so)
    local table_count
    table_count=$($MYSQL_BIN -u"$DB_USER" -p"$DB_PASS" -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$DB_NAME';" -s 2>/dev/null || echo "0")
    if [[ "$table_count" -gt 0 ]]; then
        log_warn "Database already contains $table_count tables. Re-importing may cause errors."
        read -p "Continue anyway? (y/N): " confirm
        [[ "$confirm" =~ ^[Yy]$ ]] || exit 0
    fi

    # Check SSH key access to GitHub
    log_info "Testing SSH access to GitHub..."
    if ! ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
        log_warn "SSH key may not have access to the GitHub repository."
        log_warn "The clone step may fail. Ensure your SSH key is added to GitHub."
    else
        log_success "GitHub SSH access confirmed"
    fi

    log_success "All pre-flight checks passed"
}

# ---------------------------------------------------------------------------
# Step 1: Set Server Timezone
# ---------------------------------------------------------------------------
set_timezone() {
    log_info "Setting server timezone to $SP_TIMEZONE..."

    local current_tz
    current_tz=$(timedatectl show -p Timezone --value 2>/dev/null || echo "")

    if [[ "$current_tz" == "$SP_TIMEZONE" ]]; then
        log_success "Timezone already set to $SP_TIMEZONE"
        return
    fi

    run_cmd "timedatectl set-timezone $SP_TIMEZONE"
    log_success "Server timezone set to $SP_TIMEZONE"
}

# ---------------------------------------------------------------------------
# Step 2: Backup Existing Site Files
# ---------------------------------------------------------------------------
backup_site() {
    local backup_dir="${SITE_ROOT}.bak.$(date +%Y%m%d%H%M%S)"
    log_info "Backing up current site files to $backup_dir..."
    run_cmd "cp -a '$SITE_ROOT' '$backup_dir'"
    log_success "Backup created at $backup_dir"
}

# ---------------------------------------------------------------------------
# Step 3: Clone Repository into Site Root (no nested sub-directory)
# ---------------------------------------------------------------------------
clone_repository() {
    log_info "Cloning repository from GitHub..."

    local temp_clone="/tmp/seo-panel-deploy-$$"
    local clone_cmd="git clone --depth 1"

    if [[ -n "$GIT_BRANCH" ]]; then
        clone_cmd="$clone_cmd --branch $GIT_BRANCH"
    fi
    clone_cmd="$clone_cmd $GIT_REPO $temp_clone"

    run_cmd "$clone_cmd"

    log_info "Syncing files into site root (preserving aaPanel files)..."
    # rsync with exclusions to preserve aaPanel-managed files
    # --exclude='.git' to avoid deploying git metadata
    # --exclude='.user.ini' to preserve aaPanel open_basedir config
    # --exclude='.well-known' to preserve SSL verification directory
    # --exclude='docs' to preserve our deployment documentation
    run_cmd "rsync -a --exclude='.git' --exclude='.user.ini' --exclude='.well-known' --exclude='docs' '$temp_clone/' '$SITE_ROOT/'"

    run_cmd "rm -rf '$temp_clone'"
    log_success "Repository cloned and synced to $SITE_ROOT"
}

# ---------------------------------------------------------------------------
# Step 4: Generate config/sp-config.php
# ---------------------------------------------------------------------------
generate_config() {
    log_info "Generating config/sp-config.php..."

    local config_file="$SITE_ROOT/config/sp-config.php"
    local config_content="<?php

/***************************************************************************
 *   SEO Panel - Main Configuration
 *   Generated by deploy.sh for $SITE_DOMAIN
 *   Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)
 ***************************************************************************/

# The web path or url to access seo panel through browser.
define('SP_WEBPATH', '${SP_WEBPATH}');

# DB settings
define('DB_NAME', '${DB_NAME}');
define('DB_USER', '${DB_USER}');
define('DB_PASSWORD', '${DB_PASS}');
define('DB_HOST', '${DB_HOST}');

# The name of the database engine for seo panel
define('DB_ENGINE', 'mysql');

# The version of seo panel installed
define('SP_INSTALLED', '${SP_INSTALLED}');

# The DB debug mode
define('SP_DEBUG', ${SP_DEBUG});

# The seo panel seconds for session timeout
define('SP_TIMEOUT', ${SP_TIMEOUT});
?>"

    if $DRY_RUN; then
        echo -e "${YELLOW}[DRY-RUN]${NC} Would write config to $config_file"
        echo "$config_content"
        return
    fi

    echo "$config_content" > "$config_file"
    chmod 666 "$config_file"  # writable during install phase
    log_success "config/sp-config.php generated"
}

# ---------------------------------------------------------------------------
# Step 5: Create .env and .env.example files
# ---------------------------------------------------------------------------
create_env_files() {
    log_info "Creating .env and .env.example files..."

    local env_file="$SITE_ROOT/.env"
    local env_example_file="$SITE_ROOT/.env.example"

    local env_content="MYSQL_DB_HOST=${DB_HOST}
MYSQL_DATABASE=${DB_NAME}
MYSQL_USER=${DB_USER}
MYSQL_PASSWORD=${DB_PASS}
MYSQL_ROOT_PASSWORD=$(get_mysql_root_pass 2>/dev/null || echo 'changeme')

# SMTP (Mailtrap Sandbox)
MAIL_MAILER=smtp
MAIL_HOST=${SMTP_HOST}
MAIL_PORT=${SMTP_PORT}
MAIL_USERNAME=${SMTP_USER}
MAIL_PASSWORD=${SMTP_PASS}"

    local env_example_content="MYSQL_DB_HOST=localhost
MYSQL_DATABASE=seopanel
MYSQL_USER=seopanel
MYSQL_PASSWORD=seopanelpass
MYSQL_ROOT_PASSWORD=rootpass

# SMTP Configuration
MAIL_MAILER=smtp
MAIL_HOST=your-smtp-host
MAIL_PORT=2525
MAIL_USERNAME=your-username
MAIL_PASSWORD=your-password"

    if $DRY_RUN; then
        echo -e "${YELLOW}[DRY-RUN]${NC} Would write $env_file and $env_example_file"
        return
    fi

    echo "$env_content" > "$env_file"
    echo "$env_example_content" > "$env_example_file"
    chmod 640 "$env_file" "$env_example_file"
    log_success ".env and .env.example created"
}

# ---------------------------------------------------------------------------
# Helper: Get MySQL root password from aaPanel
# ---------------------------------------------------------------------------
get_mysql_root_pass() {
    sqlite3 "$PANEL_DB" "SELECT mysql_root FROM config LIMIT 1;" 2>/dev/null || echo ""
}

# ---------------------------------------------------------------------------
# Step 6: Import Database Schema
# ---------------------------------------------------------------------------
import_database() {
    log_info "Importing database schema..."

    local sql_main="$SITE_ROOT/install/data/seopanel.sql"
    local sql_lang="$SITE_ROOT/install/data/textlang.sql"

    if $DRY_RUN; then
        echo -e "${YELLOW}[DRY-RUN]${NC} Would import $sql_main and $sql_lang"
        return
    fi

    if [[ ! -f "$sql_main" ]]; then
        log_error "SQL file not found: $sql_main"
        exit 1
    fi

    if [[ ! -f "$sql_lang" ]]; then
        log_warn "Language SQL file not found: $sql_lang -- skipping"
    fi

    log_info "Importing main schema ($sql_main)..."
    run_cmd "$MYSQL_BIN -u\"$DB_USER\" -p\"$DB_PASS\" \"$DB_NAME\" < \"$sql_main\""

    if [[ -f "$sql_lang" ]]; then
        log_info "Importing language texts ($sql_lang)..."
        run_cmd "$MYSQL_BIN -u\"$DB_USER\" -p\"$DB_PASS\" \"$DB_NAME\" < \"$sql_lang\""
    fi

    log_success "Database schema imported"
}

# ---------------------------------------------------------------------------
# Step 7: Configure SMTP Settings in Database
# ---------------------------------------------------------------------------
configure_smtp() {
    log_info "Configuring SMTP settings in database..."

    local sql="UPDATE settings SET set_val='1' WHERE set_name='SP_SMTP_MAIL';
UPDATE settings SET set_val='${SMTP_HOST}' WHERE set_name='SP_SMTP_HOST';
UPDATE settings SET set_val='${SMTP_USER}' WHERE set_name='SP_SMTP_USERNAME';
UPDATE settings SET set_val='${SMTP_PASS}' WHERE set_name='SP_SMTP_PASSWORD';
UPDATE settings SET set_val='${SMTP_PORT}' WHERE set_name='SP_SMTP_PORT';
UPDATE settings SET set_val='' WHERE set_name='SP_MAIL_ENCRYPTION';"

    if $DRY_RUN; then
        echo -e "${YELLOW}[DRY-RUN]${NC} Would execute SMTP settings UPDATE"
        return
    fi

    $MYSQL_BIN -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "$sql" 2>/dev/null
    log_success "SMTP settings configured (Mailtrap Sandbox: ${SMTP_HOST}:${SMTP_PORT})"
}

# ---------------------------------------------------------------------------
# Step 8: Set Application Timezone in Database
# ---------------------------------------------------------------------------
configure_timezone() {
    log_info "Setting application timezone to $SP_TIMEZONE in database..."

    if $DRY_RUN; then
        echo -e "${YELLOW}[DRY-RUN]${NC} Would UPDATE SP_TIME_ZONE = $SP_TIMEZONE"
        return
    fi

    $MYSQL_BIN -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" \
        -e "UPDATE settings SET set_val='${SP_TIMEZONE}' WHERE set_name='SP_TIME_ZONE';" 2>/dev/null
    log_success "Application timezone set to $SP_TIMEZONE"
}

# ---------------------------------------------------------------------------
# Step 9: Set File Permissions
# ---------------------------------------------------------------------------
set_permissions() {
    log_info "Setting file permissions..."

    if $DRY_RUN; then
        echo -e "${YELLOW}[DRY-RUN]${NC} Would set ownership to $WEB_USER and permissions"
        return
    fi

    # aaPanel protects .user.ini with the immutable (i) chattr flag.
    # Temporarily remove it so chown can succeed, then restore it.
    local user_ini="$SITE_ROOT/.user.ini"
    if [[ -f "$user_ini" ]]; then
        chattr -i "$user_ini" 2>/dev/null || true
    fi

    # Set ownership to web user
    chown -R "$WEB_USER":"$WEB_USER" "$SITE_ROOT"

    # Restore immutable flag on .user.ini to preserve aaPanel protection
    if [[ -f "$user_ini" ]]; then
        chattr +i "$user_ini" 2>/dev/null || true
    fi

    # Directories: 755
    find "$SITE_ROOT" -type d -exec chmod 755 {} \;

    # Files: 644
    find "$SITE_ROOT" -type f -exec chmod 644 {} \;

    # tmp directory: 777 (must be writable by all)
    chmod 777 "$SITE_ROOT/tmp"

    # config/sp-config.php: 644 (read-only after install)
    chmod 644 "$SITE_ROOT/config/sp-config.php"

    # .env files: 640 (restricted)
    chmod 640 "$SITE_ROOT/.env" "$SITE_ROOT/.env.example" 2>/dev/null || true

    log_success "File permissions set"
}

# ---------------------------------------------------------------------------
# Step 10: Apply php.ini Optimizations
# ---------------------------------------------------------------------------
optimize_php_ini() {
    log_info "Applying php.ini optimizations..."

    for ini_file in "$PHP_INI" "$PHP_CLI_INI"; do
        if [[ ! -f "$ini_file" ]]; then
            log_warn "php.ini not found: $ini_file -- skipping"
            continue
        fi

        set_php_ini "$ini_file" "memory_limit" "256M"
        set_php_ini "$ini_file" "max_execution_time" "300"
        set_php_ini "$ini_file" "max_input_time" "300"
        set_php_ini "$ini_file" "upload_max_filesize" "64M"
        set_php_ini "$ini_file" "post_max_size" "64M"
        set_php_ini "$ini_file" "max_input_vars" "3000"
        set_php_ini "$ini_file" "date.timezone" "$SP_TIMEZONE"
        set_php_ini "$ini_file" "session.gc_maxlifetime" "$SP_TIMEOUT"
        set_php_ini "$ini_file" "display_errors" "Off"
        set_php_ini "$ini_file" "error_reporting" "E_ALL & ~E_DEPRECATED & ~E_STRICT"
    done

    log_success "php.ini optimizations applied"
}

# ---------------------------------------------------------------------------
# Step 11: Remove Install Directory
# ---------------------------------------------------------------------------
remove_install_dir() {
    log_info "Removing install directory for security..."

    if [[ -d "$SITE_ROOT/install" ]]; then
        run_cmd "rm -rf '$SITE_ROOT/install'"
        log_success "Install directory removed"
    else
        log_success "Install directory already removed"
    fi
}

# ---------------------------------------------------------------------------
# Step 12: Reload Services
# ---------------------------------------------------------------------------
reload_services() {
    log_info "Reloading PHP-FPM and Nginx..."

    if $DRY_RUN; then
        echo -e "${YELLOW}[DRY-RUN]${NC} Would reload PHP-FPM and Nginx"
        return
    fi

    # Reload PHP-FPM
    if [[ -x "$PHP_FPM_INIT" ]]; then
        "$PHP_FPM_INIT" reload 2>/dev/null || \
            systemctl reload php8.4-fpm 2>/dev/null || \
            log_warn "Could not reload PHP-FPM -- reload manually"
        log_success "PHP-FPM reloaded"
    else
        log_warn "PHP-FPM init script not found -- reload manually"
    fi

    # Test and reload Nginx
    if "$NGINX_BIN" -t 2>/dev/null; then
        "$NGINX_BIN" -s reload 2>/dev/null || \
            systemctl reload nginx 2>/dev/null || \
            log_warn "Could not reload Nginx -- reload manually"
        log_success "Nginx reloaded"
    else
        log_warn "Nginx config test failed -- not reloading"
    fi
}

# ---------------------------------------------------------------------------
# Step 13: Set Up Cron Jobs
# ---------------------------------------------------------------------------
setup_cron() {
    log_info "Setting up cron jobs..."

    local cron_marker="# SEO Panel cron jobs - managed by deploy.sh"
    local crontab_file="/tmp/seopanel-cron-$$"

    # Export existing crontab
    crontab -l 2>/dev/null > "$crontab_file" || true

    # Remove old SEO Panel entries (between markers)
    if grep -q "$cron_marker" "$crontab_file" 2>/dev/null; then
        sed "/${cron_marker}/,/End SEO Panel cron jobs/d" "$crontab_file" > "${crontab_file}.tmp"
        mv "${crontab_file}.tmp" "$crontab_file"
    fi

    # Append new cron jobs
    cat >> "$crontab_file" << EOF
${cron_marker}
# Main SEO cron -- every 6 hours (keyword rank checking, reports)
0 */6 * * * ${PHP_BIN} ${SITE_ROOT}/cron.php
# Directory submission checker -- daily at 02:00
0 2 * * * ${PHP_BIN} ${SITE_ROOT}/directorycheckercron.php
# Site auditor -- daily at 03:00
0 3 * * * ${PHP_BIN} ${SITE_ROOT}/siteauditorcron.php
# Proxy checker -- daily at 04:00
0 4 * * * ${PHP_BIN} ${SITE_ROOT}/proxycheckercron.php
# End SEO Panel cron jobs
EOF

    if $DRY_RUN; then
        echo -e "${YELLOW}[DRY-RUN]${NC} Would install the following cron jobs:"
        cat "$crontab_file"
    else
        crontab "$crontab_file"
        log_success "Cron jobs installed"
    fi

    rm -f "$crontab_file"
}

# ---------------------------------------------------------------------------
# Step 14: Configure Firewall (verify required ports are open)
# ---------------------------------------------------------------------------
configure_firewall() {
    log_info "Verifying firewall rules..."

    if ! command -v ufw >/dev/null 2>&1; then
        log_warn "ufw not found -- skipping firewall configuration"
        return
    fi

    local ports=(80/tcp 443/tcp 443/udp 22/tcp 888/tcp)

    for port in "${ports[@]}"; do
        if ufw status 2>/dev/null | grep -q "$port"; then
            log_success "Port $port already open"
        else
            if $DRY_RUN; then
                echo -e "${YELLOW}[DRY-RUN]${NC} Would open port $port"
            else
                ufw allow "$port" >/dev/null 2>&1
                log_success "Port $port opened"
            fi
        fi
    done

    # Ensure MySQL is NOT open to the public (defense in depth)
    if ufw status 2>/dev/null | grep -q "3306/tcp"; then
        log_warn "Port 3306 (MySQL) is open to the public -- consider closing it"
        if ! $DRY_RUN; then
            read -p "Close MySQL port 3306 to the public? (Y/n): " confirm
            if [[ ! "$confirm" =~ ^[Nn]$ ]]; then
                ufw deny 3306/tcp >/dev/null 2>&1
                log_success "Port 3306 (MySQL) closed to the public"
            fi
        fi
    else
        log_success "Port 3306 (MySQL) is not open to the public"
    fi
}

# ---------------------------------------------------------------------------
# Step 15: Final Verification
# ---------------------------------------------------------------------------
verify_deployment() {
    log_info "Running post-deployment verification..."

    local errors=0

    # Skip file-based checks in dry-run (files don't exist yet)
    if $DRY_RUN; then
        echo -e "${YELLOW}[DRY-RUN]${NC} Skipping verification (files not present in dry-run)"
        return 0
    fi

    # Check config file exists
    if [[ -f "$SITE_ROOT/config/sp-config.php" ]]; then
        log_success "config/sp-config.php exists"
    else
        log_error "config/sp-config.php is missing"
        errors=$((errors + 1))
    fi

    # Check .env exists
    if [[ -f "$SITE_ROOT/.env" ]]; then
        log_success ".env exists"
    else
        log_error ".env is missing"
        errors=$((errors + 1))
    fi

    # Check install directory removed
    if [[ ! -d "$SITE_ROOT/install" ]]; then
        log_success "install/ directory removed"
    else
        log_warn "install/ directory still exists -- remove manually: rm -rf $SITE_ROOT/install"
    fi

    # Check tmp directory writable
    if [[ -w "$SITE_ROOT/tmp" ]]; then
        log_success "tmp/ directory is writable"
    else
        log_error "tmp/ directory is not writable"
        errors=$((errors + 1))
    fi

    # Check database has tables
    if ! $DRY_RUN; then
        local table_count
        table_count=$($MYSQL_BIN -u"$DB_USER" -p"$DB_PASS" -e \
            "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$DB_NAME';" -s 2>/dev/null || echo "0")
        if [[ "$table_count" -gt 0 ]]; then
            log_success "Database has $table_count tables"
        else
            log_error "Database has no tables -- import may have failed"
            errors=$((errors + 1))
        fi

        # Check SMTP settings
        local smtp_enabled
        smtp_enabled=$($MYSQL_BIN -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" \
            -e "SELECT set_val FROM settings WHERE set_name='SP_SMTP_MAIL';" -s 2>/dev/null || echo "0")
        if [[ "$smtp_enabled" == "1" ]]; then
            log_success "SMTP is enabled in database"
        else
            log_warn "SMTP is not enabled in database"
        fi

        # Check timezone
        local tz
        tz=$($MYSQL_BIN -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" \
            -e "SELECT set_val FROM settings WHERE set_name='SP_TIME_ZONE';" -s 2>/dev/null || echo "")
        if [[ "$tz" == "$SP_TIMEZONE" ]]; then
            log_success "Application timezone is $SP_TIMEZONE"
        else
            log_warn "Application timezone is '$tz' (expected $SP_TIMEZONE)"
        fi
    fi

    # Check PHP syntax of config
    if ! $DRY_RUN; then
        if $PHP_BIN -l "$SITE_ROOT/config/sp-config.php" >/dev/null 2>&1; then
            log_success "config/sp-config.php syntax OK"
        else
            log_error "config/sp-config.php has syntax errors"
            errors=$((errors + 1))
        fi
    fi

    if [[ $errors -gt 0 ]]; then
        log_error "Deployment completed with $errors error(s). Review above."
        return 1
    fi

    log_success "All verification checks passed"
}

# ---------------------------------------------------------------------------
# Main Execution
# ---------------------------------------------------------------------------
main() {
    echo ""
    echo "=============================================="
    echo "  SEO Panel - Automated Deployment"
    echo "  Target: $SITE_DOMAIN"
    echo "  Path:   $SITE_ROOT"
    if $DRY_RUN; then
        echo -e "  Mode:   ${YELLOW}DRY RUN${NC}"
    fi
    echo "=============================================="
    echo ""

    preflight_checks
    echo ""

    set_timezone
    backup_site
    clone_repository
    generate_config
    create_env_files
    import_database
    configure_smtp
    configure_timezone
    set_permissions
    optimize_php_ini
    remove_install_dir
    reload_services
    setup_cron
    configure_firewall
    verify_deployment

    echo ""
    echo "=============================================="
    echo "  Deployment Complete!"
    echo "=============================================="
    echo ""
    echo "  Site URL:       $SP_WEBPATH"
    echo "  Admin URL:      $SP_WEBPATH/login.php"
    echo "  Admin User:     spadmin"
    echo "  Admin Pass:     spadmin (CHANGE IMMEDIATELY)"
    echo ""
    echo "  Next Steps:"
    echo "    1. Visit $SP_WEBPATH/login.php"
    echo "    2. Login with spadmin / spadmin"
    echo "    3. Change the admin password (Profile link)"
    echo "    4. Configure MOZ API key (System Settings)"
    echo "    5. Test SMTP email (System Settings)"
    echo "    6. Verify SSL at aaPanel > Website > SSL"
    echo ""
    echo "  Documentation: $SITE_ROOT/docs/"
    echo ""
}

main "$@"
