# MVP

## 0.1 Foundation

Implemented in the project; verification status is recorded in [TESTING.md](TESTING.md):

- A goat animated from the supplied SCML and SVG parts walks in from the left before the start prompt, then runs across the ground and mockup-inspired landscape, with a scrolling fence after starting.
- Seeded procedural hills and fields with parallax trees, crops, flowers and occasional farm buildings from the supplied SVG. A white picket fence stays behind the track; each retry generates a new environment without changing obstacle randomness.
- The foreground mixes grasses, sprouts, lettuce, carrots, flowers, sunflowers and corn from the supplied artwork in varied clusters along the foreground, with tall crops overlapping the lower track.
- Space/up starts and jumps by default; down ducks. Each action can have one additional configurable key, which takes precedence over the other action's default. Holding jump increases height. Ducking lowers the head hitbox on the ground or in the air without changing velocity. The clothesline catches the head; ground obstacles detect both head and body.
- Gravity and ground collision through CharacterBody2D; no jump while airborne.
- A kick-derived forward running jump follows actual ascent and descent: rear legs trail at takeoff, legs gather near the apex and forelegs reach toward landing for both short and held jumps. Air ducking overrides the pose until released.
- A 1440 × 720 world with scrolling obstacles: three alternating bushes, a puddle and a hay bale to jump, and a clothesline to duck under; collisions stop the run. The goat gets caught on the clothesline. At the hay bale the goat eats, and a button starts a new run.
- A score counter awards one point for each obstacle fully cleared and resets on retry; a local high score persists between runs.
- Start and game-over menus use the supplied GUI artwork; game over shows the collision reason and score. A draggable settings menu pauses play and provides language selection, high-score reset and touch-control settings.
- Touch controls are visible by default; starting with a bound jump key hides them, while starting with touch or the start button shows them. Opening settings briefly animates their editable appearance; touching a control immediately allows dragging or resizing. Their visibility, positions, sizes and shared opacity are configurable. English, Dutch and German are supported.
- Web export preset and workflows for pull requests and Pages deployment.

Acceptance requires the scene to run, the goat to land and jump again, controls and scrolling to work, and a Web build to run at a Pages repository subpath. A successful deployed build requires a configured GitHub repository and Pages.

## Later

Additional obstacle types, unused goat animations and further easter eggs remain future work.




The Web loading page keeps the supplied SVG logo and background visible after loading. Space or a click or tap anywhere fades to the farm; the goat walks in after the fade.
