extends SceneTree

var failures := 0


func _initialize() -> void:
    call_deferred("_run")


func _check(condition: bool, message: String) -> void:
    if not condition:
        failures += 1
        push_error(message)


func _step() -> void:
    await physics_frame
    await process_frame


func _run() -> void:
    var floor_body := StaticBody2D.new()
    var collision := CollisionShape2D.new()
    var shape := RectangleShape2D.new()
    shape.size = Vector2(2000.0, 60.0)
    collision.shape = shape
    floor_body.add_child(collision)
    floor_body.position = Vector2(500.0, 600.0)
    root.add_child(floor_body)
    var goat = (load("res://scenes/goat.tscn") as PackedScene).instantiate()
    goat.position = Vector2(300.0, 570.0)
    root.add_child(goat)
    goat.autoplay = true
    goat.running = true
    await _step()
    await _step()
    var player: AnimationPlayer = goat.animation_player
    var animation := player.get_animation(&"jump")
    _check(animation != null and animation.loop_mode == Animation.LOOP_NONE, "Jump must exist and not loop")
    for track in range(animation.get_track_count()):
        var target := NodePath(String(animation.track_get_path(track)).get_slice(":", 0))
        _check(player.get_parent().has_node(target), "Missing jump target: " + str(target))
    # The public placeholder has independent artwork; verify authored poses in the private build.
    if not FileAccess.file_exists("res://assets/placeholder-assets.txt"):
        # Endpoints retain a running stride, rather than the kick's standing pose.
        player.play(&"kick")
        player.seek(0.0, true)
        var standing_hooves := {}
        for hoof in ["hoof", "hoof_000", "hoof_001", "hoof_002"]:
            standing_hooves[hoof] = player.get_parent().get_node(hoof).position.y
        player.play(&"run")
        player.seek(0.0, true)
        var grounded := {}
        for part in player.get_parent().get_children():
            if part is Sprite2D:
                grounded[part.name] = part.transform
        player.play(&"jump", -1.0, 0.0)
        for time in [0.0, 1.0]:
            player.seek(time, true)
            for part in player.get_parent().get_children():
                if part is Sprite2D:
                    _check(part.transform.is_equal_approx(grounded[part.name]), "Jump endpoint differs: " + str(part.name))
        player.seek(0.3, true)
        var rising_pitch: float = player.get_parent().get_node("body").rotation
        var rising_head: float = player.get_parent().get_node("head").rotation
        player.seek(0.75, true)
        _check(player.get_parent().get_node("body").rotation - rising_pitch < -deg_to_rad(15.0), "Jump did not pitch from nose-up ascent to nose-down landing")
        _check(absf(player.get_parent().get_node("head").rotation - rising_head) < deg_to_rad(10.0), "Jump gaze did not stay steady through the bound")
        player.seek(0.5, true)
        var apex_hooves := {}
        for hoof in ["hoof", "hoof_000", "hoof_001", "hoof_002"]:
            apex_hooves[hoof] = player.get_parent().get_node(hoof).position
            _check(apex_hooves[hoof].y < standing_hooves[hoof] - 180.0, "Hoof hung below the gathered flight pose: " + hoof)
        player.seek(0.28, true)
        for hoof in ["hoof", "hoof_001"]:
            _check(player.get_parent().get_node(hoof).position.x > apex_hooves[hoof].x + 150.0, "Rear leg did not trail before gathering: " + hoof)
        player.seek(0.82, true)
        for hoof in ["hoof_000", "hoof_002"]:
            var landing_hoof: Vector2 = player.get_parent().get_node(hoof).position
            _check(landing_hoof.x < apex_hooves[hoof].x - 80.0 and landing_hoof.y > apex_hooves[hoof].y + 150.0, "Foreleg did not reach forward and down for landing: " + hoof)
    var heights: Array[float] = []
    var durations: Array[int] = []
    for hold_frames in [1, 8, 100]:
        var ground_y: float = goat.position.y
        var expected_y := ground_y
        var expected_velocity := 0.0
        var previous_phase := 0.0
        var minimum_y := ground_y
        var descending_frames := 0
        var landed := false
        for frame in range(100):
            goat.auto_jump_pressed = frame == 0 or frame == 4
            goat.auto_jump_held = frame < hold_frames
            # Exercise both overrides and restoration while phase keeps moving.
            goat.auto_duck = frame == 2 or frame == 3 or descending_frames == 2 or descending_frames == 3
            if frame == 0:
                expected_velocity = goat.JUMP_SPEED
            var gravity: float = goat.GRAVITY
            if expected_velocity < 0.0 and not goat.auto_jump_held:
                gravity *= goat.RELEASE_GRAVITY_MULTIPLIER
            expected_velocity += gravity / 60.0
            expected_y += expected_velocity / 60.0
            await _step()
            minimum_y = minf(minimum_y, goat.position.y)
            if goat.is_on_floor():
                _check(frame > 5, "Jump landed prematurely")
                _check(player.current_animation == (&"charge" if goat.auto_duck else &"run"), "Landing did not restore ground animation")
                durations.append(frame + 1)
                landed = true
                break
            _check(absf(goat.velocity.y - expected_velocity) < 0.02, "Jump animation changed physics velocity")
            # Native floor recovery can displace the first step by safe_margin.
            _check(absf(goat.position.y - expected_y) < goat.safe_margin + 0.01, "Jump physics position: frame %d actual %.4f expected %.4f" % [frame, goat.position.y, expected_y])
            _check(goat.jump_phase >= previous_phase and goat.jump_phase <= 1.0, "Jump phase reversed or exceeded range")
            previous_phase = goat.jump_phase
            if goat.velocity.y >= 0.0:
                descending_frames += 1
                _check(goat.jump_phase >= 0.5, "Descent did not reach the apex pose")
            else:
                _check(goat.jump_phase < 0.5, "Ascent entered the landing phase")
            if goat.auto_duck:
                _check(player.current_animation == &"charge", "Air duck did not override jump")
                _check(goat.head_collision.position.y == goat.HEAD_DUCKING_Y, "Air duck hitbox changed")
            else:
                _check(player.current_animation == &"jump", "Airborne goat did not use jump")
                _check(absf(player.current_animation_position - goat.jump_phase) < 0.001, "Pose did not follow actual jump phase")
                _check(goat.head_collision.position.y == goat.HEAD_STANDING_Y, "Standing hitbox changed")
        _check(landed and descending_frames > 3, "Jump did not complete ascent and descent")
        heights.append(ground_y - minimum_y)
        goat.auto_duck = false
        goat.auto_jump_pressed = false
        await _step()
    _check(heights[0] < heights[1] and heights[1] < heights[2], "Hold duration no longer changes jump height")
    _check(durations.size() == 3 and durations[0] < durations[1] and durations[1] < durations[2], "Jump duration did not vary")
    for reaction in ["die", "catch_on_sock", "eat"]:
        goat.dead = false
        goat.stuck = false
        goat.running = true
        goat.auto_jump_pressed = true
        await _step()
        goat.auto_jump_pressed = false
        goat.call(reaction)
        await _step()
        var expected := &"game_die" if reaction == "die" else (&"sock_line_stuck" if reaction == "catch_on_sock" else &"game_to_eat")
        _check(player.current_animation == expected, "Jump replaced collision reaction: " + reaction)
    goat.free()
    floor_body.free()
    if failures == 0:
        print("Jump tests passed: heights %s, durations %s" % [heights, durations])
    quit(1 if failures else 0)
