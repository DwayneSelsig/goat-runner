extends Node2D

const SCROLL_SPEED := 550.0
const TRANSITION_SPEED := 0.35
@export var landscape_seed: int = 0

var running := false
var scroll := 0.0
var weather_time := 0.0
var weather_strength := 0.0
var has_weather := false
var cloud_amount := 0.35
var night := 0.0
var rain := 0.0
var snow := 0.0
var fog := 0.0
var wind := 0.0
var target_cloud := 0.35
var target_night := 0.0
var target_rain := 0.0
var target_snow := 0.0
var target_fog := 0.0
var target_wind := 0.0
var moon_phase := 0.2
var moon_visibility := 1.0
var target_moon_visibility := 1.0
var celestial_check := 0.0
var weather_data: Dictionary = {}
var manual_weather := false


func _ready() -> void:
	$FarmScenery.configure(landscape_seed)
	$WeatherOverlay.draw.connect(_draw_weather)
	$PrecipitationOverlay.draw.connect(_draw_precipitation)
	var weather := get_node("/root/Weather")
	weather.weather_changed.connect(_set_weather)
	if not weather.current.is_empty():
		_set_weather(weather.current)
		weather_strength = 1.0
		cloud_amount = target_cloud
		night = target_night
		rain = target_rain
		snow = target_snow
		fog = target_fog
		wind = target_wind
		moon_visibility = target_moon_visibility


func _set_weather(data: Dictionary) -> void:
	weather_data = data.duplicate(true)
	if manual_weather:
		return
	has_weather = true
	_update_celestial()
	var code: int = data.weather_code
	target_cloud = data.cloud_cover / 100.0
	target_rain = 1.0 if code in [51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82, 95, 96, 99] else 0.0
	target_snow = 1.0 if code in [71, 73, 75, 77, 85, 86] else 0.0
	target_fog = 1.0 if code in [45, 48] else 0.0
	# Meteorological direction is where the wind comes from.
	target_wind = clampf(-sin(deg_to_rad(data.wind_direction_10m)) * data.wind_speed_10m / 40.0, -1.0, 1.0)


func _update_celestial() -> void:
	if manual_weather or weather_data.is_empty():
		return
	var state: Dictionary = get_node("/root/Weather").celestial_state(weather_data, Time.get_unix_time_from_system())
	target_night = 1.0 - float(state.is_day)
	target_moon_visibility = 1.0 if state.moon_visible else 0.0
	moon_phase = state.moon_phase


func set_manual_weather(enabled: bool) -> void:
	manual_weather = enabled
	if enabled:
		has_weather = true
	elif not weather_data.is_empty():
		_set_weather(weather_data)
	else:
		has_weather = false
		target_cloud = 0.35
		target_night = 0.0
		target_rain = 0.0
		target_snow = 0.0
		target_fog = 0.0
		target_wind = 0.0
		moon_phase = 0.2
		target_moon_visibility = 1.0


func _process(delta: float) -> void:
	weather_time += delta
	celestial_check -= delta
	if celestial_check <= 0.0:
		celestial_check = 1.0
		_update_celestial()
	var weight := 1.0 - exp(-TRANSITION_SPEED * delta)
	weather_strength = lerpf(weather_strength, 1.0 if has_weather else 0.0, weight)
	cloud_amount = lerpf(cloud_amount, target_cloud, weight)
	night = lerpf(night, target_night, weight)
	rain = lerpf(rain, target_rain, weight)
	snow = lerpf(snow, target_snow, weight)
	fog = lerpf(fog, target_fog, weight)
	wind = lerpf(wind, target_wind, weight)
	moon_visibility = lerpf(moon_visibility, target_moon_visibility, weight)
	$FarmScenery.modulate = Color.WHITE.lerp(Color(0.53, 0.62, 0.76), night * 0.65)
	$WeatherOverlay.queue_redraw()
	$PrecipitationOverlay.queue_redraw()
	queue_redraw()


func _physics_process(delta: float) -> void:
	if running:
		scroll += SCROLL_SPEED * delta
		$FarmScenery.set_scroll(scroll)


func _draw() -> void:
	# The supplied sky inspires the gradient; weather still controls both ends.
	var overcast := cloud_amount * weather_strength
	var sky_top := Color("78f4f2").lerp(Color("1d304f"), night)
	var sky_bottom := Color("edffff").lerp(Color("556981"), night)
	sky_top = sky_top.lerp(Color("899fa9"), overcast * 0.45)
	sky_bottom = sky_bottom.lerp(Color("c1cbca"), overcast * 0.42)
	for band in range(72):
		var t := float(band) / 71.0
		draw_rect(Rect2(0, band * 10, 1440, 10), sky_top.lerp(sky_bottom, t))
	if night * moon_visibility > 0.01:
		_draw_moon(night * moon_visibility)
	var original_cloud := Color(1, 1, 1, 1.0 - weather_strength)
	for circle in [[170, 105, 26], [200, 103, 35], [237, 108, 23], [680, 78, 23], [711, 74, 31], [745, 80, 22]]:
		draw_circle(Vector2(circle[0], circle[1]), circle[2], original_cloud)
	for i in range(7):
		var opacity := clampf(cloud_amount * 3.0 - float(i) * 0.38, 0.0, 1.0)
		var x := fposmod(170.0 + i * 220.0 + weather_time * wind * 10.0, 1660.0) - 110.0
		var y := 105.0 if i % 2 == 0 else 78.0
		var cloud_color := Color(1.0, 1.0, 1.0, opacity * weather_strength * (0.95 - night * 0.2))
		draw_circle(Vector2(x - 30, y), 26, cloud_color)
		draw_circle(Vector2(x, y - 2), 35, cloud_color)
		draw_circle(Vector2(x + 37, y + 3), 23, cloud_color)


func _draw_weather() -> void:
	var canvas: Node2D = $WeatherOverlay
	if fog > 0.01:
		canvas.draw_rect(Rect2(0, 150, 1440, 440), Color(0.88, 0.91, 0.91, fog * 0.24))


func _draw_precipitation() -> void:
	var canvas: Node2D = $PrecipitationOverlay
	if rain > 0.01 or snow > 0.01:
		for i in range(100):
			var x := fposmod(i * 173.0 + weather_time * wind * 35.0, 1460.0) - 10.0
			if rain > 0.01:
				var y := fposmod(i * 137.0 + weather_time * 360.0, 620.0)
				canvas.draw_line(Vector2(x, y), Vector2(x + wind * 9.0, y + 17.0), Color(0.8, 0.9, 1.0, rain * 0.65), 2.0)
			if snow > 0.01:
				var y := fposmod(i * 137.0 + weather_time * 55.0, 620.0)
				canvas.draw_circle(Vector2(x + sin(weather_time + i) * 8.0, y), 3.0, Color(1, 1, 1, snow * 0.85))


func _draw_moon(opacity: float) -> void:
	# The phase fraction runs from new moon (0) through full moon (0.5).
	var points := PackedVector2Array()
	var waxing := moon_phase <= 0.5
	var side := 1.0 if waxing else -1.0
	for i in range(33):
		var y := -25.0 + 50.0 * i / 32.0
		var half_width := sqrt(maxf(0.0, 625.0 - y * y))
		points.append(Vector2(1250.0 + side * half_width, 90.0 + y))
	for i in range(32, -1, -1):
		var y := -25.0 + 50.0 * i / 32.0
		var half_width := sqrt(maxf(0.0, 625.0 - y * y))
		points.append(Vector2(1250.0 + side * cos(TAU * moon_phase) * half_width, 90.0 + y))
	draw_colored_polygon(points, Color(0.96, 0.96, 0.84, opacity))
