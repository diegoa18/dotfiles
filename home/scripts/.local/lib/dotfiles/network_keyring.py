"""GNOME Keyring access for personal NetworkManager Wi-Fi credentials."""

import os
from pathlib import Path
import re
import resource
import stat
import uuid

import gi

gi.require_version("Secret", "1")
from gi.repository import Gio, GLib, Secret


AGENT_NAME = "io.github.diegoa18.Dotfiles.NetworkKeyring"
AGENT_PATH = "/io/github/diegoa18/Dotfiles/NetworkKeyring"
SETTING = "802-11-wireless-security"
SCHEMA = Secret.Schema.new(
    "org.freedesktop.NetworkManager.Connection", Secret.SchemaFlags.DONT_MATCH_NAME,
    {name: Secret.SchemaAttributeType.STRING for name in
     ("connection-uuid", "setting-name", "setting-key")},
)


class KeyringError(Exception):
    """A fixed, non-sensitive message that is safe to display."""


def protect_process():
    os.umask(0o077)
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    # Never enable library traces in a process that handles credentials.
    for name in ("LIBNM_CLIENT_DEBUG", "G_MESSAGES_DEBUG", "G_DBUS_DEBUG", "LIBSECRET_DEBUG"):
        os.environ.pop(name, None)


def attributes(connection_uuid):
    try:
        if str(uuid.UUID(connection_uuid)) != connection_uuid.lower():
            raise ValueError
    except (ValueError, TypeError, AttributeError):
        raise KeyringError("Invalid connection identifier.") from None
    return {"connection-uuid": connection_uuid, "setting-name": SETTING, "setting-key": "psk"}


def verify_encrypted_collection(collection_path):
    """Reject GNOME's plaintext keyring format and unsafe file permissions.

    GNOME encodes collection identifiers as alphanumeric bytes or _xx.
    A nonempty master password produces its encrypted binary file format.
    """
    prefix = "/org/freedesktop/secrets/collection/"
    if not collection_path.startswith(prefix):
        raise KeyringError("A password-protected GNOME keyring is required.")
    encoded = collection_path[len(prefix):]
    if not re.fullmatch(r"(?:[A-Za-z0-9]|_[0-9a-fA-F]{2})+", encoded):
        raise KeyringError("Unsupported keyring identifier.")
    raw = bytearray()
    while encoded:
        if encoded[0] == "_":
            raw.append(int(encoded[1:3], 16))
            encoded = encoded[3:]
        else:
            raw.append(ord(encoded[0]))
            encoded = encoded[1:]
    try:
        name = raw.decode("utf-8")
    except UnicodeError:
        raise KeyringError("Unsupported keyring identifier.") from None
    if name in (".", "..") or "/" in name or "\0" in name:
        raise KeyringError("Unsupported keyring identifier.")
    data_dir = Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local/share")
    try:
        descriptor = os.open(data_dir / "keyrings" / (name + ".keyring"),
                             os.O_RDONLY | os.O_NOFOLLOW | os.O_CLOEXEC)
        with os.fdopen(descriptor, "rb") as stream:
            info = os.fstat(stream.fileno())
            if (not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid()
                    or info.st_mode & 0o077):
                raise KeyringError("The keyring file must be private to your user.")
            if stream.read(16) != b"GnomeKeyring\n\r\0\n":
                raise KeyringError("The keyring is not encrypted. Set a nonempty keyring password in Passwords and Keys.")
    except OSError:
        raise KeyringError("Create a password-protected keyring in Passwords and Keys first.") from None


class Keyring:
    def collection(self, callback, cancellable, allow_unlock=True):
        def fail():
            callback(None, KeyringError("Could not unlock the keyring. Open Passwords and Keys and try again."))

        def unlocked(service, result, collection):
            try:
                service.unlock_finish(result)
                collection.refresh()
                if collection.get_locked():
                    raise KeyringError("Unlock the keyring before connecting.")
                verify_encrypted_collection(collection.get_object_path())
                callback(collection, None)
            except KeyringError as error:
                callback(None, error)
            except GLib.Error:
                fail()

        def found(_source, result, service):
            try:
                collection = Secret.Collection.for_alias_finish(result)
                if collection is None:
                    raise KeyringError("Create a password-protected default keyring in Passwords and Keys first.")
                verify_encrypted_collection(collection.get_object_path())
                if collection.get_locked():
                    if not allow_unlock:
                        raise KeyringError("The keyring is locked.")
                    service.unlock([collection], cancellable, unlocked, collection)
                else:
                    callback(collection, None)
            except KeyringError as error:
                callback(None, error)
            except GLib.Error:
                fail()

        def ready(_source, result, _data):
            try:
                service = Secret.Service.get_finish(result)
                Secret.Collection.for_alias(service, "default", Secret.CollectionFlags.NONE,
                                            cancellable, found, service)
            except GLib.Error:
                fail()

        Secret.Service.get(Secret.ServiceFlags.OPEN_SESSION, cancellable, ready, None)

    def store(self, connection_uuid, password, callback, cancellable):
        tags = attributes(connection_uuid)

        def stored(_source, result, collection):
            try:
                if not Secret.password_store_finish(result):
                    raise KeyringError("The password could not be saved in the keyring.")
                verify_encrypted_collection(collection.get_object_path())
                callback(None)
            except KeyringError as error:
                callback(error)
            except GLib.Error:
                callback(KeyringError("The password could not be saved in the keyring."))

        def ready(collection, error):
            if error:
                callback(error)
                return
            # Labels and attributes intentionally contain no SSID or password.
            Secret.password_store(SCHEMA, tags, collection.get_object_path(),
                                  "NetworkManager Wi-Fi password", password,
                                  cancellable, stored, collection)

        self.collection(ready, cancellable)

    def lookup(self, connection_uuid, callback, cancellable, allow_unlock=False):
        tags = attributes(connection_uuid)

        def found(collection, result, _data):
            try:
                items = collection.search_finish(result)
                value = items[0].get_secret() if items else None
                callback(value.get_text() if value else None, None)
            except GLib.Error:
                callback(None, KeyringError("The saved password could not be read."))

        def ready(collection, error):
            if error:
                callback(None, error)
                return
            collection.search(SCHEMA, tags, Secret.SearchFlags.LOAD_SECRETS,
                              cancellable, found, None)

        self.collection(ready, cancellable, allow_unlock)

    def delete(self, connection_uuid, callback, cancellable):
        tags = attributes(connection_uuid)

        def removed(_source, result, _data):
            try:
                Secret.password_clear_finish(result)
                callback(None)
            except GLib.Error:
                callback(KeyringError("The saved password could not be removed."))

        def ready(_collection, error):
            if error:
                callback(error)
                return
            Secret.password_clear(SCHEMA, tags, cancellable, removed, None)

        self.collection(ready, cancellable, allow_unlock=False)
