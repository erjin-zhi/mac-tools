#!/usr/bin/env python3
"""Exercise the real Sparkle installer against isolated, signed fixture apps."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import tempfile
import threading
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]


def run(*args, capture=False):
    return subprocess.run([str(a) for a in args], check=True, text=True,
                          stdout=subprocess.PIPE if capture else subprocess.DEVNULL,
                          stderr=subprocess.PIPE).stdout


class QuietHandler(SimpleHTTPRequestHandler):
    def log_message(self, *args):
        pass


def main():
    config = json.loads((ROOT / 'Updates/config.json').read_text())
    framework = ROOT / 'dist/Window Peek.app/Contents/Frameworks/Sparkle.framework'
    if not framework.is_dir():
        raise SystemExit('Run scripts/build-app.sh first.')
    identities = run('security', 'find-identity', '-v', '-p', 'codesigning', capture=True)
    identity = re.search(r'([0-9A-F]{40}) "Developer ID Application:', identities).group(1)
    with tempfile.TemporaryDirectory(prefix='windowpeek-update-check-') as temporary:
        work = Path(temporary)
        server = ThreadingHTTPServer(('127.0.0.1', 0), partial(QuietHandler, directory=work))
        threading.Thread(target=server.serve_forever, daemon=True).start()
        base = f'http://127.0.0.1:{server.server_port}'
        binary = work / 'UpdateCheck'
        run('clang', '-fobjc-arc', '-framework', 'AppKit',
            '-framework', 'Sparkle', '-F', framework.parent, '-Wl,-rpath,@executable_path/../Frameworks',
            ROOT / 'scripts/UpdateCheck/main.m', '-o', binary)
        try:
            for scenario in ('install', 'invalid-signature', 'no-update', 'empty-feed', 'missing-feed'):
                folder = work / scenario
                folder.mkdir()
                result = folder / 'result.txt'
                bundle_id = f'local.windowpeek.updatecheck.{uuid.uuid4().hex}'
                installed = folder / 'installed/Update Check.app'
                incoming = folder / 'incoming/Update Check.app'
                info = dict(CFBundleExecutable='UpdateCheck', CFBundleIdentifier=bundle_id,
                    CFBundleName='Update Check', CFBundlePackageType='APPL', LSUIElement=True,
                    LSMinimumSystemVersion='14.0', CFBundleVersion='1', CFBundleShortVersionString='1.0',
                    SUFeedURL=f'{base}/{scenario}/appcast.xml', SUPublicEDKey=config['publicKey'],
                    SUEnableAutomaticChecks=False, SUAllowsAutomaticUpdates=False,
                    SUVerifyUpdateBeforeExtraction=True, TestResultPath=str(result),
                    NSAppTransportSecurity={'NSAllowsLocalNetworking': True})
                if scenario == 'missing-feed':
                    info['SUFeedURL'] = f'{base}/missing.xml'
                for app, version in ((installed, '1'), (incoming, '2')):
                    (app / 'Contents/MacOS').mkdir(parents=True)
                    (app / 'Contents/Frameworks').mkdir()
                    shutil.copy2(binary, app / 'Contents/MacOS/UpdateCheck')
                    run('ditto', framework, app / 'Contents/Frameworks/Sparkle.framework')
                    info['CFBundleVersion'] = version
                    info['CFBundleShortVersionString'] = version + '.0'
                    (app / 'Contents/Info.plist').write_bytes(plistlib.dumps(info))
                    run('codesign', '--force', '--sign', identity, '--options', 'runtime',
                        '--timestamp=none', app)
                    run('codesign', '--verify', '--deep', '--strict', app)
                archive = folder / 'update.zip'
                run('ditto', '-c', '-k', '--keepParent', incoming, archive)
                signature = run(ROOT / '.build/artifacts/sparkle/Sparkle/bin/sign_update',
                    '--account', config['keychainAccount'], '-p', archive, capture=True).strip()
                if scenario == 'invalid-signature':
                    # A syntactically valid signature belonging to different bytes.
                    signature = 'A' * 86 + '=='
                version = '1' if scenario == 'no-update' else '2'
                (folder / 'appcast.xml').write_text(f'''<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"><channel>
<title>Update Check</title><item><title>{version}.0</title><sparkle:version>{version}</sparkle:version>
<sparkle:shortVersionString>{version}.0</sparkle:shortVersionString>
<enclosure url="{base}/{scenario}/update.zip" length="{archive.stat().st_size}" type="application/octet-stream" sparkle:edSignature="{signature}"/>
</item></channel></rss>''')
                if scenario == 'empty-feed':
                    (folder / 'appcast.xml').write_text('<rss version="2.0"><channel><title>Update Check</title></channel></rss>')
                # Remove the source app to make the installed copy the only launch target.
                shutil.rmtree(incoming.parent)
                with (folder / 'process.log').open('w') as log:
                    process = subprocess.Popen([str(installed / 'Contents/MacOS/UpdateCheck')],
                                               stdout=log, stderr=log)
                    try:
                        deadline = time.monotonic() + 90
                        while not result.exists() and time.monotonic() < deadline:
                            time.sleep(0.2)
                        outcome = result.read_text() if result.exists() else 'timeout'
                        if scenario == 'install':
                            assert outcome == 'installed-and-relaunched', outcome
                            assert plistlib.loads((installed / 'Contents/Info.plist').read_bytes())['CFBundleVersion'] == '2'
                        elif scenario == 'invalid-signature':
                            assert outcome.startswith('error:4005:') and 'Code=3002' in outcome, outcome
                        elif scenario in ('no-update', 'empty-feed'):
                            assert outcome == 'no-update', outcome
                        else:
                            assert outcome.startswith('error:'), outcome
                        if scenario != 'install':
                            assert plistlib.loads((installed / 'Contents/Info.plist').read_bytes())['CFBundleVersion'] == '1'
                        print(f'PASS {scenario}', flush=True)
                    finally:
                        if process.poll() is None:
                            process.terminate()
                        process.wait(timeout=10)
                        # Fixture-only preferences; never touch Window Peek defaults.
                        subprocess.run(['defaults', 'delete', bundle_id], capture_output=True)
                        shutil.rmtree(Path.home() / 'Library/Caches' / bundle_id, ignore_errors=True)
        finally:
            server.shutdown()


if __name__ == '__main__':
    main()
