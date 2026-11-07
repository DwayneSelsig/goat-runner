extends Node2D

signal hit(kind: int, obstacle: Area2D)
signal cleared

const SPEED := 550.0
const GROUND_Y := 570.0
const SPAWN_INTERVAL := 3.3
const WARMUP_SECONDS := 20.0
const MAX_DIFFICULTY_SECONDS := 1800.0
# Minimum spacing is covered by collision tests for every obstacle pair.
const MIN_SPAWN_INTERVAL := 0.7
const BUSHES := [preload("res://assets/obstacles/ground/bush-1.svg"), preload("res://assets/obstacles/ground/bush-2.svg"), preload("res://assets/obstacles/ground/bush-3.svg")]
const PUDDLE := preload("res://assets/obstacles/ground/puddle.svg")
const CLOTHESLINE := preload("res://assets/obstacles/overhead/clothesline_back.svg")
const CLOTHESLINE_FRONT := preload("res://assets/obstacles/overhead/clothesline_front.svg")
const HAY := preload("res://assets/obstacles/ground/hay.svg")
const OBSTACLE_KINDS := 4
# The goat artwork's hooves extend below its physics origin.
const HOOF_OFFSET := 23.0

var running := false
var time_until_spawn := 1.0
var elapsed := 0.0
var next_kind := 0
var rng := RandomNumberGenerator.new()
var next_bush := 0

@onready var goat_collider: CollisionShape2D = $"../Goat/CollisionShape2D"


func _physics_process(delta: float) -> void:
	if not running:
		return
	elapsed += delta
	time_until_spawn -= delta
	if time_until_spawn <= 0.0:
		_spawn_obstacle(next_kind)
		if elapsed < WARMUP_SECONDS:
			next_kind = (next_kind + 1) % OBSTACLE_KINDS
		else:
			next_kind = rng.randi_range(0, OBSTACLE_KINDS - 1)
		time_until_spawn += spawn_interval(elapsed)
	for obstacle in get_children():
		obstacle.position.x -= SPEED * delta
		var collider: CollisionShape2D = obstacle.get_node("CollisionShape2D")
		var obstacle_right: float = collider.global_position.x + (collider.shape as RectangleShape2D).size.x / 2.0
		var head_collider: CollisionShape2D = $"../Goat/HeadCollision"
		var body_left: float = goat_collider.global_position.x - (goat_collider.shape as RectangleShape2D).size.x / 2.0
		var head_left: float = head_collider.global_position.x - (head_collider.shape as RectangleShape2D).size.x / 2.0
		var goat_left := minf(body_left, head_left)
		if not obstacle.has_meta("cleared") and obstacle_right < goat_left:
			obstacle.set_meta("cleared", true)
			cleared.emit()
		if obstacle.position.x < -100.0:
			obstacle.queue_free()


func spawn_interval(run_time: float) -> float:
	var progress := clampf((run_time - WARMUP_SECONDS) / (MAX_DIFFICULTY_SECONDS - WARMUP_SECONDS), 0.0, 1.0)
	return lerpf(SPAWN_INTERVAL, MIN_SPAWN_INTERVAL, progress)


func _spawn_obstacle(kind: int) -> void:
	var obstacle := Area2D.new()
	obstacle.position = Vector2(1490, GROUND_Y)
	obstacle.set_meta("kind", kind)
	obstacle.collision_layer = 0
	obstacle.collision_mask = 1
	var shape := RectangleShape2D.new()
	var collider := CollisionShape2D.new()
	collider.name = "CollisionShape2D"
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	if kind == 0:
		sprite.texture = BUSHES[next_bush]
		next_bush = (next_bush + 1) % BUSHES.size()
		var bush_size := sprite.texture.get_size()
		# Each crop retains the dimensions of the source artwork.
		var bush_scale := 115.0 / BUSHES[0].get_width()
		sprite.scale = Vector2.ONE * bush_scale
		var bush_height := bush_size.y * bush_scale
		sprite.position.y = HOOF_OFFSET - bush_height / 2.0
		shape.size = Vector2(bush_size.x * bush_scale * 0.65, bush_height * 0.8)
		collider.position.y = HOOF_OFFSET - shape.size.y / 2.0
	elif kind == 2:
		sprite.texture = CLOTHESLINE
		sprite.flip_h = true
		# Lower the artwork so the hanging clothes meet the raised hitbox.
		# The posts are visual only, so the goat can pass underneath.
				# Keep the lower edge at -69 while extending above the highest jump.
		shape.size = Vector2(72, 291)
		collider.position.y = -214.5
		sprite.scale = Vector2.ONE * 0.9
		sprite.position.y = HOOF_OFFSET - sprite.texture.get_height() * sprite.scale.y / 2.0 + 18.0
		var front := Sprite2D.new()
		front.name = "FrontPost"
		front.texture = CLOTHESLINE_FRONT
		front.scale = sprite.scale
		front.position = sprite.position
		front.flip_h = true
		# SCML goat parts have absolute animated z-indices up to 23.
		front.z_as_relative = false
		front.z_index = 100
		obstacle.add_child(front)
	elif kind == 3:
		sprite.texture = HAY
		var hay_scale := 176.0 / sprite.texture.get_width()
		sprite.scale = Vector2.ONE * hay_scale
		var hay_height := sprite.texture.get_height() * hay_scale
		sprite.position.y = HOOF_OFFSET - hay_height / 2.0
		shape.size = Vector2(120, hay_height)
		collider.position.y = sprite.position.y
	else:
		sprite.texture = PUDDLE
		var puddle_scale := 180.0 / sprite.texture.get_width()
		sprite.scale = Vector2.ONE * puddle_scale
		sprite.position.y = HOOF_OFFSET - sprite.texture.get_height() * puddle_scale / 2.0 + 8.0
		# The feet are artwork below the body collider, so the shallow trigger
		# reaches the physics origin while the puddle stays on the track.
		shape.size = Vector2(140, 12)
		collider.position.y = -2.0
	collider.shape = shape
	obstacle.add_child(collider)
	obstacle.add_child(sprite)
	obstacle.body_shape_entered.connect(_on_body_shape_entered.bind(kind, obstacle))
	add_child(obstacle)


func _on_body_shape_entered(_body_rid: RID, body: Node2D, body_shape_index: int, _local_shape_index: int, kind: int, obstacle: Area2D) -> void:
	if not running or not body is CharacterBody2D:
		return
	# A clothesline catches the head only; the body can still be underneath it.
	var shape_owner: Object = body.shape_owner_get_owner(body.shape_find_owner(body_shape_index))
	if kind == 2 and shape_owner != body.get_node("HeadCollision"):
		return
	hit.emit(kind, obstacle)
