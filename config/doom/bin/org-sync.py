#!/usr/bin/env python3
"""Encrypted Org Git sync. Never decrypts files or writes incoming files during sync."""
import argparse
import contextlib
import fcntl
import json
import os
from pathlib import Path
import re
import socket
import subprocess
import sys
import tempfile

IGNORE = b'*\n!*/\n!*.org.gpg\n!.gitignore\n!.gitattributes\n'
ATTRIBUTES = b'*.org.gpg binary\n'
POLICY = {'.gitignore': IGNORE, '.gitattributes': ATTRIBUTES}
ENV = dict(os.environ, GIT_TERMINAL_PROMPT='0', GCM_INTERACTIVE='never', GH_PROMPT_DISABLED='1', GIT_LITERAL_PATHSPECS='1')

class SyncError(Exception):
    pass

def run(args, cwd, data=None, ok=(0,), env=None):
    p = subprocess.run(args, cwd=cwd, input=data, stdout=subprocess.PIPE,
                       stderr=subprocess.PIPE, env=env or ENV, timeout=90)
    if p.returncode not in ok:
        # Git/gh errors do not contain note contents, but avoid echoing arbitrary blob output.
        raise SyncError(p.stderr.decode(errors='replace').strip() or f'{args[0]} failed ({p.returncode})')
    return p

def git(root, *args, data=None, ok=(0,)):
    return run(['git', *args], root, data, ok).stdout

def text(root, *args):
    return git(root, *args).decode().strip()

def encrypted(data):
    """Accept binary OpenPGP session-key packets followed by one protected payload.

    This checks the envelope, not integrity/decryption, and deliberately rejects armor.
    """
    pos, tags = 0, []
    try:
        while pos < len(data):
            header = data[pos]; pos += 1
            if not header & 128:
                return False
            if header & 64:
                tag = header & 63
                while True:
                    n = data[pos]; pos += 1
                    partial = False
                    if n < 192:
                        length = n
                    elif n < 224:
                        length = ((n - 192) << 8) + data[pos] + 192; pos += 1
                    elif n == 255:
                        length = int.from_bytes(data[pos:pos+4], 'big'); pos += 4
                    else:
                        length = 1 << (n & 31); partial = True
                    if pos + length > len(data) or length == 0:
                        return False
                    pos += length
                    if not partial:
                        break
            else:
                tag, size = (header >> 2) & 15, header & 3
                if size == 3:
                    return False
                count = 1 << size
                if pos + count > len(data):
                    return False
                length = int.from_bytes(data[pos:pos+count], 'big'); pos += count
                if not length or pos + length > len(data):
                    return False
                pos += length
            tags.append(tag)
    except IndexError:
        return False
    return len(tags) >= 2 and all(t == 1 for t in tags[:-1]) and tags[-1] in (18, 20)

def validate_blob(path, mode, data):
    if mode != '100644':
        raise SyncError(f'Refusing non-regular or executable file: {path}')
    if path in POLICY:
        if data != POLICY[path]:
            raise SyncError(f'Repository policy differs: {path}')
    elif (not path.endswith('.org.gpg') or any(p.startswith('.') for p in Path(path).parts)
          or not encrypted(data)):
        raise SyncError(f'Refusing unapproved or unencrypted file: {path}')

def validate_tree(root, tree, cache=None):
    cache = cache if cache is not None else set()
    for entry in git(root, 'ls-tree', '-rz', tree).split(b'\0'):
        if not entry:
            continue
        meta, rawpath = entry.split(b'\t', 1)
        mode, kind, oid = meta.decode().split()
        path = os.fsdecode(rawpath)
        key = (path, mode, oid)
        if key not in cache:
            if kind != 'blob':
                raise SyncError('Submodules are not allowed')
            validate_blob(path, mode, git(root, 'cat-file', 'blob', oid))
            cache.add(key)

def validate_history(root, ref):
    cache = set()
    for commit in text(root, 'rev-list', ref).splitlines():
        validate_tree(root, commit, cache)

def head(root):
    return text(root, 'rev-parse', 'HEAD')

def ancestor(root, old, new):
    return run(['git', 'merge-base', '--is-ancestor', old, new], root, ok=(0, 1)).returncode == 0

def ref_exists(root, ref):
    return run(['git', 'rev-parse', '--verify', '--quiet', ref], root, ok=(0, 1)).returncode == 0

@contextlib.contextmanager
def lock(root):
    directory = Path(text(root, 'rev-parse', '--absolute-git-dir'))
    with (directory / 'org-sync.lock').open('w') as handle:
        try:
            fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise SyncError('Another Org sync operation is running')
        yield

def ensure_clean(root):
    if git(root, 'status', '--porcelain', '--untracked-files=normal'):
        raise SyncError('Saved files changed during sync; retry after the next snapshot')

def snapshot(root):
    if git(root, 'diff', '--cached', '--name-only'):
        raise SyncError('The Git index has staged changes; commit or unstage them first')
    for marker in ('MERGE_HEAD', 'CHERRY_PICK_HEAD', 'rebase-merge', 'rebase-apply'):
        if Path(text(root, 'rev-parse', '--git-path', marker)).exists():
            raise SyncError('Finish the existing Git operation before syncing')
    paths = set(filter(None, git(root, 'ls-files', '-z').split(b'\0')))
    paths.update(filter(None, git(root, 'ls-files', '--others', '--exclude-standard', '-z').split(b'\0')))
    for raw in paths:
        name = os.fsdecode(raw)
        if name not in POLICY and not name.endswith('.org.gpg'):
            raise SyncError(f'Unexpected repository file: {name}')
    if paths:
        git(root, 'add', '-A', '--pathspec-from-file=-', '--pathspec-file-nul',
            data=b'\0'.join(sorted(paths)) + b'\0')
    tree = text(root, 'write-tree')
    try:
        validate_tree(root, tree)
    except SyncError:
        git(root, 'reset', '--quiet')
        raise
    if git(root, 'diff', '--cached', '--name-only'):
        git(root, 'commit', '-m', 'Sync encrypted Org files')
    return head(root)

def gh(root, *args):
    return run(['gh', *args], root).stdout

def repo_name(root):
    name = text(root, 'config', 'org-sync.repository')
    info = json.loads(gh(root, 'repo', 'view', name, '--json', 'nameWithOwner,isPrivate'))
    if not info['isPrivate']:
        raise SyncError('Org sync requires a private GitHub repository')
    remote = text(root, 'remote', 'get-url', 'origin')
    expected = info['nameWithOwner']
    if remote not in (f'https://github.com/{expected}.git', f'https://github.com/{expected}',
                      f'git@github.com:{expected}.git', f'git@github.com:{expected}'):
        raise SyncError('Origin does not match the configured private repository')
    return expected

def fetch(root):
    git(root, 'fetch', '--prune', 'origin', '+refs/heads/*:refs/remotes/origin/*')

def merge_candidate(root, ours, theirs):
    if ancestor(root, theirs, ours):
        return ours
    if ancestor(root, ours, theirs):
        return theirs
    result = run(['git', 'merge-tree', '--write-tree', ours, theirs], root, ok=(0, 1))
    if result.returncode:
        return None
    tree = result.stdout.splitlines()[0].decode()
    validate_tree(root, tree)
    return text_commit(root, tree, ours, theirs)

def text_commit(root, tree, ours, theirs):
    return git(root, 'commit-tree', tree, '-p', ours, '-p', theirs,
               data=b'Merge encrypted Org changes\n').decode().strip()

def sync(root):
    branch = text(root, 'symbolic-ref', '--short', 'HEAD')
    if not branch.startswith('devices/'):
        raise SyncError('Org sync must run on a devices/ branch')
    original = snapshot(root)
    validate_history(root, original)
    repository = repo_name(root)
    fetch(root)
    own = f'refs/remotes/origin/{branch}'
    if ref_exists(root, own) and not ancestor(root, own, original):
        validate_history(root, own)
        target = merge_candidate(root, original, own)
        if not target:
            raise SyncError('This device branch diverged. Resolve it before publishing more changes')
        return {'status': 'apply', 'from': original, 'target': target, 'conflicts': []}
    git(root, 'push', 'origin', f'HEAD:refs/heads/{branch}')
    conflicts = []
    branches = text(root, 'for-each-ref', '--format=%(refname:strip=3)',
                    'refs/remotes/origin/devices/').splitlines()
    for device in branches:
        ref = 'refs/remotes/origin/' + device
        tip = text(root, 'rev-parse', ref)
        main = text(root, 'rev-parse', 'refs/remotes/origin/main')
        if ancestor(root, tip, main):
            continue
        validate_history(root, tip)
        validate_history(root, main)
        prs = json.loads(gh(root, 'pr', 'list', '--repo', repository, '--head', device,
                            '--base', 'main', '--state', 'open', '--json', 'number,url'))
        if not prs:
            gh(root, 'pr', 'create', '--repo', repository, '--base', 'main', '--head', device,
               '--title', 'Sync encrypted Org files', '--body',
               'Encrypted Org changes. Resolve content conflicts locally before merging.')
            prs = json.loads(gh(root, 'pr', 'list', '--repo', repository, '--head', device,
                                '--base', 'main', '--state', 'open', '--json', 'number,url'))
        pr = prs[0]
        if merge_candidate(root, tip, main) is None:
            conflicts.append(pr)
            continue
        response = json.loads(gh(root, 'api', '--method', 'PUT',
                                  f'repos/{repository}/pulls/{pr["number"]}/merge',
                                  '-f', f'sha={tip}', '-f', 'merge_method=merge'))
        if not response.get('merged'):
            raise SyncError('GitHub deferred the merge; the PR remains open')
        fetch(root)
    target = text(root, 'rev-parse', 'refs/remotes/origin/main')
    validate_history(root, target)
    candidate = merge_candidate(root, original, target)
    if candidate and candidate != original:
        return {'status': 'apply', 'from': original, 'target': candidate, 'conflicts': conflicts}
    return {'status': 'conflict' if conflicts else 'synced', 'conflicts': conflicts}

def apply(root, old, target):
    if head(root) != old:
        raise SyncError('Local HEAD changed; retry sync')
    ensure_clean(root)
    validate_tree(root, target)
    if not ancestor(root, old, target):
        raise SyncError('Incoming update is not a fast-forward')
    git(root, 'merge', '--ff-only', target)
    return {'status': 'applied'}

def prepare(root, number):
    repository = repo_name(root)
    pr = json.loads(gh(root, 'pr', 'view', str(number), '--repo', repository, '--json',
                       'headRefName,headRefOid,baseRefName,isCrossRepository,state'))
    if (pr['isCrossRepository'] or pr['baseRefName'] != 'main'
            or not pr['headRefName'].startswith('devices/') or pr['state'] != 'OPEN'):
        raise SyncError('Expected an open device PR in this repository')
    fetch(root)
    tip = text(root, 'rev-parse', 'refs/remotes/origin/' + pr['headRefName'])
    main = text(root, 'rev-parse', 'refs/remotes/origin/main')
    if tip != pr['headRefOid']:
        raise SyncError('PR changed during fetch; retry')
    validate_history(root, tip); validate_history(root, main)
    state_dir = Path(text(root, 'rev-parse', '--absolute-git-dir')) / 'org-sync-resolutions'
    state_dir.mkdir(mode=0o700, exist_ok=True)
    work = state_dir / str(number)
    if work.exists():
        raise SyncError(f'Resolution already exists at {work}; resume or finish it')
    git(root, 'worktree', 'add', '--detach', str(work), tip)
    run(['git', 'merge', '--no-commit', '--no-ff', main], work, ok=(0, 1))
    (state_dir / f'{number}.json').write_text(json.dumps({'branch': pr['headRefName'],
                                                       'head': tip, 'main': main}))
    return resolution_status(root, number)

def resolution_status(root, number):
    work = Path(text(root, 'rev-parse', '--absolute-git-dir')) / 'org-sync-resolutions' / str(number)
    files = sorted(set(os.fsdecode(e.split(b'\t', 1)[1]) for e in
                       git(work, 'ls-files', '-u', '-z').split(b'\0') if e))
    return {'status': 'resolution', 'directory': str(work), 'files': files}

def finish(root, number):
    repository = repo_name(root)
    state_dir = Path(text(root, 'rev-parse', '--absolute-git-dir')) / 'org-sync-resolutions'
    state = json.loads((state_dir / f'{number}.json').read_text())
    work = state_dir / str(number)
    if git(work, 'ls-files', '-u'):
        raise SyncError('Resolve and stage every conflict before finishing')
    validate_tree(work, text(work, 'write-tree'))
    if Path(text(work, 'rev-parse', '--git-path', 'MERGE_HEAD')).exists():
        git(work, 'commit', '-m', 'Resolve encrypted Org conflicts')
    validate_history(work, 'HEAD')
    # No force push. Concurrent device updates are retained and cause a safe rejection.
    git(work, 'push', 'origin', 'HEAD:refs/heads/' + state['branch'])
    return {'status': 'resolved', 'pr': number,
            'message': 'Resolution pushed. The next sync will merge the PR if it is still compatible.'}

def install_hooks(root):
    hooks = Path(text(root, 'rev-parse', '--absolute-git-dir')) / 'hooks'
    hooks.mkdir(exist_ok=True)
    import shlex
    command = shlex.quote(str(Path(__file__).resolve()))
    for name, action in [('pre-commit', 'check-index'), ('pre-push', 'check-push')]:
        path = hooks / name
        if path.exists():
            raise SyncError(f'Refusing to overwrite existing hook {name}')
        path.write_text(f'#!/bin/sh\nexec python3 {command} --root "$(git rev-parse --show-toplevel)" {action}\n')
        path.chmod(0o700)

def initialize(root, repository, device):
    if (root / '.git').exists():
        raise SyncError('Repository already exists')
    if not re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', repository):
        raise SyncError('Expected owner/repository')
    if not re.fullmatch(r'[A-Za-z0-9_-]+', device):
        raise SyncError('Device name must contain letters, numbers, underscores or hyphens')
    info = json.loads(gh(root, 'repo', 'view', repository, '--json', 'isPrivate'))
    if not info['isPrivate']:
        raise SyncError('Repository must be private')
    url = f'https://github.com/{repository}.git'
    if run(['git', 'ls-remote', url], root).stdout:
        raise SyncError('Initial setup requires an empty remote repository')
    for name, value in POLICY.items():
        if (root / name).exists() and (root / name).read_bytes() != value:
            raise SyncError(f'Existing {name} needs review')
    git(root, 'init', '-b', 'devices/' + device)
    git(root, 'config', 'org-sync.repository', repository)
    git(root, 'config', 'push.default', 'nothing')
    git(root, 'config', 'core.autocrlf', 'false')
    git(root, 'config', 'credential.https://github.com.helper', '!gh auth git-credential')
    git(root, 'remote', 'add', 'origin', url)
    for name, value in POLICY.items():
        (root / name).write_bytes(value)
    install_hooks(root)
    git(root, 'add', '--', '.gitignore', '.gitattributes')
    for path in root.rglob('*.org.gpg'):
        if not path.is_symlink() and not any(p.startswith('.') for p in path.relative_to(root).parts):
            git(root, 'add', '--', str(path.relative_to(root)))
    validate_tree(root, text(root, 'write-tree'))
    git(root, 'commit', '-m', 'Initialize encrypted Org notes')
    git(root, 'push', '--atomic', 'origin', 'HEAD:refs/heads/main',
        f'HEAD:refs/heads/devices/{device}')
    return {'status': 'initialized'}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--root', type=Path, required=True)
    sub = parser.add_subparsers(dest='action', required=True)
    for name in ('sync', 'check-index', 'check-push'):
        sub.add_parser(name)
    ap = sub.add_parser('apply'); ap.add_argument('old'); ap.add_argument('target')
    for name in ('prepare', 'resolution-status', 'finish'):
        sub.add_parser(name).add_argument('number', type=int)
    init = sub.add_parser('init'); init.add_argument('repository'); init.add_argument('--device', default=socket.gethostname().split('.')[0])
    args = parser.parse_args(); root = args.root.expanduser().resolve()
    try:
        if args.action == 'check-index':
            validate_tree(root, text(root, 'write-tree')); return
        if args.action == 'check-push':
            for line in sys.stdin:
                _, oid, _, _ = line.split()
                if set(oid) != {'0'}:
                    validate_history(root, oid)
            return
        if args.action == 'init':
            result = initialize(root, args.repository, args.device)
        else:
            with lock(root):
                if args.action == 'sync': result = sync(root)
                elif args.action == 'apply': result = apply(root, args.old, args.target)
                elif args.action == 'prepare': result = prepare(root, args.number)
                elif args.action == 'resolution-status': result = resolution_status(root, args.number)
                else: result = finish(root, args.number)
        print(json.dumps(result))
    except (SyncError, subprocess.TimeoutExpired, OSError, ValueError) as exc:
        print(json.dumps({'status': 'error', 'message': str(exc)}))
        sys.exit(1)

if __name__ == '__main__':
    main()
