#!/usr/bin/env python3
"""Prepare a notarized Sparkle release; publishing is an explicit operation."""
import argparse
import base64
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
SPARKLE = '{http://www.andymatuschak.org/xml-namespaces/sparkle}'
EMPTY_FEED = b'<?xml version="1.0" encoding="utf-8"?><rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"><channel><title>Window Peek</title></channel></rss>\n'


def run(*args, capture=False):
    result = subprocess.run([str(a) for a in args], cwd=ROOT, check=True,
                            text=True, stdout=subprocess.PIPE if capture else None)
    return result.stdout.strip() if capture else None


def api(path, payload=None):
    result = subprocess.run(['gh', 'api', path] + (['--method', 'PUT' if '/contents/' in path else 'POST', '--input', '-'] if payload else []),
                            input=json.dumps(payload) if payload else None,
                            text=True, capture_output=True, cwd=ROOT)
    if result.returncode:
        if payload is None and '(HTTP 404)' in result.stderr:
            return None
        raise RuntimeError(result.stderr.strip())
    return json.loads(result.stdout)


def read_feed(config):
    result = api(f"repos/{config['repository']}/contents/windowpeek/appcast.xml?ref={config['feedBranch']}")
    return (base64.b64decode(result['content']), result['sha']) if result else (EMPTY_FEED, None)


def validate_feed(data, config, archive=None):
    items = ET.fromstring(data).findall('./channel/item')
    if archive is None:
        return max((int(item.findtext(SPARKLE + 'version', '0')) for item in items), default=0)
    matching = [item for item in items if item.findtext(SPARKLE + 'version') == config['build']]
    if len(matching) != 1:
        raise RuntimeError('Appcast must contain exactly one entry for this build.')
    item = matching[0]
    enclosure = item.find('enclosure')
    expected_url = f"https://github.com/{config['repository']}/releases/download/windowpeek-v{config['version']}/{archive.name}"
    if (item.findtext(SPARKLE + 'shortVersionString') != config['version']
            or enclosure is None or enclosure.get('url') != expected_url
            or enclosure.get('length') != str(archive.stat().st_size)):
        raise RuntimeError('Appcast version, URL or archive length does not match.')
    run(ROOT / '.build/artifacts/sparkle/Sparkle/bin/sign_update', '--account',
        config['keychainAccount'], '--verify', archive, enclosure.get(SPARKLE + 'edSignature', ''))


def init_feed(config):
    if read_feed(config)[1]:
        return
    ref = f"repos/{config['repository']}/git/ref/heads/{config['feedBranch']}"
    if api(ref) is None:
        head = api(f"repos/{config['repository']}/git/ref/heads/main")['object']['sha']
        api(f"repos/{config['repository']}/git/refs",
            {'ref': f"refs/heads/{config['feedBranch']}", 'sha': head})
    api(f"repos/{config['repository']}/contents/windowpeek/appcast.xml", {
        'branch': config['feedBranch'], 'message': 'chore: initialize Window Peek update feed',
        'content': base64.b64encode(EMPTY_FEED).decode()})


def publish(config, stage, head):
    if run('git', 'status', '--porcelain', capture=True) or run('git', 'rev-parse', 'HEAD', capture=True) != head:
        raise RuntimeError('Source changed during preparation; review and prepare again.')
    manifest = json.loads((stage / 'manifest.json').read_text())
    archive = stage / manifest['archive']
    feed = (stage / 'appcast.xml').read_bytes()
    if manifest['head'] != head or manifest['dirty'] or manifest['config'] != config:
        raise RuntimeError('Prepared release must match the current clean commit and configuration.')
    for name, digest in manifest['sha256'].items():
        if hashlib.sha256((stage / name).read_bytes()).hexdigest() != digest:
            raise RuntimeError(f'Prepared file changed: {name}')
    validate_feed(feed, config, archive)
    live, sha = read_feed(config)
    if live == feed:
        print('This update is already published.')
        return
    if validate_feed(live, config) >= int(config['build']):
        raise RuntimeError('Live feed already contains this or a newer build; refusing rollback.')
    tag = f"windowpeek-v{config['version']}"
    repo = config['repository']
    release = api(f'repos/{repo}/releases/tags/{tag}')
    if release is None:
        run('gh', 'release', 'create', tag, '--repo', repo, '--target', head, '--draft',
            '--title', f"Window Peek {config['version']}", '--notes-file', stage / 'notes.md')
        release = api(f'repos/{repo}/releases/tags/{tag}')
    # A remote tag must resolve to this exact commit, including annotated tags.
    if api(f'repos/{repo}/commits/{tag}')['sha'] != head:
        raise RuntimeError('Existing release tag points to a different commit.')
    for name in (archive.name, archive.name + '.sha256'):
        asset = next((a for a in release['assets'] if a['name'] == name), None)
        digest = 'sha256:' + manifest['sha256'][name]
        if asset and asset.get('digest') != digest:
            raise RuntimeError(f'Remote asset differs; refusing to overwrite: {name}')
        if not asset:
            if not release['draft']:
                raise RuntimeError('Published release is missing an expected asset.')
            run('gh', 'release', 'upload', tag, stage / name, '--repo', repo)
    release = api(f'repos/{repo}/releases/tags/{tag}')
    for name in (archive.name, archive.name + '.sha256'):
        asset = next(a for a in release['assets'] if a['name'] == name)
        if asset.get('digest') != 'sha256:' + manifest['sha256'][name]:
            raise RuntimeError('Remote asset checksum verification failed.')
    if release['draft']:
        run('gh', 'release', 'edit', tag, '--repo', repo, '--draft=false', '--latest')
    # Only advertise the version after its assets are public. The contents SHA
    # provides optimistic locking against a concurrent feed publication.
    payload = {'branch': config['feedBranch'], 'message': f'chore: publish {tag} update feed',
               'content': base64.b64encode(feed).decode()}
    if sha:
        payload['sha'] = sha
    api(f'repos/{repo}/contents/windowpeek/appcast.xml', payload)
    if read_feed(config)[0] != feed:
        raise RuntimeError('Published update feed verification failed.')
    print(f"Published: https://github.com/{repo}/releases/tag/{tag}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--publish', action='store_true', help='build, notarize, publish release and feed')
    parser.add_argument('--resume', action='store_true', help='publish the already prepared, unchanged artifacts')
    parser.add_argument('--init-feed', action='store_true', help='create only the initial empty public update feed')
    parser.add_argument('--notary-profile', default='windowpeek-notary')
    args = parser.parse_args()
    config = json.loads((ROOT / 'Updates/config.json').read_text())
    if not re.fullmatch(r'\d+\.\d+\.\d+', config['version']) or not re.fullmatch(r'[1-9]\d*', config['build']):
        raise RuntimeError('Use a semantic version and a positive integer build number.')
    if args.init_feed:
        init_feed(config)
        print(config['feedURL'])
        return
    if args.resume and not args.publish:
        parser.error('--resume requires --publish')
    head = run('git', 'rev-parse', 'HEAD', capture=True)
    dirty = bool(run('git', 'status', '--porcelain', capture=True))
    if args.publish:
        remote = api(f"repos/{config['repository']}/git/ref/heads/main")
        if dirty or remote['object']['sha'] != head:
            raise RuntimeError('Commit and push reviewed changes to main before publishing.')
        init_feed(config)
    stage = ROOT / f"dist/release-{config['version']}"
    if not args.resume:
        live, _ = read_feed(config)
        if validate_feed(live, config) >= int(config['build']):
            raise RuntimeError('Increment version and build before preparing a new release.')
        notes = ROOT / f"Updates/{config['version']}.md"
        if not notes.is_file():
            raise RuntimeError(f'Write release notes first: {notes}')
        run('python3', '-B', ROOT / 'scripts/UpdateCheck/test_release.py')
        run('swift', 'test')
        run(ROOT / 'scripts/build-dmg.sh')
        arch = run('lipo', '-archs', ROOT / 'dist/Window Peek.app/Contents/MacOS/WindowPeek', capture=True).replace(' ', '-')
        archive = ROOT / f"dist/WindowPeek-{config['version']}-{arch}-Installer.dmg"
        run(ROOT / 'scripts/notarize-dmg.sh', args.notary_profile, archive)
        bins = ROOT / '.build/artifacts/sparkle/Sparkle/bin'
        if run(bins / 'generate_keys', '--account', config['keychainAccount'], '-p', capture=True) != config['publicKey']:
            raise RuntimeError('Keychain public key does not match the application.')
        with tempfile.TemporaryDirectory(dir=ROOT / 'dist', prefix='release-stage-') as temporary:
            work = Path(temporary)
            shutil.copy2(archive, work / archive.name)
            shutil.copy2(str(archive) + '.sha256', work / (archive.name + '.sha256'))
            shutil.copy2(notes, work / (archive.stem + '.md'))
            shutil.copy2(notes, work / 'notes.md')
            if ET.fromstring(live).findall('./channel/item'):
                (work / 'appcast.xml').write_bytes(live)
            prefix = f"https://github.com/{config['repository']}/releases/download/windowpeek-v{config['version']}/"
            run(bins / 'generate_appcast', '--account', config['keychainAccount'],
                '--download-url-prefix', prefix, '--maximum-deltas', '0', '--embed-release-notes', work)
            validate_feed((work / 'appcast.xml').read_bytes(), config, work / archive.name)
            hashes = {name: hashlib.sha256((work / name).read_bytes()).hexdigest()
                      for name in (archive.name, archive.name + '.sha256', 'appcast.xml', 'notes.md')}
            (work / 'manifest.json').write_text(json.dumps(dict(head=head, dirty=dirty, config=config,
                archive=archive.name, sha256=hashes), indent=2) + '\n')
            stage.mkdir(parents=True, exist_ok=True)
            for file in work.iterdir():
                if file.is_file():
                    shutil.copy2(file, stage / file.name)
        print(f'Prepared for review: {stage}')
    if args.publish:
        publish(config, stage, head)


if __name__ == '__main__':
    main()
