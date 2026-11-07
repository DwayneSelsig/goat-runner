# Testing

## Local validation

With Godot 4.7.2 and matching export templates installed:

```sh
godot --headless --editor --path . --import
godot --headless --path . --script tests/interface.gd
godot --headless --path . --script tests/smoke.gd
godot --headless --path . --fixed-fps 60 --script tests/jump.gd
godot --headless --path . --script tests/weather.gd
godot --headless --path . --script tests/landscape.gd
godot --headless --path . --fixed-fps 60 --script tests/obstacle_schedule.gd
godot --headless --path . --fixed-fps 60 --script tests/autoplay.gd
mkdir -p build/web
godot --headless --path . --export-release Web build/web/index.html
```

Serve `build/web` over HTTP, for example `python -m http.server --directory build/web`, and open the served page in a WebGL 2 browser. For the repository-subpath check, serve the export from a `goat-runner/` subdirectory and visit that path. Check browser console errors as well as loading and scaling.

In the running game, verify the walk-in, idle scene, start, scrolling, short and held jumps, no second jump in midair, landing and jumping again, and ducking both on the ground and in the air. Verify ducking does not affect jump velocity and the duck animation plays, and walk-in, idle, running and collision animations match the game state. Check that jumping clears the bushes, puddle and hay bale, ducking clears the sock, a bush or puddle collision stops the run, the puddle rim is walkable and the goat ends at its center at normal ground height, a sock collision plays the caught animation and holds its final pose, and Space/up retries. At the hay bale verify the eating animation, ignored gameplay keys, and retry button. Verify each cleared obstacle adds one point, a collision does not, retry resets the score, and the high score survives a restart. Resize the browser and confirm aspect-preserving scaling.

Use Ctrl+D to open the debug menu. Check that the zoom button cycles through the goat's eye, tail and normal view, following the animated parts. The weather button toggles a scrollable view of the last downloaded response, or a waiting message before one arrives. Open **Weer instellen**, enable manual weather and check each slider and switch, including combined rain and snow. Disable manual weather to restore live conditions; retry resets manual mode. Enable **Zelfspelen: uit** and check that the game starts immediately at the 30-minute difficulty, jumps and ducks, and stops visibly on collision. Toggle it off during a run to verify manual control returns while difficulty remains high; after a collision, retry and confirm autoplay is off. Autoplay scores count toward the local high score. Check these controls in the browser as well.

## Automation

Pushes, pull requests and Pages deployments run `tools/build-web.sh` with Godot 4.7.2 and matching templates. Published releases also validate their four-part version tag and build that tag before deploying. The script imports resources, checks each script, runs the interface, smoke, jump, weather, landscape, obstacle scheduling and autoplay tests, and exports the Web build. The smoke test covers scene and AnimationPlayer loading, start, jumping, landing, the duck hitbox, sock collision/avoidance, score counting and high-score persistence; it does not replace interactive browser testing.

## Local results (2026-10-31)

- Godot 4.7.2 imported the project and goat SVG, parsed the scripts, and passed the headless smoke test. The sandbox prevented writes to Godot's user log/editor settings and access to the system certificate store; these warnings did not prevent those checks.
- A headless Web export was attempted but could not run because matching 4.7.2 export templates were not installed. The matching templates were not available locally.
- Interactive gameplay, browser loading, repository-subpath hosting, GitHub Actions and a Pages deployment have not yet been verified.

The headless smoke test also checks the feed-trough collision, transition to looping eating, ignored gameplay input and retry button visibility. The assembled goat scene was imported and the headless smoke test verified walk-in, idle, run, duck and collision animation selection, duck pose restoration, and the eating transition. Rendered idle, duck, collision, eating and running poses were inspected; animated motion, interactive gameplay and Web rendering still need visual testing. Animation timings follow the supplied spritesheets; articulated poses are approximations.

## SCML conversion validation

The converter was rerun and produced byte-identical output. Godot 4.7.2 imported the scene, parsed the scripts and passed the smoke test, including animation availability, target paths, game states and the eating transition. Rendered samples of idle, run, charge, die and eating were inspected alongside the supplied spritesheets; this is not a frame-by-frame equivalence proof. The Web export could not be completed locally because the matching 4.7.2 templates are absent. Interactive gameplay and browser testing remain outstanding.

## Score validation (2026-10-31)

Godot 4.7.2 imported the project, passed the headless smoke test including score and high-score checks, and exported the Web build. The sandbox prevented editor settings and certificate store access. Interactive gameplay and browser persistence were not checked.

## Weather validation

The weather test uses fixed responses to check conditions, transitions, failure handling, refresh interval and scene reload persistence. For browser validation, check that the Open-Meteo request succeeds, retry preserves the weather, and gameplay remains readable in different conditions.

## Farm environment validation (2026-11-01)

Godot 4.7.2 imported the extracted SVGs, passed the headless smoke and weather tests, and exported the Web build. The sandbox blocked access to editor settings, user logs and the system certificate store. Interactive gameplay, visual scrolling and browser weather and Web rendering were not verified.

## Farm seam and scale validation (2026-11-01)

Godot 4.7.2 passed the headless smoke and weather tests and exported the Web build. A rendered still at a shifted scroll position was inspected for seams and fence coverage. Interactive movement and browser rendering remain unverified.

## Farm obstacle validation (2026-11-01)

Godot 4.7.2 imported the extracted props and passed the smoke and weather tests, including bush cycling and the hay-bale eating collision. The Web export completed. The extracted artwork was visually inspected; interactive gameplay and browser rendering remain unverified.

## Separate head and body collisions (2026-11-01)

The headless smoke test checks ground-obstacle collisions with each goat shape and standing after the head passes the clothesline while the body is still underneath. It also checks ducking under and being caught by the line. Interactive gameplay and browser rendering remain unverified.

## Obstacle pacing (2026-11-01)

The scheduling test checks the warmup, monotonic bounded progression through 60 minutes, and all 16 ordered obstacle pairs at the minimum interval using Godot physics, with shortened jump holds and ducking. This is not a proof for every longer sequence or a substitute for human playtesting.

## Autoplay debug tool (2026-11-01)

The automated test starts autoplay at maximum difficulty, runs five seeded sequences for 60 simulated seconds each, and checks that disabling it releases the controls. Visual landscape processing is disabled in this test; landscape behavior is tested separately. The controller uses normal collision handling, so a failure stops the run. This sampling cannot prove every random sequence is survivable; interactive debug-menu and browser testing remain necessary.

## Puddle sinking (2026-11-01)

The smoke test checks the walkable rim, water collision, death animation and final pose-adjusted position at ground height. The scheduling and autoplay tests cover obstacle sequences with the larger puddle. Interactive animation and browser rendering still need checking.


## Procedural landscape (2026-11-01)

- Godot 4.7.2 imported the decor and passed every script check plus the smoke, weather, landscape, obstacle scheduling and five-seed autoplay tests. The new landscape test checks deterministic seeds, different-seed variation, matching terrain/field boundaries, bounded caches across over one million pixels of scrolling, stable eviction/revisit, decor bounds and proportions, independent gameplay randomness, and run/stop behavior.
- Rerunning the extractor produced byte-identical SVGs and left the supplied source unchanged. All 27 SVGs rendered with transparent margins on every side of their crop.
- Native Compatibility renders were inspected at two fixed seeds and multiple fractional scroll positions, plus day, night, fog, rain and snow. A rendered integration run checked entrance, start and scrolling, normal obstacle collision, stopped scrolling, and actual scene-reload retry with a new seed. Still frames from ready, running, collision and retry were inspected; this was automated input, not manual gameplay testing.
- A single-threaded Web export succeeded with the matching official 4.7.2 no-threads templates. Headless Edge loaded and rendered the actual game at `/goat-runner/`, served without COOP/COEP headers. A temporary HTTP test harness waited for the engine startup promise before capturing the frame and recorded no game JavaScript errors during startup; the exported files were unchanged. Manual browser controls, interactive resizing, browser weather transitions and deployed GitHub Pages remain unverified: the browser-control connector was unavailable and native UI access timed out.
- The native renderer reported shader initialization errors but produced the inspected frames. The sandbox also denied the native system certificate store; live native weather retrieval was not verified. Temporary tools, templates, logs, screenshots and exports are under ignored `build/`; the build script creates `.gdignore` there to exclude them from Godot imports.

To reproduce visual checks, set the landscape instance's `landscape_seed` to a nonzero value (for example 47123), inspect before and during scrolling, and repeat with another seed. Leave it at zero for fresh scenery on each retry. Check the fence at its existing position, clear space around goat/obstacles, no crop clipping or seams, and stability while stopped. Rebuild decor with `python tools/extract_environment.py` when changing selections or crop bounds.

## Picket fence joins (2026-11-01)

The fence now uses the original panel rails at a fixed height, with round SVG posts covering adjoining panel ends. Gates use their own posts and authored spacing. The source SVGs are unchanged. Godot 4.7.2 passed the scenery script check, landscape and smoke tests, and single-threaded Web export. Enlarged native renders were inspected at zero and fractional scroll positions, including gate transitions and viewport edges. Browser interaction and live scrolling were not manually tested for this correction.

## Open fence variation (2026-11-01)

The farm sheet's open leaf is extracted as `picket_open.svg`. Godot 4.7.2 imported it and passed script validation, landscape, smoke and weather tests, plus single-threaded Web export. Landscape tests additionally cover bounded fence caches, reproducible layouts after eviction/revisit, matching chunk boundaries, single and paired openings, both gate orientations, sufficient clear opening width and no duplicate standalone gate posts. Three native day renders at two seeds and fractional scroll positions were visually inspected for open leaves, gate/post transitions, broad clear passages and viewport edges. All 28 SVGs reproduced byte-identically and both source sheets stayed unchanged. Manual gameplay and browser interaction were not repeated for this visual change.

## Gate opening width correction (2026-11-01)

Openings now reserve one closed gate width per leaf plus about 4.7 pixels of clearance; surplus space is filled with fence panels and posts. The landscape test now bounds clearance to at most five pixels per leaf, including paired openings, while retaining cache, boundary and variation checks. Script validation, landscape and smoke tests, and single-threaded Web export passed. Native stills at two seeds and three scroll positions were inspected for the reduced gaps and added fence sections. Manual gameplay and browser interaction were not repeated.

## Foreground plant variation (2026-11-01)

Godot 4.7.2 imported the seven new SVG crops and passed all script checks, the landscape, smoke and weather tests, and the single-threaded Web export. The landscape test checks that every newly extracted plant and the existing crop groups appear over seeded samples, the foreground remains within its strip, groups can begin throughout a chunk, and seed reproducibility, cache bounds and eviction/revisit remain intact. The splash-page JavaScript unit test also passed.

All 35 extracted SVGs regenerated byte-identically; both supplied source sheets and all previous extractions retained their original checksums. The seven additions were rendered individually and verified to have transparent crop margins. Native Compatibility stills were inspected at two seeds and six successive scroll positions per seed for spacing, overlap, plant scale and chunk transitions. The local system certificate store was unavailable to the sandbox.

Headless Edge loaded and rendered the exported game under `/goat-runner/` without COOP/COEP headers. A temporary HTTP test harness waited for the engine and triggered the splash continue button; the exported files were unchanged. The browser frame was inspected and the harness recorded no game JavaScript errors during startup. Manual gameplay, browser controls and a deployed Pages build were not tested for this visual change.

## Clothesline artwork (2026-11-01)

Godot 4.7.2 imported the clothesline SVG. The smoke test checks the new artwork, ducking underneath and a standing head collision; the obstacle scheduling test passed. A single-threaded Web export succeeded with the matching local templates. The posts are visual only and the original raised collision remains in place. Interactive gameplay and the appearance of the clothesline in the running game have not been checked.

## Clothesline layers (2026-11-01)

Godot 4.7.2 imported both aligned clothesline layers; the smoke and obstacle scheduling tests passed, including ducking and the foreground post placement. A single-threaded Web export succeeded. Interactive gameplay and the resulting overlap in motion have not been checked.

## Mirrored clothesline (2026-11-01)

The front and back artwork are mirrored together. The foreground post uses an absolute z-index above the SCML goat animation layers (which reach 23). The smoke and obstacle scheduling tests passed, and the single-threaded Web export succeeded. The visual overlap during gameplay has not been manually verified.
`nThe Web build script copies both splash SVGs beside index.html and runs the splash flow test. Check that loading shows the SVGs, Space or the button fades to the farm, and the goat only walks in after the fade, including at different browser sizes and a repository subpath.

## SVG-only goat assets (2026-11-01)

The hidden PNG spritesheet and its scene resource were removed. The SCML AnimationPlayer now drives gameplay animation transitions directly, including the transition to looping eating. All 30 goat PNG source images and their Godot import sidecars were removed; the SCML's 17 SVG part assets remain. Updating the SCML filenames to SVG kept the generated scene byte-identical. Godot 4.7.2 imported the project, passed script checks and the smoke, weather, landscape and obstacle scheduling tests, and exported the Web build with the matching single-threaded preset and templates. The autoplay test was attempted but not completed within the available test window; it may await up to 12,000 physics frames for each of five seeds. Manual gameplay was not tested.

## Standalone goat SVG removal (2026-11-01)

Removed the unused `blackgoat.svg`, its importer settings and cached import; updated project instructions and current architecture notes, and removed the smoke test's importer assertion. Godot 4.7.2 reimported the project, passed script checks and the smoke test, and exported the single-threaded Web build with matching templates. Manual gameplay was not tested.

## Denser foreground and larger corn (2026-11-01)

Foreground corn is 95–110 pixels high and extends below the viewport so its visible cobs are larger while artwork stays below the play lane. Other plants fill large gaps without interactions or collisions. The landscape test checks corn size, foreground bounds, at most 150 pixels between object bounds within chunks, at most 80 pixels of empty space at each chunk edge, deterministic regeneration and bounded caches.

Godot 4.7.2 passed all script checks plus landscape, smoke, weather and obstacle scheduling tests, the splash JavaScript unit test, and single-threaded Web export. Native Compatibility stills at two seeds and six consecutive scroll positions were inspected for density, crop sizing and readable gameplay space. Headless Edge rendered the exported game under `/goat-runner/` after an automated splash-button click; no game JavaScript errors were recorded during startup. Manual browser interaction, gameplay and autoplay were not repeated for this visual change. The sandbox did not provide access to the native system certificate store.

## Foreground plant scale (2026-11-01)

Foreground plants were rescaled by type; sunflowers and corn rise into the lower path behind gameplay. The landscape test checks crop sizes, foreground bounds, spacing, deterministic regeneration and bounded caches. Native Compatibility stills were captured at two seeds and six scroll positions per seed; static frames were inspected. Manual gameplay and browser interaction were not checked for this change.

## Lighter foreground planting (2026-11-01)

Fewer and smaller plant groups leave more open space, with gap limits retained across chunks. The landscape and smoke tests passed and the single-threaded Web export succeeded. Native Compatibility screenshots were captured at two seeds and six scroll positions; one still was inspected. Manual gameplay and browser interaction were not tested. The sandbox reported graphics initialization and certificate-store errors while capturing, but the screenshot rendered.

## Clothesline jump collision (2026-11-01)

The smoke test verifies that a fully held jump collides with the raised clothesline while ground ducking still clears it. All ordered obstacle pairs passed the minimum-spacing physics test, and the single-threaded Web export succeeded. Interactive gameplay was not checked.

## Menu and touch controls

The interface test checks default and custom keys, conflict reassignment, staged changes, cancel, confirmation, reset, removal, scene-reload persistence and starting with a custom key. Godot 4.7.2 passed the interface and smoke tests. Web export was attempted but the matching no-threads templates were unavailable; manual gameplay and browser input were not tested.

Run `godot --headless --path . --script tests/interface.gd` for menu states, translations, settings placement and dragging, cursor selection, touch layout, opacity, reset and pause checks. Manually check all collision reasons, language switching, touch multitouch and held input, settings dragging and close-button placement, both edit cursors, dragging and resizing both arrows, opacity and visibility, persistence, reset and responsive layout in a browser and on a touch device. Verify that reopening settings aligns its cross with the gear.

Godot 4.7.2 passed the interface and smoke tests and exported the single-threaded Web build for these changes. Native stills of the settings menu and its dragged position were inspected. Interactive browser, mouse-cursor and touchscreen behavior have not been verified.

The Web font does not reliably render the up and down arrow glyphs. Player-facing instructions use translated direction words instead; when changing fonts or instructions, check the Web build in all three languages rather than relying on arrow symbols.


## Variable jump animation (2026-11-05)

Godot 4.7.2 imported the generated scene and passed every GDScript check, the new fixed-60-FPS jump test, and the interface, smoke, weather, landscape, obstacle scheduling and five-seed autoplay tests. The Web splash JavaScript test and single-threaded Web export with matching templates passed. Repeating SCML conversion produced byte-identical output; all 16 existing animation resources remained unchanged.

The jump test covers animation targets, running-stride endpoints, nose-up to nose-down body pitch, steady head orientation, all four lifted hooves, three hold durations, monotonic ascent/descent phases, return from air ducking in both halves, landing/rejump, rejected midair jumps, collision priority, and unchanged physics velocity/position (allowing native floor recovery within safe_margin). Native Compatibility pose comparisons and rendered frame sequences of short and held jumps were inspected. Temporary previews and logs are under ignored build/. Manual gameplay and interactive browser testing were not performed. The sandbox reported system certificate-store and user-log access errors; native captures also reported shader initialization errors but rendered the inspected frames.

The forward-bound refinement follows the supplied deer motion reference using the existing goat rig. Native short/held frame sequences were inspected again; jump, smoke, obstacle scheduling and five-seed autoplay tests passed again, as did import and single-threaded Web export. Generation remained byte-identical on repeat and all original animations stayed unchanged. Manual gameplay and browser interaction were not repeated.

A second reference comparison strengthened the trailing push-off and compact flight pose and delayed the foreleg reach. The pose test now checks substantial lift of every hoof, rear-leg recovery from extension to gathering, and forelegs reaching forward/down after the apex. Jump and smoke tests, import and single-threaded Web export passed again. Native short/held sequences were inspected and an animated preview was generated under build/jump-preview.gif; this is automated rendering, not manual gameplay testing. Repeat conversion stayed byte-identical and original animations remained unchanged.

## Public placeholders and private assembly

The public build uses independently drawn placeholders. Run `python tools/check-public-assets.py` to check the public asset manifest before publication. The private assembly restores licensed files in an isolated project and runs the source-specific goat animation checks as well as gameplay tests. The Pages release workflow uses a pinned private-assets commit and a read-only deploy key.

The public placeholder artwork was corrected for non-square textures, recognizable controls and obstacle silhouettes. Godot 4.7.2 imported the project and passed the interface, smoke and jump checks. Native stills of the start menu, settings, obstacles and collision were inspected. Interactive gameplay and browser testing were not performed for this visual revision.

The release workflow assembles private assets into a separate project before importing, running the full build checks and exporting. The deploy key and Pages settings must be configured on GitHub before end-to-end release validation.
