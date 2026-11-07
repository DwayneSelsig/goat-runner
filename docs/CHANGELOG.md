# Changelog

Changes follow [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## Unreleased

### Changed

- Enlarged foreground corn and filled oversized gaps with additional existing plants.

- Varied foreground clusters using existing grasses, sprouts, lettuce, carrots, flowers, sunflowers and corn from the supplied SVG artwork.

- Sized open fence passages to their closed gate leaves with small latch clearances, filling excess space with fence panels and posts.

- Varied fence runs with normal and mirrored open leaves, posts and gates, including wider paired openings from the supplied farm SVG.

- Joined picket panels using their original rails and shared round posts, removing gaps and misaligned connecting lines.

- Replaced repeating background strips with seeded procedural hills, curved fields and clustered parallax decor; each retry creates a fresh landscape. The fence now uses white pickets from the supplied artwork at its existing location.
- Restored the Web preset to single-threaded export without cross-origin isolation headers.

- The goat walks in before the start prompt, and ducking uses the same sprite scale as running.

- Increased the running speed of the landscape and obstacles by 2.5 times.

- Expanded the game world to 1440 × 720 for more visible run-up.

- Updated the project and CI build to Godot 4.7.2 with matching export templates.

### Added

- Localized start, game-over and draggable settings menus, with collision reasons, score panels and editable touch controls with persistent layout and opacity.

- A reusable landscape scene, 27 reproducibly extracted environment SVGs, and scenery generation tests in CI.

- A score counter for cleared obstacles, reset on retry, and a locally saved high score.

- A feed-trough obstacle and game-over easter egg with eating animation and retry button.

- Supplied goat sprite animations for idle, running, ducking and collision.

- Scrolling emoji obstacles, collision detection and retry.

- Goat movement, a simple landscape, and a ready/running state.
- Web export, pull-request validation, and GitHub Pages deployment workflows.
- Project documentation and a headless smoke test.

- Rescaled foreground plants and allowed tall corn and sunflowers to overlap the lower path.

- Reduced foreground plant density while retaining varied crops and their scale.
