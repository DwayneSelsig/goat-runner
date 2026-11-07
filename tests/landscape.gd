extends SceneTree

var failures := 0
var fence_styles: Dictionary = {}
var foreground_art: Dictionary = {}
var foreground_positions: Dictionary = {}
var tall_foreground_corn := 0


func check(condition: bool, message: String) -> void:
    if not condition:
        failures += 1
        push_error(message)


func _initialize() -> void:
    call_deferred("run_tests")


func check_chunks(scenery: Node2D) -> void:
    for layer in range(4):
        var cache: Dictionary = scenery.chunks[layer]
        check(cache.size() <= 6, "Scenery cache grew beyond viewport plus buffer")
        for index: int in cache:
            var chunk: Dictionary = cache[index]
            if layer < 3 and cache.has(index + 1):
                var next: Dictionary = cache[index + 1]
                check(chunk.surface[-1].y == next.surface[0].y, "Terrain seam at chunk boundary")
                check(chunk.surface[-1].x == scenery.CHUNK_WIDTH and next.surface[0].x == 0.0, "Terrain samples do not span the chunk")
                for band in range(chunk.bands.size()):
                    check(chunk.bands[band][-1].y == next.bands[band][0].y, "Field boundary seam")
            if layer == 3:
                check(not chunk.props.is_empty(), "Foreground chunk should not be empty")
                var foreground_rects: Array[Rect2] = []
                for prop: Dictionary in chunk.props:
                    foreground_rects.append(prop.rect)
                foreground_rects.sort_custom(func(a: Rect2, b: Rect2) -> bool: return a.position.x < b.position.x)
                var covered_until := 0.0
                for i in range(foreground_rects.size()):
                    var gap := foreground_rects[i].position.x - covered_until
                    check(gap <= (120.0 if i == 0 else 210.0), "Foreground has an oversized empty gap")
                    covered_until = maxf(covered_until, foreground_rects[i].end.x)
                check(scenery.CHUNK_WIDTH - covered_until <= 120.0, "Foreground has an oversized gap at the chunk boundary")
            for prop: Dictionary in chunk.props:
                var rect: Rect2 = prop.rect
                check(rect.position.x >= 0 and rect.end.x <= scenery.CHUNK_WIDTH, "Decor escaped its cluster's reserved chunk space")
                if layer == 3:
                    if prop.art in scenery.FOREGROUND_CORN or prop.art in scenery.FOREGROUND_SUNFLOWERS:
                        check(rect.size.y >= (120.0 if prop.art in scenery.FOREGROUND_CORN else 100.0), "Tall crops should retain their intended scale")
                        check(rect.position.y >= 555.0 and rect.end.y <= 730.0, "Tall crops extend beyond their foreground bounds")
                        if prop.art in scenery.FOREGROUND_CORN:
                            tall_foreground_corn += 1
                    else:
                        check(rect.position.y >= 640.0 and rect.end.y <= 720.0, "Low foreground decor extends beyond its bounds")
                    foreground_art[prop.art] = true
                    foreground_positions[roundi(rect.end.y)] = true
                else:
                    check(rect.end.y <= 470, "Background decor entered the play lane")
                var texture: Texture2D = scenery.ART[prop.art]
                check(is_equal_approx(rect.size.aspect(), texture.get_size().aspect()), "Decor aspect ratio changed")
    check(scenery.fence_chunks.size() <= 6, "Fence cache grew beyond viewport plus buffer")
    for index: int in scenery.fence_chunks:
        var sections: Array = scenery.fence_chunks[index]
        check(sections[0].kind == "panel" and sections[-1].kind == "panel", "Fence chunk lost a shared boundary post")
        var end := 0.0
        for section: Dictionary in sections:
            check(is_equal_approx(section.x, end), "Fence sections overlap or leave an unintended gap")
            end = section.x + section.span
            if section.kind == "opening":
                var leaves := int(section.left_leaf) + int(section.right_leaf)
                check(leaves >= 1 and section.span - leaves * 44.0 > 20.0, "Open leaves obscure the passage")
                var closed_width: float = leaves * scenery.GATE_SPAN
                check(section.span >= closed_width and section.span <= closed_width + leaves * 5.0, "Opening would not close: excessive space beyond gate leaf width")
                var style := "double" if leaves == 2 else "normal" if section.left_leaf else "mirrored"
                fence_styles[style] = true
            elif section.kind == "gate":
                fence_styles["gate_mirrored" if section.flip else "gate_normal"] = true
                check(not section.post_at_start, "A gate acquired a duplicate standalone post")
        check(is_equal_approx(end, scenery.FENCE_CHUNK_WIDTH), "Fence chunk does not meet its neighbour")


func run_tests() -> void:
    root.get_node("Weather").request.cancel_request()
    var packed := load("res://scenes/landscape.tscn") as PackedScene
    var landscape := packed.instantiate()
    landscape.landscape_seed = 47123
    root.add_child(landscape)
    landscape.set_process(false)
    landscape.set_physics_process(false)
    var scenery: Node2D = landscape.get_node("FarmScenery")
    var initial := var_to_str([scenery.chunks, scenery.fence_chunks])
    var other := packed.instantiate()
    other.landscape_seed = 47123
    root.add_child(other)
    other.set_process(false)
    other.set_physics_process(false)
    var second: Node2D = other.get_node("FarmScenery")
    check(var_to_str([second.chunks, second.fence_chunks]) == initial, "Equal seeds produced different scenery")
    second.configure(47124)
    check(var_to_str([second.chunks, second.fence_chunks]) != initial, "Different seeds produced identical scenery")
    seed(85291)
    var expected := [randi(), randi(), randi()]
    seed(85291)
    second.configure(47123)
    second.set_scroll(98765.4321)
    check([randi(), randi(), randi()] == expected, "Scenery advanced the gameplay random stream")
    var game := (load("res://game.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var obstacles: Node2D = game.get_node("Obstacles")
    var reference_rng := RandomNumberGenerator.new()
    reference_rng.seed = 63912
    obstacles.rng.seed = reference_rng.seed
    obstacles.elapsed = obstacles.WARMUP_SECONDS
    obstacles.running = true
    for sample in range(12):
        var previous_state: int = obstacles.rng.state
        second.configure(9000 + sample)
        second.set_scroll(sample * 17191.31)
        check(obstacles.rng.state == previous_state, "Scenery changed the obstacle RNG state")
        obstacles.time_until_spawn = 0.0
        obstacles._physics_process(0.0)
        check(obstacles.next_kind == reference_rng.randi_range(0, 3), "Scenery changed the actual obstacle schedule")
        for obstacle in obstacles.get_children():
            obstacle.free()
    game.free()
    for step in range(201):
        scenery.set_scroll(step * 5231.91)
        check_chunks(scenery)
    scenery.set_scroll(0.0)
    check(var_to_str([scenery.chunks, scenery.fence_chunks]) == initial, "Eviction/revisit changed scenery")
    for style in ["normal", "mirrored", "double", "gate_normal", "gate_mirrored"]:
        check(fence_styles.has(style), "Fence sequence is missing variation: " + style)
    for name in ["grass", "grass_tall", "sprout_low", "sprout_tall", "lettuce", "carrots", "sunflowers", "sunflower_single", "corn", "corn_single_a", "corn_single_b"]:
        check(foreground_art.has(name), "Foreground never generated plant: " + name)
    check(tall_foreground_corn > 0 and foreground_positions.size() > 8, "Foreground should include larger corn and varied vertical positions")
    landscape.running = false
    landscape._physics_process(1.0)
    check(landscape.scroll == 0.0 and scenery.scroll == 0.0, "Scenery moved while paused")
    landscape.running = true
    landscape._physics_process(1.0)
    check(landscape.scroll == 550.0 and scenery.scroll == 550.0, "Scenery did not follow running state")
    landscape.running = false
    landscape._physics_process(1.0)
    check(scenery.scroll == 550.0, "Scenery did not stop with the world")
    second.configure()
    var first_random_seed: int = second.world_seed
    second.configure()
    check(first_random_seed != second.world_seed, "New run reused the landscape seed")
    check(scenery.find_children("*", "CollisionObject2D", true, false).is_empty(), "Decor added physics objects")
    landscape.free()
    other.free()
    if failures == 0:
        print("Landscape tests passed")
    quit(1 if failures else 0)
