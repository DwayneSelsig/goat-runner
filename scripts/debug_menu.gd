extends CanvasLayer

const ZOOM_LEVELS := [1.0, 32.0, 16.0]
const ZOOM_OVERSAMPLING := 4.0

const ACTION_DISTANCE := 230.0
const ACTION_VARIATION := 4.0
const JUMP_HOLDS := [0.25, 0.25, 0.0, 0.32]

var autoplay := false
var jump_remaining := 0.0
var action_rng := RandomNumberGenerator.new()
var zoom_mode := 0
var previous_visual_visible := true
var previous_oversampling := 0.0
var weather_controls: Window
var manual_toggle: CheckButton
var night_toggle: CheckButton
var moon_toggle: CheckButton
var weather_sliders: Dictionary = {}
var weather_values: Dictionary = {}

@onready var menu: PanelContainer = $Menu
@onready var zoom_button: Button = $Menu/Buttons/Zoom
@onready var weather_panel: PanelContainer = $WeatherPanel
@onready var weather_text: TextEdit = $WeatherPanel/WeatherText
@onready var camera: Camera2D = $Camera2D
@onready var goat: CharacterBody2D = get_parent().get_node("Goat")
@onready var visual: Node2D = goat.get_node("Visual")
@onready var weather: Node = get_node("/root/Weather")
@onready var landscape: Node = get_parent().get_node("Landscape")


func _ready() -> void:
    process_physics_priority = -10
    $Menu/Buttons/Autoplay.pressed.connect(_toggle_autoplay)
    $Menu/Buttons/Zoom.pressed.connect(_cycle_zoom)
    $Menu/Buttons/Weather.pressed.connect(_toggle_weather)
    $Menu/Buttons/WeatherControls.pressed.connect(_open_weather_controls)
    _create_weather_controls()
    weather.weather_changed.connect(_update_weather)
    _update_weather({})


func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.ctrl_pressed and event.keycode == KEY_D:
        menu.visible = not menu.visible
        get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
    if zoom_mode != 0:
        var target: Sprite2D = visual.get_node("right_eye_open" if zoom_mode == 1 else "tail")
        camera.global_position = target.to_global(target.get_rect().get_center())


func _cycle_zoom() -> void:
    if zoom_mode == 0:
        previous_visual_visible = visual.visible
        previous_oversampling = get_viewport().oversampling_override
        get_viewport().oversampling_override = ZOOM_OVERSAMPLING
        visual.show()
    zoom_mode = (zoom_mode + 1) % 3
    camera.zoom = Vector2.ONE * ZOOM_LEVELS[zoom_mode]
    camera.enabled = zoom_mode != 0
    if zoom_mode == 0:
        get_viewport().oversampling_override = previous_oversampling
        if not goat.stuck:
            visual.visible = previous_visual_visible
        zoom_button.text = "Zoom: normaal -> oog"
    else:
        _process(0.0)
        zoom_button.text = "Zoom: oog -> staart" if zoom_mode == 1 else "Zoom: staart -> normaal"


func _exit_tree() -> void:
    if zoom_mode != 0:
        get_viewport().oversampling_override = previous_oversampling


func _toggle_weather() -> void:
    weather_panel.visible = not weather_panel.visible


func _update_weather(_data: Dictionary) -> void:
    weather_text.text = "Nog geen weerinformatie ontvangen." if weather.downloaded.is_empty() else JSON.stringify(weather.downloaded, "  ")


func _create_weather_controls() -> void:
    weather_controls = Window.new()
    weather_controls.title = "Weer instellen"
    weather_controls.size = Vector2i(480, 490)
    weather_controls.unresizable = false
    weather_controls.visible = false
    weather_controls.close_requested.connect(weather_controls.hide)
    add_child(weather_controls)
    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
        margin.add_theme_constant_override(side, 12)
    weather_controls.add_child(margin)
    var scroll_container := ScrollContainer.new()
    margin.add_child(scroll_container)
    var content := VBoxContainer.new()
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll_container.add_child(content)
    manual_toggle = CheckButton.new()
    manual_toggle.text = "Handmatig weer"
    manual_toggle.toggled.connect(_set_manual_weather)
    content.add_child(manual_toggle)
    for item in [["cloud", "Bewolking", 0], ["rain", "Regen", 0], ["snow", "Sneeuw", 0], ["fog", "Mist", 0], ["wind", "Wind (links / rechts)", -100], ["phase", "Maanfase", 0]]:
        var row := HBoxContainer.new()
        content.add_child(row)
        var label := Label.new()
        label.text = item[1]
        label.custom_minimum_size.x = 145
        row.add_child(label)
        var slider := HSlider.new()
        slider.min_value = item[2]
        slider.max_value = 100
        slider.step = 1
        slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(slider)
        var value_label := Label.new()
        value_label.custom_minimum_size.x = 55
        value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        row.add_child(value_label)
        weather_sliders[item[0]] = slider
        weather_values[item[0]] = value_label
        slider.value_changed.connect(_weather_slider_changed.bind(item[0]))
    night_toggle = CheckButton.new()
    night_toggle.text = "Nacht"
    night_toggle.toggled.connect(_weather_toggle_changed.bind("night"))
    content.add_child(night_toggle)
    moon_toggle = CheckButton.new()
    moon_toggle.text = "Maan zichtbaar (tijdens nacht)"
    moon_toggle.toggled.connect(_weather_toggle_changed.bind("moon"))
    content.add_child(moon_toggle)
    _sync_weather_controls()


func _open_weather_controls() -> void:
    if not landscape.manual_weather:
        _sync_weather_controls()
    weather_controls.popup_centered()


func _sync_weather_controls() -> void:
    manual_toggle.set_pressed_no_signal(landscape.manual_weather)
    var values := {"cloud": landscape.target_cloud, "rain": landscape.target_rain, "snow": landscape.target_snow, "fog": landscape.target_fog, "wind": landscape.target_wind, "phase": landscape.moon_phase}
    for key in values:
        var slider: HSlider = weather_sliders[key]
        slider.set_value_no_signal(float(values[key]) * 100.0)
        weather_values[key].text = "%d%%" % roundi(slider.value)
        slider.editable = landscape.manual_weather
    night_toggle.set_pressed_no_signal(landscape.target_night >= 0.5)
    moon_toggle.set_pressed_no_signal(landscape.target_moon_visibility >= 0.5)
    night_toggle.disabled = not landscape.manual_weather
    moon_toggle.disabled = not landscape.manual_weather


func _set_manual_weather(enabled: bool) -> void:
    landscape.set_manual_weather(enabled)
    _sync_weather_controls()


func _weather_slider_changed(value: float, key: String) -> void:
    weather_values[key].text = "%d%%" % roundi(value)
    if not landscape.manual_weather:
        return
    match key:
        "cloud": landscape.target_cloud = value / 100.0
        "rain": landscape.target_rain = value / 100.0
        "snow": landscape.target_snow = value / 100.0
        "fog": landscape.target_fog = value / 100.0
        "wind": landscape.target_wind = value / 100.0
        "phase": landscape.moon_phase = value / 100.0


func _weather_toggle_changed(enabled: bool, key: String) -> void:
    if not landscape.manual_weather:
        return
    if key == "night":
        landscape.target_night = 1.0 if enabled else 0.0
    else:
        landscape.target_moon_visibility = 1.0 if enabled else 0.0


func _toggle_autoplay() -> void:
    var game = get_parent()
    if not autoplay and game.state in [game.State.GAME_OVER, game.State.EATING]:
        $Menu/Buttons/Autoplay.text = "Herstart eerst het spel"
        return
    autoplay = not autoplay
    goat.autoplay = autoplay
    goat.auto_jump_pressed = false
    goat.auto_jump_held = false
    goat.auto_duck = false
    jump_remaining = 0.0
    $Menu/Buttons/Autoplay.text = "Zelfspelen: aan" if autoplay else "Zelfspelen: uit"
    if autoplay:
        var obstacles = game.get_node("Obstacles")
        obstacles.elapsed = obstacles.MAX_DIFFICULTY_SECONDS
        obstacles.time_until_spawn = minf(obstacles.time_until_spawn, obstacles.MIN_SPAWN_INTERVAL)
        obstacles.next_kind = obstacles.rng.randi_range(0, obstacles.OBSTACLE_KINDS - 1)
        if game.state != game.State.RUNNING:
            game.start_run()


func _physics_process(delta: float) -> void:
    if not autoplay:
        return
    var game = get_parent()
    goat.auto_jump_pressed = false
    if game.state != game.State.RUNNING:
        goat.auto_jump_held = false
        goat.auto_duck = false
        return
    var obstacles = game.get_node("Obstacles")
    var duck := false
    var target: Node2D = null
    for obstacle in obstacles.get_children():
        if not obstacle.has_meta("kind"):
            continue
        if not obstacle.has_meta("auto_distance"):
            obstacle.set_meta("auto_distance", ACTION_DISTANCE + action_rng.randf_range(-ACTION_VARIATION, ACTION_VARIATION))
        var distance: float = obstacle.global_position.x - goat.global_position.x
        var kind: int = obstacle.get_meta("kind")
        if kind == 2:
            if distance <= float(obstacle.get_meta("auto_distance")) and distance > -65.0:
                duck = true
        elif target == null and not obstacle.has_meta("auto_jumped") and distance > -80.0:
            target = obstacle
    jump_remaining = maxf(0.0, jump_remaining - delta)
    if target != null and target.global_position.x - goat.global_position.x <= float(target.get_meta("auto_distance")) and goat.is_on_floor() and jump_remaining <= 0.0:
        target.set_meta("auto_jumped", true)
        goat.auto_jump_pressed = true
        jump_remaining = JUMP_HOLDS[int(target.get_meta("kind"))]
    goat.auto_jump_held = jump_remaining > 0.0
    goat.auto_duck = duck
