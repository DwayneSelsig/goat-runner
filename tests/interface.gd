extends SceneTree

var failures := 0

func check(condition: bool, description: String) -> void:
    if not condition:
        failures += 1
        push_error(description)

func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    var game = load("res://game.tscn").instantiate()
    game.highscore_path = "res://ui-test-highscore.cfg"
    var ui = game.get_node("Interface")
    ui.settings_path = "res://ui-test-settings.cfg"
    DirAccess.remove_absolute(ProjectSettings.globalize_path(game.highscore_path))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(ui.settings_path))
    root.add_child(game)
    await process_frame
    check(ui.touch_visible and ui.controls[0].visible and ui.controls[1].visible, "Touch controls should be visible by default")
    var space := InputEventKey.new()
    space.keycode = KEY_SPACE
    space.pressed = true
    game.state = game.State.READY
    game._input(space)
    check(not ui.touch_visible and not ui.controls[0].visible and not ui.visibility_toggle.button_pressed, "Start with Space must hide touch controls")
    game.start_run()
    check(ui.touch_visible and ui.controls[0].visible and ui.visibility_toggle.button_pressed, "Starting by another input must show touch controls")
    game.state = game.State.READY
    game._input(space)
    check(not ui.touch_visible, "Space on a later start must hide touch controls")
    game.start_run()
    var up := InputEventKey.new()
    up.keycode = KEY_UP
    up.pressed = true
    game.state = game.State.READY
    game._input(up)
    check(not ui.touch_visible, "Starting with Up must hide touch controls")
    ui._visibility_changed(true)
    check(ui.controls[0].position.x == ui.controls[1].position.x and ui.controls[0].position.y < ui.controls[1].position.y, "Jump must start above duck")
    ui.show_start()
    check(ui.message.visible and ui.message_kind == -1, "Start menu missing")
    for kind in 4:
        ui.show_game_over(kind, 7)
        check(ui.message.visible and ui.message_kind == kind and ui.message_detail.text.contains("7"), "Game over reason or score missing")
    ui._language_selected(1)
    check(ui.message_title.text == "Spel voorbij" and ui.message_detail.text.contains("hooibaal"), "Dutch translation missing")
    ui._language_selected(2)
    check(ui.message_title.text == "Spiel vorbei" and ui.message_detail.text.contains("Heuballen"), "German translation missing")
    check(ui.controls[0]._get_cursor_shape(Vector2(10, 10)) == Control.CURSOR_ARROW, "Gameplay cursor should remain normal")
    ui._toggle_settings()
    check(ui.controls[0]._get_cursor_shape(Vector2(10, 10)) == Control.CURSOR_MOVE, "Editing should show the move cursor")
    check(ui.controls[0]._get_cursor_shape(ui.controls[0].size - Vector2(5, 5)) == Control.CURSOR_BDIAGSIZE, "Resize handle should show the diagonal resize cursor")
    check(paused and ui.controls[0].editing and ui.controls[1].editing, "Settings must pause and edit both controls")
    var animated_position: Vector2 = ui.controls[0].position
    var animated_size: Vector2 = ui.controls[0].size
    check(ui.controls[0].attention_duration > 0.0 and ui.controls[1].attention_duration > 0.0, "Both controls should animate on opening settings")
    await process_frame
    check(ui.controls[0].attention_elapsed > 0.0 and ui.controls[0].position == animated_position and ui.controls[0].size == animated_size, "Animation must run while paused without changing layout")
    ui.controls[0]._begin(Vector2(10, 10))
    check(ui.controls[0].attention_duration == 0.0 and ui.controls[0].moving, "Dragging must interrupt animation immediately")
    ui.controls[0]._end()
    ui.controls[1]._begin(ui.controls[1].size - Vector2(5, 5))
    check(ui.controls[1].attention_duration == 0.0 and ui.controls[1].resizing, "Resizing must interrupt animation immediately")
    ui.controls[1]._end()
    ui.controls[1].set_editing(true)
    ui.controls[1]._process(0.7)
    check(ui.controls[1].attention_duration == 0.0, "Animation must finish within 0.7 seconds")
    ui.controls[1].set_editing(true)
    ui.controls[1].set_editing(false)
    check(ui.controls[1].attention_duration == 0.0, "Leaving editing must stop animation")
    ui.controls[1].set_editing(true)
    ui._open_keybinds()
    ui._capture_key("jump")
    var down := InputEventKey.new()
    down.keycode = KEY_DOWN
    down.pressed = true
    ui._input(down)
    check(down.is_action_pressed("duck") and not down.is_action_pressed("jump"), "Pending changes must not affect active bindings")
    ui._cancel_keybinds()
    check(ui.extra_keys.jump == 0 and down.is_action_pressed("duck"), "Cancel must discard changes")
    ui._open_keybinds()
    ui._capture_key("jump")
    ui._input(down)
    ui._confirm_keybinds()
    check(down.is_action_pressed("jump") and not down.is_action_pressed("duck"), "Assigned default must move to the selected action")
    var bindings := ConfigFile.new()
    check(bindings.load(ui.settings_path) == OK and bindings.get_value("keybinds", "jump") == KEY_DOWN, "Confirmed binding must be saved")
    ui._open_keybinds()
    ui._clear_key("jump")
    ui._confirm_keybinds()
    check(down.is_action_pressed("duck") and not down.is_action_pressed("jump"), "Removing an extra key must restore the default")
    var letter := InputEventKey.new()
    letter.keycode = KEY_K
    letter.pressed = true
    ui._open_keybinds()
    ui._capture_key("jump")
    ui._input(letter)
    ui._capture_key("duck")
    ui._input(letter)
    check(ui.pending_keys.jump == 0 and ui.pending_keys.duck == KEY_K, "Assigning an extra key twice must transfer it")
    ui._reset_pending_keys()
    check(ui.pending_keys.jump == 0 and ui.pending_keys.duck == 0, "Reset must clear both extra keys")
    ui._capture_key("jump")
    ui._input(letter)
    ui._confirm_keybinds()
    check(letter.is_action_pressed("jump") and not letter.is_action_pressed("duck"), "Extra jump key was not applied")
    await process_frame
    await process_frame
    await process_frame
    check(ui.close_settings.position.distance_to(ui.gear.position) < 0.01, "Settings close button should overlap the gear")
    check(ui.settings_drag_handle.visible and ui.settings_drag_handle.position == ui.settings.position and ui.settings_drag_handle.size.x == ui.settings.size.x - 84.0, "Drag handle should cover the top edge without covering the close button")
    check(ui.settings.size.y < 650, "Settings panel must fit its content")
    ui.settings.size = Vector2(460, 1500)
    ui._fit_settings()
    await process_frame
    check(ui.settings.size.y < 650, "Settings panel retained excess height")
    var original_position: Vector2 = ui.settings.position
    var press := InputEventMouseButton.new()
    press.button_index = MOUSE_BUTTON_LEFT
    press.pressed = true
    ui._settings_header_input(press)
    var motion := InputEventMouseMotion.new()
    motion.relative = Vector2(-90, 50)
    ui._settings_header_input(motion)
    check(ui.settings.position.is_equal_approx(original_position + Vector2(-90, 50)), "Mouse drag did not move settings")
    check(ui.close_settings.position.is_equal_approx(ui.settings.position + Vector2(ui.settings.size.x - 84, 14)), "Close button did not follow settings")
    check(ui.settings_drag_handle.position == ui.settings.position, "Drag handle did not follow settings")
    press.pressed = false
    ui._settings_header_input(press)
    var touch := InputEventScreenTouch.new()
    touch.index = 2
    touch.pressed = true
    ui._settings_header_input(touch)
    var drag := InputEventScreenDrag.new()
    drag.index = 2
    drag.relative = Vector2(5000, 5000)
    ui._settings_header_input(drag)
    check(ui.settings.position.x + ui.settings.size.x <= root.get_visible_rect().size.x + 0.01 and ui.settings.position.y + ui.settings.size.y <= root.get_visible_rect().size.y + 0.01, "Settings drag escaped the screen")
    touch.pressed = false
    ui._settings_header_input(touch)
    ui.opacity_slider.value = 0.35
    check(is_equal_approx(ui.controls[0].button_opacity, 0.35) and is_equal_approx(ui.controls[1].button_opacity, 0.35), "Opacity must update both controls")
    var opacity_config := ConfigFile.new()
    check(opacity_config.load(ui.settings_path) == OK and is_equal_approx(float(opacity_config.get_value("settings", "touch_opacity")), 0.35), "Opacity must persist")
    ui.controls[0].position = Vector2(100, 100)
    ui.controls[0].size = Vector2(80, 80)
    ui.controls[1].position = Vector2(400, 200)
    ui.controls[1].size = Vector2(150, 150)
    ui._save_layout()
    ui._layout_controls()
    check(ui.controls[0].position.distance_to(Vector2(100, 100)) < 0.01 and absf(ui.controls[0].size.x - 80) < 0.01, "Jump layout not saved")
    check(ui.controls[1].position.distance_to(Vector2(400, 200)) < 0.01 and absf(ui.controls[1].size.x - 150) < 0.01, "Duck layout not saved independently")
    ui._reset_layout()
    check(ui.controls[0].size.x == 110 and ui.controls[1].size.x == 110, "Layout reset failed")
    check(ui.controls[0].position.x == ui.controls[1].position.x and ui.controls[0].position.y < ui.controls[1].position.y, "Layout reset should place jump above duck")
    game.score = 5
    game.highscore = 8
    ui.widgets["RESET_SCORE"].pressed.emit()
    check(ui.score_overlay.visible, "High score confirmation should open")
    ui.score_cancel.pressed.emit()
    check(not ui.score_overlay.visible and game.highscore == 8 and game.score == 5, "Cancel must preserve scores")
    ui.widgets["RESET_SCORE"].pressed.emit()
    ui.score_confirm.pressed.emit()
    var stored := ConfigFile.new()
    check(not ui.score_overlay.visible and stored.load(game.highscore_path) == OK and stored.get_value("scores", "highscore") == 0 and game.score == 5, "High score reset failed")
    ui.close_settings.pressed.emit()
    check(not paused and not ui.controls[0].editing and not ui.settings.visible and not ui.settings_drag_handle.visible, "Close button did not resume the game")
    game.state = game.State.READY
    game._input(letter)
    check(game.state == game.State.RUNNING and not ui.touch_visible, "Configured jump key must start and hide controls")
    game.queue_free()
    await process_frame
    var reloaded = load("res://game.tscn").instantiate()
    reloaded.highscore_path = "res://ui-test-highscore.cfg"
    reloaded.get_node("Interface").settings_path = "res://ui-test-settings.cfg"
    root.add_child(reloaded)
    await process_frame
    check(letter.is_action_pressed("jump") and reloaded.get_node("Interface").extra_keys.jump == KEY_K, "Binding must survive a scene reload")
    reloaded.queue_free()
    await process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path("res://ui-test-highscore.cfg"))
    DirAccess.remove_absolute(ProjectSettings.globalize_path("res://ui-test-settings.cfg"))
    if failures == 0: print("Interface test passed")
    quit(1 if failures else 0)


