#!/usr/bin/env bash
set -euo pipefail
mkdir -p build/web
touch build/.gdignore
godot --version
godot --headless --editor --path . --import
for script in scripts/*.gd tests/*.gd; do
  godot --headless --path . --check-only --script "$script"
done
node tests/web_splash.cjs
godot --headless --path . --script tests/interface.gd
godot --headless --path . --script tests/smoke.gd
godot --headless --path . --fixed-fps 60 --script tests/jump.gd
godot --headless --path . --script tests/weather.gd
godot --headless --path . --script tests/landscape.gd
godot --headless --path . --fixed-fps 60 --script tests/obstacle_schedule.gd
godot --headless --path . --fixed-fps 60 --script tests/autoplay.gd
godot --headless --path . --export-release Web build/web/index.html
cp assets/splash-black-goats.svg assets/splash-background.svg build/web/
test -s build/web/index.html
test -s build/web/splash-black-goats.svg
test -s build/web/splash-background.svg

