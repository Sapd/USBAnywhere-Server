#!/usr/bin/env python3
# Native macOS implementation and support: Denis Arnst (Sapd) — https://github.com/Sapd
# USBAnywhere project: oscarlosu-lab (SnakeFoxu) — https://github.com/oscarlosu-lab
# Licensed under GPL-3.0; see the repository LICENSE.
"""Unprivileged installer transactions using real files and simulated launchd.

Never calls sudo, a real service manager, or writes outside TemporaryDirectory.
Root runs exercise only the sandbox rejection; transaction tests require a user.
"""
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile
import unittest

INSTALLER = Path(__file__).resolve().parents[1] / "scripts/install-server-mac.sh"
LABEL = "local.usbanywhere.macos"
UPSTREAM = "com.usbanywhere.server"

FAKE_TOOL = r'''#!/usr/bin/env python3
import json, os, pathlib, plistlib, shutil, sys
root = pathlib.Path(os.environ['USBANYWHERE_INSTALL_SANDBOX'])
name = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
failure = os.environ.get('INSTALL_FAIL', '')
with (root/'events').open('a') as out:
    out.write(json.dumps([name] + args) + '\n')
if name == 'sleep':
    sys.exit(0)
if name == 'codesign':
    sys.exit(1 if failure == 'stage_app' else 0)
if name == 'ditto':
    shutil.copytree(args[0], args[1], symlinks=True)
    sys.exit(0)
if name == 'plutil':
    plistlib.loads(pathlib.Path(args[-1]).read_bytes())
    sys.exit(1 if failure == 'plist_validation' else 0)
if name == 'mv':
    source, target = pathlib.Path(args[-2]), pathlib.Path(args[-1])
    swap = {'swap_binary': 'usbanywhere-mac',
            'swap_plist': 'local.usbanywhere.macos.plist',
            'swap_app': 'USBAnywhere.app'}
    marker = root/'swap-failed'
    if failure in swap and source.name == 'new' and target.name == swap[failure] and not marker.exists():
        marker.touch()
        sys.exit(1)
    os.execv('/bin/mv', ['mv'] + args)
if name == 'launchctl':
    statefile = root/'services.json'
    state = json.loads(statefile.read_text())
    action = args[0]
    if action == 'print':
        label = args[1].split('/', 1)[1]
        if label not in state:
            sys.exit(113)
        version = state[label]
        if failure == 'crash' and version == 'NEW':
            print('state = waiting')
        else:
            print('state = running\n pid = 12345')
        sys.exit(0)
    if action == 'bootout':
        label = args[1].split('/', 1)[1]
        if failure == 'bootout' and label in state and not (root/'bootout-failed').exists():
            (root/'bootout-failed').touch()
            sys.exit(1)
        state.pop(label, None)
    elif action == 'bootstrap':
        config = plistlib.loads(pathlib.Path(args[2]).read_bytes())
        label = config['Label']
        binary = pathlib.Path(config['ProgramArguments'][0])
        version = 'NEW' if '# NEW' in binary.read_text() else 'OLD'
        if failure == 'bootstrap' and version == 'NEW':
            sys.exit(1)
        if label in state:
            sys.exit(5)
        state[label] = version
    else:
        raise RuntimeError(args)
    statefile.write_text(json.dumps(state))
    sys.exit(0)
raise RuntimeError(name)
'''

FAKE_SERVER = r'''#!/usr/bin/env python3
# NEW
import json, os, pathlib, plistlib, sys
root = pathlib.Path(os.environ['USBANYWHERE_INSTALL_SANDBOX'])
args = sys.argv[1:]
with (root/'events').open('a') as out:
    out.write(json.dumps(['server'] + args) + '\n')
failure = os.environ.get('INSTALL_FAIL', '')
targets = root/'Library/Application Support/USBAnywhereMac/targets.json'
if args[0] == '--validate':
    sys.exit(0)
if args[0] == '--preflight-install':
    sys.exit(1 if failure == 'preflight' else 0)
if args[0] == '--preserve-startup-devices':
    if failure == 'preserve':
        targets.write_text('migration failed after writing')
        sys.exit(1)
    if not targets.exists():
        plist = root/'Library/LaunchDaemons/local.usbanywhere.macos.plist'
        old = plistlib.loads(plist.read_bytes())['ProgramArguments'][3:] if plist.exists() else []
        catalog = [{'vendor':int(old[i],16), 'product':int(old[i+1],16),
                    'location':int(old[i+2],16), 'label':old[i+3]} for i in range(0,len(old),4)]
        targets.write_text(json.dumps(catalog))
    sys.exit(0)
if args == ['--control', 'status']:
    sys.exit(1 if failure == 'control' else 0)
raise RuntimeError(args)
'''


@unittest.skipIf(os.geteuid() == 0, 'Transaction sandbox must run unprivileged')
class InstallerTransactions(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='usbanywhere-installer-test-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root/'.usbanywhere-installer-test').touch()
        (self.root/'bin').mkdir()
        (self.root/'tmp').mkdir()
        for tool in ['launchctl', 'codesign', 'ditto', 'plutil', 'sleep', 'mv']:
            self.executable(self.root/'bin'/tool, FAKE_TOOL)
        self.package = self.root/'Package'
        self.executable(self.package/'build/usbanywhere-server-mac', FAKE_SERVER)
        (self.package/'build/USBAnywhere.app').mkdir()
        (self.package/'build/USBAnywhere.app/version').write_text('NEW APP')
        self.binary = self.root/'Library/PrivilegedHelperTools/USBAnywhereMac/usbanywhere-mac'
        self.executable(self.binary, '#!/bin/sh\n# OLD\nexit 0\n')
        self.plist = self.root/f'Library/LaunchDaemons/{LABEL}.plist'
        self.plist.parent.mkdir(parents=True)
        self.write_plist(self.plist, LABEL, self.binary)
        self.old_plist = self.plist.read_bytes()
        self.old_binary = self.binary.read_bytes()
        self.app = self.root/'Applications/USBAnywhere.app'
        self.app.mkdir(parents=True)
        (self.app/'version').write_text('OLD APP')
        self.targets = self.root/'Library/Application Support/USBAnywhereMac/targets.json'
        self.targets.parent.mkdir(parents=True)
        self.targets.write_text('[{"label":"ORIGINAL"}]')
        self.original_targets = self.targets.read_bytes()
        (self.root/'services.json').write_text(json.dumps({LABEL: 'OLD'}))
        self.env = dict(os.environ, USBANYWHERE_INSTALL_SANDBOX=str(self.root),
                        USBANYWHERE_PACKAGE_DIR=str(self.package), TMPDIR=str(self.root/'tmp'))

    def executable(self, path, text):
        path.parent.mkdir(parents=True, exist_ok=True)
        # Use the running interpreter directly; no dependency on the caller's PATH.
        if text.startswith('#!/usr/bin/env python3'):
            text = '#!' + shutil.which('python3') + text[text.index('\n'):]
        path.write_text(text)
        path.chmod(0o755)

    def write_plist(self, path, label, binary):
        path.write_bytes(plistlib.dumps({'Label': label, 'ProgramArguments': [str(binary)]}))

    def run_installer(self, failure='', extra=()):
        env = dict(self.env, INSTALL_FAIL=failure)
        result = subprocess.run(['/bin/sh', str(INSTALLER), '127.0.0.1', '127.0.0.2', *extra],
                                env=env, capture_output=True, text=True, timeout=30)
        self.assertNotIn('Rollback needs attention', result.stderr, result.stderr)
        return result

    def services(self):
        return json.loads((self.root/'services.json').read_text())

    def events(self):
        path = self.root/'events'
        return [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []

    def assert_restored(self, result):
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.binary.read_bytes(), self.old_binary)
        self.assertEqual(self.plist.read_bytes(), self.old_plist)
        self.assertEqual((self.app/'version').read_text(), 'OLD APP')
        self.assertEqual(self.targets.read_bytes(), self.original_targets)
        self.assertEqual(self.services()[LABEL], 'OLD')
        self.assertFalse(Path(str(self.binary)+'.before-swift').exists())
        self.assertFalse((self.root/'var/run/usbanywhere-mac-install.lock').exists())

    def test_success_checks_health_and_keeps_first_migration_backup(self):
        result = self.run_installer()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('# NEW', self.binary.read_text())
        self.assertEqual((self.app/'version').read_text(), 'NEW APP')
        self.assertEqual(self.services()[LABEL], 'NEW')
        self.assertEqual(Path(str(self.binary)+'.before-swift').read_bytes(), self.old_binary)
        events = self.events()
        bootout = next(i for i, event in enumerate(events) if event[:2] == ['launchctl', 'bootout'])
        for action in ['--validate', '--preflight-install', '--preserve-startup-devices']:
            self.assertTrue(any(event[:2] == ['server', action] for event in events[:bootout]))
        self.assertEqual(sum(event == ['server', '--control', 'status'] for event in events), 2)
        self.assertEqual(self.targets.read_bytes(), self.original_targets)
        self.assertFalse(list(self.binary.parent.glob('.install.*')))
        self.assertFalse(list(self.app.parent.glob('.usbanywhere.*')))

    def test_preflight_failure_keeps_the_service_and_all_files(self):
        result = self.run_installer('preflight')
        self.assert_restored(result)
        self.assertFalse(any(event[:2] == ['launchctl', 'bootout'] for event in self.events()))

    def test_explicit_catalog_conflict_fails_before_stopping(self):
        result = self.run_installer('preflight', ('231d', '0201', '1234', 'LEFT'))
        self.assert_restored(result)
        self.assertFalse(any(event[:2] == ['launchctl', 'bootout'] for event in self.events()))

    def test_explicit_shorter_configuration_preserves_old_startup_suffix(self):
        self.targets.unlink()
        old_args = [str(self.binary), '127.0.0.1', '127.0.0.2',
                    '231d', '0201', '1234', 'LEFT', '231d', '0200', '5678', 'RIGHT']
        self.plist.write_bytes(plistlib.dumps({'Label': LABEL, 'ProgramArguments': old_args}))
        result = self.run_installer(extra=('231d', '0201', '1234', 'LEFT'))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([item['label'] for item in json.loads(self.targets.read_text())], ['LEFT', 'RIGHT'])
        events = self.events()
        preserve = next(i for i, event in enumerate(events) if event[:2] == ['server', '--preserve-startup-devices'])
        bootout = next(i for i, event in enumerate(events) if event[:2] == ['launchctl', 'bootout'])
        self.assertLess(preserve, bootout)

    def test_stage_failures_do_not_stop_a_working_service(self):
        for failure in ['stage_app', 'plist_validation']:
            with self.subTest(failure=failure):
                result = self.run_installer(failure)
                self.assert_restored(result)
                self.assertFalse(any(event[:2] == ['launchctl', 'bootout'] for event in self.events()))

    def test_failed_migration_restores_catalog_before_any_service_stop(self):
        result = self.run_installer('preserve')
        self.assert_restored(result)
        self.assertFalse(any(event[:2] == ['launchctl', 'bootout'] for event in self.events()))

    def test_file_swap_failures_restore_binary_plist_app_and_service(self):
        for failure in ['swap_binary', 'swap_plist', 'swap_app']:
            with self.subTest(failure=failure):
                (self.root/'events').write_text('')
                (self.root/'swap-failed').unlink(missing_ok=True)
                self.assert_restored(self.run_installer(failure))

    def test_bootstrap_failure_rolls_back_and_restarts_previous_service(self):
        self.assert_restored(self.run_installer('bootstrap'))

    def test_registered_but_crashed_service_rolls_back(self):
        self.assert_restored(self.run_installer('crash'))

    def test_running_process_without_working_control_socket_rolls_back(self):
        self.assert_restored(self.run_installer('control'))

    def test_bootout_failure_does_not_replace_the_old_installation(self):
        self.assert_restored(self.run_installer('bootout'))

    def test_failed_upgrade_removes_newly_migrated_catalog(self):
        self.targets.unlink()
        result = self.run_installer('bootstrap')
        self.assertNotEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.targets.exists())
        self.assertEqual(self.services()[LABEL], 'OLD')
        self.assertEqual(self.binary.read_bytes(), self.old_binary)

    def test_failed_upgrade_restores_upstream_service_and_previous_archive(self):
        upstream_binary = self.root/'upstream-server'
        self.executable(upstream_binary, '#!/bin/sh\n# OLD\nexit 0\n')
        upstream_plist = self.plist.parent/f'{UPSTREAM}.plist'
        self.write_plist(upstream_plist, UPSTREAM, upstream_binary)
        original = upstream_plist.read_bytes()
        previous = self.targets.parent/'previous-upstream.plist'
        previous.write_text('OLDER ARCHIVE')
        (self.root/'services.json').write_text(json.dumps({LABEL: 'OLD', UPSTREAM: 'OLD'}))
        self.assert_restored(self.run_installer('control'))
        self.assertEqual(upstream_plist.read_bytes(), original)
        self.assertEqual(previous.read_text(), 'OLDER ARCHIVE')
        self.assertEqual(self.services()[UPSTREAM], 'OLD')

    def test_fresh_failed_install_leaves_no_replacement_files_or_service(self):
        self.binary.unlink()
        self.plist.unlink()
        shutil.rmtree(self.app)
        self.targets.unlink()
        (self.root/'services.json').write_text('{}')
        result = self.run_installer('bootstrap')
        self.assertNotEqual(result.returncode, 0)
        for path in [self.binary, self.plist, self.app, self.targets]:
            self.assertFalse(path.exists(), str(path))
        self.assertEqual(self.services(), {})

    def test_previously_unregistered_service_is_not_started_during_rollback(self):
        (self.root/'services.json').write_text('{}')
        result = self.run_installer('control')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.services(), {})
        self.assertEqual(self.binary.read_bytes(), self.old_binary)
        self.assertEqual(self.plist.read_bytes(), self.old_plist)

    def test_binary_only_update_preserves_existing_app(self):
        shutil.rmtree(self.package/'build/USBAnywhere.app')
        result = self.run_installer()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.app/'version').read_text(), 'OLD APP')

    def test_unprivileged_production_mode_cannot_be_enabled_with_fake_id(self):
        self.executable(self.root/'bin/id', '#!/bin/sh\necho 0\n')
        env = dict(self.env, PATH=str(self.root/'bin') + ':' + os.environ['PATH'])
        del env['USBANYWHERE_INSTALL_SANDBOX']
        result = subprocess.run(['/bin/sh', str(INSTALLER), '127.0.0.1', '127.0.0.2'],
                                env=env, capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, 2)
        self.assertIn('sudo', result.stderr)
        self.assertEqual(self.events(), [])


@unittest.skipUnless(os.geteuid() == 0, 'Root-only rejection check; never uses sudo')
class RootSandboxRejection(unittest.TestCase):
    def test_root_cannot_enable_sandbox_commands(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root/'.usbanywhere-installer-test').touch()
            (root/'bin').mkdir()
            marker = root/'fake-command-ran'
            (root/'bin/id').write_text(f'#!/bin/sh\ntouch "{marker}"\necho 501\n')
            (root/'bin/id').chmod(0o755)
            result = subprocess.run(['/bin/sh', str(INSTALLER), '127.0.0.1', '127.0.0.2'],
                                    env=dict(os.environ, USBANYWHERE_INSTALL_SANDBOX=directory,
                                             PATH=str(root/'bin') + ':' + os.environ['PATH']),
                                    capture_output=True, text=True, timeout=5)
            self.assertEqual(result.returncode, 2)
            self.assertIn('forbidden', result.stderr)
            self.assertFalse(marker.exists())


if __name__ == '__main__':
    unittest.main(verbosity=2)
