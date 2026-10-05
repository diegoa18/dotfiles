#!/bin/bash

set -uo pipefail

ROOT="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &&
    pwd -P
)"

failures=0

ok() {
    printf '[OK]   %s\n' "$1"
}

warn() {
    printf '[WARN] %s\n' "$1"
}

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    failures=$((failures + 1))
}

echo "Dotfiles preflight"
echo "Repository: $ROOT"
echo

# The installer must run as the target desktop user.
if [ "$EUID" -eq 0 ]; then
    fail "Do not run the installer as root; run it as your normal user."
else
    ok "Running as a regular user: $(id -un)"
fi

# HOME is the deployment target for GNU Stow.
if [ -z "${HOME:-}" ]; then
    fail "HOME is not defined."
elif [ "${HOME#/}" = "$HOME" ]; then
    fail "HOME is not an absolute path: $HOME"
elif [ ! -d "$HOME" ]; then
    fail "HOME does not exist: $HOME"
elif [ ! -w "$HOME" ]; then
    fail "HOME is not writable: $HOME"
else
    ok "HOME is usable: $HOME"
fi

# This repository currently targets Debian 13 (trixie).
if [ ! -r /etc/os-release ]; then
    fail "/etc/os-release is unavailable."
else
    # shellcheck disable=SC1091
    . /etc/os-release

    if [ "${ID:-}" != "debian" ]; then
        fail "Unsupported distribution: ${ID:-unknown}; Debian is required."
    else
        ok "Distribution: Debian"
    fi

    if [ "${VERSION_ID:-}" != "13" ]; then
        fail "Unsupported Debian version: ${VERSION_ID:-unknown}; Debian 13 is required."
    else
        ok "Debian version: 13"
    fi

    codename="${VERSION_CODENAME:-${DEBIAN_CODENAME:-}}"

    if [ "$codename" != "trixie" ]; then
        fail "Unsupported Debian codename: ${codename:-unknown}; trixie is required."
    else
        ok "Debian codename: trixie"
    fi
fi

# v1 is validated on amd64. Other architectures may work later, but are
# deliberately rejected until the complete dependency chain is tested.
if command -v dpkg >/dev/null 2>&1; then
    arch="$(dpkg --print-architecture)"

    if [ "$arch" = "amd64" ]; then
        ok "Architecture: amd64"
    else
        fail "Unsupported architecture: $arch; v1 currently targets amd64."
    fi
else
    fail "dpkg is unavailable."
fi

# Required bootstrap commands. Runtime desktop dependencies are installed
# later and therefore are intentionally not checked here.
for cmd in bash apt-get apt-cache dpkg grep sed awk sudo; do
    if command -v "$cmd" >/dev/null 2>&1; then
        ok "Bootstrap command available: $cmd"
    else
        fail "Required bootstrap command missing: $cmd"
    fi
done

# Validate the repository layout independently of its installation path.
for file in \
    packages/base.txt \
    packages/backports.txt \
    packages/external.txt
do
    if [ -f "$ROOT/$file" ]; then
        ok "Repository file present: $file"
    else
        fail "Repository file missing: $file"
    fi
done

# Backports is not a preflight failure. packages.sh will be responsible for
# configuring it on a clean Debian installation when necessary.
hyprland_policy="$(apt-cache policy hyprland 2>/dev/null || true)"

if [[ "$hyprland_policy" == *trixie-backports* ]]; then
    ok "APT knows about trixie-backports"
else
    warn "trixie-backports is not currently available; the installer will configure it."
fi

echo

if [ "$failures" -ne 0 ]; then
    printf 'Preflight failed with %d error(s).\n' "$failures" >&2
    exit 1
fi

echo "Preflight passed."
