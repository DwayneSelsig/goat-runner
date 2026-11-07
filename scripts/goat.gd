extends CharacterBody2D

const GRAVITY := 1500.0
const JUMP_SPEED := -570.0
const RELEASE_GRAVITY_MULTIPLIER := 2.5
const HEAD_STANDING_Y := -75.0
const HEAD_DUCKING_Y := -30.0
const SOCK_CARRY_DISTANCE := 90.0
const SOCK_CARRY_DURATION := 0.4
const PUDDLE_SINK_DURATION := 0.8
# The death pose extends to the right of the goat physics origin.
const PUDDLE_DEATH_OFFSET_X := -45.0

var autoplay := false
var auto_jump_pressed := false
var auto_jump_held := false
var auto_duck := false

var running := false
var entering := false
var dead := false
var sinking := false
var sink_elapsed := 0.0
var sink_start := Vector2.ZERO
var sink_target := Vector2.ZERO
var stuck := false
var stuck_start_x := 0.0
var stuck_elapsed := 0.0
var jump_active := false
var jump_ground_y := 0.0
var jump_apex_y := 0.0
var jump_phase := 0.0

@onready var animation_player: AnimationPlayer = $Visual/AnimationPlayer
@onready var head_collision: CollisionShape2D = $HeadCollision


func _ready() -> void:
    animation_player.animation_finished.connect(_on_animation_finished)


func _physics_process(delta: float) -> void:
    if sinking:
        sink_elapsed = minf(sink_elapsed + delta, PUDDLE_SINK_DURATION)
        var progress := sink_elapsed / PUDDLE_SINK_DURATION
        global_position = sink_start.lerp(sink_target, 1.0 - (1.0 - progress) * (1.0 - progress))
        return
    if stuck:
        stuck_elapsed = minf(stuck_elapsed + delta, SOCK_CARRY_DURATION)
        var progress := stuck_elapsed / SOCK_CARRY_DURATION
        position.x = stuck_start_x + SOCK_CARRY_DISTANCE * (1.0 - (1.0 - progress) * (1.0 - progress))
        return
    var ducking := running and not dead and (auto_duck if autoplay else Input.is_action_pressed("duck"))
    var jump_pressed := auto_jump_pressed if autoplay else Input.is_action_just_pressed("jump")
    var jump_held := auto_jump_held if autoplay else Input.is_action_pressed("jump")
    head_collision.position.y = HEAD_DUCKING_Y if ducking else HEAD_STANDING_Y

    if running and jump_pressed and is_on_floor():
        jump_active = true
        jump_ground_y = position.y
        jump_apex_y = position.y
        jump_phase = 0.0
        velocity.y = JUMP_SPEED
    if not is_on_floor() or velocity.y < 0.0:
        var gravity := GRAVITY
        if velocity.y < 0.0 and not jump_held:
            gravity *= RELEASE_GRAVITY_MULTIPLIER
        velocity.y += gravity * delta
    move_and_slide()
    if jump_active:
        jump_apex_y = minf(jump_apex_y, position.y)
        if is_on_floor():
            jump_active = false
        elif velocity.y < 0.0:
            jump_phase = 0.5 * clampf(1.0 - velocity.y / JUMP_SPEED, 0.0, 1.0)
        else:
            var height := maxf(jump_ground_y - jump_apex_y, 0.001)
            jump_phase = 0.5 + 0.5 * clampf((position.y - jump_apex_y) / height, 0.0, 1.0)
    if not dead:
        var animation := &"idle"
        if entering:
            animation = &"walk"
        elif running:
            animation = &"duck" if ducking else (&"jump" if jump_active else &"run")
        if animation == &"jump":
            if animation_player.current_animation != &"jump":
                animation_player.play(&"jump", -1.0, 0.0)
            # Freeze automatic playback; physics owns the normalized pose time.
            animation_player.seek(jump_phase * animation_player.get_animation(&"jump").length, true)
            return
        var converted := _convert_animation(animation)
        if animation_player.current_animation != converted or not animation_player.is_playing():
            _play_animation(animation)


func die() -> void:
    dead = true
    running = false
    _play_animation(&"die")


func sink_in_puddle(puddle_center: Vector2) -> void:
    die()
    sinking = true
    sink_elapsed = 0.0
    sink_start = global_position
    sink_target = puddle_center + Vector2(PUDDLE_DEATH_OFFSET_X, 0.0)
    velocity = Vector2.ZERO


func catch_on_sock() -> void:
    dead = true
    running = false
    stuck = true
    stuck_start_x = position.x
    stuck_elapsed = 0.0
    velocity = Vector2.ZERO
    animation_player.play(&"sock_line_stuck")


func eat() -> void:
    dead = true
    running = false
    velocity = Vector2.ZERO
    _play_animation(&"to_eat")


func _play_animation(animation: StringName) -> void:
    animation_player.play(_convert_animation(animation))


func _convert_animation(animation: StringName) -> StringName:
    match animation:
        &"duck":
            return &"charge"
        &"die":
            return &"game_die"
        &"to_eat":
            return &"game_to_eat"
        &"eat":
            return &"eating"
        _:
            return animation


func _on_animation_finished(animation: StringName) -> void:
    if dead and animation == &"game_to_eat":
        _play_animation(&"eat")
