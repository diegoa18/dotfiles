"""Offline regression checks; no connection changes or real passwords are read."""

import importlib.util
import json
import os
from pathlib import Path
import runpy
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True

import gi

gi.require_version("NM", "1.0")
from gi.repository import GLib, Gio, NM

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / "home/scripts/.local/lib/dotfiles/network_keyring.py"
spec = importlib.util.spec_from_file_location("test_keyring", LIB)
keyring = importlib.util.module_from_spec(spec)
spec.loader.exec_module(keyring)
backend = runpy.run_path(str(ROOT / "home/scripts/.local/bin/network-popup-service"))
backend["new_profile"].__globals__.update(NM=NM, GLib=GLib, Gio=Gio, keyring=keyring)
agent_code = runpy.run_path(str(ROOT / "home/scripts/.local/bin/network-keyring-agent"))


class AccessPoint:
    def __init__(self, flags=0x100, rsn=0x100, name=b"Test network"):
        self.flags, self.rsn, self.name = flags, rsn, name
    def get_wpa_flags(self): return self.flags
    def get_rsn_flags(self): return self.rsn
    def get_flags(self): return 1
    def get_ssid(self): return GLib.Bytes.new(self.name)
    def get_mode(self): return 2


def wifi_with_hardware_path():
    ap = AccessPoint()
    ap.get_path = lambda: "/org/freedesktop/NetworkManager/AccessPoint/1"
    ap.get_strength = lambda: 80
    ap.get_frequency = lambda: 5180
    return SimpleNamespace(
        bus_path="/org/freedesktop/NetworkManager/Devices/2",
        get_path=lambda: "pci-0000:00:14.3",
        get_managed=lambda: True,
        get_property=lambda _name: NM.DeviceCapabilities(1),
        get_device_type=lambda: NM.DeviceType.WIFI,
        get_state=lambda: NM.DeviceState.ACTIVATED,
        get_active_connection=lambda: None,
        get_active_access_point=lambda: ap,
        get_access_points=lambda: [ap],
        get_available_connections=lambda: [],
        get_iface=lambda: "wlo1",
        get_last_scan=lambda: 0,
    )


class NetworkSecurityTests(unittest.TestCase):
    def test_wifi_getter_shadow_does_not_hide_hardware(self):
        devices = [SimpleNamespace(
            get_managed=lambda: True, get_device_type=lambda: NM.DeviceType.WIFI,
            get_capabilities=lambda: NM.DeviceWifiCapabilities(1919),
            get_property=lambda name: NM.DeviceCapabilities(1)),
            SimpleNamespace(get_managed=lambda: True,
                get_device_type=lambda: NM.DeviceType.ETHERNET,
                get_property=lambda name: NM.DeviceCapabilities(7))]
        client = SimpleNamespace(get_devices=lambda: devices)
        self.assertEqual(backend["visible_devices"](client), [devices[0]])

    def test_device_identifiers_use_dbus_paths_despite_hardware_getter_shadow(self):
        self.assertEqual(NM.Device.get_path.get_symbol(), "nm_device_get_path")
        self.assertEqual(NM.Object.get_path.get_symbol(), "nm_object_get_path")
        device = wifi_with_hardware_path()
        client = SimpleNamespace(get_devices=lambda: [device], wireless_get_enabled=lambda: True)
        service = backend["NetworkPopup"](client, None)
        scans = []
        service.handle = lambda request: scans.append(backend["validate_request"](request))
        with patch.object(NM.Object, "get_path", side_effect=lambda obj: obj.bus_path), \
                patch.object(backend["time"], "clock_gettime", return_value=100):
            self.assertEqual(backend["device_details"](device)["path"], device.bus_path)
            rows = backend["network_rows"]([device])
            self.assertEqual(rows[0]["device"], device.bus_path)
            self.assertTrue(rows[0]["key"].startswith(device.bus_path + ":"))
            self.assertIs(service.device(device.bus_path), device)
            service.scan_if_stale()
            self.assertEqual(scans, [{"action": "scan", "device": device.bus_path}])
            device.get_last_scan = lambda: 98000
            scans.clear()
            service.scan_if_stale()
            self.assertFalse(scans)
        with self.assertRaises(backend["RequestError"]):
            backend["validate_request"]({"action": "scan", "device": device.get_path()})

    def test_startup_scan_failure_keeps_backend_available_and_hides_error_details(self):
        device = wifi_with_hardware_path()
        client = SimpleNamespace(get_devices=lambda: [device], wireless_get_enabled=lambda: True)
        loop = SimpleNamespace(quit=unittest.mock.Mock())
        service = backend["NetworkPopup"](client, loop)
        service.queue_snapshot = lambda: None
        messages = []
        globals_map = backend["NetworkPopup"].scan_if_stale.__globals__
        with patch.object(NM.Object, "get_path", side_effect=lambda obj: obj.bus_path), \
                patch.dict(globals_map, emit=messages.append):
            service.handle = unittest.mock.Mock(side_effect=backend["RequestError"]("Invalid network request."))
            service.scan_if_stale()
            self.assertEqual(messages[-1]["message"], "Invalid network request.")
            cancel = Gio.Cancellable()
            def failed_scan(_request):
                service.pending = {"cancel": cancel}
                raise GLib.Error("private-test-error-detail")
            service.handle = failed_scan
            service.scan_if_stale()
        self.assertIsNone(service.pending)
        self.assertTrue(cancel.is_cancelled())
        loop.quit.assert_not_called()
        self.assertNotIn("private-test-error-detail", json.dumps(messages))
        self.assertEqual(messages[-1]["message"], "Could not refresh Wi-Fi networks. Try scanning again.")

    def test_strict_request_protocol_rejects_ambiguous_or_sensitive_errors(self):
        path = "/org/freedesktop/NetworkManager/Devices/1"
        accepted = {"action": "connect", "device": path, "password": "test-key-only"}
        self.assertEqual(backend["parse_request"](json.dumps(accepted)), accepted)
        invalid = [b'{"action":"refresh","action":"wifi"}', b'{"action":"refresh","x":NaN}',
                   b'{"action":"wifi","enabled":"false"}', b'{"action":"refresh","password":"test"}',
                   b'{"action":"connect","device":"/tmp/device"}',
                   b'{"action":"connect","device":[]}', b'{"action":"refresh","x":1}',
                   b'{"action":[]}', b'\xff', b'x' * 4097,
                   json.dumps({**accepted, "password": "x" * 257}),
                   json.dumps({**accepted, "password": "test\0password"})]
        for line in invalid:
            with self.subTest(size=len(line)):
                with self.assertRaises(backend["RequestError"]) as raised:
                    backend["parse_request"](line)
                self.assertEqual(str(raised.exception), "Invalid network request.")

    def test_profiles_keep_original_ssid_and_use_agent_owned_secrets(self):
        for flags, key_mgmt in ((0x100, "wpa-psk"), (0x500, "sae")):
            ap = AccessPoint(flags, flags, b"raw\nssid")
            profile = backend["new_profile"](None, ap, "test-key-only")
            self.assertTrue(profile.verify())
            setting = profile.get_setting_wireless_security()
            self.assertEqual(setting.get_key_mgmt(), key_mgmt)
            self.assertEqual(setting.get_psk_flags(), NM.SettingSecretFlags.AGENT_OWNED)
            self.assertEqual(profile.get_setting_wireless().get_ssid().get_data(), ap.name)
            self.assertEqual(setting.get_proto(0), "rsn")
            if key_mgmt == "sae":
                self.assertEqual(setting.get_pmf(), NM.SettingWirelessSecurityPmf.REQUIRED)
        with self.assertRaises(backend["RequestError"]):
            backend["new_profile"](None, AccessPoint(0x100, 0), "test-key-only")

    def test_labels_cannot_insert_control_characters_or_bidi_overrides(self):
        self.assertEqual(backend["safe_label"]("normal\nname\u202e"), "normal\ufffdname\ufffd")
        self.assertEqual(backend["safe_label"]("Café 🌐"), "Café 🌐")

    def test_snapshot_does_not_export_network_identifiers(self):
        state = dict(type="state", running=True, wifiEnabled=True, wifiHardwareEnabled=True,
                     hasWifi=True, busy=False, scanning=False, networks=[{"ssid": "PRIVATE_SSID"}],
                     devices=[dict(kind="wifi", state="Connected", connected=True, signal=90,
                                   security="WPA2", title="PRIVATE_SSID", interface="wlo1",
                                   addresses=["192.0.2.1/24"], gateway="192.0.2.254", dns=["192.0.2.2"])])
        output = json.dumps(backend["diagnostic_snapshot"](state))
        for private in ("PRIVATE_SSID", "wlo1", "192.0.2."):
            self.assertNotIn(private, output)

    def test_unencrypted_or_shared_keyring_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory, patch.dict(os.environ, {"XDG_DATA_HOME": directory}):
            folder = Path(directory) / "keyrings"
            folder.mkdir()
            path = folder / "login.keyring"
            collection = "/org/freedesktop/secrets/collection/login"
            path.write_bytes(b"[keyring]\npassword=test-fixture\n")
            path.chmod(0o600)
            with self.assertRaises(keyring.KeyringError):
                keyring.verify_encrypted_collection(collection)
            path.write_bytes(b"GnomeKeyring\n\r\0\n")
            path.chmod(0o644)
            with self.assertRaises(keyring.KeyringError):
                keyring.verify_encrypted_collection(collection)
            path.chmod(0o600)
            keyring.verify_encrypted_collection(collection)
            symlink = folder / "link.keyring"
            symlink.symlink_to(path)
            with self.assertRaises(keyring.KeyringError):
                keyring.verify_encrypted_collection("/org/freedesktop/secrets/collection/link")
            with self.assertRaises(keyring.KeyringError):
                keyring.verify_encrypted_collection("/org/freedesktop/secrets/collection/_2e_2e_2f")

    def test_only_networkmanager_can_request_credentials(self):
        agent = agent_code["Agent"].__new__(agent_code["Agent"])
        agent.client = SimpleNamespace(get_dbus_name_owner=lambda: ":1.10")
        calls = []
        invocation = SimpleNamespace(return_dbus_error=lambda *args: calls.append(args))
        # Parameters are deliberately absent: unauthorized callers must be
        # rejected before parsing any request or contacting the keyring.
        agent.request(None, ":1.11", None, None, "GetSecrets", None, invocation)
        self.assertEqual(calls[0][0], "org.freedesktop.NetworkManager.SecretAgent.PermissionDenied")

    def test_password_flags_change_only_after_encrypted_storage_succeeds(self):
        profile = backend["new_profile"](None, AccessPoint(), "test-key-only")
        security = profile.get_setting_wireless_security()
        security.set_property("psk-flags", NM.SettingSecretFlags.NONE)
        service = backend["NetworkPopup"](None, None)
        service.pending = {"cancel": Gio.Cancellable()}
        callbacks, errors, followups = [], [], []
        service.store = SimpleNamespace(store=lambda *args: callbacks.append(args[2]))
        service.finish_operation = errors.append
        service.store_password(profile, "test-key-only", lambda: followups.append(True))
        callbacks.pop()(keyring.KeyringError("Test keyring is locked."))
        self.assertEqual(security.get_psk_flags(), NM.SettingSecretFlags.NONE)
        self.assertEqual(security.get_psk(), "test-key-only")
        self.assertFalse(followups)
        service.store_password(profile, "test-key-only", lambda: followups.append(True))
        callbacks.pop()(None)
        self.assertEqual(security.get_psk_flags(), NM.SettingSecretFlags.AGENT_OWNED)
        self.assertIsNone(security.get_psk())
        self.assertEqual(followups, [True])
        self.assertEqual(profile.get_setting_connection().get_num_permissions(), 1)

    def test_authenticated_agent_reply_and_cancellation(self):
        Agent = agent_code["Agent"]
        agent = Agent.__new__(Agent)
        agent.client = SimpleNamespace(get_dbus_name_owner=lambda: ":1.10")
        agent.pending = {}
        lookups, responses, errors = [], [], []
        agent.store = SimpleNamespace(lookup=lambda *args: lookups.append(args[1]))
        settings = {"connection": {"uuid": GLib.Variant("s", "ad2a0ecb-8658-44c9-ab14-7a22a4872286"),
                                  "type": GLib.Variant("s", "802-11-wireless")},
                    "802-11-wireless-security": {"key-mgmt": GLib.Variant("s", "wpa-psk"),
                                                 "psk-flags": GLib.Variant("u", 1)}}
        path = "/org/freedesktop/NetworkManager/Settings/1"
        params = GLib.Variant("(a{sa{sv}}osasu)", (settings, path, keyring.SETTING, [], 0))
        invocation = SimpleNamespace(return_value=responses.append, return_dbus_error=lambda *args: errors.append(args))
        agent.request(None, ":1.10", None, None, "GetSecrets", params, invocation)
        lookups.pop()("test-key-only", None)
        self.assertEqual(responses[0].unpack(), ({keyring.SETTING: {"psk": "test-key-only"}},))
        agent.request(None, ":1.10", None, None, "GetSecrets", params, invocation)
        agent.request(None, ":1.10", None, None, "CancelGetSecrets",
                      GLib.Variant("(os)", (path, keyring.SETTING)), invocation)
        lookups.pop()("test-key-only", None)
        self.assertEqual(len(responses), 2)
        self.assertEqual(errors[-1][0], "org.freedesktop.NetworkManager.SecretAgent.AgentCanceled")

    def test_request_errors_never_echo_a_secret_and_stream_recovers(self):
        service = backend["NetworkPopup"](None, SimpleNamespace(quit=lambda: None))
        secret = b"test-private-password"
        chunks = [b"x" * 4096, b"x" * 4096,
                  b'\n{"action":"refresh"}\n',
                  b'{"action":"connect","device":[],"password":"' + secret + b'"}\n']
        messages, handled = [], []
        service.handle = handled.append
        globals_map = backend["NetworkPopup"].read_input.__globals__
        with patch.object(os, "read", side_effect=chunks), patch.dict(globals_map, emit=messages.append):
            for _ in chunks:
                service.read_input(0, 0)
                self.assertLessEqual(len(service.input_buffer), 4096)
        self.assertEqual(handled, [{"action": "refresh"}])
        self.assertNotIn(secret.decode(), json.dumps(messages))


if __name__ == "__main__":
    unittest.main()
