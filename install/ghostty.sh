#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &&
    pwd -P
)"

# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

GHOSTTY_VERSION="1.3.1"
ZIG_VERSION="0.15.2"

GHOSTTY_ARCHIVE="ghostty-${GHOSTTY_VERSION}.tar.gz"
ZIG_ARCHIVE="zig-x86_64-linux-${ZIG_VERSION}.tar.xz"

GHOSTTY_URL="https://release.files.ghostty.org/${GHOSTTY_VERSION}/${GHOSTTY_ARCHIVE}"
ZIG_URL="https://ziglang.org/download/${ZIG_VERSION}/${ZIG_ARCHIVE}"

GHOSTTY_MINISIGN_KEY="RWQlAjJC23149WL2sEpT/l0QKy7hMIFhYdQOFy0Z7z7PbneUgvlsnYcV"
ZIG_MINISIGN_KEY="RWSGOq2NVecA2UPNdBUZykf1CCb147pkmdtYxgb3Ti+JO/wCYvhbAb/U"

PREFIX="$HOME/.local"
GHOSTTY_BIN="$PREFIX/bin/ghostty"
MARKER="$PREFIX/share/dotfiles/ghostty-build"

CACHE_ROOT="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/ghostty/$GHOSTTY_VERSION"
DOWNLOAD_DIR="$CACHE_ROOT/downloads"
ZIG_CACHE="$CACHE_ROOT/zig-$ZIG_VERSION"

WORK=""

cleanup() {
    if [ -n "$WORK" ] && [ -d "$WORK" ]; then
        rm -rf -- "$WORK"
    fi
}

expected_marker() {
    cat <<EOF_MARKER
ghostty_version=$GHOSTTY_VERSION
ghostty_source=$GHOSTTY_URL
zig_version=$ZIG_VERSION
zig_source=$ZIG_URL
build_mode=ReleaseFast
cpu=baseline
prefix=$PREFIX
EOF_MARKER
}

installation_is_current() {
    local version
    local marker

    [ -x "$GHOSTTY_BIN" ] || return 1
    [ -r "$MARKER" ] || return 1
    [ -d "$PREFIX/share/ghostty" ] || return 1

    if [ ! -r "$PREFIX/share/terminfo/g/ghostty" ] &&
       [ ! -r "$PREFIX/share/terminfo/x/xterm-ghostty" ]; then
        return 1
    fi

    version="$(
        "$GHOSTTY_BIN" --version 2>/dev/null |
            sed -n '1p' ||
            true
    )"

    [ "$version" = "Ghostty $GHOSTTY_VERSION" ] || return 1

    marker="$(cat "$MARKER")"
    [ "$marker" = "$(expected_marker)" ]
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

verify_signed_artifact() {
    local artifact="$1"
    local signature="$2"
    local public_key="$3"
    local expected_name="$4"
    local trusted_name

    minisign \
        -Vm "$artifact" \
        -x "$signature" \
        -P "$public_key" \
        >/dev/null 2>&1 ||
        return 1

    trusted_name="$(
        sed -n \
            's/^trusted comment:.*file:\([^[:space:]]*\).*/\1/p' \
            "$signature"
    )"

    [ "$trusted_name" = "$expected_name" ]
}

fetch_signed_artifact() {
    local url="$1"
    local archive="$2"
    local public_key="$3"
    local artifact="$DOWNLOAD_DIR/$archive"
    local signature="$DOWNLOAD_DIR/${archive}.minisig"
    local attempt

    for attempt in 1 2; do
        download "$url" "$artifact"
        download "${url}.minisig" "$signature"

        if verify_signed_artifact \
            "$artifact" \
            "$signature" \
            "$public_key" \
            "$archive"
        then
            return 0
        fi

        rm -f -- "$artifact" "$signature"
    done

    die "Signature verification failed for $archive"
}

fetch_ghostty_dependencies() {
    local src="$1"
    local zig="$2"
    local manifest="$src/build.zig.zon.txt"
    local url
    local attempt
    local fetched

    [ -r "$manifest" ] ||
        die "Ghostty dependency manifest not found: $manifest"

    while IFS= read -r url || [ -n "$url" ]; do
        [ -n "$url" ] || continue

        fetched=0
        printf 'Fetching dependency: %s\n' "$url"

        for ((attempt = 1; attempt <= 5; attempt++)); do
            if env \
                ZIG_GLOBAL_CACHE_DIR="$ZIG_CACHE" \
                "$zig" fetch "$url" \
                >/dev/null
            then
                fetched=1
                break
            fi

            if [ "$attempt" -lt 5 ]; then
                printf \
                    'Retrying dependency fetch (%d/5)...\n' \
                    "$((attempt + 1))" \
                    >&2

                sleep "$((attempt * 2))"
            fi
        done

        [ "$fetched" -eq 1 ] ||
            die "Failed to fetch Ghostty dependency: $url"
    done < "$manifest"
}

main() {
    local -a build_packages
    local src
    local stage
    local staged_prefix
    local staged_ghostty
    local zig_dir
    local zig
    local local_cache
    local source_version
    local zig_version
    local version
    local ldd_output

    "$DOTFILES_ROOT/install/preflight.sh"

    if installation_is_current; then
        log "Ghostty $GHOSTTY_VERSION is already installed"
        exit 0
    fi

    mapfile -t build_packages < <(
        manifest_packages "$DOTFILES_ROOT/packages/build-ghostty.txt"
    )

    [ "${#build_packages[@]}" -gt 0 ] ||
        die "packages/build-ghostty.txt contains no packages"

    log "Installing Ghostty build dependencies"
    sudo apt-get install -y "${build_packages[@]}"

    mkdir -p "$DOWNLOAD_DIR" "$ZIG_CACHE"

    log "Fetching and verifying Zig $ZIG_VERSION"
    fetch_signed_artifact \
        "$ZIG_URL" \
        "$ZIG_ARCHIVE" \
        "$ZIG_MINISIGN_KEY"

    log "Fetching and verifying Ghostty $GHOSTTY_VERSION"
    fetch_signed_artifact \
        "$GHOSTTY_URL" \
        "$GHOSTTY_ARCHIVE" \
        "$GHOSTTY_MINISIGN_KEY"

    WORK="$(mktemp -d)"
    trap cleanup EXIT

    src="$WORK/src"
    stage="$WORK/stage"
    local_cache="$WORK/zig-local-cache"

    mkdir -p "$src" "$stage" "$local_cache"

    tar \
        -C "$WORK" \
        -xf "$DOWNLOAD_DIR/$ZIG_ARCHIVE"

    zig_dir="$WORK/zig-x86_64-linux-${ZIG_VERSION}"
    zig="$zig_dir/zig"

    [ -x "$zig" ] ||
        die "Zig executable was not extracted"

    zig_version="$("$zig" version)"

    [ "$zig_version" = "$ZIG_VERSION" ] ||
        die "Unexpected Zig version: $zig_version"

    tar \
        -C "$src" \
        --strip-components=1 \
        -xf "$DOWNLOAD_DIR/$GHOSTTY_ARCHIVE"

    [ -r "$src/VERSION" ] ||
        die "Ghostty VERSION file is missing"

    source_version="$(tr -d '\r\n' < "$src/VERSION")"

    [ "$source_version" = "$GHOSTTY_VERSION" ] ||
        die "Unexpected Ghostty source version: $source_version"

    grep -Fq \
        ".minimum_zig_version = \"$ZIG_VERSION\"" \
        "$src/build.zig.zon" ||
        die "Ghostty source does not declare Zig $ZIG_VERSION"

    log "Fetching Ghostty dependency cache"
    fetch_ghostty_dependencies "$src" "$zig"

    log "Building Ghostty $GHOSTTY_VERSION"

    (
        cd "$src"

        DESTDIR="$stage" \
        ZIG_GLOBAL_CACHE_DIR="$ZIG_CACHE" \
        ZIG_LOCAL_CACHE_DIR="$local_cache" \
            "$zig" build \
                --prefix "$PREFIX" \
                -Doptimize=ReleaseFast \
                -Dcpu=baseline \
                -Dversion-string="$GHOSTTY_VERSION"
    )

    staged_prefix="$stage$PREFIX"
    staged_ghostty="$staged_prefix/bin/ghostty"

    [ -x "$staged_ghostty" ] ||
        die "Staged Ghostty binary was not created"

    version="$(
        "$staged_ghostty" --version 2>/dev/null |
            sed -n '1p' ||
            true
    )"

    [ "$version" = "Ghostty $GHOSTTY_VERSION" ] ||
        die "Unexpected staged Ghostty version: $version"

    ldd_output="$(ldd "$staged_ghostty" 2>&1)" ||
        die "Unable to inspect staged Ghostty dynamic dependencies"

    if grep -q 'not found' <<<"$ldd_output"; then
        printf '%s\n' "$ldd_output" >&2
        die "Staged Ghostty has unresolved dynamic dependencies"
    fi

    log "Installing Ghostty into $PREFIX"

    mkdir -p "$PREFIX"
    cp -a "$staged_prefix/." "$PREFIX/"

    mkdir -p "$(dirname "$MARKER")"
    expected_marker > "$MARKER"

    if ! installation_is_current; then
        die "Installed Ghostty failed verification"
    fi

    log "Ghostty installation complete"
    "$GHOSTTY_BIN" --version
}

main "$@"
