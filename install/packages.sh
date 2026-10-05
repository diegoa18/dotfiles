#!/bin/bash

set -euo pipefail

ROOT="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &&
    pwd -P
)"

BACKPORTS_SOURCE="/etc/apt/sources.list.d/dotfiles-backports.sources"

log() {
    printf '\n==> %s\n' "$1"
}

die() {
    printf 'ERROR: %s\n' "$1" >&2
    exit 1
}

manifest_packages() {
    local manifest="$1"
    local line

    [ -r "$manifest" ] ||
        die "Manifest not readable: $manifest"

    while IFS= read -r line || [ -n "$line" ]; do
        # Remove comments.
        line="${line%%#*}"

        # Trim leading whitespace.
        line="${line#"${line%%[![:space:]]*}"}"

        # Trim trailing whitespace.
        line="${line%"${line##*[![:space:]]}"}"

        [ -n "$line" ] || continue

        printf '%s\n' "$line"
    done < "$manifest"
}

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

    "$ROOT/install/preflight.sh"

    mapfile -t base_packages < <(
        manifest_packages "$ROOT/packages/base.txt"
    )

    mapfile -t backports_packages < <(
        manifest_packages "$ROOT/packages/backports.txt"
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

    log "Package installation complete"
}

main "$@"
