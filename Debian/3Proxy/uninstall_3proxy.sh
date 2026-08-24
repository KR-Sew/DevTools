#!/usr/bin/env bash
#
# uninstall-3proxy.sh
# Completely remove a source-installed 3proxy instance from /usr/local/3proxy.
#
# Targets:
#   /usr/local/3proxy
#   /etc/systemd/system/3proxy.service
#   /usr/local/src/3proxy-*
#   /var/backups/3proxy
#
# Does NOT remove build dependency packages or package-managed 3proxy files.
#
# Usage:
#   sudo ./uninstall-3proxy.sh
#   sudo ./uninstall-3proxy.sh --force
#

set -Eeuo pipefail

INSTALL_DIR="/usr/local/3proxy"
SERVICE_NAME="3proxy"
SERVICE_FILE="/etc/systemd/system/3proxy.service"
SOURCE_ROOT="/usr/local/src"
BACKUP_DIR="/var/backups/3proxy"
FORCE=0

if [[ -t 1 ]]; then
    RED=$'\033[0;31m'
    GREEN=$'\033[0;32m'
    YELLOW=$'\033[1;33m'
    BLUE=$'\033[0;34m'
    CYAN=$'\033[0;36m'
    MAGENTA=$'\033[0;35m'
    BOLD=$'\033[1m'
    RESET=$'\033[0m'
else
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    CYAN=""
    MAGENTA=""
    BOLD=""
    RESET=""
fi

info()       { printf '%s[INFO]%s %s\n' "$CYAN" "$RESET" "$*"; }
success()    { printf '%s[ OK ]%s %s\n' "$GREEN" "$RESET" "$*"; }
warn()       { printf '%s[WARN]%s %s\n' "$YELLOW" "$RESET" "$*"; }
error()      { printf '%s[FAIL]%s %s\n' "$RED" "$RESET" "$*" >&2; }
remove_msg() { printf '%s[ DEL ]%s %s\n' "$MAGENTA" "$RESET" "$*"; }
section()    { printf '\n%s==> %s%s\n' "$BOLD$BLUE" "$*" "$RESET"; }

die() {
    error "$*"
    exit 1
}

on_error() {
    local exit_code=$?
    error "Uninstall failed at line ${BASH_LINENO[0]} with exit code ${exit_code}."
    exit "$exit_code"
}
trap on_error ERR

show_help() {
    cat <<EOF
Usage: $0 [OPTIONS]

Completely remove the source-installed 3proxy installation under:
  ${INSTALL_DIR}

Options:
  --force     Skip interactive confirmation
  -h, --help  Show this help

The script does NOT remove build dependency packages.
EOF
}

parse_args() {
    while (($#)); do
        case "$1" in
            --force) FORCE=1 ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *) die "Unknown argument: $1" ;;
        esac
        shift
    done
}

require_root() {
    [[ $EUID -eq 0 ]] || die "Run this script as root: sudo $0"
}

detect_installation() {
    section "Checking 3proxy installation"

    local found=0

    if [[ -d "$INSTALL_DIR" ]]; then
        success "Found installation directory: $INSTALL_DIR"
        found=1
    else
        warn "Installation directory not found: $INSTALL_DIR"
    fi

    if [[ -x "${INSTALL_DIR}/bin/3proxy" ]]; then
        success "Found 3proxy binary: ${INSTALL_DIR}/bin/3proxy"
        found=1
    fi

    if [[ -f "$SERVICE_FILE" ]]; then
        success "Found systemd service file: $SERVICE_FILE"
        found=1
    elif systemctl cat "$SERVICE_NAME" >/dev/null 2>&1; then
        warn "A ${SERVICE_NAME}.service exists outside ${SERVICE_FILE}."
        warn "It will be stopped/disabled, but only ${SERVICE_FILE} is deleted."
        found=1
    fi

    if find "$SOURCE_ROOT" -maxdepth 1 -mindepth 1 -type d -name '3proxy-*' -print -quit 2>/dev/null | grep -q .; then
        success "Found 3proxy source tree(s) under $SOURCE_ROOT."
        found=1
    fi

    if [[ -d "$BACKUP_DIR" ]]; then
        success "Found backup directory: $BACKUP_DIR"
        found=1
    fi

    if ((found == 0)); then
        success "No matching /usr/local/3proxy installation was found."
        exit 0
    fi
}

show_removal_plan() {
    section "Removal plan"

    printf '%sThe following matching items will be removed if they exist:%s\n' "$BOLD" "$RESET"
    printf '  - %s\n' "$INSTALL_DIR"
    printf '  - %s\n' "$SERVICE_FILE"
    printf '  - %s/3proxy-*\n' "$SOURCE_ROOT"
    printf '  - %s\n' "$BACKUP_DIR"

    printf '\n'
    warn "Build dependencies will NOT be removed."
    warn "Package-managed files such as /usr/bin/3proxy and /etc/3proxy are NOT targeted."
}

confirm_removal() {
    if ((FORCE)); then
        warn "--force specified; skipping interactive confirmation."
        return
    fi

    printf '\n%sType YES to permanently remove this 3proxy installation: %s' \
        "$BOLD$YELLOW" "$RESET"

    local answer
    read -r answer

    if [[ "$answer" != "YES" ]]; then
        warn "Removal cancelled."
        exit 0
    fi
}

stop_and_disable_service() {
    section "Stopping and disabling 3proxy"

    if systemctl cat "$SERVICE_NAME" >/dev/null 2>&1; then
        if systemctl is-active --quiet "$SERVICE_NAME"; then
            info "Stopping ${SERVICE_NAME}.service..."
            systemctl stop "$SERVICE_NAME"
            success "Service stopped."
        else
            info "${SERVICE_NAME}.service is already stopped."
        fi

        if systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
            info "Disabling ${SERVICE_NAME}.service..."
            systemctl disable "$SERVICE_NAME" >/dev/null
            success "Service disabled."
        else
            info "${SERVICE_NAME}.service is already disabled or not enabled."
        fi
    else
        info "No registered ${SERVICE_NAME}.service was found."
    fi

    local pids=""
    pids="$(pgrep -f "^${INSTALL_DIR}/bin/3proxy([[:space:]]|$)" 2>/dev/null || true)"

    if [[ -n "$pids" ]]; then
        warn "Found remaining 3proxy process(es): ${pids//$'\n'/ }"
        info "Terminating remaining process(es)..."
        kill $pids 2>/dev/null || true
        sleep 1

        pids="$(pgrep -f "^${INSTALL_DIR}/bin/3proxy([[:space:]]|$)" 2>/dev/null || true)"
        if [[ -n "$pids" ]]; then
            warn "Force-killing remaining process(es): ${pids//$'\n'/ }"
            kill -KILL $pids 2>/dev/null || true
        fi
    fi
}

remove_service_file() {
    section "Removing systemd service"

    if [[ -f "$SERVICE_FILE" ]] || [[ -L "$SERVICE_FILE" ]]; then
        remove_msg "$SERVICE_FILE"
        rm -f "$SERVICE_FILE"
        success "Systemd service file removed."
    else
        info "Service file not present: $SERVICE_FILE"
    fi

    systemctl daemon-reload
    systemctl reset-failed "$SERVICE_NAME" >/dev/null 2>&1 || true
}

remove_installation() {
    section "Removing 3proxy installation"

    if [[ -e "$INSTALL_DIR" ]]; then
        remove_msg "$INSTALL_DIR"
        rm -rf --one-file-system "$INSTALL_DIR"
        success "Installation directory removed."
    else
        info "Installation directory already absent."
    fi
}

remove_source_trees() {
    section "Removing 3proxy source trees"

    local found=0
    local dir

    while IFS= read -r -d '' dir; do
        found=1
        remove_msg "$dir"
        rm -rf --one-file-system "$dir"
    done < <(
        find "$SOURCE_ROOT" \
            -maxdepth 1 \
            -mindepth 1 \
            -type d \
            -name '3proxy-*' \
            -print0 2>/dev/null || true
    )

    if ((found)); then
        success "3proxy source trees removed."
    else
        info "No 3proxy source trees found under $SOURCE_ROOT."
    fi
}

remove_backups() {
    section "Removing 3proxy backups"

    if [[ -e "$BACKUP_DIR" ]]; then
        remove_msg "$BACKUP_DIR"
        rm -rf --one-file-system "$BACKUP_DIR"
        success "Backup directory removed."
    else
        info "No backup directory found."
    fi
}

validate_removal() {
    section "Validating removal"

    local errors=0

    if [[ -e "$INSTALL_DIR" ]]; then
        error "Still exists: $INSTALL_DIR"
        errors=1
    else
        success "Installation directory is gone."
    fi

    if [[ -e "$SERVICE_FILE" ]]; then
        error "Still exists: $SERVICE_FILE"
        errors=1
    else
        success "Custom systemd service file is gone."
    fi

    if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        error "${SERVICE_NAME}.service is still active."
        errors=1
    else
        success "3proxy service is not running."
    fi

    if pgrep -f "^${INSTALL_DIR}/bin/3proxy([[:space:]]|$)" >/dev/null 2>&1; then
        error "A process using ${INSTALL_DIR}/bin/3proxy is still running."
        errors=1
    else
        success "No process is running from ${INSTALL_DIR}/bin/3proxy."
    fi

    if ((errors)); then
        die "Removal completed with one or more validation problems."
    fi
}

print_summary() {
    section "3proxy removal completed"

    success "The /usr/local/3proxy installation has been removed completely."
    info "Dependency packages were intentionally left installed."
    info "No package-managed /usr/bin/3proxy or /etc/3proxy installation was touched."
}

main() {
    parse_args "$@"
    require_root

    section "3proxy uninstaller"

    detect_installation
    show_removal_plan
    confirm_removal
    stop_and_disable_service
    remove_service_file
    remove_installation
    remove_source_trees
    remove_backups
    validate_removal
    print_summary
}

main "$@"
