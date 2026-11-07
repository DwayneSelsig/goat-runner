# Goat Runner

A small browser endless runner built with Godot and the Compatibility renderer. After the goat walks in, press **Space** or **Up** to start and jump; hold longer to jump higher. Hold **Down** to duck, including in the air. Jump over bushes, puddles and hay bales; duck under the hanging sock. Most collisions end the run: press Space or Up to retry. If the goat finds a hay bale, it stops to eat; use the retry button to start again. Each cleared obstacle earns a point, and the local high score is saved between runs.

## Menus and touch controls

The start menu provides a start button and keyboard instructions. The game-over menu shows the score, the collision reason and a retry button. Score and high score appear at the top of the screen.

The touch buttons are visible by default at the lower right, with jump above duck. Open the gear in the upper-right corner to pause the game and edit settings. The menu opens over the gear; drag its title bar to move it and use the cross to close it. In settings, drag each touch button to move it or drag its lower-right resize icon to change its size independently. The opacity slider applies to both buttons; visibility, opacity, position and size are saved locally. Reset button layout restores the default positions and sizes.

Settings also offers English, Dutch and German, with the device language selected initially when supported and English otherwise. The chosen language is saved locally. Resetting the high score requires confirmation and leaves the current run's score intact.

The in-game instructions spell out direction keys because the Web font may not display arrow glyphs.

## Autoplay debug mode

Press **Ctrl+D** to open the debug menu, then select **Zelfspelen: uit** to turn autoplay on. It starts the game if needed and immediately selects the difficulty reached after 30 minutes: obstacles appear at the minimum 0.7-second interval. The goat chooses a slightly varied action point for each obstacle, uses shorter jumps for bushes and puddles, longer jumps for hay bales, and ducks under socks, including in the air.

Autoplay uses normal collisions and scoring, including the saved high score. It stops on a collision so you can inspect the result; retry starts a new manual run. Select **Zelfspelen: aan** to return control to the player during a run; the current high difficulty remains until retry. After game over, restart before enabling autoplay again. This tool helps observe long runs but does not prove every possible sequence is playable; see [testing](docs/TESTING.md).

## Run locally

The public project contains independent placeholder artwork and a minimal goat scene. Licensed artwork and animation data are private. To assemble the licensed local build, place `goat-runner-assets` beside this project and run `python tools/prepare-private-build.py`, then open `../goat-runner-build/project.godot` in Godot 4.7.2. Run the script again after changes. Use `--assets` and `--output` for other directories. The assembled build is private; do not commit its source assets. Public CI and Pages currently export placeholders.


Open `project.godot` in Godot 4.7.2 and run the project. Godot 4.7.2 is also the version used by CI and its matching Web export templates. See [testing](docs/TESTING.md) for a headless test and export.

## Publish on GitHub Pages

1. Commit the project and push it to the configured GitHub repository's `main` branch.
2. In the repository's **Settings → Pages**, select **GitHub Actions** as the build and deployment source.
3. If the `github-pages` environment has deployment restrictions, allow the release tags you want to publish.
4. Publish a release with a valid version tag and wait for its deployment workflow to finish. If it fails due to configuration or a transient error, fix the cause and rerun that release's workflow from **Actions**. If the code needs fixing, publish a new release from the corrected commit.
5. Open the URL displayed by the deployment job, normally `https://dwayneselsig.github.io/goat-runner/` without a custom domain.

Pushes and pull requests run validation and a Web export without deploying. Publishing a GitHub release or pre-release with a four-part tag such as `v1.2.3.4` validates the version, checks out that tag, and runs the same tests and export before deploying it to Pages. Each component must be between 0 and 65534. An invalid tag fails the deployment workflow; the GitHub release itself remains published. Publish a release with a valid tag to trigger a new deployment. Generated builds belong in the ignored `build/` directory, not Git. Web builds need a browser with WebAssembly and WebGL 2 support.
