extends SceneTree

var failures := 0

func check(condition: bool, message: String) -> void:
    if not condition:
        failures += 1
        push_error(message)

func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    var packed := load("res://game.tscn") as PackedScene
    var game := packed.instantiate()
    root.add_child(game)
    var obstacles = game.get_node("Obstacles")
    check(is_equal_approx(obstacles.spawn_interval(0.0), 3.3), "Initial interval changed")
    check(is_equal_approx(obstacles.spawn_interval(20.0), 3.3), "Warmup interval changed")
    var previous: float = obstacles.spawn_interval(0.0)
    for second in range(1, 3601):
        var interval: float = obstacles.spawn_interval(float(second))
        check(interval <= previous and interval >= obstacles.MIN_SPAWN_INTERVAL - 0.00001, "Interval is not bounded and decreasing at %d" % second)
        previous = interval
    check(is_equal_approx(obstacles.spawn_interval(1800.0), obstacles.MIN_SPAWN_INTERVAL), "30-minute interval is not the minimum")
    game.free()

    # Exercise all ordered pairs at the most demanding spacing with real Godot
    # movement and collision shapes, including repeated types and transitions.
    for first in range(4):
        for second in range(4):
            game = packed.instantiate()
            root.add_child(game)
            var goat = game.get_node("Goat")
            obstacles = game.get_node("Obstacles")
            game.state = 1
            goat.position.x = 105.0
            goat.entering = false
            goat.running = true
            obstacles.running = true
            obstacles.time_until_spawn = 1000.0
            for frame in range(5):
                await physics_frame
            obstacles._spawn_obstacle(first)
            obstacles._spawn_obstacle(second)
            var a: Area2D = obstacles.get_child(0)
            var b: Area2D = obstacles.get_child(1)
            a.position.x = goat.position.x + 300.0
            b.position.x = a.position.x + obstacles.SPEED * obstacles.MIN_SPAWN_INTERVAL
            var jumped := [false, false]
            var hold_frames := 0
            for frame in range(200):
                var target: Area2D = null
                if not jumped[0] and first != 2:
                    target = a
                elif not jumped[1] and second != 2:
                    target = b
                if is_instance_valid(target) and target.position.x - goat.position.x <= 260.0 and goat.is_on_floor():
                    Input.action_press("jump")
                    hold_frames = 25
                    if target == a:
                        jumped[0] = true
                    else:
                        jumped[1] = true
                if hold_frames > 0:
                    Input.action_release("duck")
                    hold_frames -= 1
                    if hold_frames == 0:
                        Input.action_release("jump")
                else:
                    Input.action_press("duck")
                await physics_frame
            Input.action_release("jump")
            Input.action_release("duck")
            check(game.state == 1 and game.score == 2, "Pair %d -> %d could not be cleared at minimum spacing (state %d, score %d)" % [first, second, game.state, game.score])
            game.free()
            await process_frame
    if failures == 0:
        print("Obstacle scheduling test passed")
    quit(1 if failures else 0)





