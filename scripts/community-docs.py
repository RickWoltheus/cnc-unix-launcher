#!/usr/bin/env python3
import argparse
import csv
from datetime import date
from decimal import Decimal
import json
from pathlib import Path
import re
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[1]


def render():
    info = json.loads((ROOT / 'resources/community.json').read_text())
    ledger = json.loads((ROOT / 'resources/donations.json').read_text())
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
    date.fromisoformat(ledger['lastUpdated'])
    seen = set()
    totals = {}
    rows = []
    for donation in ledger['donations']:
        date.fromisoformat(donation['date'])
        if donation['id'] in seen:
            raise ValueError('Donation IDs must be unique.')
        seen.add(donation['id'])
        if donation['project'] not in names:
            raise ValueError('Donation recipient must have a community credit.')
        if not re.fullmatch(r'[0-9]+\.[0-9]{2}', donation['amount']) or Decimal(donation['amount']) <= 0:
            raise ValueError('Record a positive amount as a decimal string, e.g. 25.00.')
        currency = donation['currency']
        if not re.fullmatch(r'[A-Z]{3}', currency):
            raise ValueError('Use a three-letter currency code.')
        totals[currency] = totals.get(currency, Decimal(0)) + Decimal(donation['amount'])
        evidence = donation.get('evidenceURL')
        if evidence and urlparse(evidence).scheme != 'https':
            raise ValueError('Public donation records must use HTTPS.')
        record = f'[Public record]({evidence})' if evidence else 'Not published'
        rows.append(f'| {donation["date"]} | {donation["project"]} | {donation["amount"]} {currency} | {record} |')
    text = f'# {info["title"]}\n\n{info["mission"]}\n\n{info["credit"]}\n\n'
    text += f'## Support and onward donations\n\n{info["donationPolicy"]}\n\n[Support the launcher on Ko-fi](https://ko-fi.com/ricklemore).\n\n'
    text += f'**{len(rows)} onward donations recorded.** Ledger updated: {ledger["lastUpdated"]}.\n\n{info["ledgerDetail"]}\n\n'
    if rows:
        text += '| Date | Recipient | Amount | Evidence |\n| --- | --- | --- | --- |\n' + '\n'.join(rows) + '\n\n'
        text += 'Recorded totals: ' + ', '.join(f'{total:.2f} {currency}' for currency, total in sorted(totals.items())) + '. Currencies are not converted or combined.\n\n'
    else:
        text += info['emptyLedger'] + '\n\n'
    text += '## Engines, mods and tools\n\nProject contributor/team pages credit the people behind each project. Upstream credits also cover their own dependencies and earlier work.\n\n| Project | Contribution | People |\n| --- | --- | --- |\n'
    for project in info['projects']:
        text += f'| [{project["name"]}]({project["url"]}) | {project["role"]} | [Contributors / team]({project["contributorsURL"]}) |\n'
    repository = (ROOT / 'manifests/product.tsv').read_text().split('\t')[2]
    text += f'\n[C&C Unix Launcher contributors](https://github.com/{repository}/graphs/contributors).\n\n'
    text += '## Updating the record\n\nMaintain `resources/donations.json` manually. Add an entry only after a donation has actually been made: a unique `id`, `date` (YYYY-MM-DD), credited `project`, `amount` (decimal string), `currency` (three-letter code), and optional `evidenceURL` or null. Update `lastUpdated`. Public evidence must omit payment details and private donor information. This record tracks onward donations, not individual Ko-fi supporters or the account balance.\n\nCredits live in `resources/community.json`. Both launchers read the same files. Preview the resulting documentation, then update it:\n\n```sh\npython3 scripts/community-docs.py\npython3 scripts/community-docs.py --write\npython3 scripts/community-docs.py --check\n```\n\nThe app bundles the ledger available when its release was built. Its public-record link opens this document for newer entries.\n'
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
        print('Community credits, donation ledger and documentation agree.')
    else:
        print(text, end='')
