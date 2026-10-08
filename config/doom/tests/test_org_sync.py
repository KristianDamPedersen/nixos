import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import json

spec = importlib.util.spec_from_file_location('sync', Path(__file__).parents[1] / 'bin' / 'org-sync.py')
sync = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sync)

def envelope(value=b'ciphertext'):
    return b'\xc1\x03abc\xd2' + bytes([len(value)]) + value

class SyncTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        sync.git(self.root, 'init', '-b', 'devices/test')
        sync.git(self.root, 'config', 'user.name', 'Test')
        sync.git(self.root, 'config', 'user.email', 'test@example.test')
        for name, data in sync.POLICY.items():
            (self.root / name).write_bytes(data)
        (self.root / 'note.org.gpg').write_bytes(envelope())
        sync.git(self.root, 'add', '.')
        sync.git(self.root, 'commit', '-m', 'Initial')
        self.base = sync.head(self.root)

    def tearDown(self):
        self.temp.cleanup()

    def commit(self, filename, content):
        (self.root / filename).write_bytes(content)
        return sync.snapshot(self.root)

    def test_envelope(self):
        self.assertTrue(sync.encrypted(envelope()))
        for data in (b'* plaintext', envelope()[:-1], envelope() + b'plaintext', b'', b'\xd2\x01x'):
            self.assertFalse(sync.encrypted(data))

    def test_plaintext_rejected_even_with_gpg_extension(self):
        with self.assertRaises(sync.SyncError):
            self.commit('note.org.gpg', b'* private note')
        self.assertEqual(sync.head(self.root), self.base)
        self.assertEqual((self.root / 'note.org.gpg').read_bytes(), b'* private note')

    def test_supporting_files_never_staged(self):
        (self.root / 'shopping.xlsx').write_bytes(b'private')
        self.commit('new.org.gpg', envelope(b'new'))
        self.assertNotIn('shopping', sync.text(self.root, 'ls-files'))

    def test_binary_conflict_preserves_working_copy(self):
        ours = self.commit('note.org.gpg', envelope(b'ours'))
        sync.git(self.root, 'checkout', '--detach', self.base)
        theirs = self.commit('note.org.gpg', envelope(b'theirs'))
        sync.git(self.root, 'checkout', 'devices/test')
        self.assertIsNone(sync.merge_candidate(self.root, ours, theirs))
        self.assertEqual((self.root / 'note.org.gpg').read_bytes(), envelope(b'ours'))
        self.assertEqual(sync.head(self.root), ours)
        self.assertFalse(sync.git(self.root, 'ls-files', '-u'))

    def test_disjoint_merge_and_apply(self):
        ours = self.commit('first.org.gpg', envelope(b'first'))
        sync.git(self.root, 'checkout', '--detach', self.base)
        theirs = self.commit('second.org.gpg', envelope(b'second'))
        sync.git(self.root, 'checkout', 'devices/test')
        merged = sync.merge_candidate(self.root, ours, theirs)
        self.assertFalse((self.root / 'second.org.gpg').exists())
        sync.apply(self.root, ours, merged)
        self.assertTrue((self.root / 'first.org.gpg').exists())
        self.assertTrue((self.root / 'second.org.gpg').exists())

    def test_apply_refuses_concurrent_save(self):
        target = self.commit('note.org.gpg', envelope(b'remote'))
        sync.git(self.root, 'reset', '--hard', self.base)
        (self.root / 'note.org.gpg').write_bytes(envelope(b'local'))
        with self.assertRaises(sync.SyncError): sync.apply(self.root, self.base, target)
        self.assertEqual((self.root / 'note.org.gpg').read_bytes(), envelope(b'local'))

    def test_history_check_catches_removed_plaintext(self):
        (self.root / 'leak.txt').write_text('private')
        sync.git(self.root, 'add', '-f', 'leak.txt')
        sync.git(self.root, 'commit', '-m', 'Bad')
        sync.git(self.root, 'rm', 'leak.txt')
        sync.git(self.root, 'commit', '-m', 'Remove')
        sync.validate_tree(self.root, 'HEAD')
        with self.assertRaises(sync.SyncError): sync.validate_history(self.root, 'HEAD')

    def test_staged_user_changes_preserved(self):
        (self.root / 'note.org.gpg').write_bytes(envelope(b'staged'))
        sync.git(self.root, 'add', 'note.org.gpg')
        before = sync.git(self.root, 'diff', '--cached', '--raw')
        with self.assertRaises(sync.SyncError): sync.snapshot(self.root)
        self.assertEqual(before, sync.git(self.root, 'diff', '--cached', '--raw'))

    def test_delete_is_snapshotted(self):
        (self.root / 'note.org.gpg').unlink()
        sync.snapshot(self.root)
        self.assertNotIn('note.org.gpg', sync.text(self.root, 'ls-files'))

    def test_symlink_rejected(self):
        (self.root / 'link.org.gpg').symlink_to('note.org.gpg')
        with self.assertRaises(sync.SyncError): sync.snapshot(self.root)

class NetworkFlowTests(unittest.TestCase):
    commit = SyncTests.commit
    def setUp(self):
        SyncTests.setUp(self)
        self.remote_temp = tempfile.TemporaryDirectory()
        self.remote = Path(self.remote_temp.name)
        sync.git(self.root, 'clone', '--bare', str(self.root), str(self.remote))
        sync.git(self.remote, 'config', 'user.name', 'Test')
        sync.git(self.remote, 'config', 'user.email', 'test@example.test')
        sync.git(self.remote, 'update-ref', 'refs/heads/main', self.base)
        sync.git(self.root, 'remote', 'add', 'origin', str(self.remote))
        self.calls = []

    def tearDown(self):
        self.remote_temp.cleanup()
        SyncTests.tearDown(self)

    def fake_gh(self, root, *args):
        self.calls.append(args)
        if args[:2] == ('pr', 'view'):
            return json.dumps({'headRefName': 'devices/test',
                               'headRefOid': sync.text(self.remote, 'rev-parse', 'devices/test'),
                               'baseRefName': 'main', 'isCrossRepository': False, 'state': 'OPEN'}).encode()
        if args[:2] == ('pr', 'list'):
            return json.dumps([{'number': 1, 'url': 'https://example.test/pr/1'}]).encode()
        if args[0] == 'api':
            tip = next(a[4:] for a in args if a.startswith('sha='))
            main = sync.text(self.remote, 'rev-parse', 'main')
            merged = sync.merge_candidate(self.remote, main, tip)
            self.assertIsNotNone(merged)
            sync.git(self.remote, 'update-ref', 'refs/heads/main', merged)
            return b'{"merged":true}'
        raise AssertionError(args)

    def test_full_sync_commits_pushes_merges_and_applies(self):
        (self.root / 'note.org.gpg').write_bytes(envelope(b'new'))
        with patch.object(sync, 'repo_name', return_value='test/notes'), patch.object(sync, 'gh', self.fake_gh):
            result = sync.sync(self.root)
        self.assertIn(result['status'], ('synced', 'apply'))
        if result['status'] == 'apply': sync.apply(self.root, result['from'], result['target'])
        self.assertEqual(sync.head(self.root), sync.text(self.remote, 'rev-parse', 'main'))

    def test_offline_sync_still_commits_saved_changes(self):
        (self.root / 'note.org.gpg').write_bytes(envelope(b'offline'))
        with patch.object(sync, 'repo_name', side_effect=sync.SyncError('Offline')):
            with self.assertRaises(sync.SyncError): sync.sync(self.root)
        self.assertNotEqual(sync.head(self.root), self.base)
        self.assertFalse(sync.git(self.root, 'diff', '--cached', '--name-only'))

    def test_conflicting_pr_is_left_open(self):
        sync.git(self.root, 'checkout', '-b', 'incoming', self.base)
        incoming = self.commit('note.org.gpg', envelope(b'incoming'))
        sync.git(self.root, 'push', 'origin', 'HEAD:main')
        sync.git(self.root, 'checkout', 'devices/test')
        (self.root / 'note.org.gpg').write_bytes(envelope(b'local'))
        with patch.object(sync, 'repo_name', return_value='test/notes'), patch.object(sync, 'gh', self.fake_gh):
            result = sync.sync(self.root)
        self.assertEqual(result['status'], 'conflict')
        self.assertEqual((self.root / 'note.org.gpg').read_bytes(), envelope(b'local'))
        self.assertEqual(sync.text(self.remote, 'rev-parse', 'main'), incoming)
        self.assertFalse(any(c[0] == 'api' for c in self.calls))

    def test_conflict_resolution_roundtrip(self):
        sync.git(self.root, 'checkout', '-b', 'incoming', self.base)
        self.commit('note.org.gpg', envelope(b'incoming'))
        sync.git(self.root, 'push', 'origin', 'HEAD:main')
        sync.git(self.root, 'checkout', 'devices/test')
        (self.root / 'note.org.gpg').write_bytes(envelope(b'local'))
        with patch.object(sync, 'repo_name', return_value='test/notes'), patch.object(sync, 'gh', self.fake_gh):
            self.assertEqual(sync.sync(self.root)['status'], 'conflict')
            resolution = sync.prepare(self.root, 1)
            self.assertEqual(resolution['files'], ['note.org.gpg'])
            work = Path(resolution['directory'])
            (work / 'note.org.gpg').write_bytes(envelope(b'resolved'))
            sync.git(work, 'add', 'note.org.gpg')
            self.assertEqual(sync.finish(self.root, 1)['status'], 'resolved')
            result = sync.sync(self.root)
            sync.apply(self.root, result['from'], result['target'])
            result = sync.sync(self.root)
            if result['status'] == 'apply': sync.apply(self.root, result['from'], result['target'])
            self.assertEqual((self.root / 'note.org.gpg').read_bytes(), envelope(b'resolved'))
            self.assertEqual(sync.head(self.root), sync.text(self.remote, 'rev-parse', 'main'))

if __name__ == '__main__': unittest.main()
