extends Node

signal weather_changed(data: Dictionary)

const REFRESH_SECONDS := 900.0
const URL := "https://api.open-meteo.com/v1/forecast?latitude=51.5&longitude=4.3&hourly=temperature_2m,rain,showers,snowfall,snow_depth,cloud_cover,cloud_cover_low,cloud_cover_mid,cloud_cover_high,wind_speed_10m,wind_direction_10m,wind_gusts_10m,weather_code,precipitation,visibility,is_day,relative_humidity_2m&daily=sunrise,sunset,moonrise,moonset,moon_phase&current=temperature_2m,weather_code,is_day,wind_speed_10m,wind_direction_10m,wind_gusts_10m,precipitation,cloud_cover&timezone=Europe%2FAmsterdam&forecast_days=2&past_days=2&timeformat=unixtime"

var current: Dictionary = {}
var downloaded: Dictionary = {}
var request: HTTPRequest
var timer: Timer


func _ready() -> void:
    request = HTTPRequest.new()
    request.timeout = 20.0
    add_child(request)
    request.request_completed.connect(_on_request_completed)
    timer = Timer.new()
    timer.wait_time = REFRESH_SECONDS
    timer.timeout.connect(_refresh)
    add_child(timer)
    timer.start()
    _refresh()


func _refresh() -> void:
    if request.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED:
        request.request(URL)


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
        return
    var json := JSON.new()
    if json.parse(body.get_string_from_utf8()) != OK:
        return
    var data := parse_current(json.data)
    if data.is_empty():
        return
    current = data
    downloaded = json.data
    weather_changed.emit(current)


func parse_current(payload: Variant) -> Dictionary:
    if not payload is Dictionary or not payload.get("current") is Dictionary:
        return {}
    var values: Dictionary = payload.current
    for key in ["weather_code", "is_day", "cloud_cover", "wind_speed_10m", "wind_direction_10m"]:
        if not values.has(key) or not (values[key] is float or values[key] is int):
            return {}
        if not is_finite(float(values[key])):
            return {}
    var code: float = values.weather_code
    var day: float = values.is_day
    var clouds: float = values.cloud_cover
    var speed: float = values.wind_speed_10m
    var direction: float = values.wind_direction_10m
    if code < 0 or code > 99 or code != floor(code) or day not in [0.0, 1.0] or clouds < 0 or clouds > 100 or speed < 0 or direction < 0 or direction > 360:
        return {}
    var data := {"weather_code": int(code), "is_day": int(day), "cloud_cover": clouds, "wind_speed_10m": speed, "wind_direction_10m": direction}
    if payload.get("daily") is Dictionary:
        var daily: Dictionary = payload.daily
        for key in ["sunrise", "sunset", "moonrise", "moonset"]:
            if daily.get(key) is Array:
                data[key] = daily[key]
        var phases: Variant = daily.get("moon_phase")
        # Two past days are requested, so index 2 is the current local day.
        if phases is Array and phases.size() > 2 and (phases[2] is float or phases[2] is int):
            var phase := float(phases[2])
            if is_finite(phase) and phase >= 0.0 and phase <= 1.0:
                data["moon_phase"] = phase
    return data


func celestial_state(data: Dictionary, now: float) -> Dictionary:
    var result := {"is_day": data.is_day, "moon_visible": true, "moon_phase": data.get("moon_phase", 0.2)}
    for pair in [["sunrise", "sunset", "is_day"], ["moonrise", "moonset", "moon_visible"]]:
        var latest := -1.0
        var visible := false
        for index in range(2):
            var events: Variant = data.get(pair[index], [])
            if not events is Array:
                continue
            for event in events:
                if (event is float or event is int) and is_finite(float(event)) and event <= now and event > latest:
                    latest = float(event)
                    visible = index == 0
        # Do not extrapolate indefinitely if refreshes fail or event data is incomplete.
        if latest >= 0.0 and now - latest <= 172800.0:
            result[pair[2]] = visible
    return result
