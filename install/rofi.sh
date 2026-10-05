#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &&
    pwd -P
)"

# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

ROFI_REPO="https://github.com/lbonn/rofi.git"
ROFI_TAG="1.7.9+wayland1"
ROFI_REV="07955bf9b37cb149d8d6f51ccf831f3444140087"
ROFI_VERSION="1.7.9+wayland1"

PREFIX="$HOME/.local"
ROFI_BIN="$PREFIX/bin/rofi"
MARKER="$PREFIX/share/dotfiles/rofi-build"
WORK=""



cleanup() {
    if [ -n "$WORK" ] && [ -d "$WORK" ]; then
        rm -rf -- "$WORK"
    fi
}


expected_marker() {
    cat <<EOF_MARKER
repository=$ROFI_REPO
tag=$ROFI_TAG
revision=$ROFI_REV
version=$ROFI_VERSION
wayland=enabled
xcb=disabled
imdkit=false
EOF_MARKER
}

installation_is_current() {
    local version
    local marker

    [ -x "$ROFI_BIN" ] || return 1
    [ -r "$MARKER" ] || return 1

    version="$("$ROFI_BIN" -v 2>/dev/null || true)"
    [ "$version" = "Version: $ROFI_VERSION" ] || return 1

    marker="$(cat "$MARKER")"
    [ "$marker" = "$(expected_marker)" ]
}

main() {
    local -a build_packages
    local src
    local build
    local stage
    local staged_prefix
    local staged_rofi
    local actual_rev
    local version

    "$DOTFILES_ROOT/install/preflight.sh"

    if installation_is_current; then
        log "Rofi $ROFI_VERSION is already installed"
        exit 0
    fi

    mapfile -t build_packages < <(
        manifest_packages "$DOTFILES_ROOT/packages/build-rofi.txt"
    )

    [ "${#build_packages[@]}" -gt 0 ] ||
        die "packages/build-rofi.txt contains no packages"

    log "Installing Rofi build dependencies"
    sudo apt-get install -y "${build_packages[@]}"

    WORK="$(mktemp -d)"
    trap cleanup EXIT

    src="$WORK/src"
    build="$WORK/build"
    stage="$WORK/stage"

    log "Cloning Rofi $ROFI_TAG"

    git clone \
        --quiet \
        --depth 1 \
        --branch "$ROFI_TAG" \
        --recurse-submodules \
        --shallow-submodules \
        "$ROFI_REPO" \
        "$src"

    actual_rev="$(git -C "$src" rev-parse HEAD)"

    [ "$actual_rev" = "$ROFI_REV" ] ||
        die "Rofi tag resolved to unexpected revision: $actual_rev"

    log "Configuring Wayland-only Rofi build"

    meson setup \
        "$build" \
        "$src" \
        --prefix="$PREFIX" \
        -Dwayland=enabled \
        -Dxcb=disabled \
        -Dcheck=disabled \
        -Dimdkit=false

    log "Building Rofi"
    meson compile -C "$build"

    log "Staging Rofi installation"
    DESTDIR="$stage" meson install -C "$build"

    staged_prefix="$stage$PREFIX"
    staged_rofi="$staged_prefix/bin/rofi"

    [ -x "$staged_rofi" ] ||
        die "Staged Rofi binary was not created"

    version="$("$staged_rofi" -v 2>/dev/null || true)"

    [ "$version" = "Version: $ROFI_VERSION" ] ||
        die "Unexpected staged Rofi version: $version"

    log "Installing Rofi into $PREFIX"

    mkdir -p "$PREFIX"
    cp -a "$staged_prefix/." "$PREFIX/"

    mkdir -p "$(dirname "$MARKER")"
    expected_marker > "$MARKER"

    version="$("$ROFI_BIN" -v 2>/dev/null || true)"

    [ "$version" = "Version: $ROFI_VERSION" ] ||
        die "Installed Rofi failed verification"

    log "Rofi installation complete"
    printf '%s\n' "$version"
}

main "$@"
