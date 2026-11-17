#!/usr/bin/env python3
"""Maintain the SHA-256 pinned downloads in manifests/.

lint      offline consistency checks (CI and tests/downloads.sh)
check     every pin still has a source whose file matches its SHA-256
updates   newer upstream releases and changed rolling installers
mirror    copy redistributable pins to this repository's download-mirror release
"""
import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request
from dataclasses import dataclass
from datetime import date
from pathlib import Path

# PINS_ROOT checks another checkout's manifests, such as a published release's.
ROOT = Path(os.environ.get('PINS_ROOT') or Path(__file__).resolve().parents[1]).resolve()
MANIFESTS = ROOT / 'manifests'
POLICY = MANIFESTS / 'mirror-sources.tsv'
TRACKS = 'pin-updates.tsv'
MIRROR_TAG = 'download-mirror'
GITHUB_ASSET = re.compile(r'^https://github\.com/([^/]+)/([^/]+)/releases/download/([^/]+)/([^/]+)$')
DATE = re.compile(r'\d{4}-\d{2}-\d{2}')
USER_AGENT = 'cnc-unix-launcher-pins'


@dataclass
class Pin:
    key: str
    manifest: str
    row: int
    version: str
    archive: str
    url: str
    sha: str
    # Column indexes of version, archive, URL and SHA-256; None when not stored.
    columns: tuple

    @property
    def rolling(self):
        return self.version == 'rolling' or bool(DATE.search(self.version))

    @property
    def mod(self):
        return self.key.startswith('mod/')


def rows(name):
    path = MANIFESTS / name
    return [line.split('\t') for line in path.read_text().splitlines() if line.strip()] if path.exists() else []


def pins():
    found = []
    for name in ('compatibility-packages.tsv', 'engine-packages.tsv'):
        for index, row in enumerate(rows(name)):
            found.append(Pin(row[0], name, index, row[1], row[2], row[3], row[4], (1, 2, 3, 4)))
    for index, row in enumerate(rows('native-packages.tsv')):
        for platform, url, sha in (('macos', 1, 2), ('linux', 3, 4)):
            tag = GITHUB_ASSET.match(row[url])
            found.append(Pin(f'{row[0]}-{platform}', 'native-packages.tsv', index, tag.group(3) if tag else '',
                             row[url].rsplit('/', 1)[1], row[url], row[sha], (None, None, url, sha)))
    for index, row in enumerate(rows('original-sources.tsv')):
        found.append(Pin(row[0], 'original-sources.tsv', index, row[1], row[2], row[3], row[4], (1, 2, 3, 4)))
    for mod in rows('mods.tsv'):
        for index, row in enumerate(rows(f'{mod[0]}.tsv')):
            url = row[2] if len(row) > 2 and row[2] else f'{mod[4]}/{row[0]}'
            found.append(Pin(f'mod/{mod[0]}/{row[0]}', f'{mod[0]}.tsv', index, mod[2], f'{mod[0]}/{row[0]}', url, row[1],
                             (None, None, 2 if len(row) > 2 else None, 1)))
    return found


def mirror_asset(pin):
    """Name of pin's copy in the mirror release; scripts/downloads.sh derives the same name."""
    return f'{pin.sha[:12]}-{Path(pin.archive).name}'


def mirror_url(pin):
    return f'https://github.com/{repository()}/releases/download/{MIRROR_TAG}/{mirror_asset(pin)}'


def policy():
    """Mirrorable pins: key (a trailing - matches a prefix), license, source URLs or -."""
    return [{'key': row[0], 'license': row[1], 'sources': [] if row[2] == '-' else row[2].split()}
            for row in rows(POLICY.name)]


def mirror_entry(pin, entries):
    return next((entry for entry in entries if pin.key == entry['key']
                 or (entry['key'].endswith('-') and pin.key.startswith(entry['key']))), None)


def source_asset(url):
    """Release asset name for a source archive URL; None for a page link."""
    if not re.search(r'\.(tar\.gz|tar\.xz|tgz|zip)$', url):
        return None
    return 'source-' + re.sub(r'[^A-Za-z0-9._-]+', '-', url.split('://', 1)[1])[-180:]


def repository():
    return rows('product.tsv')[0][2]


def request(url, method='GET', headers=None):
    headers = {'User-Agent': USER_AGENT, **(headers or {})}
    token = os.environ.get('GITHUB_TOKEN') or os.environ.get('GH_TOKEN')
    if token and url.startswith('https://api.github.com/'):
        headers['Authorization'] = f'Bearer {token}'
    return urllib.request.urlopen(urllib.request.Request(url, method=method, headers=headers), timeout=60)


def api(path):
    with request(f'https://api.github.com/{path}', headers={'Accept': 'application/vnd.github+json'}) as response:
        return json.load(response)


def reachable(url):
    """Status of the first byte of url: 'ok', 'missing' (404/410) or an error."""
    try:
        with request(url, headers={'Range': 'bytes=0-0'}) as response:
            response.read(1)
        return 'ok'
    except urllib.error.HTTPError as error:
        return 'missing' if error.code in (404, 410) else f'HTTP {error.code}'
    except (urllib.error.URLError, OSError) as error:
        return f'error: {getattr(error, "reason", error)}'


def fetch(url, target):
    digest = hashlib.sha256()
    with request(url) as response, open(target, 'wb') as stream:
        while chunk := response.read(1 << 20):
            digest.update(chunk)
            stream.write(chunk)
    return digest.hexdigest()


def sha_of(url):
    with tempfile.TemporaryDirectory() as directory:
        return fetch(url, Path(directory) / 'download')


def lint(args):  # noqa: ARG001
    problems = []
    all_pins = pins()
    seen = {}
    for pin in all_pins:
        if not re.fullmatch(r'[0-9a-f]{64}', pin.sha):
            problems.append(f'{pin.key}: SHA-256 is not 64 lowercase hex digits')
        if not pin.mod and not pin.url.startswith('https://'):
            problems.append(f'{pin.key}: runtime downloads must use HTTPS')
        if pin.archive in seen and seen[pin.archive] != pin.sha:
            problems.append(f'{pin.key}: cache name {pin.archive} is shared with {seen[pin.archive]}')
        seen[pin.archive] = pin.sha
    entries = policy()
    for entry in entries:
        if not any(mirror_entry(pin, [entry]) for pin in all_pins):
            problems.append(f'mirror-sources.tsv: {entry["key"]} matches no pin')
        if not entry['license']:
            problems.append(f'mirror-sources.tsv: {entry["key"]} needs a license')
    problems += [f'{pin.key}: Valve and mod files are never mirrored' for pin in all_pins
                 if (pin.mod or pin.rolling) and mirror_entry(pin, entries)]
    for script in sorted((ROOT / 'scripts').glob('*.sh')):
        for number, line in enumerate(script.read_text().splitlines(), 1):
            if re.search(r'\bdownload\s+\S+\s+"?https?://', line):
                problems.append(f'{script.name}:{number}: move this pinned URL into a manifest')
    for problem in problems:
        print(problem, file=sys.stderr)
    return 1 if problems else 0


def check(args):
    broken = 0
    for pin in pins():
        if args.only and not any(pin.key.startswith(prefix) for prefix in args.only):
            continue
        upstream = reachable(pin.url)
        if upstream == 'ok' and pin.rolling and not pin.mod:
            actual = sha_of(pin.url)
            upstream = 'ok' if actual == pin.sha else f'changed (now {actual[:12]})'
        if upstream == 'ok':
            print(f'ok       {pin.key}')
        elif not pin.mod and reachable(mirror_url(pin)) == 'ok':
            print(f'mirror   {pin.key}: publisher {upstream}; served from our mirror')
            print(f'::warning::{pin.key}: publisher {upstream}; only our mirror serves it')
        else:
            broken += 1
            print(f'BROKEN   {pin.key}: publisher {upstream}, no working mirror ({pin.url})')
            print(f'::error::{pin.key} cannot be downloaded: publisher {upstream}, no mirror')
    if broken:
        print(f'{broken} pinned download(s) cannot be installed.', file=sys.stderr)
    return 1 if broken else 0


def family(tag):
    """Tags of one release line: the same words and, for dotted versions, the same major."""
    tag = re.sub(r'(\d+)(?:[._]\d+)+', lambda match: match.group(1) + '.#', tag)
    return re.sub(r'(?<![\d.])\d+(?![\d.#])', '#', tag)


def tracks(pin, tag):
    """Whether tag is on the release line pin follows: pin-updates.tsv, else the pinned tag's family."""
    rule = next((row[1] for row in rows(TRACKS) if pin.key.startswith(row[0])), None)
    return re.fullmatch(rule, tag) is not None if rule else family(tag) == family(GITHUB_ASSET.match(pin.url).group(3))


def core(tag):
    return re.sub(r'^[^0-9]*', '', tag)


def replace_version(text, old_tag, new_tag):
    if old_tag in text:
        return text.replace(old_tag, new_tag)
    if core(old_tag) and core(old_tag) in text:
        return text.replace(core(old_tag), core(new_tag))
    return text


def newer_release(pin):
    owner, repo, tag, asset = GITHUB_ASSET.match(pin.url).groups()  # type: ignore[union-attr]
    listed = api(f'repos/{owner}/{repo}/releases?per_page=30')
    pinned = next((release for release in listed if release['tag_name'] == tag), None)
    accept_prerelease = bool(pinned and pinned['prerelease'])
    releases = [release for release in listed if not release['draft'] and tracks(pin, release['tag_name'])
                and (accept_prerelease or not release['prerelease'])]
    if not releases or releases[0]['tag_name'] == tag:
        return None
    release = releases[0]
    name = replace_version(asset, tag, release['tag_name'])
    match = next((item for item in release['assets'] if item['name'] == name), None)
    if not match:
        return {'tag': release['tag_name'], 'problem': f'no asset named {name}; update this pin by hand'}
    digest = (match.get('digest') or '').removeprefix('sha256:') or sha_of(match['browser_download_url'])
    version = replace_version(pin.version, tag, release['tag_name'])
    if version == pin.version and pin.version:
        version = release['tag_name']  # e.g. 11.0 for tag 11.0_1: installed runtimes must see the change
    return {'tag': release['tag_name'], 'url': match['browser_download_url'], 'sha': digest,
            'version': version,
            'archive': replace_version(pin.archive, tag, release['tag_name']), 'old_tag': tag}


def rolling_update(pin):
    actual = sha_of(pin.url)
    if actual == pin.sha:
        return None
    today = date.today().isoformat()
    return {'tag': today, 'url': pin.url, 'sha': actual, 'version': DATE.sub(today, pin.version),
            'archive': DATE.sub(today, pin.archive), 'old_tag': None}


def references(old_tag):
    if not old_tag or len(core(old_tag)) < 4:
        return []
    output = subprocess.run(['git', 'grep', '-l', '-F', old_tag, '--', '.', ':!manifests/*.tsv'],
                            cwd=ROOT, capture_output=True, text=True).stdout
    return output.split()


def apply(pin, update):
    path = MANIFESTS / pin.manifest
    table = rows(pin.manifest)
    row = table[pin.row]
    for column, field in zip(pin.columns, ('version', 'archive', 'url', 'sha')):
        if column is not None:
            row[column] = update[field]
    path.write_text(''.join('\t'.join(line) + '\n' for line in table))


def move_sources(key, old_tag, new_tag):
    """Point a mirror policy row's source links from old_tag to new_tag; False when none named it."""
    table = rows(POLICY.name)
    for row in table:
        if row[0] == key and row[2] != '-':
            moved = [replace_version(url, old_tag, new_tag) for url in row[2].split()]
            if any(new == old for new, old in zip(moved, row[2].split())):
                return False  # a link pinned to a commit needs a person to find the new one
            row[2] = ' '.join(moved)
            POLICY.write_text(''.join('\t'.join(line) + '\n' for line in table))
            return True
    return False


def updates(args):
    found = []
    for pin in pins():
        if pin.mod or (args.only and not any(pin.key.startswith(prefix) for prefix in args.only)):
            continue
        if args.kind and (args.kind == 'rolling') != pin.rolling:
            continue
        try:
            if pin.rolling:
                update = rolling_update(pin)
            elif GITHUB_ASSET.match(pin.url):
                update = newer_release(pin)
            else:
                continue
        except (urllib.error.URLError, OSError) as error:
            print(f'::warning::{pin.key}: could not check for updates ({error})')
            continue
        if update:
            found.append((pin, update))
    lines, listed = [], set()
    for pin, update in found:
        if 'problem' in update:
            lines.append(f'- **{pin.key}**: {update["tag"]} is out, but {update["problem"]}.')
            continue
        if args.apply:
            apply(pin, update)
        change = 'new checksum for the rolling installer' if pin.rolling else f'{update["old_tag"]} → {update["tag"]}'
        lines.append(f'- **{pin.key}**: {change} (`{update["sha"][:12]}`)')
        if update['old_tag'] not in listed:
            listed.add(update['old_tag'])
            lines += [f'  - also names `{update["old_tag"]}`: `{name}`' for name in references(update['old_tag'])]
        if (entry := mirror_entry(pin, policy())) and entry['sources']:
            if args.apply and update['old_tag'] and move_sources(entry['key'], update['old_tag'], update['tag']):
                lines.append('  - its source link in `manifests/mirror-sources.tsv` now names the new version')
            elif not any(core(update['tag']) in url for url in entry['sources']):
                lines.append('  - check its source link in `manifests/mirror-sources.tsv` before mirroring')
    report = '\n'.join(lines) if lines else 'All pins are current.'
    print(report)
    if args.report:
        Path(args.report).write_text(report + '\n')
    return 0


def mirror_notes(mirrored, all_pins, entries, previous=''):
    lines = [
        '# Download mirror',
        '',
        'Unmodified copies of open-source files that C&C Unix Launcher installs. The launcher downloads from',
        'the publisher first and uses these copies only when a pinned file is no longer available there.',
        'Either way, it installs a file only when its SHA-256 matches the pin in `manifests/`.',
        'Source archives are copied here too, so the corresponding source stays available with the binaries.',
        'Copies of earlier versions stay, so older launcher releases keep working.',
        '',
        '| File | Publisher | License | Source code | SHA-256 |',
        '| --- | --- | --- | --- | --- |',
    ]
    for pin in all_pins:
        entry = mirror_entry(pin, entries)
        if entry and mirror_asset(pin) in mirrored:
            sources = ', '.join(f'{url} (copy: `{source_asset(url)}`)' if source_asset(url) else url
                                for url in entry['sources']) or 'the file is the source archive'
            lines.append(f'| {mirror_asset(pin)} | {pin.url} | {entry["license"]} | {sources} | `{pin.sha}` |')
    # Rows for copies of earlier pins keep their license and source.
    listed = {line.split(' | ')[0] for line in lines}
    lines += [line for line in previous.splitlines() if line.startswith('| ') and not line.startswith('| File')
              and line.split(' | ')[0] not in listed and line.split(' | ')[0][2:] in mirrored]
    return '\n'.join(lines) + '\n'


def gh(*arguments, check=True):
    return subprocess.run(['gh', *arguments], cwd=ROOT, capture_output=True, text=True, check=check)


def mirror(args):
    repo, entries, all_pins = repository(), policy(), pins()
    view = gh('release', 'view', MIRROR_TAG, '--repo', repo, '--json', 'assets,body', check=False)
    release = json.loads(view.stdout) if view.returncode == 0 else {'assets': [], 'body': ''}
    existing = {asset['name'] for asset in release['assets']}
    planned = [pin for pin in all_pins if mirror_entry(pin, entries) and mirror_asset(pin) not in existing]
    sources = sorted({(source_asset(url), url) for pin in all_pins if (entry := mirror_entry(pin, entries))
                      for url in entry['sources'] if source_asset(url) and source_asset(url) not in existing})
    for pin in planned:
        print(f'binary   {mirror_asset(pin)} from {pin.url}')
    for name, url in sources:
        print(f'source   {name} from {url}')
    if not planned and not sources:
        print('Every mirrorable pin and its source archive is mirrored.')
    after = existing | {mirror_asset(pin) for pin in planned}
    if not args.upload:
        print('\nRelease notes preview:\n\n' + mirror_notes(after, all_pins, entries, release['body']))
        return 0
    if view.returncode:
        gh('release', 'create', MIRROR_TAG, '--repo', repo, '--title', 'Download mirror', '--latest=false',
           '--notes', 'Preparing mirror.')
    with tempfile.TemporaryDirectory() as directory:
        for name, url in sources:
            target = Path(directory) / name
            fetch(url, target)
            gh('release', 'upload', MIRROR_TAG, str(target), '--repo', repo)
            target.unlink()
        for pin in planned:
            target = Path(directory) / mirror_asset(pin)
            if fetch(pin.url, target) != pin.sha:
                print(f'{pin.key}: publisher file does not match its pin; not mirrored', file=sys.stderr)
                return 1
            gh('release', 'upload', MIRROR_TAG, str(target), '--repo', repo)
            target.unlink()
    with tempfile.NamedTemporaryFile('w', suffix='.md') as notes:
        notes.write(mirror_notes(after, all_pins, entries, release['body']))
        notes.flush()
        gh('release', 'edit', MIRROR_TAG, '--repo', repo, '--notes-file', notes.name)
    print(f'Mirrored {len(planned)} file(s) and {len(sources)} source archive(s).')
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest='command', required=True)
    commands.add_parser('lint').set_defaults(run=lint)
    command = commands.add_parser('check')
    command.add_argument('--only', nargs='*', help='pin key prefixes')
    command.set_defaults(run=check)
    command = commands.add_parser('updates')
    command.add_argument('--apply', action='store_true', help='rewrite manifests with the new pins')
    command.add_argument('--only', nargs='*', help='pin key prefixes')
    command.add_argument('--report', help='write the Markdown summary here')
    command.add_argument('--kind', choices=('rolling', 'release'), help="only Valve-style rolling checksums, or only versioned releases")
    command.set_defaults(run=updates)
    command = commands.add_parser('mirror')
    command.add_argument('--upload', action='store_true', help='upload to the GitHub release (default: preview)')
    command.set_defaults(run=mirror)
    args = parser.parse_args()
    return args.run(args)


if __name__ == '__main__':
    sys.exit(main())
