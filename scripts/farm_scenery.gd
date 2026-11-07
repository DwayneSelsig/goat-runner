extends Node2D
## Bounded, deterministic scenery chunks. All coordinates are independent of
## gameplay RNG and collision geometry; only the landscape controls scrolling.

const CHUNK_WIDTH := 720.0
const VIEW_WIDTH := 1440.0
const SAMPLE_STEP := 24.0
const SPEEDS := [0.08, 0.18, 0.3, 1.0]
const BASELINES := [282.0, 349.0, 432.0]
const AMPLITUDES := [65.0, 48.0, 28.0]
const COLORS := [Color("a7be98"), Color("b6ca54"), Color("85b536")]
const OUTLINES := [Color("718d70"), Color("80943e"), Color("527b2c")]
const TREES := ["tree_broad", "tree_small", "tree_tall", "tree_leaning", "tree_round"]
const FRUIT := ["fruit_yellow", "fruit_red", "fruit_green"]
const FLOWERS := ["flower_yellow", "flower_red", "flower_blue", "flower_purple", "flower_white", "flower_orange"]
const FOREGROUND_GRASS := ["grass", "grass_tall", "sprout_low", "sprout_tall"]
const FOREGROUND_SUNFLOWERS := ["sunflowers", "sunflower_single"]
const FOREGROUND_CORN := ["corn", "corn_single_b", "corn_single_b", "corn_single_a"]
const ART := {
    "tree_broad": preload("res://assets/environment/props/vegetation/tree_broad.svg"),
    "tree_small": preload("res://assets/environment/props/vegetation/tree_small.svg"),
    "tree_tall": preload("res://assets/environment/props/vegetation/tree_tall.svg"),
    "tree_leaning": preload("res://assets/environment/props/vegetation/tree_leaning.svg"),
    "tree_round": preload("res://assets/environment/props/vegetation/tree_round.svg"),
    "fruit_yellow": preload("res://assets/environment/props/vegetation/fruit_yellow.svg"),
    "fruit_red": preload("res://assets/environment/props/vegetation/fruit_red.svg"),
    "fruit_green": preload("res://assets/environment/props/vegetation/fruit_green.svg"),
    "flower_yellow": preload("res://assets/environment/props/vegetation/flower_yellow.svg"),
    "flower_red": preload("res://assets/environment/props/vegetation/flower_red.svg"),
    "flower_blue": preload("res://assets/environment/props/vegetation/flower_blue.svg"),
    "flower_purple": preload("res://assets/environment/props/vegetation/flower_purple.svg"),
    "flower_white": preload("res://assets/environment/props/vegetation/flower_white.svg"),
    "flower_orange": preload("res://assets/environment/props/vegetation/flower_orange.svg"),
    "grass": preload("res://assets/environment/props/vegetation/grass.svg"),
    "grass_tall": preload("res://assets/environment/props/vegetation/grass_tall.svg"),
    "sprout_low": preload("res://assets/environment/props/vegetation/sprout_low.svg"),
    "sprout_tall": preload("res://assets/environment/props/vegetation/sprout_tall.svg"),
    "sunflowers": preload("res://assets/environment/props/crops/sunflowers.svg"),
    "corn": preload("res://assets/environment/props/crops/corn.svg"),
    "carrots": preload("res://assets/environment/props/crops/carrots.svg"),
    "lettuce": preload("res://assets/environment/props/crops/lettuce.svg"),
    "sunflower_single": preload("res://assets/environment/props/crops/sunflower_single.svg"),
    "corn_single_a": preload("res://assets/environment/props/crops/corn_single_a.svg"),
    "corn_single_b": preload("res://assets/environment/props/crops/corn_single_b.svg"),
    "barn": preload("res://assets/environment/props/buildings/barn.svg"),
    "silo": preload("res://assets/environment/props/buildings/silo.svg"),
    "windmill": preload("res://assets/environment/props/buildings/windmill.svg"),
    "shed_red": preload("res://assets/environment/props/buildings/shed_red.svg"),
    "shed_wood": preload("res://assets/environment/props/buildings/shed_wood.svg"),
    "scarecrow": preload("res://assets/environment/props/crops/scarecrow.svg"),
}
const FENCE := preload("res://assets/environment/props/fence/picket_fence.svg")
const GATE := preload("res://assets/environment/props/fence/picket_gate.svg")
const POST := preload("res://assets/environment/props/fence/picket_post.svg")
const OPEN_FENCE := preload("res://assets/environment/props/fence/picket_open.svg")
const TRACK := preload("res://assets/environment/layers/track.svg")
const FOREGROUND := preload("res://assets/environment/layers/foreground.svg")
const FENCE_WIDTH := 86.0
const FENCE_HEIGHT := 66.0
const POST_HEIGHT := 75.0
# Authored post-cap centres in the source SVG's viewBox coordinates. Gates
# already contain both posts, so their natural spacing determines their span.
const GATE_SPAN := 814.345 * POST_HEIGHT / 751.0
const GATE_LEFT_POST := 132.595 * POST_HEIGHT / 751.0
const POST_CENTRE := 136.296 * POST_HEIGHT / 751.0
# Eight fence-width bays plus one gate keep chunks aligned without stretching
# artwork. Each open leaf replaces one closed bay, leaving 4.7 px latch room.
const FENCE_CHUNK_WIDTH := 8.0 * FENCE_WIDTH + GATE_SPAN

var world_seed := 0
var scroll := 0.0
var noises: Array[FastNoiseLite] = []
var chunks: Array[Dictionary] = []
var fence_chunks: Dictionary = {}


func configure(requested_seed: int = 0) -> void:
    var random := RandomNumberGenerator.new()
    random.randomize()
    world_seed = requested_seed if requested_seed != 0 else random.randi_range(1, 2147483646)
    noises.clear()
    chunks.clear()
    fence_chunks.clear()
    for layer in range(4):
        chunks.append({})
        if layer < 3:
            var noise := FastNoiseLite.new()
            noise.seed = int((world_seed + layer * 104729) % 2147483647)
            noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
            noise.frequency = 0.0016 + layer * 0.0004
            noise.fractal_octaves = 3
            noise.fractal_gain = 0.35
            noises.append(noise)
    set_scroll(0.0)


func set_scroll(distance: float) -> void:
    scroll = distance
    for layer in range(4):
        var first := floori(scroll * SPEEDS[layer] / CHUNK_WIDTH) - 1
        var last := floori((scroll * SPEEDS[layer] + VIEW_WIDTH) / CHUNK_WIDTH) + 1
        var cache: Dictionary = chunks[layer]
        for index: int in cache.keys():
            if index < first or index > last:
                cache.erase(index)
        for index in range(first, last + 1):
            if not cache.has(index):
                cache[index] = _make_chunk(layer, index)
    var first_fence := floori(scroll * 0.5 / FENCE_CHUNK_WIDTH) - 1
    var last_fence := floori((scroll * 0.5 + VIEW_WIDTH) / FENCE_CHUNK_WIDTH) + 1
    for index: int in fence_chunks.keys():
        if index < first_fence or index > last_fence:
            fence_chunks.erase(index)
    for index in range(first_fence, last_fence + 1):
        if not fence_chunks.has(index):
            fence_chunks[index] = _make_fence_chunk(index)
    queue_redraw()


func height_at(layer: int, world_x: float) -> float:
    return BASELINES[layer] + noises[layer].get_noise_1d(world_x) * AMPLITUDES[layer]


func _field_edge(world_x: float, band: int) -> float:
    return minf(474.0, height_at(1, world_x) + 29.0 + band * 33.0 + sin(world_x * 0.002 + band * 1.9) * 13.0)


func _make_chunk(layer: int, index: int) -> Dictionary:
    var surface := PackedVector2Array()
    var bands: Array[PackedVector2Array] = []
    if layer < 3:
        for sample in range(int(CHUNK_WIDTH / SAMPLE_STEP) + 1):
            var x := sample * SAMPLE_STEP
            surface.append(Vector2(x, height_at(layer, index * CHUNK_WIDTH + x)))
        if layer == 1:
            for band in range(3):
                var edge := PackedVector2Array()
                for sample in range(surface.size()):
                    var x := sample * SAMPLE_STEP
                    edge.append(Vector2(x, _field_edge(index * CHUNK_WIDTH + x, band)))
                bands.append(edge)
    var random := RandomNumberGenerator.new()
    # Each chunk has its own stream, so eviction/revisit and frame rate cannot
    # change its contents, nor advance Godot's global obstacle RNG.
    random.seed = world_seed + layer * 1000003 + index * 7919
    return {"surface": surface, "bands": bands, "props": _make_props(layer, index, random)}


func _add_prop(props: Array[Dictionary], name: String, x: float, bottom: float, height: float, flip: bool = false) -> void:
    var texture: Texture2D = ART[name]
    var width := height * texture.get_width() / texture.get_height()
    props.append({"art": name, "rect": Rect2(x - width * 0.5, bottom - height, width, height), "flip": flip})


func _make_props(layer: int, index: int, random: RandomNumberGenerator) -> Array[Dictionary]:
    if layer == 3:
        return _make_foreground_props(random)
    var props: Array[Dictionary] = []
    for slot in range(2):
        # Reserved margins keep neighbouring clusters from colliding across a
        # chunk boundary. Empty cells provide breathing room between clusters.
        if random.randf() < (0.38 if layer == 0 else 0.2):
            continue
        var x := 180.0 + slot * 360.0 + random.randf_range(-18.0, 18.0)
        var bottom := minf(464.0, height_at(layer, index * CHUNK_WIDTH + x) + 15.0)
        if layer == 0:
            for tree in range(random.randi_range(1, 2)):
                _add_prop(props, TREES[random.randi_range(0, 4)], x + tree * 40.0 - 20.0, bottom, random.randf_range(42.0, 67.0), random.randf() < 0.5)
        elif layer == 1:
            var orchard := random.randf() < 0.5
            for tree in range(random.randi_range(2, 3)):
                var name: String = FRUIT[random.randi_range(0, 2)] if orchard else TREES[random.randi_range(0, 4)]
                _add_prop(props, name, x - 58.0 + tree * 55.0, bottom + random.randf_range(-3, 3), random.randf_range(78, 108), random.randf() < 0.5)
        elif layer == 2:
            var choice := random.randi_range(0, 99)
            if slot == 1 and posmod(index, 3) == 0 and choice < 65:
                # A farm silhouette is occasional, rather than repeated in
                # every screen. Buildings keep their natural aspect ratio.
                if choice < 24:
                    _add_prop(props, "silo", x + 85.0, bottom - 2, 188)
                    _add_prop(props, "barn", x - 35.0, bottom, 172)
                elif choice < 45:
                    _add_prop(props, "windmill", x - 85.0, bottom - 1, 205)
                    _add_prop(props, "shed_wood", x + 36.0, bottom, 138)
                else:
                    _add_prop(props, "shed_red", x - 20.0, bottom, 150)
                _add_prop(props, "sunflowers", x + 108.0, bottom + 2, 65)
            elif choice < 32:
                for tree in range(random.randi_range(2, 3)):
                    _add_prop(props, TREES[random.randi_range(0, 4)], x - 60 + tree * 60, bottom + random.randf_range(-3, 3), random.randf_range(125, 174), random.randf() < 0.5)
            elif choice < 52:
                for tree in range(3):
                    _add_prop(props, FRUIT[random.randi_range(0, 2)], x - 62 + tree * 62, bottom, random.randf_range(100, 125))
            elif choice < 77:
                _add_prop(props, "sunflowers", x - 66, bottom, random.randf_range(85, 112))
                _add_prop(props, "corn", x + 40, bottom + 2, random.randf_range(65, 90))
                if choice > 68:
                    _add_prop(props, "scarecrow", x + 20, bottom - 6, 120)
                _add_prop(props, "carrots", x + 100, bottom + 3, 33)
            else:
                _flower_patch(props, random, x, bottom, 38.0)
    props.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.rect.end.y < b.rect.end.y)
    return props


func _make_foreground_props(random: RandomNumberGenerator) -> Array[Dictionary]:
    var props: Array[Dictionary] = []
    var intervals: Array[Vector2] = []
    var cluster_count := 3 if random.randf() < 0.75 else 4
    for cluster in range(cluster_count):
        var patch := _make_foreground_patch(random)
        var patch_width := 0.0
        for item: Dictionary in patch:
            var rect: Rect2 = item.rect
            patch_width = maxf(patch_width, rect.end.x)
        # Place the first group anywhere in the chunk. Further groups stay
        # with varied open space between them.
        var position := -1.0
        for attempt in range(20):
            var candidate := random.randf_range(16.0, CHUNK_WIDTH - 16.0 - patch_width)
            if not intervals.is_empty():
                var anchor: Vector2 = intervals[random.randi_range(0, intervals.size() - 1)]
                var gap := random.randf_range(25.0, 130.0)
                candidate = anchor.y + gap if random.randf() < 0.5 else anchor.x - gap - patch_width
            if candidate < 16.0 or candidate + patch_width > CHUNK_WIDTH - 16.0:
                continue
            var available := true
            for interval in intervals:
                if candidate < interval.y + 12.0 and candidate + patch_width > interval.x - 12.0:
                    available = false
                    break
            if available:
                position = candidate
                break
        if position < 0.0:
            continue
        intervals.append(Vector2(position, position + patch_width))
        for item: Dictionary in patch:
            var rect: Rect2 = item.rect
            rect.position.x += position
            item.rect = rect
            props.append(item)
    _fill_foreground_gaps(props, intervals, random)
    props.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.rect.end.y < b.rect.end.y)
    return props


func _foreground_patch_width(patch: Array[Dictionary]) -> float:
    var width := 0.0
    for item: Dictionary in patch:
        var rect: Rect2 = item.rect
        width = maxf(width, rect.end.x)
    return width


func _foreground_filler(random: RandomNumberGenerator) -> Array[Dictionary]:
    var props: Array[Dictionary] = []
    var end := 0.0
    for item in range(random.randi_range(1, 3)):
        var name: String = FOREGROUND_GRASS[random.randi_range(0, FOREGROUND_GRASS.size() - 1)]
        var height := random.randf_range(24.0, 34.0)
        var texture: Texture2D = ART[name]
        var width := height * texture.get_width() / texture.get_height()
        if item > 0 and end + width > 42.0:
            break
        _add_prop(props, name, end + width * 0.5, random.randf_range(705.0, 719.0), height, random.randf() < 0.5)
        end += width + random.randf_range(0.0, 3.0)
    return props


func _fill_foreground_gaps(props: Array[Dictionary], intervals: Array[Vector2], random: RandomNumberGenerator) -> void:
    # Fill unusually large holes while keeping uneven distances and a 16-pixel
    # margin at each boundary. Neighbouring chunks then leave at most 240 px.
    for attempt in range(20):
        intervals.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
        var gap_left := 16.0
        var gap_right := CHUNK_WIDTH - 16.0
        var edge := 0
        if intervals.is_empty():
            edge = -1
        elif intervals[0].x > 120.0:
            gap_right = intervals[0].x - 12.0
            edge = -1
        elif CHUNK_WIDTH - intervals[-1].y > 120.0:
            gap_left = intervals[-1].y + 12.0
            edge = 1
        else:
            var found := false
            for i in range(intervals.size() - 1):
                if intervals[i + 1].x - intervals[i].y > 210.0:
                    gap_left = intervals[i].y + 12.0
                    gap_right = intervals[i + 1].x - 12.0
                    found = true
                    break
            if not found:
                return
        var patch := _make_foreground_patch(random)
        var width := _foreground_patch_width(patch)
        if width > gap_right - gap_left:
            patch = _foreground_filler(random)
            width = _foreground_patch_width(patch)
        var left := gap_left
        var right := gap_right - width
        if edge == -1:
            right = minf(right, 104.0)
        elif edge == 1:
            left = maxf(left, CHUNK_WIDTH - 120.0 - width)
        else:
            var midpoint := (gap_left + gap_right - width) * 0.5
            left = maxf(left, midpoint - 20.0)
            right = minf(right, midpoint + 20.0)
        var position := random.randf_range(left, right)
        intervals.append(Vector2(position, position + width))
        for item: Dictionary in patch:
            var rect: Rect2 = item.rect
            rect.position.x += position
            item.rect = rect
            props.append(item)


func _make_foreground_patch(random: RandomNumberGenerator) -> Array[Dictionary]:
    var props: Array[Dictionary] = []
    var choice := random.randi_range(0, 99)
    var names: Array = FOREGROUND_GRASS
    var min_height := 24.0
    var max_height := 42.0
    if choice >= 30 and choice < 50:
        names = ["lettuce"]
        min_height = 36.0
        max_height = 54.0
    elif choice >= 50 and choice < 65:
        names = ["carrots"]
        min_height = 40.0
        max_height = 58.0
    elif choice >= 65 and choice < 80:
        names = FLOWERS
        min_height = 32.0
        max_height = 50.0
    elif choice >= 80 and choice < 90:
        names = FOREGROUND_SUNFLOWERS
        min_height = 100.0
        max_height = 135.0
    elif choice >= 90:
        names = FOREGROUND_CORN
        min_height = 120.0
        max_height = 155.0
    var patch_end := 0.0
    var max_width := random.randf_range(70.0, 160.0)
    for item in range(random.randi_range(1, 3)):
        var name: String = names[random.randi_range(0, names.size() - 1)]
        var height := random.randf_range(min_height, max_height)
        var texture: Texture2D = ART[name]
        var width := height * texture.get_width() / texture.get_height()
        # Plants within a group may overlap lightly; groups retain a gap.
        var left := maxf(0.0, patch_end + (random.randf_range(-minf(width * 0.2, 8.0), 10.0) if item > 0 else 0.0))
        var right := left + width
        if item > 0 and right > max_width:
            break
        # Tall crops grow up from the foreground and can overlap the path.
        # Their roots remain near the bottom rather than hiding most of the plant.
        var bottom := random.randf_range(710.0, 730.0) if choice >= 80 else random.randf_range(700.0, 719.0)
        _add_prop(props, name, left + width * 0.5, bottom, height, random.randf() < 0.5)
        patch_end = maxf(patch_end, right)
    return props


func _flower_patch(props: Array[Dictionary], random: RandomNumberGenerator, x: float, bottom: float, height: float) -> void:
    for flower in range(random.randi_range(5, 8)):
        var name: String = "grass" if random.randf() < 0.22 else FLOWERS[random.randi_range(0, 5)]
        _add_prop(props, name, x - 85 + flower * 24 + random.randf_range(-4, 4), bottom - random.randf_range(0, 5), height * random.randf_range(0.7, 1.2), random.randf() < 0.5)


func _draw() -> void:
    if chunks.is_empty():
        return
    for layer in range(3):
        _draw_terrain(layer)
        _draw_props(layer)
    _draw_fence()
    draw_rect(Rect2(0, 475, VIEW_WIDTH, 245), Color("79691f"))
    _draw_strip(TRACK, 475.0, 180.0)
    draw_rect(Rect2(0, 650, VIEW_WIDTH, 70), Color("70ac22"))
    _draw_strip(FOREGROUND, 650.0, 70.0)
    _draw_props(3)


func _draw_terrain(layer: int) -> void:
    # Join cached samples into one contour: no separately rasterized polygon
    # edges can leak sky between chunks, including during fractional scrolling.
    var contour := PackedVector2Array()
    var field_edges: Array[PackedVector2Array] = [PackedVector2Array(), PackedVector2Array(), PackedVector2Array()]
    var indices: Array = chunks[layer].keys()
    indices.sort()
    for index: int in indices:
        var chunk: Dictionary = chunks[layer][index]
        var offset := Vector2(index * CHUNK_WIDTH - scroll * SPEEDS[layer], 0)
        for sample in range(chunk.surface.size() - 1):
            contour.append(chunk.surface[sample] + offset)
            if layer == 1:
                for band in range(3):
                    field_edges[band].append(chunk.bands[band][sample] + offset)
        if index == indices.back():
            contour.append(chunk.surface[-1] + offset)
            if layer == 1:
                for band in range(3):
                    field_edges[band].append(chunk.bands[band][-1] + offset)
    _fill_to_ground(contour, COLORS[layer])
    draw_polyline(contour, OUTLINES[layer], 3.0, true)
    if layer == 1:
        var field_colors := [Color("d5ce66"), Color("a1bd45"), Color("c4ce66")]
        for band in range(3):
            _fill_to_ground(field_edges[band], field_colors[band])
            draw_polyline(field_edges[band], Color("8c9c43"), 2.0, true)


func _fill_to_ground(contour: PackedVector2Array, color: Color) -> void:
    var polygon := contour.duplicate()
    polygon.append(Vector2(contour[-1].x, 476))
    polygon.append(Vector2(contour[0].x, 476))
    draw_colored_polygon(polygon, color)


func _draw_props(layer: int) -> void:
    var tint := Color(0.87, 0.94, 0.86, 0.65) if layer == 0 else Color.WHITE
    if layer == 1:
        tint = Color(0.94, 0.98, 0.90, 0.87)
    var indices: Array = chunks[layer].keys()
    indices.sort()
    for index: int in indices:
        var chunk: Dictionary = chunks[layer][index]
        var offset: float = index * CHUNK_WIDTH - scroll * SPEEDS[layer]
        for prop: Dictionary in chunk.props:
            var rect: Rect2 = prop.rect
            rect.position.x += offset
            if rect.end.x < 0 or rect.position.x > VIEW_WIDTH:
                continue
            if prop.flip:
                draw_set_transform(Vector2(rect.end.x, 0), 0.0, Vector2(-1, 1))
                rect.position.x = 0
            draw_texture_rect(ART[prop.art], rect, false, tint)
            if prop.flip:
                draw_set_transform(Vector2.ZERO)


func _make_fence_chunk(index: int) -> Array[Dictionary]:
    var random := RandomNumberGenerator.new()
    random.seed = world_seed + 4100009 + index * 104729
    var double_leaf := random.randf() < 0.3
    var mirrored := random.randf() < 0.5
    var gate_at_opening := random.randf() < 0.65
    var leaf_count := 2 if double_leaf else 1
    var panel_count := 8 - leaf_count
    var left_count := random.randi_range(1, panel_count - 1)
    var gap := leaf_count * FENCE_WIDTH
    var other_gate_slot := -1
    if not gate_at_opening:
        var candidates: Array[int] = []
        for slot in range(1, panel_count):
            if slot != left_count:
                candidates.append(slot)
        other_gate_slot = candidates[random.randi_range(0, candidates.size() - 1)]
    var sections: Array[Dictionary] = []
    var x := 0.0
    for panel in range(panel_count):
        if panel == left_count:
            # A mirrored entrance starts after a mirrored gate or post; the
            # other orientation ends at a normal gate or post. The opening is
            # only as wide as its leaves when closed, plus small latch gaps.
            if gate_at_opening and mirrored:
                sections.append({"kind": "gate", "x": x, "span": GATE_SPAN, "flip": true})
                x += GATE_SPAN
            sections.append({"kind": "opening", "x": x, "span": gap, "left_leaf": double_leaf or not mirrored, "right_leaf": double_leaf or mirrored})
            x += gap
            if gate_at_opening and not mirrored:
                sections.append({"kind": "gate", "x": x, "span": GATE_SPAN, "flip": false})
                x += GATE_SPAN
        elif panel == other_gate_slot:
            # If the entrance ends at plain posts, put the chunk's gate in the
            # closed run instead. The remaining space is always filled by fence.
            sections.append({"kind": "gate", "x": x, "span": GATE_SPAN, "flip": mirrored})
            x += GATE_SPAN
        sections.append({"kind": "panel", "x": x, "span": FENCE_WIDTH, "flip": random.randf() < 0.5})
        x += FENCE_WIDTH
    # Every chunk starts and ends with a regular panel. Its neighbour supplies
    # the shared end post, even when either chunk is evicted and regenerated.
    for section in range(sections.size()):
        sections[section]["post_at_start"] = sections[section].kind != "gate" and (section == 0 or sections[section - 1].kind != "gate")
    return sections


func _draw_fence() -> void:
    var distance := scroll * 0.5
    var sections: Array[Dictionary] = []
    var indices: Array = fence_chunks.keys()
    indices.sort()
    for index: int in indices:
        for cached: Dictionary in fence_chunks[index]:
            var x: float = index * FENCE_CHUNK_WIDTH + cached.x - distance
            if x + cached.span + 30.0 < 0 or x - 30.0 > VIEW_WIDTH:
                continue
            var section := cached.duplicate()
            section.x = x
            sections.append(section)
    # Crop out the flat end post, retaining all five pickets and the original
    # two rails. No synthetic lines or per-panel height changes are needed.
    # Source sheet x=210..867.02 lies to the right of that post's cap (x=203.36).
    var panel_source := Rect2(190.0 / 867.0 * FENCE.get_width(), 0, 657.02 / 867.0 * FENCE.get_width(), FENCE.get_height())
    var panel_width := 657.02 / 559.0 * FENCE_HEIGHT
    for section: Dictionary in sections:
        if section.kind == "panel":
            if section.flip:
                draw_set_transform(Vector2(section.x + FENCE_WIDTH - 4.5, 0), 0.0, Vector2(-1, 1))
                draw_texture_rect_region(FENCE, Rect2(0, 470 - FENCE_HEIGHT, panel_width, FENCE_HEIGHT), panel_source)
                draw_set_transform(Vector2.ZERO)
            else:
                draw_texture_rect_region(FENCE, Rect2(section.x + 4.5, 470 - FENCE_HEIGHT, panel_width, FENCE_HEIGHT), panel_source)
        elif section.kind == "opening":
            if section.left_leaf:
                _draw_open_leaf(section.x, false)
            if section.right_leaf:
                _draw_open_leaf(section.x + section.span, true)
    # Draw posts over rail ends to mask filtering at the joins. Gate posts are
    # part of their SVG already, aligned to the same shared post centres.
    for section: Dictionary in sections:
        if section.kind == "gate":
            var width := POST_HEIGHT * GATE.get_width() / GATE.get_height()
            if section.flip:
                draw_set_transform(Vector2(section.x + GATE_SPAN + GATE_LEFT_POST, 0), 0.0, Vector2(-1, 1))
                draw_texture_rect(GATE, Rect2(0, 395, width, POST_HEIGHT), false)
                draw_set_transform(Vector2.ZERO)
            else:
                draw_texture_rect(GATE, Rect2(section.x - GATE_LEFT_POST, 395, width, POST_HEIGHT), false)
        elif section.post_at_start:
            var width := POST_HEIGHT * POST.get_width() / POST.get_height()
            draw_texture_rect(POST, Rect2(section.x - POST_CENTRE, 395, width, POST_HEIGHT), false)


func _draw_open_leaf(post_x: float, mirrored: bool) -> void:
    var width := FENCE_HEIGHT * OPEN_FENCE.get_width() / OPEN_FENCE.get_height()
    if mirrored:
        draw_set_transform(Vector2(post_x - 3.0, 0), 0.0, Vector2(-1, 1))
        draw_texture_rect(OPEN_FENCE, Rect2(0, 470 - FENCE_HEIGHT, width, FENCE_HEIGHT), false)
        draw_set_transform(Vector2.ZERO)
    else:
        draw_texture_rect(OPEN_FENCE, Rect2(post_x + 3.0, 470 - FENCE_HEIGHT, width, FENCE_HEIGHT), false)


func _draw_strip(texture: Texture2D, y: float, height: float) -> void:
    var first := floori(scroll / VIEW_WIDTH)
    var offset := fposmod(scroll, VIEW_WIDTH)
    var source := Rect2(8, 0, texture.get_width() - 16, texture.get_height())
    for index in range(2):
        var x := roundf(index * VIEW_WIDTH - offset)
        if posmod(first + index, 2) == 1:
            draw_set_transform(Vector2(x + VIEW_WIDTH, 0), 0.0, Vector2(-1, 1))
            draw_texture_rect_region(texture, Rect2(0, y, VIEW_WIDTH, height), source)
            draw_set_transform(Vector2.ZERO)
        else:
            draw_texture_rect_region(texture, Rect2(x, y, VIEW_WIDTH, height), source)
