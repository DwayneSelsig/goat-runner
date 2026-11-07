extends Node2D

enum State { READY, RUNNING, GAME_OVER, INTRO, EATING }

const INTRO_START_X := -100.0
const INTRO_SPEED := 180.0

var state: State = State.INTRO
var starting_x := 0.0
var score := 0
var highscore := 0
var highscore_path := "user://highscore.cfg"
var waiting_for_web_splash := false

@onready var landscape: Node2D = $Landscape
@onready var obstacles: Node2D = $Obstacles
@onready var goat: CharacterBody2D = $Goat
@onready var instructions: Label = $Instructions
@onready var retry_button: Button = $RetryButton
@onready var score_label: Label = $Score
@onready var interface: CanvasLayer = $Interface


func _ready() -> void:
    if OS.has_feature("web"):
        waiting_for_web_splash = bool(JavaScriptBridge.eval("window.goatSplashWaiting === true"))
    _load_highscore()
    interface.update_scores(score, highscore)
    obstacles.hit.connect(_on_obstacle_hit)
    obstacles.cleared.connect(_on_obstacle_cleared)
    retry_button.pressed.connect(_restart_game)
    starting_x = goat.position.x
    goat.position.x = INTRO_START_X
    goat.entering = true
    instructions.hide()


func _physics_process(delta: float) -> void:
    if waiting_for_web_splash:
        waiting_for_web_splash = bool(JavaScriptBridge.eval("window.goatSplashWaiting === true"))
        if waiting_for_web_splash:
            return
    if state == State.INTRO:
        goat.position.x = move_toward(goat.position.x, starting_x, INTRO_SPEED * delta)
        if goat.position.x == starting_x:
            goat.entering = false
            state = State.READY
            interface.show_start()
    elif state == State.READY and Input.is_action_just_pressed("jump"):
        start_run()
    elif state == State.GAME_OVER and Input.is_action_just_pressed("jump"):
        _restart_game()


func _input(event: InputEvent) -> void:
    if state == State.READY and not get_tree().paused and event is InputEventKey and event.pressed and not event.echo and event.is_action_pressed("jump"):
        start_run(true)
        get_viewport().set_input_as_handled()


func start_run(with_keyboard: bool = false) -> void:
    interface.set_touch_for_start(not with_keyboard)
    goat.position.x = starting_x
    goat.entering = false
    state = State.RUNNING
    landscape.running = true
    goat.running = true
    obstacles.running = true
    instructions.hide()
    interface.hide_message()


func _load_highscore() -> void:
    var config := ConfigFile.new()
    if config.load(highscore_path) == OK:
        highscore = maxi(0, int(config.get_value("scores", "highscore", 0)))
    $Highscore.text = "Highscore: %d" % highscore


func _on_obstacle_cleared() -> void:
    if state == State.RUNNING:
        score += 1
        score_label.text = "Score: %d" % score
        if score > highscore:
            highscore = score
            $Highscore.text = "Highscore: %d" % highscore
            var config := ConfigFile.new()
            config.set_value("scores", "highscore", highscore)
            config.save(highscore_path)
        interface.update_scores(score, highscore)


func _on_obstacle_hit(kind: int, obstacle: Area2D = null) -> void:
    if state != State.RUNNING:
        return
    landscape.running = false
    obstacles.running = false
    if kind == 3:
        state = State.EATING
        goat.eat()
        retry_button.show()
    else:
        state = State.GAME_OVER
        if kind == 2:
            goat.catch_on_sock()
        elif kind == 1 and is_instance_valid(obstacle):
            obstacle.z_index = 1
            goat.sink_in_puddle(obstacle.global_position)
        else:
            goat.die()
    interface.show_game_over(kind, score)


func reset_highscore() -> void:
    highscore = 0
    var config := ConfigFile.new()
    config.set_value("scores", "highscore", 0)
    config.save(highscore_path)
    $Highscore.text = "Highscore: 0"
    interface.update_scores(score, highscore)


func _restart_game() -> void:
    get_tree().reload_current_scene()
