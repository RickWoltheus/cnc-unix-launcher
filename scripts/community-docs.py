#!/usr/bin/env python3
import argparse
import csv
from datetime import date
import json
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[1]


def render():
    info = json.loads((ROOT / 'resources/community.json').read_text())
    names = [project['name'] for project in info['projects']]
    if len(names) != len(set(names)):
        raise ValueError('Credit project names must be unique.')
    for filename in ('mods.tsv', 'native-mods.tsv'):
        with (ROOT / 'manifests' / filename).open() as stream:
            for row in csv.reader(stream, delimiter='\t'):
                if row[1] not in names:
                    raise ValueError('Missing community credit for ' + row[1])
    for project in info['projects']:
        for field in ('url', 'contributorsURL'):
            if urlparse(project[field]).scheme != 'https':
                raise ValueError('Credit links must use HTTPS.')
    seen = set()
    for support in info['supportLinks']:
        if support['project'] not in names:
            raise ValueError('Support recipient must have a community credit.')
        for field in ('url', 'sourceURL'):
            if urlparse(support[field]).scheme != 'https':
                raise ValueError('Support links and their published sources must use HTTPS.')
        if support['url'] in seen:
            raise ValueError('Support links must be unique.')
        seen.add(support['url'])
        date.fromisoformat(support['verifiedOn'])
    text = f'# {info["title"]}\n\n{info["mission"]}\n\n{info["credit"]}\n\n'
    text += f'## {info["supportTitle"]}\n\n{info["supportDetail"]}\n\n[Support the launcher on Ko-fi](https://ko-fi.com/ricklemore).\n\n'
    for support in info['supportLinks']:
        text += f'- {support["project"]} — [{support["platform"]}]({support["url"]}). [Published funding links]({support["sourceURL"]}) (checked {support["verifiedOn"]}).\n'
    text += '\n'
    text += '## Engines, mods and tools\n\nProject contributor/team pages credit the people behind each project. Upstream credits also cover their own dependencies and earlier work.\n\n| Project | Contribution | People |\n| --- | --- | --- |\n'
    for project in info['projects']:
        text += f'| [{project["name"]}]({project["url"]}) | {project["role"]} | [Contributors / team]({project["contributorsURL"]}) |\n'
    repository = (ROOT / 'manifests/product.tsv').read_text().split('\t')[2]
    text += f'\n[C&C Unix Launcher contributors](https://github.com/{repository}/graphs/contributors).\n\n'
    text += '## Updating credits and support links\n\nCredits and support links live in `resources/community.json`. Verify each donation URL against the project’s own published funding links; include `sourceURL` and `verifiedOn`. Both launchers read the same resources. Preview documentation, then regenerate it:\n\n```sh\npython3 scripts/community-docs.py\npython3 scripts/community-docs.py --write\npython3 scripts/community-docs.py --check\n```\n'
    return text


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--write', action='store_true')
    mode.add_argument('--check', action='store_true')
    args = parser.parse_args()
    text = render()
    destination = ROOT / 'docs/community.md'
    if args.write:
        destination.write_text(text)
    elif args.check:
        if not destination.exists() or destination.read_text() != text:
            raise SystemExit('Community documentation is stale. Preview and regenerate it.')
        print('Community credits, published support links and documentation agree.')
    else:
        print(text, end='')
