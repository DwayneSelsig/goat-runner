extends SceneTree

var failures := 0


func _initialize() -> void:
    call_deferred("_run")


func _check(condition: bool, message: String) -> void:
    if not condition:
        failures += 1
        push_error(message)


func _check_stuck_animation() -> void:
    var visual := (load("res://scenes/goat_scml.tscn") as PackedScene).instantiate()
    root.add_child(visual)
    var player: AnimationPlayer = visual.get_node("AnimationPlayer")
    var original := &"transition_out_of_charge_run_sudden_brake"
    var stuck := &"sock_line_stuck"
    _check(player.has_animation(stuck), "Sock-line animation is missing")
    if player.has_animation(stuck):
        _check(is_equal_approx(player.get_animation(stuck).length, 1.25), "Sock-line animation has the wrong duration")
        _check(player.get_animation(stuck).loop_mode == Animation.LOOP_NONE, "Sock-line animation should hold its last pose")
        for time in [0.0, 0.35, 0.7]:
            player.play(original)
            player.seek(time, true)
            var poses := {}
            for part in visual.get_children():
                if part is Sprite2D:
                    poses[part.name] = [part.transform, part.texture, part.visible, part.z_index]
            player.play(stuck)
            player.seek(time, true)
            for part in visual.get_children():
                if part is Sprite2D:
                    var pose: Array = poses[part.name]
                    _check(part.transform.is_equal_approx(pose[0]) and part.texture == pose[1] and part.visible == pose[2] and part.z_index == pose[3], "Sock-line source differs at %.2f: %s" % [time, part.name])
        player.play(stuck)
        player.seek(0.7, true)
        var settled_position: Vector2 = visual.get_node("body").position
        player.seek(0.79, true)
        _check(not visual.get_node("body").position.is_equal_approx(settled_position), "Sock-line ending does not move")
        player.seek(1.25, true)
        _check(visual.get_node("body").position.is_equal_approx(settled_position), "Sock-line ending did not settle")
    visual.queue_free()


func _run() -> void:
    if not FileAccess.file_exists("res://assets/placeholder-assets.txt"):
        _check_stuck_animation()
    var goat_parts := ["back_leg_upper", "beard", "body", "ear", "front_leg_upper", "grass_one", "grass_two", "head", "hoof", "left_eye_closed", "left_eye_open", "lower_leg", "mouth", "neck", "right_eye_closed", "right_eye_open", "tail"]
    for part in goat_parts:
        _check(load("res://assets/characters/goat/parts/%s.svg" % part) is DPITexture, "Goat SVG must use DPITexture: " + part)
    var packed := load("res://game.tscn") as PackedScene
    if packed == null:
        push_error("Main scene could not be loaded")
        quit(1)
        return
    var game := packed.instantiate()
    game.highscore_path = "res://test-highscore.tmp"
    DirAccess.remove_absolute(ProjectSettings.globalize_path(game.highscore_path))
    root.add_child(game)
    for i in range(5):
        await physics_frame
    var goat: CharacterBody2D = game.get_node("Goat")
    var debug: CanvasLayer = game.get_node("DebugMenu")
    var original_oversampling := root.oversampling_override
    var debug_key := InputEventKey.new()
    debug_key.keycode = KEY_D
    debug_key.ctrl_pressed = true
    debug_key.pressed = true
    debug._input(debug_key)
    _check(debug.get_node("Menu").visible, "Ctrl+D did not open debug menu")
    debug.get_node("Menu/Buttons/Zoom").pressed.emit()
    _check(debug.zoom_mode == 1 and debug.get_node("Camera2D").enabled, "Eye zoom did not start")
    var eye: Sprite2D = goat.get_node("Visual/right_eye_open")
    _check(eye.texture is DPITexture, "Eye must use DPITexture")
    _check(is_equal_approx(root.oversampling_override, 4.0), "Debug zoom did not increase oversampling")
    _check(debug.get_node("Camera2D").global_position.is_equal_approx(eye.to_global(eye.get_rect().get_center())), "Camera did not target the eye")
    debug.get_node("Menu/Buttons/Zoom").pressed.emit()
    var tail: Sprite2D = goat.get_node("Visual/tail")
    _check(tail.texture is DPITexture, "Tail must use DPITexture")
    _check(debug.zoom_mode == 2 and debug.get_node("Camera2D").global_position.is_equal_approx(tail.to_global(tail.get_rect().get_center())), "Camera did not target the tail")
    debug.get_node("Menu/Buttons/Zoom").pressed.emit()
    _check(debug.zoom_mode == 0 and not debug.get_node("Camera2D").enabled, "Camera did not return to normal")
    _check(is_equal_approx(root.oversampling_override, original_oversampling), "Debug zoom did not restore oversampling")
    debug.get_node("Menu/Buttons/Weather").pressed.emit()
    _check(debug.get_node("WeatherPanel").visible, "Weather overlay did not open")
    debug.get_node("Menu/Buttons/Weather").pressed.emit()
    debug._input(debug_key)
    _check(not debug.get_node("WeatherPanel").visible and not debug.get_node("Menu").visible, "Debug controls did not close")
    var head_collision: CollisionShape2D = goat.get_node("HeadCollision")
    var landscape: Node2D = game.get_node("Landscape")
    var sprite: AnimationPlayer = goat.get_node("Visual/AnimationPlayer")
    _check(not goat.has_node("Spritesheet"), "Obsolete PNG spritesheet node remains")
    _check(sprite.has_animation(&"walk") and sprite.current_animation == &"walk", "Walk animation did not start")
    var expected := ["base", "kick", "transition_into_charge", "transition_into_charge_hit", "transition_out_of_charge_run_sudden_brake", "charge", "run", "die", "transition_to_eat", "eating", "transition_from_eat", "walk", "idle"]
    for animation_name in expected:
        _check(sprite.has_animation(animation_name), "Missing SCML animation: " + animation_name)
        if sprite.has_animation(animation_name):
            _check(is_equal_approx(sprite.get_animation(animation_name).length, 1.0), "Incorrect SCML animation duration: " + animation_name)
            var animation := sprite.get_animation(animation_name)
            for track in range(animation.get_track_count()):
                var track_node := NodePath(String(animation.track_get_path(track)).get_slice(":", 0))
                _check(sprite.get_parent().has_node(track_node), "SCML track targets missing node: " + str(track_node))
    _check(not sprite.get_animation(&"game_die").loop_mode and not sprite.get_animation(&"game_to_eat").loop_mode, "Gameplay transitions must not loop")
    _check(goat.position.x > -100.0 and goat.position.x < 105.0, "Goat did not enter from the left")
    _check(not landscape.running and not game.get_node("Obstacles").running, "World started during entrance")
    for i in range(110):
        await physics_frame
    _check(is_equal_approx(goat.position.x, 105.0), "Goat did not reach the starting position")
    _check(sprite.current_animation == &"idle", "Goat did not switch to idle after entrance")
    _check(goat.is_on_floor(), "Goat did not land on the ground")
    _check(not landscape.running, "Landscape moved before starting")
    Input.action_press("jump")
    for i in range(3):
        await physics_frame
    _check(landscape.running, "Game did not start")
    _check(sprite.current_animation == &"jump", "Starting with jump did not show the jump animation")
    var obstacles: Node2D = game.get_node("Obstacles")
    _check(obstacles.running, "Obstacles did not start")
    var score_label: Label = game.get_node("Score")
    _check(game.score == 0 and score_label.text == "Score: 0", "Score should start at zero")
    obstacles.time_until_spawn = 100.0
    var bush_textures: Array[Texture2D] = []
    for i in range(4):
        obstacles._spawn_obstacle(0)
        var bush: Area2D = obstacles.get_child(0)
        var bush_sprite: Sprite2D = bush.get_node("Sprite2D")
        bush_textures.append(bush_sprite.texture)
        _check(is_equal_approx(bush.position.y, 570.0), "Bush did not spawn on the track")
        bush.free()
    _check(bush_textures[0] != bush_textures[1] and bush_textures[1] != bush_textures[2] and bush_textures[0] != bush_textures[2] and bush_textures[0] == bush_textures[3], "Bush variants did not cycle")
    obstacles._spawn_obstacle(0)
    var cleared_obstacle: Area2D = obstacles.get_child(0)
    cleared_obstacle.position.x = goat.position.x
    obstacles._physics_process(0.0)
    _check(game.score == 0, "Obstacle counted before it was fully cleared")
    cleared_obstacle.position.x = goat.position.x - 100.0
    obstacles._physics_process(0.0)
    obstacles._physics_process(0.0)
    _check(game.score == 1 and score_label.text == "Score: 1", "Cleared obstacle should count exactly once")
    _check(game.highscore == 1 and game.get_node("Highscore").text == "Highscore: 1", "Highscore did not update")
    cleared_obstacle.free()
    obstacles.running = false
    _check(goat.velocity.y < 0.0, "Goat did not jump")
    Input.action_release("jump")
    await physics_frame
    var before_double_jump := goat.velocity.y
    Input.action_press("jump")
    await physics_frame
    await physics_frame
    _check(goat.velocity.y > before_double_jump, "Jumping again in air reset the velocity")
    Input.action_release("jump")
    await physics_frame
    var before_duck := goat.velocity.y
    Input.action_press("duck")
    await physics_frame
    await physics_frame
    _check(head_collision.position.y == goat.HEAD_DUCKING_Y, "Duck hitbox did not shrink in air")
    _check(sprite.current_animation == &"charge", "Duck animation did not start")
    _check(goat.velocity.y > before_duck, "Ducking unexpectedly changed upward velocity")
    Input.action_release("duck")
    for i in range(3):
        await physics_frame
    for i in range(100):
        await physics_frame
    _check(goat.is_on_floor(), "Goat did not land after jumping")
    _check(sprite.current_animation == &"run", "Landing did not restore the run animation")
    _check(head_collision.position.y == goat.HEAD_STANDING_Y, "Standing hitbox was not restored")
    var ground_y := goat.position.y
    Input.action_press("jump")
    for i in range(2):
        await physics_frame
    Input.action_release("jump")
    for i in range(12):
        await physics_frame
    var short_jump_height: float = ground_y - goat.position.y
    for i in range(100):
        await physics_frame
    _check(goat.is_on_floor(), "Goat did not land after short jump")
    Input.action_press("jump")
    for i in range(14):
        await physics_frame
    var held_jump_height: float = ground_y - goat.position.y
    _check(goat.velocity.y < 0.0 and not goat.is_on_floor(), "Goat could not jump again after landing")
    _check(held_jump_height > short_jump_height, "Holding jump did not increase jump height")
    Input.action_release("jump")
    for i in range(100):
        await physics_frame
    for obstacle in obstacles.get_children():
        obstacle.queue_free()
    await physics_frame
    obstacles.running = true
    obstacles.time_until_spawn = 100.0
    Input.action_press("duck")
    await physics_frame
    await physics_frame
    obstacles._spawn_obstacle(2)
    var sock: Area2D = obstacles.get_child(0)
    _check(sock.get_node("Sprite2D").texture.resource_path == "res://assets/obstacles/overhead/clothesline_back.svg", "Clothesline artwork was not loaded")
    _check(sock.get_node("FrontPost").z_index == 100 and not sock.get_node("FrontPost").z_as_relative and sock.get_node("FrontPost").flip_h and sock.get_node("Sprite2D").flip_h and sock.get_node("FrontPost").position == sock.get_node("Sprite2D").position, "Clothesline front post layer is misplaced")
    sock.position.x = goat.position.x + 60.0
    for i in range(5):
        await physics_frame
    _check(game.state == 1, "Ducking did not avoid the raised obstacle")
    # The head is clear, but the body is still under the clothesline.
    sock.position.x = goat.position.x - 40.0
    for i in range(2):
        await physics_frame
    Input.action_release("duck")
    for i in range(2):
        await physics_frame
    _check(game.state == 1, "Standing after the head cleared the clothesline caused a collision")
    _check(game.score == 1, "Clothesline counted before the body cleared it")
    Input.action_press("duck")
    await physics_frame
    sock.position.x = goat.position.x + 60.0
    Input.action_release("duck")
    for i in range(5):
        await physics_frame
    _check(game.state == 2, "Standing goat did not collide with raised obstacle")
    _check(not obstacles.running and not landscape.running, "World did not stop after collision")
    _check(sprite.current_animation == &"sock_line_stuck" and sprite.is_playing(), "Sock collision animation did not start")
    _check(goat.get_node("Visual").visible, "Sock collision hid the assembled goat")
    var early_position := goat.position
    _check(early_position.x > goat.stuck_start_x and early_position.x < goat.stuck_start_x + goat.SOCK_CARRY_DISTANCE, "Goat should continue moving briefly after collision")
    for i in range(90):
        await physics_frame
    _check(is_equal_approx(goat.position.x, goat.stuck_start_x + goat.SOCK_CARRY_DISTANCE) and is_equal_approx(goat.position.y, early_position.y), "Goat did not settle after the short forward motion")
    _check(goat.position.x >= sock.position.x and goat.position.x - sock.position.x < 55.0, "Goat did not move into the sock")
    var settled_position := goat.position
    for i in range(5):
        await physics_frame
    _check(goat.position.is_equal_approx(settled_position), "Goat did not remain caught")
    _check(sprite.assigned_animation == &"sock_line_stuck" and not sprite.is_playing() and is_equal_approx(sprite.current_animation_position, 1.25), "Sock collision did not hold the final pose")
    game.queue_free()
    await process_frame
    # A fully held jump must not pass above the clothesline trigger.
    var jump_game := packed.instantiate()
    root.add_child(jump_game)
    var jump_goat: CharacterBody2D = jump_game.get_node("Goat")
    var jump_obstacles: Node2D = jump_game.get_node("Obstacles")
    jump_game.state = 1
    jump_goat.entering = false
    jump_goat.running = true
    jump_obstacles.running = true
    jump_obstacles.time_until_spawn = 100.0
    for i in range(5):
        await physics_frame
    var jump_ground_y := jump_goat.position.y
    Input.action_press("jump")
    for i in range(22):
        await physics_frame
    _check(jump_goat.position.y < jump_ground_y - 80.0, "Held jump did not reach the intended height")
    jump_obstacles._spawn_obstacle(2)
    jump_obstacles.get_child(0).position.x = jump_goat.position.x + 60.0
    for i in range(8):
        await physics_frame
    Input.action_release("jump")
    _check(jump_game.state == 2, "A full-height jump passed over the clothesline")
    jump_game.queue_free()
    await process_frame
    var crash_game := packed.instantiate()
    crash_game.highscore_path = "res://test-highscore.tmp"
    root.add_child(crash_game)
    _check(crash_game.highscore == 1 and crash_game.get_node("Highscore").text == "Highscore: 1", "Highscore was not retained in a new game")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(crash_game.highscore_path))
    _check(crash_game.score == 0 and crash_game.get_node("Score").text == "Score: 0", "New game should reset the score")
    crash_game.state = 1
    crash_game._on_obstacle_hit(0)
    crash_game._on_obstacle_cleared()
    _check(crash_game.score == 0, "Score changed after collision")
    _check(crash_game.get_node("Goat/Visual/AnimationPlayer").current_animation == &"game_die", "Cactus collision should still play the normal collision animation")
    crash_game.queue_free()
    await process_frame
    # Check each goat shape against a ground obstacle independently.
    for target in ["head", "body"]:
        var shape_game := packed.instantiate()
        root.add_child(shape_game)
        var shape_goat: CharacterBody2D = shape_game.get_node("Goat")
        var shape_obstacles: Node2D = shape_game.get_node("Obstacles")
        shape_game.state = 1
        shape_goat.position.x = 200.0
        shape_goat.entering = false
        shape_goat.running = true
        shape_obstacles.running = true
        shape_obstacles.set_physics_process(false)
        for i in range(3):
            await physics_frame
        shape_obstacles._spawn_obstacle(1)
        var puddle: Area2D = shape_obstacles.get_child(0)
        if target == "head":
            puddle.position = shape_goat.position + Vector2(67, -55)
        else:
            puddle.position = shape_goat.position + Vector2(-60, 0)
        for i in range(3):
            await physics_frame
        _check(shape_game.state == 2, "Ground obstacle did not hit the goat's " + target)
        shape_game.queue_free()
        await process_frame
    # A puddle must hit a grounded goat at its normal track position.
    var puddle_game := packed.instantiate()
    root.add_child(puddle_game)
    var puddle_goat: CharacterBody2D = puddle_game.get_node("Goat")
    var puddle_obstacles: Node2D = puddle_game.get_node("Obstacles")
    puddle_game.state = 1
    puddle_goat.position.x = 105.0
    puddle_goat.entering = false
    puddle_goat.running = true
    puddle_obstacles.running = true
    puddle_obstacles.time_until_spawn = 100.0
    for i in range(5):
        await physics_frame
    puddle_obstacles._spawn_obstacle(1)
    var track_puddle: Area2D = puddle_obstacles.get_child(0)
    _check(track_puddle.get_node("Sprite2D").texture.resource_path == "res://assets/obstacles/ground/puddle.svg", "Puddle artwork was not loaded")
    var puddle_sprite: Sprite2D = track_puddle.get_node("Sprite2D")
    var puddle_shape: CollisionShape2D = track_puddle.get_node("CollisionShape2D")
    _check(puddle_sprite.texture.get_width() * puddle_sprite.scale.x > (puddle_shape.shape as RectangleShape2D).size.x, "Puddle must have a walkable rim")
    puddle_obstacles.set_physics_process(false)
    track_puddle.position.x = puddle_goat.position.x + 120.0
    for i in range(5):
        await physics_frame
    _check(puddle_game.state == 1, "Walking on the puddle rim caused a collision")
    track_puddle.position.x = puddle_goat.position.x + 70.0
    puddle_obstacles.set_physics_process(true)
    for i in range(10):
        await physics_frame
    _check(puddle_game.state == 2, "Grounded goat did not collide with puddle")
    _check(puddle_goat.sinking and puddle_goat.get_node("Visual/AnimationPlayer").current_animation == &"game_die", "Puddle did not start the sinking death animation")
    var water_center := track_puddle.global_position
    for i in range(70):
        await physics_frame
    _check(is_equal_approx(puddle_goat.global_position.x, water_center.x + puddle_goat.PUDDLE_DEATH_OFFSET_X), "Goat did not settle at the adjusted puddle position")
    _check(is_equal_approx(puddle_goat.global_position.y, water_center.y), "Goat did not settle at the normal ground height")
    _check(track_puddle.z_index == 1, "Puddle should retain its collision layer order")
    puddle_game.queue_free()
    await process_frame
    var feed_game := packed.instantiate()
    root.add_child(feed_game)
    var feed_goat: CharacterBody2D = feed_game.get_node("Goat")
    var feed_obstacles: Node2D = feed_game.get_node("Obstacles")
    var feed_sprite: AnimationPlayer = feed_goat.get_node("Visual/AnimationPlayer")
    feed_game.state = 1
    feed_goat.position.x = 180.0
    feed_goat.entering = false
    feed_goat.running = true
    feed_obstacles.running = true
    feed_obstacles.time_until_spawn = 100.0
    feed_game.get_node("Landscape").running = true
    for i in range(5):
        await physics_frame
    feed_obstacles._spawn_obstacle(3)
    var trough: Area2D = feed_obstacles.get_child(0)
    trough.position.x = feed_goat.position.x + 50.0
    for i in range(5):
        await physics_frame
    _check(feed_game.state == 4, "Feed trough did not end the run with eating")
    _check(feed_sprite.current_animation == &"game_to_eat", "Eating transition did not start")
    _check(not feed_obstacles.running and not feed_game.get_node("Landscape").running, "World did not stop at feed trough")
    _check(feed_game.get_node("RetryButton").visible, "Retry button is missing after eating")
    Input.action_press("jump")
    Input.action_press("duck")
    for i in range(90):
        await physics_frame
    _check(feed_game.state == 4 and feed_goat.is_on_floor(), "Gameplay controls affected the eating goat")
    _check(feed_sprite.current_animation == &"eating" and feed_sprite.is_playing(), "Eating animation did not loop")
    Input.action_release("jump")
    Input.action_release("duck")
    feed_game.queue_free()
    if failures == 0:
        print("Smoke test passed")
    quit(1 if failures else 0)
