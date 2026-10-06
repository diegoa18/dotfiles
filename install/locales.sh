#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &&
    pwd -P
)"

# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

DESKTOP_LOCALE="es_CL.UTF-8"
LOCALE_CONFIG="/etc/locale.gen"

locale_is_selected() {
    awk -v name="$DESKTOP_LOCALE" '
        $1 == name && $2 == "UTF-8" { found = 1 }
        END { exit !found }
    ' "$LOCALE_CONFIG"
}

locale_is_available() {
    LC_ALL=C locale -a |
        awk '
            /^es_CL[.](utf8|UTF-8)$/ { found = 1 }
            END { exit !found }
        '
}

main() {
    "$DOTFILES_ROOT/install/preflight.sh"

    [ -x /usr/sbin/locale-gen ] ||
        die "locale-gen is missing; run install/packages.sh first"

    [ -r "$LOCALE_CONFIG" ] ||
        die "$LOCALE_CONFIG is missing"

    if ! locale_is_selected; then
        log "Selecting $DESKTOP_LOCALE for generation"

        printf '\n%s UTF-8\n' "$DESKTOP_LOCALE" |
            sudo tee -a "$LOCALE_CONFIG" >/dev/null
    fi

    locale_is_selected ||
        die "$DESKTOP_LOCALE was not selected in $LOCALE_CONFIG"

    if locale_is_available; then
        log "Locale $DESKTOP_LOCALE is selected and already available"
        return
    fi

    log "Generating selected locales"
    sudo /usr/sbin/locale-gen --keep-existing

    locale_is_available ||
        die "Locale $DESKTOP_LOCALE is still unavailable"

    [ "$(LC_ALL="$DESKTOP_LOCALE" locale charmap)" = "UTF-8" ] ||
        die "Locale $DESKTOP_LOCALE does not use UTF-8"

    log "Locale $DESKTOP_LOCALE is ready"
}

main "$@"
