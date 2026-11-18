"""Bump and mirror logic of scripts/pins.py on copies of the real manifests. No network."""
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / 'scripts'))
import pins  # noqa: E402


def asset(owner, repo, tag, name, digest='a' * 64):
    return {'name': name, 'digest': f'sha256:{digest}',
            'browser_download_url': f'https://github.com/{owner}/{repo}/releases/download/{tag}/{name}'}


def release(tag, assets=(), prerelease=False):
    return {'tag_name': tag, 'draft': False, 'prerelease': prerelease, 'assets': list(assets)}


class PinChecks(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        manifests = Path(self.directory.name) / 'manifests'
        shutil.copytree(REPO / 'manifests', manifests)
        self.saved = pins.MANIFESTS, pins.POLICY, pins.api
        pins.MANIFESTS, pins.POLICY = manifests, manifests / 'mirror-sources.tsv'

    def tearDown(self):
        pins.MANIFESTS, pins.POLICY, pins.api = self.saved
        self.directory.cleanup()

    def pin(self, key):
        return next(pin for pin in pins.pins() if pin.key == key)

    def test_stable_wine_bump_changes_the_installed_version_marker(self):
        pin = self.pin('macos')
        pins.api = lambda path: [
            release('11.21', [asset('Gcenx', 'macOS_Wine_builds', '11.21', 'wine-devel-11.21-osx64.tar.xz')]),
            release('11.0_2', [asset('Gcenx', 'macOS_Wine_builds', '11.0_2', 'wine-stable-11.0_2-osx64.tar.xz')]),
            release('11.0_1'),
        ]
        update = pins.newer_release(pin)
        self.assertEqual((update['version'], update['archive']), ('11.0_2', 'wine-stable-11.0_2-osx64.tar.xz'))
        pins.apply(pin, update)
        bumped = self.pin('macos')
        self.assertEqual((bumped.version, bumped.sha), ('11.0_2', 'a' * 64))
        self.assertTrue(bumped.url.endswith('/11.0_2/wine-stable-11.0_2-osx64.tar.xz'))
        self.assertEqual(pins.lint(None), 0)

    def test_prereleases_are_skipped_unless_the_pin_is_one(self):
        pins.api = lambda path: [release('v0.4.0', [asset('athei', 'mach9', 'v0.4.0', 'wine-v0.4.0-macos-arm64.tar.xz')],
                                         prerelease=True), release('v0.3.1')]
        self.assertIsNone(pins.newer_release(self.pin('sage-metal-wine')))
        pins.api = lambda path: [release('v0.3.2', [asset('athei', 'mach9', 'v0.3.2', 'wine-v0.3.2-macos-arm64.tar.xz')]),
                                 release('v1.0.0'), release('v0.3.1')]
        self.assertEqual(pins.newer_release(self.pin('sage-metal-wine'))['archive'], 'wine-v0.3.2-macos-arm64.tar.xz')

    def test_source_links_move_only_when_every_link_names_the_version(self):
        self.assertFalse(pins.move_sources('sage-metal-wine', 'v0.3.1', 'v0.3.2'))
        self.assertTrue(pins.move_sources('generalsx-', '1.0.2', '1.0.6'))
        entry = pins.mirror_entry(self.pin('generalsx-linux-base'), pins.policy())
        self.assertEqual(entry['sources'], ['https://github.com/fbraz3/GeneralsX/archive/refs/tags/1.0.6.tar.gz'])

    def test_mirror_name_matches_the_launcher(self):
        for key in ('sage-metal-wine', 'openra-linux-ra', 'tdhd-macos'):
            pin = self.pin(key)
            launcher = subprocess.run(
                ['bash', '-c', 'unset GX_DOWNLOAD_MIRROR; RESOURCES="$1"; source "$1/scripts/downloads.sh"; download_sources "$2" "$3" "$4"',
                 'pins', str(REPO), pin.url, pin.sha, pin.archive],
                capture_output=True, text=True, check=True).stdout.split()
            self.assertEqual(launcher, [pin.url, pins.mirror_url(pin)])


if __name__ == '__main__':
    unittest.main()
