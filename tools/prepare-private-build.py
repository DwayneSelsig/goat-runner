#!/usr/bin/env python3
"""Assemble a local Godot project with the separately stored licensed assets."""
import argparse
import json
import shutil
import tempfile
from pathlib import Path

project = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--assets', type=Path, default=project.parent / 'goat-runner-assets')
parser.add_argument('--output', type=Path, default=project.parent / 'goat-runner-build')
args = parser.parse_args()
assets = args.assets.resolve()
if args.output.is_symlink():
    parser.error('Output must not be a symlink')
output = args.output.resolve()
if output in (project, assets) or output in project.parents or output in assets.parents or project in output.parents or assets in output.parents:
    parser.error('Output must be separate from both the public project and private assets')
if output.is_symlink() or (output.exists() and not output.is_dir()):
    parser.error('Output must be a real directory')
manifest = json.loads((project / 'tools/private-assets.json').read_text(encoding='utf-8'))['files']
for item in manifest:
    path = Path(item)
    if path.is_absolute() or '..' in path.parts or not (assets / path).is_file():
        parser.error(f'Missing or invalid private file: {item}')
if output.exists() and any(output.iterdir()) and not (output / '.goat-runner-generated-build').is_file():
    parser.error('Output is not an empty or previously generated build; refusing to overwrite it')
output.parent.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory(prefix='.goat-runner-assemble-', dir=output.parent) as tmp:
    assembled = Path(tmp) / 'project'
    shutil.copytree(project, assembled, ignore=shutil.ignore_patterns('.git', '.godot', 'build', '__pycache__', '*.pyc'))
    for item in manifest:
        dest = assembled / item
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(assets / item, dest)
    (assembled / 'assets/placeholder-assets.txt').unlink()
    (assembled / '.goat-runner-generated-build').write_text('Generated local build; do not commit.\n', encoding='utf-8')
    if output.exists():
        shutil.rmtree(output)
    shutil.move(str(assembled), str(output))
print(f'Private build prepared at {output}; import or open project.godot with Godot 4.7.2.')
