extends SceneTree

var failures := 0

func check(condition: bool, message: String) -> void:
    if not condition:
        failures += 1
        push_error(message)

func _initialize() -> void:
    call_deferred("run_tests")

func run_tests() -> void:
    var service: Node = root.get_node("Weather")
    service.request.cancel_request()
    var sample := {"current": {"weather_code": 61, "is_day": 1, "cloud_cover": 80, "wind_speed_10m": 20, "wind_direction_10m": 270}}
    var sample_json := JSON.stringify(JSON.parse_string(JSON.stringify(sample)))
    var parsed: Dictionary = service.parse_current(sample)
    check(not parsed.is_empty(), "Valid weather rejected")
    check(service.parse_current({}).is_empty(), "Missing current accepted")
    check(service.parse_current({"current": {"weather_code": null}}).is_empty(), "Invalid data accepted")
    var invalid := sample.duplicate(true)
    invalid.current.cloud_cover = 101
    check(service.parse_current(invalid).is_empty(), "Invalid cloud cover accepted")
    service._on_request_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify(sample).to_utf8_buffer())
    check(service.current == parsed, "Successful response not stored")
    check(JSON.stringify(service.downloaded) == sample_json, "Downloaded response not stored")
    service._on_request_completed(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray())
    service._on_request_completed(HTTPRequest.RESULT_SUCCESS, 500, PackedStringArray(), PackedByteArray())
    service._on_request_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), "not json".to_utf8_buffer())
    check(service.current == parsed, "Failure replaced last valid weather")
    check(JSON.stringify(service.downloaded) == sample_json, "Failure replaced last downloaded response")
    check(service.timer.wait_time == 900.0 and not service.timer.is_stopped(), "Refresh timer must run every 15 minutes")
    var astronomy := sample.duplicate(true)
    astronomy.daily = {"sunrise": [1000, 87400, 173800, 260200], "sunset": [44200, 130600, 217000, 303400], "moonrise": [2000, null, 174800, 261200], "moonset": [46000, 132400, 218800, null], "moon_phase": [0.1, 0.2, 0.5, 0.6]}
    var celestial: Dictionary = service.parse_current(astronomy)
    check(celestial.moon_phase == 0.5, "Current local day moon phase not parsed")
    var before_rise: Dictionary = service.celestial_state(celestial, 173799.0)
    var after_rise: Dictionary = service.celestial_state(celestial, 174801.0)
    var after_set: Dictionary = service.celestial_state(celestial, 218801.0)
    check(not before_rise.is_day and not before_rise.moon_visible, "Previous sunset or moonset not applied across midnight")
    check(after_rise.is_day and after_rise.moon_visible, "Sunrise or moonrise not applied")
    check(not after_set.is_day and not after_set.moon_visible, "Sunset or moonset not applied")
    var fallback: Dictionary = service.celestial_state(parsed, 300000.0)
    check(fallback.is_day and fallback.moon_visible, "Missing astronomy did not fall back to current conditions")
    # Absolute timestamps work the same on either side of a daylight-saving change.
    var dst := parsed.duplicate(true)
    dst.sunrise = [1792904400, 1792994400]
    dst.sunset = [1792940400, 1793026800]
    check(not service.celestial_state(dst, 1792994399.0).is_day and service.celestial_state(dst, 1792994400.0).is_day, "Daylight-saving transition changed event comparison")
    var game := (load("res://game.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var landscape: Node = game.get_node("Landscape")
    var weather_text: TextEdit = game.get_node("DebugMenu/WeatherPanel/WeatherText")
    check(JSON.stringify(JSON.parse_string(weather_text.text)) == sample_json, "Weather overlay did not show downloaded response")
    check(is_equal_approx(landscape.target_cloud, 0.8) and landscape.target_rain == 1.0 and landscape.target_wind > 0.0, "Rain, cloud or wind mapping failed")
    var night_snow := {"weather_code": 75, "is_day": 0, "cloud_cover": 10.0, "wind_speed_10m": 20.0, "wind_direction_10m": 90.0}
    landscape._set_weather(night_snow)
    check(landscape.target_night == 1.0 and landscape.target_snow == 1.0 and landscape.target_rain == 0.0 and landscape.target_wind < 0.0, "Night, snow or opposite wind mapping failed")
    night_snow.weather_code = 45
    landscape._set_weather(night_snow)
    check(landscape.target_fog == 1.0 and landscape.target_snow == 0.0, "Fog mapping failed")
    night_snow.weather_code = 0
    landscape._set_weather(night_snow)
    check(landscape.target_fog == 0.0 and landscape.target_cloud == 0.1, "Clear weather mapping failed")
    var old_night: float = landscape.night
    landscape._process(0.1)
    check(landscape.night > old_night and landscape.night < landscape.target_night, "Weather did not transition gradually")
    var debug: Node = game.get_node("DebugMenu")
    debug.get_node("Menu/Buttons/WeatherControls").pressed.emit()
    check(debug.weather_controls.visible, "Weather controls did not open")
    debug.manual_toggle.button_pressed = true
    check(landscape.manual_weather, "Manual weather did not activate")
    for key in ["cloud", "rain", "snow", "fog", "wind", "phase"]:
        debug.weather_sliders[key].value = -40.0 if key == "wind" else 40.0
    debug.night_toggle.button_pressed = true
    debug.moon_toggle.button_pressed = false
    check(is_equal_approx(landscape.target_cloud, 0.4) and is_equal_approx(landscape.target_rain, 0.4) and is_equal_approx(landscape.target_snow, 0.4) and is_equal_approx(landscape.target_fog, 0.4) and is_equal_approx(landscape.target_wind, -0.4) and is_equal_approx(landscape.moon_phase, 0.4), "Manual sliders did not set targets")
    check(landscape.target_night == 1.0 and landscape.target_moon_visibility == 0.0, "Manual switches did not set targets")
    var updated := {"weather_code": 45, "is_day": 1, "cloud_cover": 60.0, "wind_speed_10m": 0.0, "wind_direction_10m": 0.0}
    service._on_request_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify({"current": updated}).to_utf8_buffer())
    landscape._update_celestial()
    check(is_equal_approx(landscape.target_rain, 0.4) and landscape.target_night == 1.0 and is_equal_approx(landscape.moon_phase, 0.4), "Live update overwrote manual weather")
    debug.manual_toggle.button_pressed = false
    check(not landscape.manual_weather and landscape.target_fog == 1.0 and is_equal_approx(landscape.target_cloud, 0.6), "Latest live weather was not restored")
    debug.weather_controls.close_requested.emit()
    check(not debug.weather_controls.visible, "Weather controls did not close")
    # Exercise the no-network fallback independently of the service cache.
    landscape.weather_data = {}
    landscape.set_manual_weather(true)
    landscape.target_rain = 0.7
    landscape.set_manual_weather(false)
    check(not landscape.has_weather and landscape.target_rain == 0.0 and landscape.target_cloud == 0.35, "Offline fallback was not restored")
    service._on_request_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify(sample).to_utf8_buffer())
    var timer: Timer = service.timer
    game.free()
    var next_game := (load("res://game.tscn") as PackedScene).instantiate()
    root.add_child(next_game)
    var next_landscape: Node = next_game.get_node("Landscape")
    check(not next_landscape.manual_weather and service.timer == timer and service.current == parsed and next_landscape.target_rain == 1.0, "Weather did not survive scene reload")
    check(next_landscape.weather_strength == 1.0 and next_landscape.cloud_amount == next_landscape.target_cloud and next_landscape.night == next_landscape.target_night and next_landscape.rain == next_landscape.target_rain and next_landscape.snow == next_landscape.target_snow and next_landscape.fog == next_landscape.target_fog and next_landscape.wind == next_landscape.target_wind, "Cached weather was not applied immediately after reload")
    next_game.free()
    if failures == 0:
        print("Weather tests passed")
    quit(1 if failures else 0)
