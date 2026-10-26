#!/usr/bin/env python3
# Copyright 2026 Denis Arnst (Sapd) — https://github.com/Sapd
# USBAnywhere project: oscarlosu-lab (SnakeFoxu) — https://github.com/oscarlosu-lab
# Licensed under GPL-3.0; see the repository LICENSE.
"""Shared CLI/native Mac integration with a real isolated helper subprocess."""
import contextlib
import importlib.machinery
import importlib.util
import io
import json
from pathlib import Path
import socket
import struct
import subprocess
import sys
import tempfile
import threading
import unittest
from unittest import mock

SCRIPT = Path(__file__).resolve().parents[1] / 'scripts/usbanywhere-ctl'

class NativeMacControl(unittest.TestCase):
    def setUp(self):
        loader = importlib.machinery.SourceFileLoader('native_control_test', str(SCRIPT))
        spec = importlib.util.spec_from_loader(loader.name, loader)
        self.ctl = importlib.util.module_from_spec(spec)
        loader.exec_module(self.ctl)
        self.ctl.IS_MACOS, self.ctl.IS_LINUX = True, False
        self.temp = tempfile.TemporaryDirectory(prefix='USBAnywhere native CLI ')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.ctl.MAC_HELPER = str(self.root / 'native-helper')
        self.ctl.MAC_PLIST = str(self.root / 'service.plist')
        Path(self.ctl.MAC_PLIST).touch()
        self.reply = {'ok': True, 'message': 'Sharing updated', 'status': {
            'listen': '100.64.1.2', 'peer': '100.64.1.3',
            'devices': [{'id': '1-1', 'name': 'Left stick', 'model': '231d:0201',
                         'state': 'Connected to Windows', 'enabled': True}],
            'availableDevices': [{'location': '12340000', 'name': 'Unconfigured', 'vendor': '1234', 'product': '5678'}]}}
        self.response(self.reply)
        Path(self.ctl.MAC_HELPER).write_text('#!' + sys.executable + '\n' + '''import json,pathlib,sys
root=pathlib.Path(__file__).parent
with (root/'requests').open('a') as f:f.write(json.dumps(sys.argv[1:])+'\\n')
print((root/'reply').read_text())
sys.exit(int((root/'exit').read_text()) if (root/'exit').exists() else 0)
''')
        Path(self.ctl.MAC_HELPER).chmod(0o755)

    def response(self, value):
        (self.root / 'reply').write_text(json.dumps(value))

    def requests(self):
        path = self.root / 'requests'
        return [json.loads(x) for x in path.read_text().splitlines()] if path.exists() else []

    def main(self, *args):
        out, err = io.StringIO(), io.StringIO()
        with mock.patch.object(sys, 'argv', [str(SCRIPT), *args]), contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            try:
                self.ctl.main()
                code = 0
            except SystemExit as result:
                code = result.code
        return code, out.getvalue(), err.getvalue()

    def test_status_uses_native_devices_and_configured_address(self):
        with mock.patch.object(self.ctl, 'is_port_open', return_value=True) as probe:
            code, out, err = self.main('status', '--json')
        self.assertEqual(code, 0, err)
        state = json.loads(out)
        self.assertTrue(state['running'])
        self.assertEqual(state['lan_ip'], '100.64.1.2')
        self.assertEqual(state['devices'], self.reply['status']['devices'])
        probe.assert_called_once_with('100.64.1.2')
        self.assertEqual(self.requests(), [['--control', 'status']])

    def test_inventory_displays_remembered_ids_and_unconfigured_devices(self):
        code, out, err = self.main('list')
        self.assertEqual(code, 0, err)
        self.assertIn('[1-1] Left stick', out)
        self.assertIn('[unconfigured 12340000]', out)
        self.assertIn('Share in USBAnywhere.app', out)

    def test_share_unshare_and_reconnect_use_native_authorization_without_sudo(self):
        with mock.patch.object(self.ctl, 'is_root', return_value=False):
            for action in ['share', 'unshare', 'reconnect']:
                code, out, err = self.main(action, '1-1')
                self.assertEqual(code, 0, err)
                self.assertIn('Sharing updated', out)
        self.assertEqual(self.requests(), [['--control', action, '1-1'] for action in ['share', 'unshare', 'reconnect']])

    def test_native_permission_or_persistence_failure_returns_failure(self):
        self.response({'ok': False, 'message': 'Could not save sharing settings'})
        code, out, err = self.main('unshare', '1-1')
        self.assertEqual(code, 1)
        self.assertNotIn('Sharing updated', out)
        self.assertIn('Could not save sharing settings', err)

    def test_nonzero_helper_exit_cannot_be_reported_as_success(self):
        (self.root / 'exit').write_text('17')
        self.assertEqual(self.main('share', '1-1')[0], 1)

    def test_invalid_bus_ids_never_reach_the_helper(self):
        for value in ['1-0', '1-17', '1-01', '1-1; touch bad', '--help']:
            with self.assertRaises(RuntimeError):
                self.ctl.mac_control('share', value)
        self.assertEqual(self.requests(), [])

    def test_malformed_native_reply_is_visible_and_not_running(self):
        for value in ['not JSON', '[]', '{"ok":true,"status":{}}']:
            (self.root / 'reply').write_text(value)
            status = self.ctl.get_service_status()
            self.assertFalse(status['running'])
            self.assertIn('error', status)

    def test_missing_helper_does_not_infer_service_health_from_an_unrelated_port(self):
        Path(self.ctl.MAC_HELPER).unlink()
        with mock.patch.object(self.ctl, 'is_port_open', return_value=True) as probe:
            state = self.ctl.get_service_status()
        self.assertFalse(state['running'])
        self.assertFalse(state['port_active'])
        probe.assert_not_called()

    def test_start_bootstraps_only_the_native_system_service(self):
        commands = []
        def run(command, **kwargs):
            commands.append(command)
            return subprocess.CompletedProcess(command, 113 if command[1] == 'print' else 0)
        with mock.patch.object(self.ctl, 'is_root', return_value=True), mock.patch.object(self.ctl.subprocess, 'run', side_effect=run):
            self.assertEqual(self.main('start')[0], 0)
        self.assertEqual(commands, [
            ['launchctl', 'print', 'system/local.usbanywhere.macos'],
            ['launchctl', 'enable', 'system/local.usbanywhere.macos'],
            ['launchctl', 'bootstrap', 'system', self.ctl.MAC_PLIST],
            ['launchctl', 'kickstart', 'system/local.usbanywhere.macos']])

    def test_stop_and_restart_target_only_the_registered_service(self):
        with mock.patch.object(self.ctl, 'is_root', return_value=True), mock.patch.object(self.ctl.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0)) as run:
            self.assertEqual(self.main('stop')[0], 0)
            self.assertEqual(run.call_args.args[0], ['launchctl', 'bootout', 'system/local.usbanywhere.macos'])
            self.assertEqual(self.main('restart')[0], 0)
            self.assertEqual(run.call_args.args[0], ['launchctl', 'kickstart', '-k', 'system/local.usbanywhere.macos'])

    def test_stopping_an_unloaded_service_is_idempotent(self):
        with mock.patch.object(self.ctl, 'is_root', return_value=True), mock.patch.object(self.ctl.subprocess, 'run', return_value=subprocess.CompletedProcess([], 113)) as run:
            code, out, err = self.main('stop')
        self.assertEqual(code, 0, err)
        self.assertIn('already stopped', out)
        run.assert_called_once()
        self.assertEqual(run.call_args.args[0], ['launchctl', 'print', 'system/local.usbanywhere.macos'])

    def test_failed_launchctl_action_returns_nonzero(self):
        with mock.patch.object(self.ctl, 'is_root', return_value=True), mock.patch.object(self.ctl.subprocess, 'run', side_effect=subprocess.CalledProcessError(5, ['launchctl'])):
            self.assertEqual(self.main('stop')[0], 1)

    def test_sudo_uses_an_argument_array(self):
        with mock.patch.object(self.ctl, 'is_root', return_value=False), mock.patch.object(self.ctl.subprocess, 'run', return_value=subprocess.CompletedProcess([], 1)) as run:
            self.assertEqual(self.main('start')[0], 1)
        command = run.call_args.args[0]
        self.assertEqual(command[:2], ['sudo', sys.executable])
        self.assertEqual(command[-1], 'start')
        self.assertNotIn('shell', run.call_args.kwargs)

    def test_mac_self_test_uses_local_control_instead_of_an_unauthorized_network_import(self):
        code, out, err = self.main('test')
        self.assertEqual(code, 0, err)
        self.assertIn('local-control self-test passed', out)
        self.assertIn('allowed Windows peer 100.64.1.3', out)
        self.assertEqual(self.requests(), [['--control', 'status']])

    def test_native_logs_use_the_correct_path(self):
        with mock.patch.object(self.ctl.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0)) as run:
            self.assertEqual(self.main('logs')[0], 0)
        self.assertEqual(run.call_args.args[0], ['tail', '-f', '/Library/Logs/USBAnywhereMac/swift-server.log'])

    def test_linux_keeps_its_own_service_and_usbip_commands(self):
        self.ctl.IS_MACOS, self.ctl.IS_LINUX = False, True
        with mock.patch.object(self.ctl, 'is_root', return_value=True), mock.patch.object(self.ctl.shutil, 'which', return_value='/usr/bin/usbip'), mock.patch.object(self.ctl, 'run_cmd', return_value='active') as run:
            self.assertTrue(self.ctl.share_device('1-5'))
            self.assertEqual(run.call_args.args[0], ['/usr/bin/usbip', 'bind', '-b', '1-5'])
            self.assertTrue(self.ctl.unshare_device('1-5'))
            self.assertEqual(run.call_args.args[0], ['/usr/bin/usbip', 'unbind', '-b', '1-5'])
            self.assertTrue(self.ctl.stop_service())
            self.assertIn(mock.call(['systemctl', 'stop', 'usbipd']), run.call_args_list)

    def test_remote_protocol_probe_accepts_fragmentation_and_rejects_truncated_count(self):
        for truncated in [False, True]:
            server = socket.socket()
            server.bind(('127.0.0.1', 0))
            server.listen(1)
            def serve():
                with server:
                    client, _ = server.accept()
                    with client:
                        request = b''
                        while len(request) < 8:
                            request += client.recv(8 - len(request))
                        payload = struct.pack('>HHII', 0x111, 5, 0, 0)
                        if truncated:
                            payload = payload[:10]
                        for byte in payload:
                            client.sendall(bytes([byte]))
            thread = threading.Thread(target=serve)
            port = server.getsockname()[1]
            thread.start()
            with contextlib.redirect_stdout(io.StringIO()):
                result = self.ctl.run_self_test('127.0.0.1', port)
            thread.join(timeout=3)
            self.assertFalse(thread.is_alive())
            self.assertEqual(result, not truncated)

if __name__ == '__main__':
    unittest.main()
