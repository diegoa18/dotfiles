# shellcheck shell=bash

# Shared helpers for dotfiles installation scripts.
#
# This file is sourced by scripts under install/. It intentionally does not
# change shell options; each executable script owns its execution policy.

# Used by scripts that source this library.
# shellcheck disable=SC2034
DOTFILES_ROOT="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." &&
    pwd -P
)"

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
        line="${line%%#*}"
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"

        [ -n "$line" ] || continue

        printf '%s\n' "$line"
    done < "$manifest"
}
