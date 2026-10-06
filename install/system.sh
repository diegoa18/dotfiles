#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &&
    pwd -P
)"

# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

GREETD_CONFIG_SOURCE="$DOTFILES_ROOT/system/greetd/config.toml"
GREETD_CONFIG_TARGET="/etc/greetd/config.toml"
DEFAULT_X_DISPLAY_MANAGER="/etc/X11/default-display-manager"

main() {
    local greetd_unit
    local display_manager_unit

    "$DOTFILES_ROOT/install/preflight.sh"

    [ -r "$GREETD_CONFIG_SOURCE" ] ||
        die "Missing greetd configuration: $GREETD_CONFIG_SOURCE"

    [ -x /usr/bin/tuigreet ] ||
        die "tuigreet is not installed at /usr/bin/tuigreet"

    [ -x /usr/bin/start-hyprland ] ||
        die "start-hyprland is not installed at /usr/bin/start-hyprland"

    systemctl cat greetd.service >/dev/null 2>&1 ||
        die "greetd.service is not installed"

    log "Installing greetd configuration"

    sudo install \
        -D \
        -o root \
        -g root \
        -m 0644 \
        "$GREETD_CONFIG_SOURCE" \
        "$GREETD_CONFIG_TARGET"

    if [ -e "$DEFAULT_X_DISPLAY_MANAGER" ] ||
       [ -L "$DEFAULT_X_DISPLAY_MANAGER" ]; then
        log "Removing obsolete X display-manager selection"
        sudo rm -f -- "$DEFAULT_X_DISPLAY_MANAGER"
    fi

    log "Setting graphical.target as the default target"
    sudo systemctl set-default graphical.target

    log "Enabling greetd as the display manager"
    sudo systemctl enable --force greetd.service

    cmp -s \
        "$GREETD_CONFIG_SOURCE" \
        "$GREETD_CONFIG_TARGET" ||
        die "Installed greetd configuration differs from repository"

    [ "$(systemctl get-default)" = "graphical.target" ] ||
        die "graphical.target is not the default target"

    greetd_unit="$(
        systemctl show \
            -p FragmentPath \
            --value \
            greetd.service
    )"

    display_manager_unit="$(
        readlink -f \
            /etc/systemd/system/display-manager.service \
            2>/dev/null ||
            true
    )"

    [ -n "$greetd_unit" ] ||
        die "Unable to determine greetd.service unit path"

    [ "$display_manager_unit" = "$greetd_unit" ] ||
        die "display-manager.service does not point to greetd.service"

    systemctl is-enabled --quiet greetd.service ||
        die "greetd.service is not enabled"

    log "System configuration complete"
    printf 'display manager: %s\n' "$display_manager_unit"
    printf 'default target: %s\n' "$(systemctl get-default)"
}

main "$@"
