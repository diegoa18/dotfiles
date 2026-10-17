#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &&
    pwd -P
)"

. "$SCRIPT_DIR/lib/common.sh"

STOW_DIR="$DOTFILES_ROOT/home"

STOW_PACKAGES=(
    bat
    dunst
    ghostty
    git
    hypr
    nautilus
    opencode
    quickshell
    rofi
    scripts
    waybar
    xdg
    zed
    zsh
)

main() {
    local package

    "$DOTFILES_ROOT/install/preflight.sh"

    command -v stow >/dev/null 2>&1 ||
        die "GNU Stow is not installed; run install/packages.sh first"

    [ -d "$STOW_DIR" ] ||
        die "Stow package directory not found: $STOW_DIR"

    for package in "${STOW_PACKAGES[@]}"; do
        [ -d "$STOW_DIR/$package" ] ||
            die "Stow package missing: $package"
    done

    mkdir -p \
        "$HOME/.config" \
        "$HOME/.local/bin"

    log "Checking Stow deployment for conflicts"

    if ! stow \
        --simulate \
        --restow \
        --no-folding \
        --dir="$STOW_DIR" \
        --target="$HOME" \
        "${STOW_PACKAGES[@]}"
    then
        die "Stow detected a conflict; existing files were left untouched"
    fi

    log "Deploying user configuration"

    stow \
        --restow \
        --no-folding \
        --dir="$STOW_DIR" \
        --target="$HOME" \
        "${STOW_PACKAGES[@]}"

    log "Restoring Nautilus configuration"
    if [ -r "$STOW_DIR/nautilus/nautilus-settings.ini" ]; then
        dconf load /org/gnome/nautilus/ < "$STOW_DIR/nautilus/nautilus-settings.ini" || true
    fi

    log "User configuration deployment complete"
}

main "$@"
