import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import time
import sys

sys.dont_write_bytecode = True

# The worker runs on a new session bus, never the desktop's actual keyring.
if '--worker' not in sys.argv:
    result = subprocess.run(['dbus-run-session', '--', sys.executable, '-I',
                             str(Path(__file__).resolve()), '--worker'],
                            env=dict(os.environ, DOTFILES_PRIVATE_SECRET_TEST='1'))
    raise SystemExit(result.returncode)
if os.environ.get('DOTFILES_PRIVATE_SECRET_TEST') != '1':
    raise SystemExit('Run this check without --worker.')

import gi
gi.require_version('Secret', '1')
from gi.repository import Gio, GLib, Secret

root = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('network_keyring', root / 'home/scripts/.local/lib/dotfiles/network_keyring.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


def run_operation(start):
    loop = GLib.MainLoop()
    output = []
    def completed(*values):
        output.extend(values)
        loop.quit()
    timeout = GLib.timeout_add_seconds(10, lambda: (loop.quit(), GLib.SOURCE_REMOVE)[1])
    start(completed)
    loop.run()
    if GLib.MainContext.default().find_source_by_id(timeout):
        GLib.source_remove(timeout)
    assert output, 'Keyring operation timed out'
    return output


with tempfile.TemporaryDirectory(prefix='dotfiles-keyring-test-') as folder:
    runtime = Path(folder) / 'run'
    data = Path(folder) / 'data'
    runtime.mkdir(mode=0o700)
    data.mkdir(mode=0o700)
    os.environ['XDG_RUNTIME_DIR'] = str(runtime)
    os.environ['XDG_DATA_HOME'] = str(data)
    os.environ['XDG_CONFIG_HOME'] = str(Path(folder) / 'config')
    os.environ['XDG_CACHE_HOME'] = str(Path(folder) / 'cache')
    os.environ.pop('GNOME_KEYRING_PID', None)
    os.environ['GNOME_KEYRING_CONTROL'] = str(runtime / 'keyring')
    binary = Path('/usr/bin/gnome-keyring-daemon')
    daemon = subprocess.Popen([str(binary), '--foreground', '--components=secrets', '--unlock'],
                              stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    daemon.stdin.write(b'test-master-password-only')
    daemon.stdin.close()
    bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    try:
        deadline = time.monotonic() + 8
        while time.monotonic() < deadline:
            answer = bus.call_sync('org.freedesktop.DBus', '/org/freedesktop/DBus',
                'org.freedesktop.DBus', 'NameHasOwner', GLib.Variant('(s)', ('org.freedesktop.secrets',)),
                None, Gio.DBusCallFlags.NONE, 1000, None)
            if answer.unpack()[0]:
                break
            if daemon.poll() is not None:
                raise AssertionError('Isolated GNOME Keyring daemon did not start')
            time.sleep(0.02)
        else:
            raise AssertionError('Isolated Secret Service startup timed out')
        store = module.Keyring()
        uuid = 'ad2a0ecb-8658-44c9-ab14-7a22a4872286'
        fixture = 'test-wifi-password-only'
        output = run_operation(lambda done: store.store(uuid, fixture, done, Gio.Cancellable()))
        assert output == [None], str(output[-1])
        output = run_operation(lambda done: store.lookup(uuid, done, Gio.Cancellable()))
        assert output[-1] is None and output[0] == fixture, 'Encrypted credential round trip failed'
        files = list((data / 'keyrings').glob('*.keyring'))
        assert files, 'No persistent keyring was created'
        for file in files:
            content = file.read_bytes()
            assert content.startswith(b'GnomeKeyring\n\r\0\n'), 'Keyring is not in the encrypted format'
            assert fixture.encode() not in content, 'Fixture was stored in plaintext'
        print('PASS: actual GNOME Keyring encrypted store/read; fixture absent from disk plaintext')
        output = run_operation(lambda done: store.delete(uuid, done, Gio.Cancellable()))
        assert output == [None], 'Keyring deletion failed'
        output = run_operation(lambda done: store.lookup(uuid, done, Gio.Cancellable()))
        assert output == [None, None], 'Deleted fixture was returned'
        print('PASS: actual Secret Service deletion and missing-password handling')
    finally:
        daemon.terminate()
        try:
            daemon.wait(timeout=3)
        except subprocess.TimeoutExpired:
            daemon.kill()
            daemon.wait()
