#!/usr/bin/env python3
"""Fail closed if the public build contains a file reserved for licensed assets."""
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
manifest = json.loads((root / 'tools/private-assets.json').read_text(encoding='utf-8'))['files']
for item in manifest:
    path = root / item
    if item.endswith('.svg'):
        if not path.is_file() or '<!-- goat-runner-placeholder-v1 -->' not in path.read_text(encoding='utf-8'):
            raise SystemExit(f'Not a public placeholder: {item}')
    elif item == 'scenes/goat_scml.tscn':
        if not path.is_file() or 'metadata/placeholder = "goat-runner-placeholder-v1"' not in path.read_text(encoding='utf-8'):
            raise SystemExit(f'Not the public goat scene: {item}')
    elif path.exists():
        raise SystemExit(f'Private-only file present: {item}')
print('Public placeholder assets verified.')
