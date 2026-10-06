#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &&
    pwd -P
)"

# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

BACKPORTS_SOURCE="/etc/apt/sources.list.d/dotfiles-backports.sources"




backports_configured() {
    grep -RqsE \
        '(^|[[:space:]/])trixie-backports([[:space:]/]|$)' \
        /etc/apt/sources.list \
        /etc/apt/sources.list.d \
        2>/dev/null
}

configure_backports() {
    local tmp

    if backports_configured; then
        log "trixie-backports is already configured"
        return
    fi

    log "Configuring trixie-backports"

    tmp="$(mktemp)"

    trap 'rm -f "$tmp"' RETURN

    cat > "$tmp" <<'SOURCES'
Types: deb
URIs: http://deb.debian.org/debian
Suites: trixie-backports
Components: main
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
SOURCES

    sudo install \
        -D \
        -m 0644 \
        "$tmp" \
        "$BACKPORTS_SOURCE"

    rm -f "$tmp"
    trap - RETURN
}

main() {
    local -a base_packages
    local -a backports_packages

    "$DOTFILES_ROOT/install/preflight.sh"

    mapfile -t base_packages < <(
        manifest_packages "$DOTFILES_ROOT/packages/base.txt"
    )

    mapfile -t backports_packages < <(
        manifest_packages "$DOTFILES_ROOT/packages/backports.txt"
    )

    [ "${#base_packages[@]}" -gt 0 ] ||
        die "packages/base.txt contains no packages"

    [ "${#backports_packages[@]}" -gt 0 ] ||
        die "packages/backports.txt contains no packages"

    configure_backports

    log "Updating APT package metadata"
    sudo apt-get update

    log "Installing Debian runtime packages"
    sudo apt-get install -y \
        "${base_packages[@]}"

    log "Installing trixie-backports desktop packages"
    sudo apt-get install -y \
        -t trixie-backports \
        "${backports_packages[@]}"

    "$DOTFILES_ROOT/install/locales.sh"

    log "Package installation complete"
}

main "$@"
