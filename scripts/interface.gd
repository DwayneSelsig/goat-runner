extends CanvasLayer

const TOUCH_SCRIPT := preload("res://scripts/touch_control.gd")
const GREEN_RIBBON := preload("res://assets/gui/ribbon-green.svg")
const RED_RIBBON := preload("res://assets/gui/ribbon-red-torn.svg")
const GEAR_ICON := preload("res://assets/gui/icon-settings.svg")
const CROSS_ICON := preload("res://assets/gui/icon-cross.svg")
const CHECK_ICON := preload("res://assets/gui/icon-check.svg")
const TRASH_ICON := preload("res://assets/gui/icon-trash.svg")
const WOOD_FLAT := preload("res://assets/gui/button-wood-flat.svg")
const WOOD_RAISED := preload("res://assets/gui/button-wood-raised.svg")
const WOOD_PANEL := preload("res://assets/gui/panel-wood-horizontal.svg")
const WOOD_PANEL_VERTICAL := preload("res://assets/gui/panel-wood-vertical.svg")
const WOOD_SQUARE := preload("res://assets/gui/panel-wood-square.svg")
const WOOD_BAR := preload("res://assets/gui/bar-wood-thin.svg")
const YELLOW_KNOB := preload("res://assets/gui/button-round-yellow.svg")
var settings_path := "user://interface.cfg"
const LANGUAGES := ["en", "nl", "de"]
const MESSAGES := {
    "START": ["Start game", "Start spel", "Spiel starten"],
    "TITLE": ["Ready to run?", "Klaar om te rennen?", "Bereit zum Laufen?"],
    "HELP": ["%s: jump · %s: duck", "%s: springen · %s: bukken", "%s: springen · %s: ducken"],
    "KEYBINDS": ["Keybinds", "Toetsen", "Tastenbelegung"],
    "JUMP_KEY": ["Jump", "Springen", "Springen"],
    "DUCK_KEY": ["Duck", "Bukken", "Ducken"],
    "PRESS_KEY": ["Press a key…", "Druk op een toets…", "Taste drücken…"],
    "NO_KEY": ["No extra key", "Geen extra toets", "Keine zusätzliche Taste"],
    "RESET_KEYS": ["Restore defaults", "Herstel standaard", "Standard wiederherstellen"],
    "DELETE_KEY": ["Remove extra key", "Extra toets verwijderen", "Zusätzliche Taste entfernen"],
    "ACCEPT_KEYS": ["Save keybinds", "Toetsen opslaan", "Tasten speichern"],
    "KEY_SPACE": ["Space", "Spatie", "Leertaste"],
    "KEY_UP": ["Up", "Omhoog", "Hoch"],
    "KEY_DOWN": ["Down", "Omlaag", "Runter"],
    "OVER": ["Game over", "Spel voorbij", "Spiel vorbei"],
    "BUSH": ["The goat ran into a bush.", "De geit botste tegen een struik.", "Die Ziege ist gegen einen Busch gelaufen."],
    "PUDDLE": ["The goat fell into a puddle.", "De geit viel in een plas.", "Die Ziege ist in eine Pfütze gefallen."],
    "LINE": ["The goat got caught on the clothesline.", "De geit bleef aan de waslijn hangen.", "Die Ziege blieb an der Wäscheleine hängen."],
    "HAY": ["The goat found a hay bale and stopped to eat.", "De geit vond een hooibaal en ging eten.", "Die Ziege fand einen Heuballen und frisst."],
    "RETRY": ["Play again", "Opnieuw spelen", "Erneut spielen"],
    "SCORE": ["Score: %d", "Score: %d", "Punkte: %d"],
    "BEST": ["High score: %d", "Highscore: %d", "Rekord: %d"],
    "SETTINGS": ["Settings", "Instellingen", "Einstellungen"],
    "LANGUAGE": ["Language", "Taal", "Sprache"],
    "OPACITY": ["Button opacity", "Dekking knoppen", "Deckkraft der Tasten"],
    "SHOW_TOUCH": ["Show touch controls", "Toon aanraakknoppen", "Touch-Steuerung anzeigen"],
    "EDIT_HELP": ["Drag buttons to move; drag their corner to resize.", "Versleep de knoppen; sleep de hoek om de grootte te wijzigen.", "Tasten ziehen; an der Ecke die Größe ändern."],
    "RESET_LAYOUT": ["Reset on-screen buttons", "Herstel aanraakknoppen", "Bildschirmtasten zurücksetzen"],
    "RESET_SCORE": ["Reset high score", "Reset highscore", "Rekord zurücksetzen"],
    "CONFIRM": ["Reset the high score?", "Highscore resetten?", "Rekord zurücksetzen?"],
    "CANCEL": ["Cancel", "Annuleren", "Abbrechen"],
    "RESET": ["Reset", "Resetten", "Zurücksetzen"],
    "CLOSE": ["Close", "Sluiten", "Schließen"]
}

var config := ConfigFile.new()
var touch_visible := true
var touch_opacity := 1.0
var message_kind := -2
var game_score := 0
var game_highscore := 0
var controls: Array[Control] = []
var root_ui: Control
var hud: HBoxContainer
var score_label: Label
var best_label: Label
var message: Control
var message_title: Label
var message_detail: Label
var message_button: Button
var ribbon: TextureRect
var settings: PanelContainer
var settings_drag_handle: Control
var gear: Button
var close_settings: Button
var language: OptionButton
var visibility_toggle: CheckButton
var opacity_slider: HSlider
var score_overlay: Control
var score_confirm: Button
var score_cancel: Button
var settings_open := false
var dragging_settings := false
var settings_touch_index := -1
var widgets := {}
const DEFAULT_KEYS := {"jump": [KEY_SPACE, KEY_UP], "duck": [KEY_DOWN]}
var extra_keys := {"jump": 0, "duck": 0}
var pending_keys := {"jump": 0, "duck": 0}
var keybind_overlay: Control
var keybind_fields := {}
var keybind_delete := {}
var keybind_ok: Button
var keybind_cancel: Button
var capturing_action := ""

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _register_translations()
    config.load(settings_path)
    for action in extra_keys:
        extra_keys[action] = maxi(0, int(config.get_value("keybinds", action, 0)))
    if extra_keys.jump != 0 and extra_keys.jump == extra_keys.duck:
        extra_keys.duck = 0
    _apply_keybinds()
    var selected := str(config.get_value("settings", "language", ""))
    if not selected in LANGUAGES:
        selected = OS.get_locale_language()
    TranslationServer.set_locale(selected if selected in LANGUAGES else "en")
    touch_visible = bool(config.get_value("settings", "touch_visible", true))
    touch_opacity = clampf(float(config.get_value("settings", "touch_opacity", 1.0)), 0.0, 1.0)
    _build_ui()
    update_scores(get_parent().score, get_parent().highscore)
    _refresh_text()
    get_viewport().size_changed.connect(_layout_controls)
    get_viewport().size_changed.connect(_clamp_settings_position)

func _register_translations() -> void:
    for i in LANGUAGES.size():
        var translation := Translation.new()
        translation.locale = LANGUAGES[i]
        for key in MESSAGES:
            translation.add_message(key, MESSAGES[key][i])
        TranslationServer.add_translation(translation)

func _wood_style(texture: Texture2D, padding: float) -> StyleBoxTexture:
    var style := StyleBoxTexture.new()
    style.texture = texture
    for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
        style.set_content_margin(side, padding)
    return style

func _style_button(button: Button, texture: Texture2D, padding: float) -> void:
    for state in ["normal", "hover", "pressed", "focus", "disabled"]:
        var style := _wood_style(texture, padding)
        if state == "hover": style.modulate_color = Color(1.15, 1.15, 1.15)
        if state == "pressed": style.modulate_color = Color(0.8, 0.8, 0.8)
        if state == "focus": style.modulate_color = Color(1, 1, 1, 0)
        button.add_theme_stylebox_override(state, style)
    button.add_theme_color_override("font_color", Color(1, 0.96, 0.86))
    button.add_theme_color_override("font_hover_color", Color.WHITE)
    button.add_theme_font_size_override("font_size", 22)

func _build_ui() -> void:
    root_ui = Control.new()
    root_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root_ui)
    hud = HBoxContainer.new()
    hud.name = "ScorePanels"
    hud.set_anchors_preset(Control.PRESET_CENTER_TOP)
    hud.offset_left = -265
    hud.offset_right = 265
    hud.offset_top = 14
    hud.offset_bottom = 78
    hud.add_theme_constant_override("separation", 10)
    root_ui.add_child(hud)
    for index in 2:
        var panel := PanelContainer.new()
        panel.custom_minimum_size = Vector2(260, 64)
        panel.add_theme_stylebox_override("panel", _wood_style(WOOD_FLAT, 12))
        var label := Label.new()
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        label.add_theme_font_size_override("font_size", 23)
        label.add_theme_color_override("font_color", Color(1, 0.96, 0.86))
        panel.add_child(label)
        hud.add_child(panel)
        if index == 0: score_label = label
        else: best_label = label
    gear = Button.new()
    gear.icon = GEAR_ICON
    gear.expand_icon = true
    gear.tooltip_text = tr("SETTINGS")
    gear.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    gear.position = Vector2(-98, 16)
    gear.size = Vector2(76, 76)
    _style_button(gear, WOOD_SQUARE, 16)
    gear.pressed.connect(_toggle_settings)
    root_ui.add_child(gear)
    _build_message()
    for i in 2:
        var control: Control = TOUCH_SCRIPT.new()
        control.action = "jump" if i == 0 else "duck"
        control.button_opacity = touch_opacity
        control.name = "JumpControl" if i == 0 else "DuckControl"
        root_ui.add_child(control)
        controls.append(control)
        control.layout_changed.connect(_save_layout)
    _layout_controls()
    _build_settings()
    _build_keybind_popup()
    _build_score_popup()
    _update_touch_visibility()

func _build_message() -> void:
    message = Control.new()
    message.set_anchors_preset(Control.PRESET_CENTER)
    message.position = Vector2(-270, -170)
    message.size = Vector2(540, 310)
    message.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root_ui.add_child(message)
    var panel := PanelContainer.new()
    panel.position = Vector2(20, 55)
    panel.size = Vector2(500, 265)
    panel.add_theme_stylebox_override("panel", _wood_style(WOOD_PANEL, 24))
    message.add_child(panel)
    var box := VBoxContainer.new()
    box.alignment = BoxContainer.ALIGNMENT_CENTER
    box.add_theme_constant_override("separation", 20)
    panel.add_child(box)
    ribbon = TextureRect.new()
    ribbon.position = Vector2(0, -28)
    ribbon.size = Vector2(540, 145)
    ribbon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    ribbon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    message.add_child(ribbon)
    message_title = Label.new()
    message_title.position = Vector2(100, -22)
    message_title.size = Vector2(340, 60)
    message_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    message_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    message_title.add_theme_font_size_override("font_size", 26)
    message_title.add_theme_color_override("font_color", Color(1, 1, 1))
    message_title.add_theme_color_override("font_outline_color", Color(0.15, 0.2, 0.05, 0.9))
    message_title.add_theme_constant_override("outline_size", 4)
    message_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
    message.add_child(message_title)
    var spacer := Control.new()
    spacer.custom_minimum_size.y = 44
    box.add_child(spacer)
    message_detail = Label.new()
    message_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    message_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    message_detail.add_theme_font_size_override("font_size", 21)
    box.add_child(message_detail)
    message_button = Button.new()
    message_button.custom_minimum_size = Vector2(250, 70)
    _style_button(message_button, WOOD_RAISED, 14)
    message_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    message_button.pressed.connect(_message_pressed)
    box.add_child(message_button)
    message.hide()

func _build_settings() -> void:
    settings = PanelContainer.new()
    settings.set_anchors_preset(Control.PRESET_TOP_LEFT)
    settings.position = Vector2(105, 20)
    var settings_style := _wood_style(WOOD_PANEL_VERTICAL, 76)
    settings_style.content_margin_top = 65
    settings_style.content_margin_bottom = 72
    settings.add_theme_stylebox_override("panel", settings_style)
    settings.custom_minimum_size = Vector2(550, 0)
    root_ui.add_child(settings)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 10)
    settings.add_child(box)
    var header := HBoxContainer.new()
    header.mouse_filter = Control.MOUSE_FILTER_STOP
    header.mouse_default_cursor_shape = Control.CURSOR_MOVE
    header.gui_input.connect(_settings_header_input)
    box.add_child(header)
    var title_margin := MarginContainer.new()
    title_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
    title_margin.add_theme_constant_override("margin_top", 10)
    header.add_child(title_margin)
    var title := Label.new()
    title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    title.mouse_filter = Control.MOUSE_FILTER_IGNORE
    title.add_theme_font_size_override("font_size", 25)
    title_margin.add_child(title)
    widgets["SETTINGS"] = title
    var close_anchor := Control.new()
    close_anchor.custom_minimum_size = Vector2(48, 48)
    close_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
    header.add_child(close_anchor)
    settings_drag_handle = Control.new()
    settings_drag_handle.mouse_filter = Control.MOUSE_FILTER_STOP
    settings_drag_handle.mouse_default_cursor_shape = Control.CURSOR_MOVE
    settings_drag_handle.gui_input.connect(_settings_header_input)
    root_ui.add_child(settings_drag_handle)
    settings_drag_handle.hide()
    close_settings = Button.new()
    close_settings.icon = CROSS_ICON
    close_settings.expand_icon = true
    close_settings.size = Vector2(76, 76)
    _style_button(close_settings, WOOD_SQUARE, 16)
    close_settings.pressed.connect(_toggle_settings)
    root_ui.add_child(close_settings)
    close_settings.hide()
    settings.resized.connect(_place_close_button)
    _place_close_button()
    var row := HBoxContainer.new()
    box.add_child(row)
    var lang_label := Label.new()
    lang_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(lang_label)
    widgets["LANGUAGE"] = lang_label
    language = OptionButton.new()
    for item in ["English", "Nederlands", "Deutsch"]: language.add_item(item)
    language.select(LANGUAGES.find(TranslationServer.get_locale().substr(0, 2)))
    language.item_selected.connect(_language_selected)
    row.add_child(language)
    visibility_toggle = CheckButton.new()
    visibility_toggle.button_pressed = touch_visible
    visibility_toggle.toggled.connect(_visibility_changed)
    box.add_child(visibility_toggle)
    widgets["SHOW_TOUCH"] = visibility_toggle
    var opacity_label := Label.new()
    box.add_child(opacity_label)
    widgets["OPACITY"] = opacity_label
    var slider_holder := Control.new()
    slider_holder.custom_minimum_size.y = 48
    box.add_child(slider_holder)
    var bar := TextureRect.new()
    bar.texture = WOOD_BAR
    bar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    slider_holder.add_child(bar)
    opacity_slider = HSlider.new()
    opacity_slider.min_value = 0.0
    opacity_slider.max_value = 1.0
    opacity_slider.step = 0.01
    opacity_slider.value = touch_opacity
    opacity_slider.custom_minimum_size.y = 48
    opacity_slider.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    opacity_slider.add_theme_stylebox_override("slider", StyleBoxEmpty.new())
    opacity_slider.add_theme_stylebox_override("grabber_area", StyleBoxEmpty.new())
    opacity_slider.add_theme_stylebox_override("grabber_area_highlight", StyleBoxEmpty.new())
    var knob_image := YELLOW_KNOB.get_image()
    knob_image.resize(44, 44, Image.INTERPOLATE_LANCZOS)
    var knob := ImageTexture.create_from_image(knob_image)
    opacity_slider.add_theme_icon_override("grabber", knob)
    opacity_slider.add_theme_icon_override("grabber_highlight", knob)
    opacity_slider.add_theme_icon_override("grabber_disabled", knob)
    opacity_slider.value_changed.connect(_opacity_changed)
    slider_holder.add_child(opacity_slider)
    var hint := Label.new()
    hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(hint)
    widgets["EDIT_HELP"] = hint
    _setting_button(box, "RESET_LAYOUT", _reset_layout)
    _setting_button(box, "KEYBINDS", _open_keybinds)
    _setting_button(box, "RESET_SCORE", _open_score_popup)
    settings.hide()

func _fit_settings() -> void:
    settings.reset_size()
    _clamp_settings_position()

func _open_settings_at_gear() -> void:
    if not settings_open:
        return
    _fit_settings()
    settings.position = gear.position - Vector2(settings.size.x - 84, 14)
    _clamp_settings_position()

func _settings_header_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed and settings_touch_index == -1:
            settings_touch_index = event.index
        elif not event.pressed and event.index == settings_touch_index:
            settings_touch_index = -1
    elif event is InputEventScreenDrag and event.index == settings_touch_index:
        _move_settings(event.relative)
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and settings_touch_index == -1:
        dragging_settings = event.pressed
    elif event is InputEventMouseMotion and dragging_settings and settings_touch_index == -1:
        _move_settings(event.relative)

func _move_settings(delta: Vector2) -> void:
    settings.position += delta
    _clamp_settings_position()

func _clamp_settings_position() -> void:
    var bounds := get_viewport().get_visible_rect().size
    settings.position = settings.position.clamp(Vector2.ZERO, (bounds - settings.size).max(Vector2.ZERO))
    _place_close_button()

func _place_close_button() -> void:
    close_settings.position = settings.position + Vector2(settings.size.x - 84, 14)
    settings_drag_handle.position = settings.position
    settings_drag_handle.size = Vector2(maxf(0.0, settings.size.x - 84.0), 65.0)

func _setting_button(box: VBoxContainer, key: String, callback: Callable) -> void:
    var button := Button.new()
    button.custom_minimum_size.y = 52
    _style_button(button, WOOD_RAISED, 10)
    button.pressed.connect(callback)
    box.add_child(button)
    widgets[key] = button

func _create_popup(panel_size: Vector2) -> Dictionary:
    var overlay := Control.new()
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    root_ui.add_child(overlay)
    var shade := ColorRect.new()
    shade.color = Color(0, 0, 0, 0.55)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    overlay.add_child(shade)
    var panel := PanelContainer.new()
    panel.set_anchors_preset(Control.PRESET_CENTER)
    panel.position = -panel_size / 2.0
    panel.size = panel_size
    panel.add_theme_stylebox_override("panel", _wood_style(WOOD_PANEL, 55))
    overlay.add_child(panel)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 10)
    panel.add_child(box)
    overlay.hide()
    return {"overlay": overlay, "box": box}

func _build_keybind_popup() -> void:
    var popup := _create_popup(Vector2(620, 420))
    keybind_overlay = popup.overlay
    var box: VBoxContainer = popup.box
    var title := Label.new()
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 26)
    box.add_child(title)
    widgets["KEYBINDS_TITLE"] = title
    for action in ["jump", "duck"]:
        var row := HBoxContainer.new()
        box.add_child(row)
        var label := Label.new()
        label.custom_minimum_size.x = 130
        label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        row.add_child(label)
        widgets["JUMP_KEY" if action == "jump" else "DUCK_KEY"] = label
        var field := Button.new()
        field.custom_minimum_size = Vector2(240, 54)
        field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        _style_button(field, WOOD_FLAT, 10)
        field.pressed.connect(_capture_key.bind(action))
        row.add_child(field)
        keybind_fields[action] = field
        var trash := _keybind_icon_button(TRASH_ICON, _clear_key.bind(action))
        row.add_child(trash)
        keybind_delete[action] = trash
    _setting_button(box, "RESET_KEYS", _reset_pending_keys)
    var buttons := HBoxContainer.new()
    buttons.alignment = BoxContainer.ALIGNMENT_CENTER
    box.add_child(buttons)
    keybind_ok = _keybind_icon_button(CHECK_ICON, _confirm_keybinds)
    keybind_cancel = _keybind_icon_button(CROSS_ICON, _cancel_keybinds)
    buttons.add_child(keybind_ok)
    buttons.add_child(keybind_cancel)
    keybind_overlay.hide()

func _build_score_popup() -> void:
    var popup := _create_popup(Vector2(620, 300))
    score_overlay = popup.overlay
    var box: VBoxContainer = popup.box
    box.alignment = BoxContainer.ALIGNMENT_CENTER
    var question := Label.new()
    question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    question.add_theme_font_size_override("font_size", 26)
    box.add_child(question)
    widgets["CONFIRM"] = question
    var buttons := HBoxContainer.new()
    buttons.alignment = BoxContainer.ALIGNMENT_CENTER
    box.add_child(buttons)
    score_confirm = _keybind_icon_button(CHECK_ICON, _confirm_score_reset)
    score_cancel = _keybind_icon_button(CROSS_ICON, _close_score_popup)
    buttons.add_child(score_confirm)
    buttons.add_child(score_cancel)

func _open_score_popup() -> void:
    score_overlay.show()
    score_cancel.grab_focus()

func _close_score_popup() -> void:
    score_overlay.hide()

func _confirm_score_reset() -> void:
    get_parent().reset_highscore()
    _close_score_popup()

func _keybind_icon_button(icon: Texture2D, callback: Callable) -> Button:
    var button := Button.new()
    button.custom_minimum_size = Vector2(60, 60)
    button.icon = icon
    button.expand_icon = true
    button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
    button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
    _style_button(button, WOOD_SQUARE, 14)
    button.pressed.connect(callback)
    return button

func _open_keybinds() -> void:
    pending_keys = extra_keys.duplicate()
    capturing_action = ""
    _refresh_keybind_fields()
    keybind_overlay.show()

func _capture_key(action: String) -> void:
    capturing_action = action
    _refresh_keybind_fields()

func _input(event: InputEvent) -> void:
    if is_instance_valid(score_overlay) and score_overlay.visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
        _close_score_popup()
        get_viewport().set_input_as_handled()
        return
    if not is_instance_valid(keybind_overlay) or not keybind_overlay.visible or capturing_action.is_empty():
        return
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_ESCAPE:
            capturing_action = ""
        elif event.keycode != KEY_NONE and event.keycode not in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]:
            var other := "duck" if capturing_action == "jump" else "jump"
            if pending_keys[other] == event.keycode:
                pending_keys[other] = 0
            pending_keys[capturing_action] = event.keycode
            capturing_action = ""
        _refresh_keybind_fields()
        get_viewport().set_input_as_handled()

func _clear_key(action: String) -> void:
    pending_keys[action] = 0
    capturing_action = ""
    _refresh_keybind_fields()

func _reset_pending_keys() -> void:
    pending_keys = {"jump": 0, "duck": 0}
    capturing_action = ""
    _refresh_keybind_fields()

func _cancel_keybinds() -> void:
    capturing_action = ""
    keybind_overlay.hide()

func _confirm_keybinds() -> void:
    extra_keys = pending_keys.duplicate()
    for action in extra_keys:
        config.set_value("keybinds", action, extra_keys[action])
    config.save(settings_path)
    _apply_keybinds()
    _cancel_keybinds()
    if message_kind == -1: show_start()

func _apply_keybinds() -> void:
    for action in DEFAULT_KEYS:
        if not InputMap.has_action(action): InputMap.add_action(action)
        InputMap.action_erase_events(action)
        var other := "duck" if action == "jump" else "jump"
        var keys: Array = DEFAULT_KEYS[action].duplicate()
        if extra_keys[action] != 0 and not keys.has(extra_keys[action]):
            keys.append(extra_keys[action])
        for key in keys:
            if key == extra_keys[other]: continue
            var event := InputEventKey.new()
            event.keycode = key
            InputMap.action_add_event(action, event)

func _key_name(key: int) -> String:
    match key:
        KEY_SPACE: return tr("KEY_SPACE")
        KEY_UP: return tr("KEY_UP")
        KEY_DOWN: return tr("KEY_DOWN")
        _: return OS.get_keycode_string(key)

func _action_key_names(action: String) -> String:
    var names: PackedStringArray = []
    for event in InputMap.action_get_events(action):
        if event is InputEventKey: names.append(_key_name(event.keycode))
    return ", ".join(names) if not names.is_empty() else "—"

func _refresh_keybind_fields() -> void:
    for action in keybind_fields:
        keybind_fields[action].text = tr("PRESS_KEY") if capturing_action == action else (_key_name(pending_keys[action]) if pending_keys[action] != 0 else tr("NO_KEY"))
        keybind_delete[action].tooltip_text = tr("DELETE_KEY")
    keybind_ok.tooltip_text = tr("ACCEPT_KEYS")
    keybind_cancel.tooltip_text = tr("CANCEL")

func _refresh_text() -> void:
    for key in widgets: widgets[key].text = tr("KEYBINDS" if key == "KEYBINDS_TITLE" else key)
    _refresh_keybind_fields()
    gear.tooltip_text = tr("SETTINGS")
    close_settings.tooltip_text = tr("CLOSE")
    score_confirm.tooltip_text = tr("RESET")
    score_cancel.tooltip_text = tr("CANCEL")
    update_scores(game_score, game_highscore)
    if message_kind == -1: show_start()
    elif message_kind >= 0: show_game_over(message_kind, game_score)
    _fit_settings.call_deferred()

func update_scores(current: int, best: int) -> void:
    game_score = current
    game_highscore = best
    score_label.text = tr("SCORE") % current
    best_label.text = tr("BEST") % best

func show_start() -> void:
    message_kind = -1
    ribbon.texture = GREEN_RIBBON
    message_title.text = tr("TITLE")
    message_detail.text = tr("HELP") % [_action_key_names("jump"), _action_key_names("duck")]
    message_button.text = tr("START")
    message.show()

func show_game_over(kind: int, current: int) -> void:
    message_kind = kind
    ribbon.texture = RED_RIBBON
    message_title.text = tr("OVER")
    message_detail.text = tr(["BUSH", "PUDDLE", "LINE", "HAY"][clampi(kind, 0, 3)]) + "\n" + tr("SCORE") % current
    message_button.text = tr("RETRY")
    message.show()

func hide_message() -> void:
    message_kind = -2
    message.hide()

func _message_pressed() -> void:
    if settings_open: return
    if message_kind == -1: get_parent().start_run()
    elif message_kind >= 0: get_parent()._restart_game()

func _toggle_settings() -> void:
    if keybind_overlay.visible:
        _cancel_keybinds()
    if score_overlay.visible:
        _close_score_popup()
    settings_open = not settings_open
    dragging_settings = false
    settings_touch_index = -1
    settings.visible = settings_open
    settings_drag_handle.visible = settings_open
    if settings_open: _open_settings_at_gear.call_deferred()
    close_settings.visible = settings_open
    get_tree().paused = settings_open
    for control in controls: control.set_editing(settings_open)
    _update_touch_visibility()

func _exit_tree() -> void:
    if settings_open: get_tree().paused = false
    Input.action_release("jump")
    Input.action_release("duck")

func _language_selected(index: int) -> void:
    TranslationServer.set_locale(LANGUAGES[index])
    config.set_value("settings", "language", LANGUAGES[index])
    config.save(settings_path)
    _refresh_text()

func _visibility_changed(value: bool) -> void:
    touch_visible = value
    config.set_value("settings", "touch_visible", value)
    config.save(settings_path)
    _update_touch_visibility()

func _opacity_changed(value: float) -> void:
    touch_opacity = value
    for control in controls:
        control.button_opacity = value
        control.queue_redraw()
    config.set_value("settings", "touch_opacity", value)
    config.save(settings_path)

func set_touch_for_start(value: bool) -> void:
    visibility_toggle.set_pressed_no_signal(value)
    _visibility_changed(value)

func _update_touch_visibility() -> void:
    for control in controls: control.visible = touch_visible or settings_open

func _layout_controls() -> void:
    var viewport := get_viewport().get_visible_rect().size
    for i in controls.size():
        var control := controls[i]
        var section := "jump" if i == 0 else "duck"
        var edge := clampf(float(config.get_value(section, "size", 110.0)), 64.0, 260.0)
        control.size = Vector2.ONE * edge
        var default_position := Vector2(1.0, 1.0) - Vector2(150.0 / viewport.x, (280.0 - i * 130.0) / viewport.y)
        var normalized: Vector2 = config.get_value(section, "position", default_position)
        control.position = (normalized * viewport).clamp(Vector2.ZERO, (viewport - control.size).max(Vector2.ZERO))
        control.queue_redraw()

func _save_layout() -> void:
    var viewport := get_viewport().get_visible_rect().size
    for i in controls.size():
        var section := "jump" if i == 0 else "duck"
        config.set_value(section, "size", controls[i].size.x)
        config.set_value(section, "position", controls[i].position / viewport)
    config.save(settings_path)

func _reset_layout() -> void:
    for section in ["jump", "duck"]: config.erase_section(section)
    config.save(settings_path)
    _layout_controls()
