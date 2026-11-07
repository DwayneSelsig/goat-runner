#!/usr/bin/env bash
set -euo pipefail
version=4.7.2
release="${version}-stable"
base="https://github.com/godotengine/godot-builds/releases/download/${release}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
curl --fail --location --retry 3 "$base/Godot_v${release}_linux.x86_64.zip" -o "$tmp/godot.zip"
curl --fail --location --retry 3 "$base/Godot_v${release}_export_templates.tpz" -o "$tmp/templates.zip"
unzip -q "$tmp/godot.zip" -d "$tmp/editor"
mkdir -p "$HOME/.local/bin" "$HOME/.local/share/godot/export_templates/${version}.stable"
install -m 755 "$tmp/editor/Godot_v${release}_linux.x86_64" "$HOME/.local/bin/godot"
unzip -q "$tmp/templates.zip" 'templates/*' -d "$tmp"
cp -a "$tmp/templates/." "$HOME/.local/share/godot/export_templates/${version}.stable/"
echo "$HOME/.local/bin" >> "$GITHUB_PATH"
