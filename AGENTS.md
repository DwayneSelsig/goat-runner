# Development instructions

- Public assets are independent placeholders. Keep licensed artwork, the SCML and the generated goat scene private. Assemble the original visual assets with `tools/prepare-private-build.py` and `tools/private-assets.json`.


- Read `docs/MVP.md` and relevant entries in `docs/DECISIONS.md` before implementing features.
- Preserve the existing Godot project and Compatibility renderer; maintain Web export compatibility. Use Godot 4.7.2 and matching templates in Actions unless a version change is agreed.
- Use typed GDScript where appropriate, native Godot physics and reusable scenes. Keep assets, scenes, scripts, tests and documentation in their respective directories.
- In the private build, goat visuals use the supplied SCML and its SVG part assets; the standalone `assets/characters/goat/blackgoat.svg` was removed as unused. The agreed MVP now includes emoji obstacles and collision/retry. Supplied spritesheets are approved for goat animations. The feed-trough eating easter egg is approved. Consult the user before adding scoring or additional easter eggs.
- Perform straightforward changes independently. Consult the user before significant design changes or replacing suitable built-in engine functionality with custom systems; do not ask approval for each file edit.
- Keep relevant documentation accurate and concise; record consequential decisions and significant deviations.
- Validate imports, scripts, available tests and Web export when possible. Report checks that could not be run; never claim unperformed gameplay testing.
- Keep PR validation and main-branch Pages deployment working, use matching editor and export templates, and avoid committing generated builds. Keep Web export single-threaded unless a change is justified.
