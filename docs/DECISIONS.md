# Decisions

## Public and licensed assets

The public project uses independent placeholder SVGs and a minimal goat scene. Licensed artwork, SCML and the generated animation scene are private. `tools/prepare-private-build.py` assembles an isolated local project using `tools/private-assets.json`. Source-specific animation tests run for the private build. Earlier entries describe the original artwork and private build. Release deployments fetch the latest commit on the private assets repository's default branch using a fine-grained read-only token and record the resolved commit in the build summary. Asset updates need no workflow edit; reruns can pick up newer assets. Public CI continues to use placeholders.


## Native movement and simple visual style

Use CharacterBody2D and built-in collisions. `Visual` is generated from the black goat in the supplied SCML and uses the matching SVG parts. Regenerate it with `python tools/convert_goat_scml.py`. The generated scene retains the source bone hierarchy and bakes independent sprite transforms at 120 samples per second: Spriter and Godot compose non-uniform scale differently, so attaching sprites directly would distort them. Editing a bone does not automatically move these baked sprites; regenerate from the SCML or edit the sprite tracks. Source scale animation is retained. The standalone `sock_line_stuck` animation preserves the first 0.7 seconds of `transition_out_of_charge_run_sudden_brake` and adds a settling struggle; it plays on sock collisions; the goat briefly slides into the socks and then stays in place until retry. The SCML animations drive all gameplay states, including the eating transition. The unused standalone `blackgoat.svg` was removed; the SCML and part SVGs remain as editable sources. Hold-to-jump changes height; ducking lowers the head collision shape and changes the animation, including in air, without changing velocity. The clothesline catches only the head, so the goat can stand once its head has passed; both head and body collide with ground obstacles. The environment scrolls around a fixed horizontal player. The mockup guides composition, not final colors.

## Variable jump animation

The converter derives a non-looping `jump` from the kick rig, preserving the supplied SCML and original animations. The supplied deer sequence guides a forward running bound: rear legs extend almost horizontally through push-off, all four hooves gather close under the belly at the apex, and the forelegs unfold later to reach forward and down for landing. The torso pitches nose-up then nose-down; head counter-rotation steadies the gaze. Both endpoints use a running stride. Independent root legs rotate around the body pivot to keep attachments aligned, with no authored translation of that pivot. Gameplay freezes automatic playback and seeks each physics tick: upward velocity maps to the first half, and distance fallen from the observed apex relative to departure height maps to the second half. Air ducking overrides the visual while phase tracking continues; landing restores running and collisions retain priority. Jump physics and hitboxes are unchanged.

## Obstacles and viewport

All goat SVGs use Godot 4.7's experimental DPITexture importer. The debug zoom temporarily raises viewport oversampling so the parts are re-rasterized with more detail, then restores the previous setting.

The world is 1440 Ã— 720 to show more run-up, with a resizable aspect-preserving display. A custom SVG clothesline replaces the sock artwork. Its posts are visual only; the head collision keeps the duck clearance and extends above the maximum jump, so jumping cannot bypass it. The clothesline is mirrored so the near post is on the right. It is drawn in front of the goat at absolute z-index 100, above the goat parts’ animated absolute z-indices; the rest stays behind her. The editable clothesline.svg is retained alongside the two aligned rendering layers. Each obstacle awards one point when its collision box has fully passed the goat; retry resets the score, while the high score is saved locally in Godot user storage. A collision stops the run and allows retry. The puddle has a walkable rim; its water trigger starts the death animation while the goat moves toward the center at normal ground height with an offset for the death pose, behind the water. A hay-bale collision is a game-over easter egg: the goat eats and ignores gameplay input, with a separate retry button.

## Obstacle pacing

The first 20 seconds retain the original 3.3-second interval and obstacle cycle. Afterwards obstacle types are randomly selected, including repeats, and the interval decreases linearly to 0.7 seconds at 30 minutes, remaining bounded thereafter. Retry resets the schedule. The minimum interval is checked against every ordered pair using actual physics and collisions; this does not establish human difficulty or cover every longer sequence.

## Autoplay debug tool

Ctrl+D opens a toggle that starts the run at the 30-minute obstacle interval. The debug controller picks a slightly varied action point per obstacle, holds jumps shorter for bushes and puddles than for hay, and ducks for socks, including in the air. It uses normal collisions and stops on game over so failures remain visible; retry returns to manual play. Disabling the toggle returns control to the player without resetting difficulty.

## Browser and deployment

Keep Compatibility and use single-threaded Godot 4.7.2 Web export so GitHub Pages does not need cross-origin isolation headers. CI and deployment use matching editor and templates. A Pages repository and deployment must be configured by the owner. The Web shell retains the SVG loading screen until the player continues, then fades through black; the initial goat walk waits for the fade.

## Live weather

Use Open-Meteo at 51.5, 4.3 (Europe/Amsterdam), refreshed every 15 minutes. Weather affects the landscape visually only. The debug menu can temporarily override each visual weather effect; live data continues updating and retry clears the override. The last valid conditions survive retry and failed requests; a daytime palette is the offline default. Weather is model-based, and the selected forecast fields are retained in the request even though only current conditions needed for visuals are interpreted.

The request URL is defined in [`scripts/weather.gd`](../scripts/weather.gd):

```text
https://api.open-meteo.com/v1/forecast?latitude=51.5&longitude=4.3&hourly=temperature_2m,rain,showers,snowfall,snow_depth,cloud_cover,cloud_cover_low,cloud_cover_mid,cloud_cover_high,wind_speed_10m,wind_direction_10m,wind_gusts_10m,weather_code,precipitation,visibility,is_day,relative_humidity_2m&daily=sunrise,sunset,moonrise,moonset,moon_phase&current=temperature_2m,weather_code,is_day,wind_speed_10m,wind_direction_10m,wind_gusts_10m,precipitation,cloud_cover&timezone=Europe%2FAmsterdam&forecast_days=2&past_days=2&timeformat=unixtime
```

Sunrise, sunset, moonrise and moonset use UTC timestamps from Open-Meteo; the location remains Europe/Amsterdam, including daylight-saving changes. The moon follows its daily phase and horizon events. If astronomy data is unavailable, current is_day and a default moon remain the fallback.

## Farm environment

The reusable landscape scene separates the weather-driven sky, scenery and weather overlay. FastNoiseLite generates continuous hills and curved field bands from absolute world coordinates. Each parallax layer retains only visible 720-pixel chunks plus a buffer; adjoining samples are joined into one drawn contour to prevent seams.

Each run chooses a fresh landscape seed; setting `Landscape.landscape_seed` to a nonzero value reproduces the environment. Chunk-local RandomNumberGenerators make eviction/revisits stable and never consume gameplay randomness. Weighted groves, orchards, crop and flower clusters alternate with empty spaces; farm buildings appear less often. Distant decor has reduced contrast. All decor is visual only: background objects stay behind the white fence, and foreground plants may overlap the lower play lane behind gameplay. The fence retains its position and half-speed scrolling. Regular panels use a fixed height and their own SVG rails, cropped past the flat end post, with shared round SVG posts covering the joins. Gates retain their authored spacing and built-in posts. No synthetic connecting lines or horizontal stretching are used.

The foreground uses independently seeded chunks of three to four irregular groups, with extra plants filling unusually large gaps. Grass, sprouts, lettuce, carrots and flowers are sized to relate to the larger sunflowers and corn. Tall crops grow from near the viewport bottom and overlap the lower path behind the goat and obstacles. Group bounding boxes leave at most 210 pixels within a chunk and 120 pixels at each chunk edge. All plants use the supplied SVG artwork without redrawing.

Seeded fence chunks contain eight fence-width bays plus one gate. Each open leaf replaces one closed bay: an opening is 86 pixels per leaf, allowing about 4.7 pixels of latch clearance relative to the closed gate's authored span. All remaining space is filled with fence panels and shared posts. Single leaves can face either direction, ending at a post/normal gate or starting after a post/mirrored gate. A paired opening fits two closed leaves without intermediate posts or connecting rails. Gates can also sit elsewhere in the closed run so some entrances end at plain posts. The fence cache is bounded like the other scenery caches; revisiting a chunk restores the same arrangement without consuming gameplay RNG.

Run `python tools/extract_environment.py` to rebuild the 35 decor SVGs from `source/enviroment_props.svg` and `source/enviroment_props-farm.svg`. The script records source group IDs and crop bounds, preserves ancestor transforms and definitions, and leaves both source sheets unchanged. Imported decor resolution is capped at 512 pixels while retaining vector paths. The supplied track and foreground strips remain, as do the goat and obstacle collisions. The bushes and hay bale are extracted from the props SVG; the puddle comes from the farm background SVG; the original environment SVGs remain as source artwork.

## Release deployments

Pages deploys only after tests on published releases. Release tags follow the reference project's v1.2.3.4 format with components from 0 to 65534; the release tag is checked out and tested before deployment.

## Menus and touch controls

The interface uses the supplied GUI artwork and Godot translations for English, Dutch and German. Settings pause the game and persist the chosen language, touch visibility and opacity, and independent normalized positions and sizes for the two touch controls. The draggable settings menu opens over the gear, and its close button follows the panel. Both controls briefly move and wobble independently with highlighted edit handles when settings open; pressing one immediately stops its animation without changing its saved layout. Both controls are editable while settings are open; resetting their layout restores the lower-right defaults, with jump above duck. Touch controls are visible by default. Starting a run with any bound jump key hides them; starting with another input shows them. Each start saves the resulting visibility setting. Players can restore visibility in settings. High-score reset requires confirmation and preserves the current run score.

The keybind popup stages one extra key each for jump and duck; confirmation saves them and cancel discards changes. Explicit assignments override the other action's default or extra key, and removing an assignment restores its defaults. Jump keys also start and retry the game. The popup uses the supplied GUI artwork.
