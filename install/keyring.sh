#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &&
    pwd -P
)"

# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

main() {
    "$DOTFILES_ROOT/install/preflight.sh"

    [ "$(dpkg-query -W -f='${Status}' libpam-gnome-keyring 2>/dev/null)" = "install ok installed" ] ||
        die "Install libpam-gnome-keyring before configuring the keyring"

    log "Configuring GNOME Keyring unlock for greetd"

    sudo /usr/bin/python3 - /etc/pam.d/greetd <<'PY'
import os
from pathlib import Path
import re
import stat
import sys
import tempfile

path = Path(sys.argv[1])
info = path.lstat()
if not stat.S_ISREG(info.st_mode) or info.st_uid != 0 or info.st_mode & 0o022:
    raise SystemExit("Unexpected greetd PAM file ownership or permissions; nothing was changed.")
text = path.read_text(encoding="utf-8")
lines = text.splitlines()

for kind, include, suffix in (("auth", "common-auth", ""), ("session", "common-session", " auto_start")):
    existing = [index for index, line in enumerate(lines)
                if re.match(r"^\s*-?" + kind + r"\s+\S+\s+pam_gnome_keyring\.so(?:\s|$)", line)]
    if existing:
        if kind == "session" and not all("auto_start" in lines[index].split() for index in existing):
            raise SystemExit("An existing keyring session rule lacks auto_start; nothing was changed.")
        continue
    anchors = [index for index, line in enumerate(lines)
               if re.fullmatch(r"\s*@include\s+" + include + r"\s*(?:#.*)?", line)]
    if len(anchors) != 1:
        raise SystemExit("Unexpected greetd PAM include layout; nothing was changed.")
    lines.insert(anchors[0] + 1, kind + " optional pam_gnome_keyring.so" + suffix)

updated = "\n".join(lines) + "\n"
if updated == text:
    print("greetd keyring integration is already configured.")
    raise SystemExit(0)

backup = path.with_name("greetd.dotfiles-before-keyring")
try:
    descriptor = os.open(backup, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
except FileExistsError:
    pass
else:
    with os.fdopen(descriptor, "w", encoding="utf-8") as stream:
        stream.write(text)

descriptor, temporary = tempfile.mkstemp(prefix=".greetd-keyring-", dir=path.parent)
try:
    with os.fdopen(descriptor, "w", encoding="utf-8") as stream:
        os.fchmod(stream.fileno(), stat.S_IMODE(info.st_mode))
        os.fchown(stream.fileno(), info.st_uid, info.st_gid)
        stream.write(updated)
        stream.flush()
        os.fsync(stream.fileno())
    os.replace(temporary, path)
finally:
    if os.path.exists(temporary):
        os.unlink(temporary)
print("greetd keyring integration configured; the current session was left running.")
PY
}

main "$@"
