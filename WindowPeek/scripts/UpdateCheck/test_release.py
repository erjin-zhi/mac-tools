"""Publication ordering and immutable-asset regression checks; no network calls."""
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('release', Path(__file__).parents[1] / 'release.py')
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


class PublicationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.stage = Path(self.temporary.name)
        self.config = dict(version='1.0.0', build='10', repository='owner/repo', feedBranch='updates')
        self.head = 'a' * 40
        self.files = {'update.dmg': b'archive', 'update.dmg.sha256': b'checksum',
                      'appcast.xml': b'new-feed', 'notes.md': b'notes'}
        for name, data in self.files.items():
            (self.stage / name).write_bytes(data)
        hashes = {name: hashlib.sha256(data).hexdigest() for name, data in self.files.items()}
        (self.stage / 'manifest.json').write_text(json.dumps(dict(head=self.head, dirty=False,
            config=self.config, archive='update.dmg', sha256=hashes)))
        self.remote = dict(draft=True, assets=[dict(name=name, digest='sha256:' + hashes[name])
            for name in ('update.dmg', 'update.dmg.sha256')])
        self.events = []

    def run_command(self, *args, **kwargs):
        if args[:2] == ('git', 'status'):
            return ''
        if args[:2] == ('git', 'rev-parse'):
            return self.head
        self.events.append(args)

    def api(self, path, payload=None):
        if '/releases/tags/' in path:
            return self.remote
        if '/git/ref/tags/' in path:
            return {'object': {'sha': self.head}}
        if '/commits/' in path:
            return dict(sha=self.head)
        self.events.append(('feed', payload))
        return {}

    def publish(self):
        with patch.object(release, 'run', side_effect=self.run_command), \
             patch.object(release, 'api', side_effect=self.api), \
             patch.object(release, 'read_feed', side_effect=[(b'old-feed', 'old-sha'), (b'new-feed', 'new-sha')]), \
             patch.object(release, 'validate_feed', return_value=9):
            release.publish(self.config, self.stage, self.head)

    def test_missing_tag_is_created_before_release_publication(self):
        original_api = self.api
        def request(path, payload=None):
            if '/git/ref/tags/' in path:
                return None
            if path.endswith('/git/refs'):
                self.events.append(('tag', payload))
                return {}
            return original_api(path, payload)
        with patch.object(self, 'api', side_effect=request):
            self.publish()
        self.assertEqual(self.events[0], ('tag', {'ref': 'refs/tags/windowpeek-v1.0.0', 'sha': self.head}))
        self.assertEqual(self.events[1][:3], ('gh', 'release', 'edit'))

    def test_existing_draft_is_found_without_creating_another(self):
        draft = dict(tag_name='v1', draft=True, id=42)
        with patch.object(release, 'api', side_effect=[None, [draft]]) as request:
            self.assertEqual(release.find_release('owner/repo', 'v1'), draft)
            self.assertEqual(request.call_args.args[0], 'repos/owner/repo/releases?per_page=100&page=1')

    def test_ambiguous_drafts_are_rejected(self):
        drafts = [dict(tag_name='v1', id=1), dict(tag_name='v1', id=2)]
        with patch.object(release, 'api', side_effect=[None, drafts]):
            with self.assertRaisesRegex(RuntimeError, 'Multiple release drafts'):
                release.find_release('owner/repo', 'v1')

    def test_assets_public_before_feed_update(self):
        self.publish()
        self.assertEqual(self.events[0][:3], ('gh', 'release', 'edit'))
        self.assertEqual(self.events[1][0], 'feed')
        self.assertEqual(self.events[1][1]['sha'], 'old-sha')

    def test_changed_remote_asset_is_never_overwritten_or_advertised(self):
        self.remote['assets'][0]['digest'] = 'sha256:wrong'
        with self.assertRaisesRegex(RuntimeError, 'refusing to overwrite'):
            self.publish()
        self.assertEqual(self.events, [])

    def test_modified_prepared_archive_is_rejected(self):
        (self.stage / 'update.dmg').write_bytes(b'changed')
        with self.assertRaisesRegex(RuntimeError, 'Prepared file changed'):
            self.publish()
        self.assertEqual(self.events, [])

    def test_resume_public_release_only_updates_feed(self):
        self.remote['draft'] = False
        self.publish()
        self.assertEqual([event[0] for event in self.events], ['feed'])

    def test_missing_asset_in_public_release_is_not_silently_repaired(self):
        self.remote['draft'] = False
        self.remote['assets'].pop()
        with self.assertRaisesRegex(RuntimeError, 'missing an expected asset'):
            self.publish()
        self.assertEqual(self.events, [])


if __name__ == '__main__':
    unittest.main()
