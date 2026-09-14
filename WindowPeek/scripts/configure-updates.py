"""Write public Sparkle configuration into a staged bundle. Never reads private keys."""
import base64
import json
import plistlib
import sys
from pathlib import Path
root = Path(__file__).resolve().parents[1]
config = json.loads((root / 'Updates/config.json').read_text())
if len(base64.b64decode(config['publicKey'], validate=True)) != 32:
    raise SystemExit('Initialize the Sparkle signing key before building (see Updates/README.md).')
p = Path(sys.argv[1]) / 'Contents/Info.plist'
info = plistlib.loads(p.read_bytes())
info.update(CFBundleShortVersionString=config['version'], CFBundleVersion=config['build'],
    LSMinimumSystemVersion=config['minimumSystemVersion'],
    SUFeedURL=config['feedURL'], SUPublicEDKey=config['publicKey'],
    SUEnableAutomaticChecks=True, SUScheduledCheckInterval=86400,
    SUAutomaticallyUpdate=False, SUAllowsAutomaticUpdates=False,
    SUEnableSystemProfiling=False, SUVerifyUpdateBeforeExtraction=True)
p.write_bytes(plistlib.dumps(info))
