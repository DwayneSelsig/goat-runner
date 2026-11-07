extends Control

signal layout_changed

const ARROW_UP := preload("res://assets/gui/arrow-wood-triangle-up.svg")
const ARROW_DOWN := preload("res://assets/gui/arrow-wood-triangle-down.svg")
const RESIZE_ICON := preload("res://assets/gui/icon-resize-diagonal.svg")

var action := "jump"
var editing := false
var button_opacity := 1.0
var touch_index := -1
var moving := false
var resizing := false
var drag_origin := Vector2.ZERO
var original_position := Vector2.ZERO
var original_size := Vector2.ZERO
var texture: Texture2D
var attention_rng := RandomNumberGenerator.new()
var attention_elapsed := 0.0
var attention_duration := 0.0
var attention_direction := Vector2.ZERO
var attention_phase := 0.0
var attention_spin := 1.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    texture = ARROW_UP if action == "jump" else ARROW_DOWN
    attention_rng.randomize()
    queue_redraw()

func _process(delta: float) -> void:
    if attention_duration <= 0.0:
        return
    attention_elapsed += delta
    if attention_elapsed >= attention_duration:
        _stop_attention()
    else:
        queue_redraw()

func _draw() -> void:
    var glow := 0.0
    if attention_duration > 0.0:
        var progress := clampf(attention_elapsed / attention_duration, 0.0, 1.0)
        var envelope := sin(PI * progress)
        glow = envelope
        var angle := deg_to_rad(3.0) * attention_spin * sin(progress * TAU * 2.0 + attention_phase) * envelope
        var offset := attention_direction * 6.0 * sin(progress * TAU) * envelope
        var half := size * 0.5
        var extent := Vector2(absf(cos(angle)) * half.x + absf(sin(angle)) * half.y, absf(sin(angle)) * half.x + absf(cos(angle)) * half.y)
        var center := global_position + half
        var viewport := get_viewport_rect().size
        offset = (center + offset).clamp(extent, viewport - extent) - center
        draw_set_transform(half + offset, angle)
        draw_texture_rect(texture, Rect2(-half, size), false, Color(1, 1, 1, button_opacity))
        draw_set_transform(Vector2.ZERO)
    else:
        draw_texture_rect(texture, Rect2(Vector2.ZERO, size), false, Color(1, 1, 1, button_opacity))
    if editing:
        draw_rect(Rect2(Vector2.ZERO, size), Color("6b281b").lerp(Color("ffe78c"), glow), false, 3.0 + glow * 2.0)
        var icon_position := size - Vector2(18, 18)
        var visible_limit := get_viewport_rect().size - global_position - Vector2(36, 36)
        icon_position = icon_position.min(visible_limit)
        draw_texture_rect(RESIZE_ICON, Rect2(icon_position, Vector2(36, 36)), false)
        if glow > 0.0:
            draw_texture_rect(RESIZE_ICON, Rect2(icon_position, Vector2(36, 36)), false, Color(1.0, 0.9, 0.4, glow * 0.8))

func _has_point(point: Vector2) -> bool:
    if editing and Rect2(size - Vector2(36, 36), Vector2(54, 54)).has_point(point):
        return true
    return Rect2(Vector2.ZERO, size).has_point(point)

func _is_resize_area(point: Vector2) -> bool:
    return Rect2(size - Vector2(36, 36), Vector2(54, 54)).has_point(point)

func _get_cursor_shape(at_position: Vector2) -> CursorShape:
    if editing:
        return CURSOR_BDIAGSIZE if _is_resize_area(at_position) else CURSOR_MOVE
    return CURSOR_ARROW

func _gui_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed and touch_index == -1:
            touch_index = event.index
            _begin(event.position)
            accept_event()
        elif not event.pressed and event.index == touch_index:
            _end()
            touch_index = -1
            accept_event()
    elif event is InputEventScreenDrag and event.index == touch_index:
        _drag(event.relative)
        accept_event()
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            _begin(event.position)
        else:
            _end()
        accept_event()
    elif event is InputEventMouseMotion and (moving or resizing):
        _drag(event.relative)
        accept_event()

func _begin(at: Vector2) -> void:
    if editing:
        _stop_attention()
        resizing = _is_resize_area(at)
        moving = not resizing
    else:
        Input.action_press(action)

func _drag(relative: Vector2) -> void:
    if resizing:
        var edge := clampf(size.x + relative.x, 64.0, 260.0)
        size = Vector2.ONE * edge
        _clamp_position()
        queue_redraw()
    elif moving:
        position += relative
        _clamp_position()
        queue_redraw()

func _clamp_position() -> void:
    var bounds := get_viewport_rect().size
    position = position.clamp(Vector2.ZERO, (bounds - size).max(Vector2.ZERO))

func _end() -> void:
    if moving or resizing:
        layout_changed.emit()
    moving = false
    resizing = false
    Input.action_release(action)

func set_editing(value: bool) -> void:
    _end()
    touch_index = -1
    editing = value
    if editing:
        attention_elapsed = 0.0
        attention_duration = attention_rng.randf_range(0.55, 0.7)
        attention_direction = Vector2.from_angle(attention_rng.randf_range(0.0, TAU))
        attention_phase = attention_rng.randf_range(-0.4, 0.4)
        attention_spin = 1.0 if attention_rng.randi_range(0, 1) == 0 else -1.0
    else:
        _stop_attention()
    queue_redraw()

func _stop_attention() -> void:
    attention_duration = 0.0
    attention_elapsed = 0.0
    queue_redraw()
