class_name Hud
extends CanvasLayer
## 重制版 HUD：毛玻璃面板 / 回合横幅 / 队伍状态 / 道具卡槽 / 事件弹窗 / 开始与结算

signal roll_pressed
signal restart_pressed
signal camera_pressed(action: String)
signal card_pressed(index: int)
signal piece_pressed(index: int)
signal start_pressed(mode: int, level: int, theme_id: String)
signal theme_previewed(theme_id: String)

const GOLD := Color("f0cd8a")
const TEXT := Color("e8edf7")
const DIM := Color("98a3b8")

const ITEM_INFO := {
	"boost": ["加速", "+2 点数", Color("ff9a3c")],
	"shield": ["护盾", "免疫一次", Color("6cc6ff")],
	"warp": ["跃迁", "前进 3 格", Color("b484ff")],
	"snipe": ["狙击", "击退对手", Color("ff5566")],
	"swap": ["换位", "与对手换位", Color("ffd166")],
	"freeze": ["冰冻", "对手停一轮", Color("7fe6ff")],
	"double": ["双倍", "点数 ×2", Color("ffe066")],
	"teleport": ["传送", "前进 5 格", Color("7cf0a8")],
}

var _root: Control
var _turn_label: Label
var _dice_value: Label
var _log_label: Label
var _roll_button: Button
var _banner: PanelContainer
var _banner_label: Label
var _pick_panel: PanelContainer
var _pick_box: HBoxContainer
var _pick_hint: Label
var _card_buttons: Array = []
var _card_labels: Array = []
var _team_chips: Array = []
var _start_overlay: Control
var _win_overlay: Control
var _win_title: Label
var _win_stats: Label
var _event_overlay: Control
var _event_card: PanelContainer
var _event_title: Label
var _event_desc: Label
var _mode := 0
var _level := 1
var _theme_id := "dusk"
var _mode_buttons: Array = []
var _level_buttons: Array = []
var _theme_buttons: Array = []
var _safe := Vector4.ZERO
var _event_tween: Tween
var _game_nodes: Array = []


func _ready() -> void:
	layer = 10
	_safe = _safe_insets()

	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_build_vignette()
	_build_title()
	_build_team_bar()
	_build_banner()
	_build_log()
	_build_bottom()
	_build_pick()
	_build_event()
	_build_start()
	_build_win()


func _build_vignette() -> void:
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform float strength = 0.62;
void fragment() {
	vec2 uv = UV - vec2(0.5);
	float d = length(uv * vec2(1.0, 0.82));
	float v = smoothstep(0.30, 0.92, d);
	COLOR = vec4(0.015, 0.022, 0.045, v * strength);
}
"""
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = sh
	rect.material = mat
	_root.add_child(rect)


func _safe_insets() -> Vector4:
	var win := DisplayServer.window_get_size()
	if win.x <= 0 or win.y <= 0:
		return Vector4.ZERO
	var sa := DisplayServer.get_display_safe_area()
	if sa.size.x <= 0 or sa.size.y <= 0:
		return Vector4.ZERO
	var scale := 1280.0 / float(win.x)
	var left := maxf(0.0, float(sa.position.x) * scale)
	var top := maxf(0.0, float(sa.position.y) * scale)
	var right := maxf(0.0, float(win.x - sa.position.x - sa.size.x) * scale)
	var bottom := maxf(0.0, float(win.y - sa.position.y - sa.size.y) * scale)
	return Vector4(left, top, right, bottom)


# ---------------------------------------------------------------- 样式

func _flat(bg: Color, radius := 14, border := Color(1, 1, 1, 0.07), bw := 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.corner_radius_top_left = radius
	s.corner_radius_top_right = radius
	s.corner_radius_bottom_left = radius
	s.corner_radius_bottom_right = radius
	s.border_width_left = bw
	s.border_width_top = bw
	s.border_width_right = bw
	s.border_width_bottom = bw
	s.border_color = border
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 10
	s.shadow_offset = Vector2(0, 5)
	return s


func _label(text: String, size: int, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _btn(text: String, size: Vector2, font_size := 17) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = size
	b.add_theme_font_size_override("font_size", font_size)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", _btn_style(Color(1, 1, 1, 0.07), Color(1, 1, 1, 0.1)))
	b.add_theme_stylebox_override("hover", _btn_style(Color(1, 1, 1, 0.14), GOLD))
	b.add_theme_stylebox_override("pressed", _btn_style(Color(1, 1, 1, 0.2), GOLD))
	b.add_theme_stylebox_override("disabled", _btn_style(Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.05)))
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.3))
	return b


func _btn_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.corner_radius_top_left = 12
	s.corner_radius_top_right = 12
	s.corner_radius_bottom_left = 12
	s.corner_radius_bottom_right = 12
	s.border_width_left = 1
	s.border_width_top = 1
	s.border_width_right = 1
	s.border_width_bottom = 1
	s.border_color = border
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s


# ---------------------------------------------------------------- 构建

func _build_title() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _flat(Color(0.035, 0.05, 0.085, 0.78), 18))
	panel.position = Vector2(24.0 + _safe.x, 20.0 + _safe.y)
	_root.add_child(panel)
	_game_nodes.append(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	panel.add_child(vb)

	vb.add_child(_label("骑士飞行棋", 26, GOLD))
	vb.add_child(_label("KNIGHT'S GAMBIT · 2026", 10, Color(1, 1, 1, 0.4)))

	var space := Control.new()
	space.custom_minimum_size = Vector2(0, 8)
	vb.add_child(space)

	_turn_label = _label("准备开始", 19, TEXT)
	vb.add_child(_turn_label)

	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override("panel", _flat(Color(1, 1, 1, 0.05), 10, Color(1, 1, 1, 0.06)))
	pill.custom_minimum_size = Vector2(0, 34)
	vb.add_child(pill)
	_dice_value = _label("点数  —", 16, Color(1, 1, 1, 0.75))
	pill.add_child(_dice_value)

	var restart := _btn("重新开始", Vector2(0, 32), 13)
	restart.pressed.connect(func(): restart_pressed.emit())
	vb.add_child(restart)


func _build_team_bar() -> void:
	var holder := HBoxContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	holder.offset_top = 20.0 + _safe.y
	holder.offset_left = 350.0 + _safe.x
	holder.offset_right = -390.0 - _safe.z
	holder.alignment = BoxContainer.ALIGNMENT_CENTER
	holder.add_theme_constant_override("separation", 10)
	_root.add_child(holder)
	_game_nodes.append(holder)

	for t in 4:
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", _flat(Color(0.035, 0.05, 0.085, 0.66), 14))
		chip.custom_minimum_size = Vector2(112, 0)
		holder.add_child(chip)
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 2)
		chip.add_child(vb)
		var name_l := _label("队伍", 16, TEXT)
		vb.add_child(name_l)
		var info_l := _label("0/4", 12, DIM)
		vb.add_child(info_l)
		_team_chips.append({"panel": chip, "name": name_l, "info": info_l})


func _build_banner() -> void:
	_banner = PanelContainer.new()
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_left = -170.0
	_banner.offset_right = 170.0
	_banner.offset_top = 96.0 + _safe.y
	_banner.offset_bottom = 146.0 + _safe.y
	_banner.add_theme_stylebox_override("panel", _flat(Color(0.05, 0.06, 0.09, 0.9), 18, GOLD, 2))
	_root.add_child(_banner)
	_game_nodes.append(_banner)

	_banner_label = _label("准备开始", 24, GOLD)
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.add_child(_banner_label)


func _build_log() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _flat(Color(0.035, 0.05, 0.085, 0.7), 16))
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -364.0 - _safe.z
	panel.offset_right = -24.0 - _safe.z
	panel.offset_top = 20.0 + _safe.y
	panel.offset_bottom = 176.0 + _safe.y
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_root.add_child(panel)
	_game_nodes.append(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	panel.add_child(vb)
	vb.add_child(_label("战  报", 12, Color(1, 1, 1, 0.45)))
	_log_label = _label("", 14, Color(0.85, 0.9, 1.0, 0.9))
	_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_label.custom_minimum_size = Vector2(308, 96)
	_log_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	vb.add_child(_log_label)


func _build_bottom() -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -104.0 - _safe.w
	bar.offset_bottom = -20.0 - _safe.w
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 16)
	_root.add_child(bar)
	_game_nodes.append(bar)

	# 相机
	var cam_row := HBoxContainer.new()
	cam_row.add_theme_constant_override("separation", 6)
	cam_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_child(cam_row)
	for spec in [["◀", "left"], ["▶", "right"], ["＋", "in"], ["－", "out"], ["⌂", "top"]]:
		var b := _btn(spec[0], Vector2(42, 44), 18)
		b.add_theme_stylebox_override("normal", _btn_style(Color(0.06, 0.08, 0.12, 0.9), Color(1, 1, 1, 0.28)))
		b.add_theme_stylebox_override("hover", _btn_style(Color(0.12, 0.15, 0.22, 0.95), GOLD))
		b.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0, 0.95))
		var act: String = spec[1]
		b.pressed.connect(func(): camera_pressed.emit(act))
		cam_row.add_child(b)

	_roll_button = Button.new()
	_roll_button.text = "掷 骰 子"
	_roll_button.custom_minimum_size = Vector2(214, 66)
	_roll_button.add_theme_font_size_override("font_size", 26)
	_roll_button.focus_mode = Control.FOCUS_NONE
	_roll_button.pressed.connect(func(): roll_pressed.emit())
	bar.add_child(_roll_button)
	_set_roll_style(Color("d9473c"))

	# 道具卡
	var card_panel := PanelContainer.new()
	card_panel.add_theme_stylebox_override("panel", _flat(Color(0.035, 0.05, 0.085, 0.7), 16))
	bar.add_child(card_panel)
	var cvb := VBoxContainer.new()
	cvb.add_theme_constant_override("separation", 4)
	card_panel.add_child(cvb)
	cvb.add_child(_label("道具卡", 11, Color(1, 1, 1, 0.45)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	cvb.add_child(row)
	for i in 4:
		var b := Button.new()
		b.custom_minimum_size = Vector2(88, 56)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_stylebox_override("normal", _btn_style(Color(1, 1, 1, 0.06), Color(1, 1, 1, 0.09)))
		b.add_theme_stylebox_override("hover", _btn_style(Color(1, 1, 1, 0.14), GOLD))
		b.add_theme_stylebox_override("pressed", _btn_style(Color(1, 1, 1, 0.2), GOLD))
		b.add_theme_stylebox_override("disabled", _btn_style(Color(1, 1, 1, 0.02), Color(1, 1, 1, 0.04)))
		b.add_theme_color_override("font_color", TEXT)
		b.add_theme_color_override("font_hover_color", Color.WHITE)
		b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.25))
		var idx := i
		b.pressed.connect(func(): card_pressed.emit(idx))
		row.add_child(b)
		var vb := VBoxContainer.new()
		vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(vb)
		var t1 := _label("—", 14, Color(1, 1, 1, 0.3))
		t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t1.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(t1)
		var t2 := _label("", 10, Color(1, 1, 1, 0.45))
		t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(t2)
		_card_buttons.append(b)
		_card_labels.append([t1, t2])


func _build_pick() -> void:
	var holder := CenterContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	holder.offset_top = -200.0 - _safe.w
	holder.offset_bottom = -118.0 - _safe.w
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(holder)

	_pick_panel = PanelContainer.new()
	_pick_panel.add_theme_stylebox_override("panel", _flat(Color(0.035, 0.05, 0.085, 0.88), 16, Color(1, 1, 1, 0.1)))
	_pick_panel.visible = false
	holder.add_child(_pick_panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	_pick_panel.add_child(vb)
	_pick_hint = _label("选择一枚棋子", 12, Color(1, 1, 1, 0.5))
	_pick_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_pick_hint)
	_pick_box = HBoxContainer.new()
	_pick_box.add_theme_constant_override("separation", 8)
	_pick_box.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(_pick_box)


func _build_event() -> void:
	_event_overlay = Control.new()
	_event_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_event_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_event_overlay.visible = false
	_root.add_child(_event_overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_event_overlay.add_child(center)

	_event_card = PanelContainer.new()
	_event_card.add_theme_stylebox_override("panel", _flat(Color(0.04, 0.055, 0.095, 0.96), 22, GOLD, 2))
	_event_card.custom_minimum_size = Vector2(520, 0)
	center.add_child(_event_card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	_event_card.add_child(vb)
	_event_title = _label("随机事件", 30, GOLD)
	_event_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_event_title)
	_event_desc = _label("", 17, Color(0.9, 0.94, 1.0, 0.9))
	_event_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_event_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_event_desc)


func _build_start() -> void:
	_start_overlay = Control.new()
	_start_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_start_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_start_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.015, 0.03, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_start_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_start_overlay.add_child(center)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _flat(Color(0.04, 0.055, 0.095, 0.96), 24, Color(1, 1, 1, 0.1)))
	card.custom_minimum_size = Vector2(640, 0)
	center.add_child(card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	card.add_child(vb)

	var t := _label("骑士飞行棋 3", 38, GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	var sub := _label("KNIGHT'S GAMBIT · 2026 REMAKE", 11, Color(1, 1, 1, 0.45))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)
	vb.add_child(_spacer(8))

	vb.add_child(_label("对战模式", 13, DIM))
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 10)
	vb.add_child(mode_row)
	for i in 2:
		var txt: String = ["人机 · 1v3", "4 人热座"][i]
		var b := _btn(txt, Vector2(0, 46), 17)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var idx := i
		b.pressed.connect(func(): _select_mode(idx))
		mode_row.add_child(b)
		_mode_buttons.append(b)

	vb.add_child(_label("AI 难度", 13, DIM))
	var level_row := HBoxContainer.new()
	level_row.add_theme_constant_override("separation", 10)
	vb.add_child(level_row)
	for i in 3:
		var txt2: String = ["简单", "普通", "困难"][i]
		var b2 := _btn(txt2, Vector2(0, 44), 16)
		b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var idx2 := i
		b2.pressed.connect(func(): _select_level(idx2))
		level_row.add_child(b2)
		_level_buttons.append(b2)

	vb.add_child(_label("棋盘主题", 13, DIM))
	var theme_row := HBoxContainer.new()
	theme_row.add_theme_constant_override("separation", 10)
	vb.add_child(theme_row)
	var ids := ["dusk", "frost", "ember"]
	for i in 3:
		var txt3: String = ["暮色竞技场", "霜封荒原", "熔火深渊"][i]
		var b3 := _btn(txt3, Vector2(0, 44), 15)
		b3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tid: String = ids[i]
		b3.pressed.connect(func(): _select_theme(tid))
		theme_row.add_child(b3)
		_theme_buttons.append(b3)

	vb.add_child(_spacer(10))
	var go := _btn("开 始 对 局", Vector2(0, 58), 24)
	go.add_theme_stylebox_override("normal", _btn_style(Color("c99a4e"), Color("f0cd8a")))
	go.add_theme_stylebox_override("hover", _btn_style(Color("e0b060"), Color("ffe0a0")))
	go.add_theme_stylebox_override("pressed", _btn_style(Color("b5863f"), Color("ffe0a0")))
	go.add_theme_color_override("font_color", Color("1a1206"))
	go.pressed.connect(func(): _start_clicked())
	vb.add_child(go)
	var hint := _label("8 种道具 · 7 种随机事件 · 宝箱格触发 · 掷 6 出基地", 12, Color(1, 1, 1, 0.45))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(hint)
	var hint2 := _label("拖动旋转视角 · 双指 / 滚轮缩放 · 点棋子或按钮走子", 11, Color(1, 1, 1, 0.3))
	hint2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(hint2)

	_select_mode(0)
	_select_level(1)
	_select_theme("dusk")


func _build_win() -> void:
	_win_overlay = Control.new()
	_win_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_win_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_win_overlay.visible = false
	_root.add_child(_win_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.015, 0.03, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_win_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_win_overlay.add_child(center)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _flat(Color(0.04, 0.055, 0.095, 0.97), 24, Color(1, 1, 1, 0.1)))
	card.custom_minimum_size = Vector2(480, 0)
	center.add_child(card)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	card.add_child(vb)
	_win_title = _label("红队 胜利", 36, GOLD)
	_win_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_win_title)
	_win_stats = _label("", 14, Color(0.85, 0.9, 1.0, 0.8))
	_win_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_win_stats)
	var again := _btn("再 来 一 局", Vector2(0, 52), 20)
	again.add_theme_stylebox_override("normal", _btn_style(Color("c99a4e"), Color("f0cd8a")))
	again.add_theme_stylebox_override("hover", _btn_style(Color("e0b060"), Color("ffe0a0")))
	again.add_theme_stylebox_override("pressed", _btn_style(Color("b5863f"), Color("ffe0a0")))
	again.add_theme_color_override("font_color", Color("1a1206"))
	again.pressed.connect(func(): restart_pressed.emit())
	vb.add_child(again)


func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _select_mode(i: int) -> void:
	_mode = i
	_paint_choice(_mode_buttons, i)


func _select_level(i: int) -> void:
	_level = i
	_paint_choice(_level_buttons, i)


func _select_theme(id: String) -> void:
	_theme_id = id
	var ids := ["dusk", "frost", "ember"]
	_paint_choice(_theme_buttons, ids.find(id))
	theme_previewed.emit(id)


func _paint_choice(buttons: Array, active: int) -> void:
	for k in buttons.size():
		var b: Button = buttons[k]
		if k == active:
			b.add_theme_stylebox_override("normal", _btn_style(Color(0.55, 0.42, 0.22, 0.6), GOLD))
			b.add_theme_color_override("font_color", Color("ffe6b8"))
		else:
			b.add_theme_stylebox_override("normal", _btn_style(Color(1, 1, 1, 0.06), Color(1, 1, 1, 0.1)))
			b.add_theme_color_override("font_color", TEXT)


func _start_clicked() -> void:
	hide_start()
	start_pressed.emit(_mode, _level, _theme_id)


# ---------------------------------------------------------------- 对外接口

func show_start() -> void:
	_start_overlay.visible = true
	for n in _game_nodes:
		if is_instance_valid(n):
			n.visible = false
	hide_win()


func hide_start() -> void:
	_start_overlay.visible = false
	for n in _game_nodes:
		if is_instance_valid(n):
			n.visible = true


func set_turn(text: String, color: Color) -> void:
	_turn_label.text = text
	_turn_label.add_theme_color_override("font_color", color)
	_banner_label.text = text
	_banner_label.add_theme_color_override("font_color", color.lightened(0.45))
	_banner.add_theme_stylebox_override("panel", _flat(Color(color.darkened(0.62).r, color.darkened(0.62).g, color.darkened(0.62).b, 0.92), 18, color.lightened(0.25), 2))
	_set_roll_style(color)


func _set_roll_style(color: Color) -> void:
	if _roll_button == null:
		return
	var base := color.darkened(0.18)
	_roll_button.add_theme_stylebox_override("normal", _btn_style(base, color.lightened(0.35)))
	_roll_button.add_theme_stylebox_override("hover", _btn_style(color.lightened(0.1), Color.WHITE))
	_roll_button.add_theme_stylebox_override("pressed", _btn_style(color.darkened(0.25), Color.WHITE))
	_roll_button.add_theme_stylebox_override("disabled", _btn_style(Color(1, 1, 1, 0.05), Color(1, 1, 1, 0.08)))
	_roll_button.add_theme_color_override("font_color", Color(0.06, 0.03, 0.01))
	_roll_button.add_theme_color_override("font_hover_color", Color(0.04, 0.02, 0.0))
	_roll_button.add_theme_color_override("font_pressed_color", Color(0.04, 0.02, 0.0))
	_roll_button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.3))


func set_dice(value: int, total := 0) -> void:
	if value <= 0:
		_dice_value.text = "点数  —"
	elif total > value:
		_dice_value.text = "点数  %d  + %d  =  %d" % [value, total - value, total]
	else:
		_dice_value.text = "点数  %d" % value


func set_roll_enabled(on: bool, text := "掷 骰 子") -> void:
	_roll_button.disabled = not on
	_roll_button.text = text


func set_teams(status: Array) -> void:
	for t in 4:
		if t >= _team_chips.size() or t >= status.size():
			continue
		var chip: Dictionary = _team_chips[t]
		var s: Dictionary = status[t]
		var name_l: Label = chip["name"]
		name_l.text = ("▶ " if s["current"] else "") + s["name"] + ("  AI" if s["ai"] else "  你")
		name_l.add_theme_color_override("font_color", s["color"])
		var info: Label = chip["info"]
		info.text = "%d/4 · 吃%d · 卡%d" % [s["finished"], s["captures"], s["cards"]]
		var panel: PanelContainer = chip["panel"]
		if s["current"]:
			panel.add_theme_stylebox_override("panel", _flat(Color(0.10, 0.12, 0.18, 0.94), 14, s["color"], 3))
		else:
			panel.add_theme_stylebox_override("panel", _flat(Color(0.035, 0.05, 0.085, 0.66), 14))


func log(text: String) -> void:
	if _log_label == null:
		return
	var lines: Array = Array(_log_label.text.split("\n"))
	lines.append(text)
	while lines.size() > 6:
		lines.pop_front()
	_log_label.text = "\n".join(lines)


func set_cards(cards: Array, enabled: bool) -> void:
	for i in _card_buttons.size():
		var b: Button = _card_buttons[i]
		var labels: Array = _card_labels[i]
		if i < cards.size():
			var id: String = cards[i]
			var info: Array = ITEM_INFO.get(id, ["?", "", TEXT])
			labels[0].text = info[0]
			labels[1].text = info[1]
			labels[0].add_theme_color_override("font_color", info[2])
			b.add_theme_stylebox_override("normal", _btn_style(Color(info[2].r * 0.18, info[2].g * 0.18, info[2].b * 0.18, 0.9), info[2].darkened(0.2)))
			b.disabled = not enabled
		else:
			labels[0].text = "空"
			labels[1].text = ""
			labels[0].add_theme_color_override("font_color", Color(1, 1, 1, 0.25))
			b.add_theme_stylebox_override("normal", _btn_style(Color(1, 1, 1, 0.04), Color(1, 1, 1, 0.07)))
			b.disabled = true


func show_pick(options: Array, hint := "选择一枚棋子") -> void:
	for c in _pick_box.get_children():
		c.queue_free()
	if _pick_hint:
		_pick_hint.text = hint
	for opt in options:
		var b := _btn(opt["label"], Vector2(132, 46), 15)
		var col: Color = opt["color"]
		b.add_theme_stylebox_override("normal", _btn_style(Color(col.r * 0.35, col.g * 0.35, col.b * 0.35, 0.9), col))
		b.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
		var idx: int = opt["index"]
		b.pressed.connect(func(): piece_pressed.emit(idx))
		_pick_box.add_child(b)
	_pick_panel.visible = true


func hide_pick() -> void:
	_pick_panel.visible = false


func show_event(title: String, desc: String, color: Color) -> void:
	_event_title.text = title
	_event_title.add_theme_color_override("font_color", color)
	_event_desc.text = desc
	_event_card.add_theme_stylebox_override("panel", _flat(Color(0.04, 0.055, 0.095, 0.96), 22, color, 3))
	_event_overlay.visible = true
	_event_overlay.modulate.a = 0.0
	if _event_tween and _event_tween.is_valid():
		_event_tween.kill()
	_event_tween = create_tween()
	_event_tween.tween_property(_event_overlay, "modulate:a", 1.0, 0.16)
	_event_tween.tween_interval(1.9)
	_event_tween.tween_property(_event_overlay, "modulate:a", 0.0, 0.24)
	_event_tween.tween_callback(func(): _event_overlay.visible = false)


func show_win(title: String, color: Color, stats: String) -> void:
	_win_title.text = title
	_win_title.add_theme_color_override("font_color", color)
	_win_stats.text = stats
	_win_overlay.visible = true


func hide_win() -> void:
	_win_overlay.visible = false


func set_start_visible(v: bool) -> void:
	_start_overlay.visible = v
