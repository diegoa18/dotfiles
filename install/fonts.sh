#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &&
    pwd -P
)"

# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

NERD_FONTS_VERSION="3.5.1"

ARCHIVE="NerdFontsSymbolsOnly.tar.xz"
URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v${NERD_FONTS_VERSION}/${ARCHIVE}"
SHA256="01172f37db8543edb102e5cb5c64101c9f4686630804d49b419aa07b23a69996"

FONT_DIR="$HOME/.local/share/fonts/nerd-fonts-symbols"
REGULAR_FONT="$FONT_DIR/SymbolsNerdFont-Regular.ttf"
MONO_FONT="$FONT_DIR/SymbolsNerdFontMono-Regular.ttf"

MARKER="$HOME/.local/share/dotfiles/nerd-fonts-symbols"

CACHE_ROOT="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/nerd-fonts/$NERD_FONTS_VERSION"
DOWNLOAD_DIR="$CACHE_ROOT/downloads"
ARTIFACT="$DOWNLOAD_DIR/$ARCHIVE"

WORK=""

cleanup() {
    if [ -n "$WORK" ] && [ -d "$WORK" ]; then
        rm -rf -- "$WORK"
    fi
}

expected_marker() {
    cat <<EOF_MARKER
version=$NERD_FONTS_VERSION
source=$URL
sha256=$SHA256
font_dir=$FONT_DIR
EOF_MARKER
}

font_family() {
    local file="$1"

    fc-query \
        --format '%{family[0]}\n' \
        "$file" \
        2>/dev/null |
        sed -n '1p'
}

glyph_is_available() {
    local codepoint="$1"

    fc-list \
        ":family=Symbols Nerd Font:charset=$codepoint" \
        -f '%{file}\n' \
        2>/dev/null |
        grep -q .
}

installation_is_current() {
    local marker

    command -v fc-query >/dev/null 2>&1 || return 1
    command -v fc-list >/dev/null 2>&1 || return 1

    [ -r "$REGULAR_FONT" ] || return 1
    [ -r "$MONO_FONT" ] || return 1
    [ -r "$MARKER" ] || return 1

    [ "$(font_family "$REGULAR_FONT")" = "Symbols Nerd Font" ] ||
        return 1

    [ "$(font_family "$MONO_FONT")" = "Symbols Nerd Font Mono" ] ||
        return 1

    marker="$(cat "$MARKER")"
    [ "$marker" = "$(expected_marker)" ] || return 1

    # Glyphs currently required by the desktop configuration.
    glyph_is_available F075F || return 1
    glyph_is_available F0200 || return 1
    glyph_is_available F05AA || return 1
}

download() {
    local url="$1"
    local destination="$2"
    local partial="${destination}.part"

    if [ -s "$destination" ]; then
        return 0
    fi

    rm -f -- "$partial"

    curl \
        --fail \
        --location \
        --proto '=https' \
        --tlsv1.2 \
        --retry 5 \
        --retry-all-errors \
        --retry-delay 2 \
        --connect-timeout 20 \
        --output "$partial" \
        "$url"

    mv -- "$partial" "$destination"
}

artifact_is_valid() {
    local actual

    [ -s "$ARTIFACT" ] || return 1

    actual="$(
        sha256sum "$ARTIFACT" |
            awk '{print $1}'
    )"

    [ "$actual" = "$SHA256" ]
}

fetch_artifact() {
    local attempt

    mkdir -p "$DOWNLOAD_DIR"

    for attempt in 1 2; do
        log "Checking font artifact (attempt $attempt/2)"
        download "$URL" "$ARTIFACT"

        if artifact_is_valid; then
            return 0
        fi

        rm -f -- "$ARTIFACT"
    done

    die "SHA-256 verification failed for $ARCHIVE"
}

verify_installed_fonts() {
    local codepoint

    [ -r "$REGULAR_FONT" ] ||
        die "Regular Symbols Nerd Font was not installed"

    [ -r "$MONO_FONT" ] ||
        die "Mono Symbols Nerd Font was not installed"

    [ "$(font_family "$REGULAR_FONT")" = "Symbols Nerd Font" ] ||
        die "Unexpected regular font family"

    [ "$(font_family "$MONO_FONT")" = "Symbols Nerd Font Mono" ] ||
        die "Unexpected mono font family"

    for codepoint in F075F F0200 F05AA; do
        glyph_is_available "$codepoint" ||
            die "Symbols Nerd Font does not provide U+$codepoint"
    done
}

main() {
    local -a install_packages
    local regular_source
    local mono_source
    local regular_count
    local mono_count

    "$DOTFILES_ROOT/install/preflight.sh"

    if installation_is_current; then
        log "Nerd Fonts Symbols Only $NERD_FONTS_VERSION is already installed"
        exit 0
    fi

    mapfile -t install_packages < <(
        manifest_packages "$DOTFILES_ROOT/packages/install-fonts.txt"
    )

    [ "${#install_packages[@]}" -gt 0 ] ||
        die "packages/install-fonts.txt contains no packages"

    log "Installing font deployment dependencies"
    sudo apt-get install -y "${install_packages[@]}"

    fetch_artifact

    WORK="$(mktemp -d)"
    trap cleanup EXIT

    log "Extracting Nerd Fonts Symbols Only $NERD_FONTS_VERSION"

    tar \
        -xJf "$ARTIFACT" \
        -C "$WORK"

    regular_count="$(
        find "$WORK" \
            -type f \
            -name 'SymbolsNerdFont-Regular.ttf' \
            -printf '.' |
            wc -c
    )"

    mono_count="$(
        find "$WORK" \
            -type f \
            -name 'SymbolsNerdFontMono-Regular.ttf' \
            -printf '.' |
            wc -c
    )"

    [ "$regular_count" -eq 1 ] ||
        die "Expected exactly one SymbolsNerdFont-Regular.ttf"

    [ "$mono_count" -eq 1 ] ||
        die "Expected exactly one SymbolsNerdFontMono-Regular.ttf"

    regular_source="$(
        find "$WORK" \
            -type f \
            -name 'SymbolsNerdFont-Regular.ttf' \
            -print
    )"

    mono_source="$(
        find "$WORK" \
            -type f \
            -name 'SymbolsNerdFontMono-Regular.ttf' \
            -print
    )"

    [ "$(font_family "$regular_source")" = "Symbols Nerd Font" ] ||
        die "Archive contains an unexpected regular font"

    [ "$(font_family "$mono_source")" = "Symbols Nerd Font Mono" ] ||
        die "Archive contains an unexpected mono font"

    log "Installing Nerd Fonts Symbols Only into $FONT_DIR"

    rm -rf -- "$FONT_DIR"
    mkdir -p "$FONT_DIR"

    install \
        -m 0644 \
        "$regular_source" \
        "$REGULAR_FONT"

    install \
        -m 0644 \
        "$mono_source" \
        "$MONO_FONT"

    log "Refreshing user font cache"
    fc-cache -f "$FONT_DIR"

    verify_installed_fonts

    mkdir -p "$(dirname "$MARKER")"
    expected_marker > "$MARKER"

    installation_is_current ||
        die "Installed Nerd Fonts Symbols Only failed verification"

    log "Nerd Fonts Symbols Only installation complete"

    fc-match \
        -f '%{family[0]} | %{file}\n' \
        "Symbols Nerd Font"
}

main "$@"
