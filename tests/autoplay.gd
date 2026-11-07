extends SceneTree

var failures := 0

func check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error(message)

func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    var packed := load("res://game.tscn") as PackedScene
    for seed_value in range(5):
        var game = packed.instantiate()
        game.highscore_path = "res://test-autoplay-highscore.tmp"
        # The landscape is visual only; its chunk generation is tested separately.
        var landscape: Node2D = game.get_node("Landscape")
        landscape.process_mode = Node.PROCESS_MODE_DISABLED
        landscape.visible = false
        root.add_child(game)
        var debug = game.get_node("DebugMenu")
        var obstacles = game.get_node("Obstacles")
        var goat = game.get_node("Goat")
        obstacles.rng.seed = seed_value
        debug.action_rng.seed = seed_value + 100
        debug.get_node("Menu/Buttons/Autoplay").pressed.emit()
        check(debug.autoplay and goat.autoplay and game.state == game.State.RUNNING, "Autoplay did not start the game")
        check(obstacles.elapsed >= obstacles.MAX_DIFFICULTY_SECONDS, "Autoplay did not start at maximum difficulty")
        for frame in range(3600):
            await physics_frame
            if game.state != game.State.RUNNING:
                break
        if game.state != game.State.RUNNING:
            for obstacle in obstacles.get_children():
                print("kind ", obstacle.get_meta("kind"), " x ", obstacle.position.x - goat.position.x, " marked ", obstacle.has_meta("auto_jumped"), " goat y ", goat.position.y)
        check(game.state == game.State.RUNNING and game.score >= 60, "Autoplay seed %d stopped at score %d" % [seed_value, game.score])
        debug.get_node("Menu/Buttons/Autoplay").pressed.emit()
        check(not goat.autoplay and not goat.auto_jump_held and not goat.auto_duck, "Autoplay did not release controls")
        game.free()
        await process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path("res://test-autoplay-highscore.tmp"))
    if failures == 0:
        print("Autoplay tests passed")
    quit(1 if failures else 0)
