class_name Hud
extends CanvasLayer
## 2026 重制版 HUD
##  布局：左上角「≡」特效按钮展开控制台 / 顶部中央队伍状态 / 右上角折叠战报
##        底部中央骰子提示 / 右下角紧凑道具栏 / 居中事件卡与道具播报

signal roll_pressed
signal restart_pressed
signal home_pressed
signal card_pressed(index: int)
signal piece_pressed(index: int)
signal start_pressed(mode: int, level: int, theme_id: String, cells: int, styles: Array)
signal theme_previewed(theme_id: String)
signal theme_selected(theme_id: String)
signal sound_toggled(on: bool)
signal music_toggled(on: bool)
signal prefs_changed
signal roulette_done(index: int)
signal roulette_tick
signal home_create
signal home_load
signal home_settings
signal home_lan
signal save_pressed
signal load_slot_pressed(slot: int)
signal delete_slot_pressed(slot: int)
signal save_slot_pressed(slot: int)
signal duel_chosen(pick: int)
signal duel_toggled(on: bool)
signal rules_toggled(on: bool)
signal update_toggled(on: bool)
signal update_check_pressed
signal update_download_pressed
signal update_later_pressed
signal update_browser_pressed
signal lan_host_pressed(player_name: String)
signal lan_join_pressed(ip: String, room: String)
signal lan_leave_pressed
signal lan_refresh_pressed
signal lan_start_pressed
signal lan_ready_pressed(on: bool)
signal lan_seat_ai_pressed(seat: int, on: bool)
signal lan_kick_pressed(seat: int)
signal lan_name_changed(name: String)

const GOLD := Color("f0cd8a")
const TEXT := Color("e8edf7")
const DIM := Color("98a3b8")

const UpdateFeedScript := preload("res://src/Update.gd")
const THEME_IDS := ["cozy", "dusk", "frost", "ember", "jade", "void", "dune", "clock"]
const THEME_NAMES := ["晴日牧野", "暮色浮岛", "霜封冰湖", "熔火裂谷", "翠玉雨林", "虚空星海", "沙海神庙", "齿轮高塔"]
const THEME_SHORT := ["晴日", "暮色", "霜封", "熔火", "翠玉", "虚空", "沙海", "齿轮"]

const ITEM_INFO := {
	"boost": ["加速", "+2 点数", Color("ff9a3c")],
	"shield": ["护盾", "免疫一次", Color("6cc6ff")],
	"warp": ["跃迁", "前进 3 格", Color("b484ff")],
	"snipe": ["狙击", "击退对手", Color("ff5566")],
	"swap": ["换位", "与对手换位", Color("ffd166")],
	"freeze": ["冰冻", "对手停一轮", Color("7fe6ff")],
	"double": ["双倍", "点数 ×2", Color("ffe066")],
	"teleport": ["传送", "前进 5 格", Color("7cf0a8")],
	"moonstep": ["月影跃步", "+2 格并得护盾", Color("cfd8ff")],
	"frostlock": ["极寒锁链", "击退并冻结", Color("a8e6ff")],
	"inferno": ["熔火冲锋", "冲锋并炸退敌人", Color("ff7a3c")],
	"vortex": ["漩涡", "对手全体后退", Color("9a7bff")],
	"steal": ["窃取", "抢对手一张卡", Color("ffb84a")],
	"bomb": ["炸弹", "把对手炸回基地", Color("ff6a3c")],
	"gale": ["疾风", "+2 格并再掷一次", Color("8ff0c0")],
	"jadeguard": ["玉灵护体", "己方全体获得护盾", Color("8ff0c0")],
	"voidstep": ["虚空牵引", "随机放逐一枚敌子", Color("c8b8ff")],
}

const CHAR_NAMES := ["骑士", "法师", "弓手", "国王", "刺客", "守卫", "女武神", "机械兵"]
const BOARD_SIZES := [40, 52, 64]
## 玩法说明：与 Main.gd 的场景规则、道具、事件保持一致
const HELP_THEME_RULES := [
	"牧野微风：每次掷骰点数 +1。",
	"云梯：棋子从基地出发时直接落在第 2 格。",
	"冰面滑行：棋子停稳后再向前滑 1 格。",
	"灼热地面：停在第 3、6、9… 格（3 的倍数）会被烫退 1 格。",
	"丛林捷径：掷骰点数最低按 3 计算（掷 1、2 都算 3）。",
	"虚空裂隙：每次停稳有 20% 概率再前进 1 格。",
	"流沙陷足：每次掷骰点数 -1（最低 1 点，掷 6 算 5，但仍可出基地）。",
	"齿轮咬合：停在第 4、8、12… 格（4 的倍数）会再前进 1 格。",
]
const HELP_ITEM_DESC := {
	"boost": "本回合点数 +2。",
	"shield": "免疫一次被吃棋，护盾触发后消失。",
	"warp": "立即向前移动 3 格。",
	"snipe": "选择一名对手棋子，把它击退 3 格。",
	"swap": "选择一名对手棋子，与其交换位置。",
	"freeze": "选择一名对手，使其下一回合无法行动。",
	"double": "本回合掷骰点数 ×2。",
	"teleport": "立即向前移动 5 格。",
	"moonstep": "前进 2 格，并获得一层护盾。",
	"frostlock": "对手棋子后退 2 格，并被冻结一回合。",
	"inferno": "向前冲锋 4 格，落点附近的对手全部被炸退。",
	"vortex": "所有对手棋子后退 1 格。",
	"steal": "从道具最多的对手手中抢走一张道具卡。",
	"bomb": "选择一名对手棋子，直接炸回基地。",
	"gale": "前进 2 格，之后可以再掷一次骰子。",
	"jadeguard": "己方所有在场棋子获得一层护盾。",
	"voidstep": "随机把一名对手棋子放逐回基地。",
}
const HELP_EVENTS := [
	["秘 宝", "获得一张随机道具卡；卡槽已满时化为金币。"],
	["陨 石", "所有对手棋子后退 2 格。"],
	["顺 风", "己方触发事件的棋子前进 2 格。"],
	["陷 阱", "己方触发事件的棋子后退 3 格。"],
	["传送门", "己方棋子被传送到前方最近的安全格。"],
	["混 沌", "全场棋子随机前后移动 0～2 格。"],
	["祝 福", "己方棋子获得护盾，并额外抽一张道具卡。"],
	["星辉之赐", "己方所有在场棋子前进 1 格。"],
	["暴风雪", "所有对手棋子后退 3 格。"],
	["火山喷发", "随机 2 枚棋子被冲击波掀退 2 格。"],
	["伏 击", "落点附近的对手棋子后退 3 格（最多 3 枚）。"],
	["金 雨", "四队各抽一张道具卡（卡槽未满时）。"],
	["地 震", "全场棋子后退 1 格。"],
	["诅 咒", "己方下一回合被冻结，领先的棋子后退 2 格。"],
	["翠 蛇 缠 绕", "对手所有在场棋子后退 2 格并破盾，落点获得护盾。"],
	["虚 空 裂 隙", "全场棋子被空间乱流随机抛动：对手可能后退 3 格或前进 4 格，己方只会前进。"],
]
const BOARD_SIZE_NAMES := ["标准 · 40 格", "大型 · 52 格", "巨型 · 64 格"]
const TEAMS_ROW_H := 60.0
const CAST_TEAM_COLORS := [Color("e0503f"), Color("3d8ae0"), Color("3fb96a"), Color("e0a92f")]
const SAVE_SLOTS_MAX := 19
const DUEL_TEAM_NAMES := ["红队", "蓝队", "绿队", "黄队"]
const DUEL_GESTURES := ["石头", "剪刀", "布"]

var _root: Control
var _log_panel: PanelContainer
var _log_label: Label
var _log_button: Button
var _menu_panel: PanelContainer
var _menu_button: Button
var _menu_ring: Panel
var _menu_open := false
var _sound_on := true
var _sound_button: Button
var _music_on := true
var _music_button: Button
var _applying_prefs := false
var _theme_row: GridContainer
var _theme_btns: Array = []
var _team_chips: Array = []
var _teams_slide: Control
var _teams_open := false
var _teams_tween: Tween
var _teams_open_y := 34.0
var _turn_bar: PanelContainer
var _turn_bar_label: Label
var _turn_bar_ms := 0
var _card_buttons: Array = []
var _card_labels: Array = []
var _card_ids: Array = ["", "", "", ""]
var _card_bar: Control
var _items_panel: PanelContainer
var _items_handle: Button
var _items_tween: Tween
var _items_open := true
var _items_w := 320.0
var _items_edge := -34.0
var _pick_panel: PanelContainer
var _pick_box: VBoxContainer
var _pick_hint: Label
var _pick_visible := true
var _pick_toggle: Button
var _last_options: Array = []
var _last_hint := "选择一枚棋子"
var _roulette_overlay: Control
var _roulette_wheel: Wheel
var _roulette_title: Label
var _roulette_sub: Label
var _roulette_result: Label
var _roulette_spin_btn: Button
var _roulette_segments: Array = []
var _roulette_spinning := false
var _roulette_tween: Tween
var _board_cells := 40
var _board_buttons: Array = []
var _char_styles: Array = [0, 1, 2, 3]
var _char_buttons: Array = []
var _char_team_buttons: Array = []
var _char_team := 0
var _start_overlay: Control
var _win_overlay: Control
var _win_title: Label
var _win_stats: Label
var _event_overlay: Control
var _event_card: PanelContainer
var _event_title: Label
var _event_desc: Label
var _event_tween: Tween
var _toast: PanelContainer
var _toast_title: Label
var _toast_desc: Label
var _toast_tween: Tween
var _cast_bar: PanelContainer
var _cast_chip: ColorRect
var _cast_left: Label
var _cast_right: Label
var _cast_effect: Label
var _cast_tween: Tween
var _cast_base_top := 32.0
var _cast_base_bottom := 88.0
var _flash: ColorRect
var _gesture: Label
var _turn_text := "准备开始"
var _turn_short := "准备开始"
var _turn_color := GOLD
var _hint_override := ""
var _mode := 0
var _level := 1
var _theme_id := "dusk"
var _mode_buttons: Array = []
var _level_buttons: Array = []
var _start_theme_buttons: Array = []
var _safe := Vector4.ZERO
var _game_nodes: Array = []
var _home_overlay: Control
var _load_overlay: Control
var _saves_box: VBoxContainer
var _load_hint: Label
var _settings_overlay: Control
var _help_overlay: Control
var _help_scroll: ScrollContainer
var _s_sound_button: Button
var _s_music_button: Button
var _s_pick_button: Button
var _s_items_button: Button
var _lan_overlay: Control
var _lan_status: Label
var _lan_rooms_box: VBoxContainer
var _lan_host_info: Label
var _lan_host_btn: Button
var _lan_leave_btn: Button
var _lan_ip_edit: LineEdit
var _lan_room_edit: LineEdit
var _lan_name_edit: LineEdit
var _lan_host_box: PanelContainer
var _lan_browse: VBoxContainer
var _lan_lobby_panel: PanelContainer
var _lan_room_label: Label
var _lan_seats_box: VBoxContainer
var _lan_start_btn: Button
var _lan_ready_btn: Button
var _lan_player_name := "骑士"
var _lan_my_seat := -1
var _lan_is_host := false
var _lan_in_room := false
var _save_overlay: Control
var _save_box: VBoxContainer
var _save_hint: Label
var _save_confirm_slot := -1
var _save_confirm_until := 0
var _save_confirm_btn: Button = null
var _s_duel_button: Button = null
var _s_rules_button: Button = null
var _duel_on := false
var _rules_on := true
var _duel_overlay: Control
var _duel_title: Label
var _duel_sub: Label
var _duel_result: Label
var _duel_bar: ProgressBar
var _duel_buttons: Array = []
var _duel_token := 0
var _duel_locked := true
var _duel_pick_value := -1
var _duel_tween: Tween
## 更新检查（小对话框，不做全屏强制）
var _s_update_button: Button = null
var _update_on := true
var _update_version_label: Label = null
var _update_status_label: Label = null
var _update_overlay: Control = null
var _update_title: Label = null
var _update_body: Label = null
var _update_download_btn: Button = null
var _update_browser_btn: Button = null
var _update_retry_btn: Button = null


func _ready() -> void:
	layer = 10
	_safe = _safe_insets()

	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_build_vignette()
	_build_flash()
	_build_menu()
	_build_teams()
	_build_log()
	_build_cards()
	_build_pick()
	_build_roulette()
	_build_toast()
	_build_cast_bar()
	_build_event()
	_build_gesture()
	_build_start()
	_build_win()
	_build_duel()
	_build_home()
	_build_load()
	_build_save()
	_build_settings()
	_build_help()
	_build_lan()
	_build_update_dialog()


# ---------------------------------------------------------------- 基础样式

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
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	s.shadow_color = Color(0, 0, 0, 0.4)
	s.shadow_size = 12
	s.shadow_offset = Vector2(0, 6)
	return s


func _btn_style(bg: Color, border: Color, radius := 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.corner_radius_top_left = radius
	s.corner_radius_top_right = radius
	s.corner_radius_bottom_left = radius
	s.corner_radius_bottom_right = radius
	s.border_width_left = 1
	s.border_width_top = 1
	s.border_width_right = 1
	s.border_width_bottom = 1
	s.border_color = border
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s


func _label(text: String, size: int, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _btn(text: String, size: Vector2, font_size := 16) -> Button:
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


func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


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


func _build_vignette() -> void:
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform float strength = 0.40;
void fragment() {
	vec2 uv = UV - vec2(0.5);
	float d = length(uv * vec2(1.0, 0.82));
	float v = smoothstep(0.32, 0.95, d);
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


func _build_flash() -> void:
	_flash = ColorRect.new()
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(1, 1, 1, 0.0)
	_root.add_child(_flash)


# ---------------------------------------------------------------- 左上角控制台

func _build_menu() -> void:
	_menu_ring = Panel.new()
	_menu_ring.position = Vector2(20.0 + _safe.x, 16.0 + _safe.y)
	_menu_ring.size = Vector2(66, 66)
	_menu_ring.pivot_offset = Vector2(33, 33)
	_menu_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rs := StyleBoxFlat.new()
	rs.bg_color = Color(0, 0, 0, 0)
	rs.corner_radius_top_left = 33
	rs.corner_radius_top_right = 33
	rs.corner_radius_bottom_left = 33
	rs.corner_radius_bottom_right = 33
	rs.border_width_left = 2
	rs.border_width_top = 2
	rs.border_width_right = 2
	rs.border_width_bottom = 2
	rs.border_color = GOLD
	_menu_ring.add_theme_stylebox_override("panel", rs)
	_root.add_child(_menu_ring)
	_game_nodes.append(_menu_ring)

	var pulse := create_tween()
	pulse.set_loops()
	pulse.tween_property(_menu_ring, "scale", Vector2(1.38, 1.38), 1.5).set_trans(Tween.TRANS_SINE)
	pulse.parallel().tween_property(_menu_ring, "modulate:a", 0.0, 1.5)
	pulse.tween_property(_menu_ring, "scale", Vector2.ONE, 0.01)
	pulse.tween_property(_menu_ring, "modulate:a", 0.7, 0.01)

	_menu_button = _btn("≡", Vector2(54, 54), 26)
	_menu_button.position = Vector2(26.0 + _safe.x, 22.0 + _safe.y)
	_menu_button.add_theme_stylebox_override("normal", _btn_style(Color(0.05, 0.07, 0.11, 0.88), GOLD, 16))
	_menu_button.add_theme_stylebox_override("hover", _btn_style(Color(0.12, 0.10, 0.06, 0.95), GOLD, 16))
	_menu_button.add_theme_color_override("font_color", GOLD)
	_menu_button.pressed.connect(_toggle_menu)
	_root.add_child(_menu_button)
	_game_nodes.append(_menu_button)

	_menu_panel = PanelContainer.new()
	_menu_panel.add_theme_stylebox_override("panel", _flat(Color(0.035, 0.05, 0.085, 0.94), 18, Color(1, 1, 1, 0.12)))
	_menu_panel.position = Vector2(24.0 + _safe.x, 86.0 + _safe.y)
	_menu_panel.custom_minimum_size = Vector2(246, 0)
	_menu_panel.visible = false
	_root.add_child(_menu_panel)
	_game_nodes.append(_menu_panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 7)
	_menu_panel.add_child(vb)
	vb.add_child(_label("控 制 台", 12, Color(1, 1, 1, 0.42)))

	var close := _btn("继续对局", Vector2(0, 36), 14)
	close.pressed.connect(_toggle_menu)
	vb.add_child(close)

	var save_btn := _btn("保存进度", Vector2(0, 36), 14)
	save_btn.pressed.connect(func():
		_toggle_menu()
		save_pressed.emit())
	vb.add_child(save_btn)

	var restart := _btn("重新开始", Vector2(0, 36), 14)
	restart.pressed.connect(func():
		_toggle_menu()
		restart_pressed.emit())
	vb.add_child(restart)

	var home := _btn("返回主菜单", Vector2(0, 36), 14)
	home.pressed.connect(func():
		_toggle_menu()
		home_pressed.emit())
	vb.add_child(home)

	_sound_button = _btn("音效：开", Vector2(0, 36), 14)
	_sound_button.pressed.connect(_toggle_sound)
	vb.add_child(_sound_button)

	_music_button = _btn("主题音乐：开", Vector2(0, 36), 14)
	_music_button.pressed.connect(_toggle_music)
	vb.add_child(_music_button)

	_pick_toggle = _btn("走子列表：开", Vector2(0, 36), 14)
	_pick_toggle.pressed.connect(_toggle_pick_visible)
	vb.add_child(_pick_toggle)

	vb.add_child(_spacer(4))
	vb.add_child(_label("棋盘主题", 12, Color(1, 1, 1, 0.42)))
	_theme_row = GridContainer.new()
	_theme_row.columns = 4
	_theme_row.add_theme_constant_override("h_separation", 5)
	_theme_row.add_theme_constant_override("v_separation", 5)
	vb.add_child(_theme_row)
	for i in THEME_IDS.size():
		var b := _btn(THEME_SHORT[i], Vector2(0, 32), 13)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tid: String = THEME_IDS[i]
		b.pressed.connect(func(): _pick_theme(tid))
		_theme_row.add_child(b)
		_theme_btns.append(b)
	_paint_theme_btns()


func _toggle_menu() -> void:
	_menu_open = not _menu_open
	_menu_panel.visible = _menu_open
	_menu_button.text = "✕" if _menu_open else "≡"


func _toggle_sound() -> void:
	set_sound(not _sound_on)
	sound_toggled.emit(_sound_on)
	if not _applying_prefs:
		prefs_changed.emit()


func _toggle_music() -> void:
	set_music(not _music_on)
	music_toggled.emit(_music_on)
	if not _applying_prefs:
		prefs_changed.emit()


func _toggle_pick_visible() -> void:
	_pick_visible = not _pick_visible
	_pick_toggle.text = "走子列表：开" if _pick_visible else "走子列表：关"
	if _s_pick_button != null:
		_s_pick_button.text = _pick_toggle.text
	if not _pick_visible:
		_pick_panel.visible = false
	elif not _last_options.is_empty():
		_pick_panel.visible = true
	if not _applying_prefs:
		prefs_changed.emit()


func _toggle_duel() -> void:
	_duel_on = not _duel_on
	_paint_duel_button()
	duel_toggled.emit(_duel_on)
	if not _applying_prefs:
		prefs_changed.emit()


func _paint_duel_button() -> void:
	if _s_duel_button != null:
		_s_duel_button.text = "吃棋对决：开" if _duel_on else "吃棋对决：关"


func _toggle_rules() -> void:
	_rules_on = not _rules_on
	_paint_rules_button()
	rules_toggled.emit(_rules_on)
	if not _applying_prefs:
		prefs_changed.emit()


func _paint_rules_button() -> void:
	if _s_rules_button != null:
		_s_rules_button.text = "场景规则：开" if _rules_on else "场景规则：关"


func _pick_theme(id: String) -> void:
	_theme_id = id
	_paint_theme_btns()
	theme_selected.emit(id)
	if not _applying_prefs:
		prefs_changed.emit()


func _paint_theme_btns() -> void:
	for i in _theme_btns.size():
		var b: Button = _theme_btns[i]
		if THEME_IDS[i] == _theme_id:
			b.add_theme_stylebox_override("normal", _btn_style(Color(0.55, 0.42, 0.22, 0.7), GOLD))
			b.add_theme_color_override("font_color", Color("ffe6b8"))
		else:
			b.add_theme_stylebox_override("normal", _btn_style(Color(1, 1, 1, 0.06), Color(1, 1, 1, 0.1)))
			b.add_theme_color_override("font_color", TEXT)


# ---------------------------------------------------------------- 顶部记分牌

## 记分牌默认向上贴边收起，只露出「当前回合」细条；点细条展开 / 收起
func _build_teams() -> void:
	_teams_open_y = 34.0 + _safe.y

	_turn_bar = PanelContainer.new()
	_turn_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_turn_bar.offset_left = -96.0
	_turn_bar.offset_right = 96.0
	_turn_bar.offset_top = 0.0 + _safe.y
	_turn_bar.offset_bottom = 28.0 + _safe.y
	_turn_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_turn_bar.gui_input.connect(_on_turn_bar_input)
	_root.add_child(_turn_bar)
	_game_nodes.append(_turn_bar)

	_turn_bar_label = _label("准备开始  ▾", 13, GOLD)
	_turn_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_turn_bar_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_turn_bar.add_child(_turn_bar_label)

	_teams_slide = Control.new()
	_teams_slide.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_teams_slide.offset_left = -280.0
	_teams_slide.offset_right = 280.0
	_teams_slide.offset_top = _teams_open_y
	_teams_slide.offset_bottom = _teams_open_y + TEAMS_ROW_H
	_teams_slide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_teams_slide)
	_game_nodes.append(_teams_slide)

	var holder := HBoxContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.alignment = BoxContainer.ALIGNMENT_CENTER
	holder.add_theme_constant_override("separation", 8)
	_teams_slide.add_child(holder)

	for t in 4:
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", _flat(Color(0.035, 0.05, 0.085, 0.7), 14))
		chip.custom_minimum_size = Vector2(126, 0)
		holder.add_child(chip)
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 1)
		chip.add_child(vb)
		var name_l := _label("队伍", 15, TEXT)
		vb.add_child(name_l)
		var info_l := _label("0/4", 11, DIM)
		vb.add_child(info_l)
		_team_chips.append({"panel": chip, "name": name_l, "info": info_l})

	_set_teams_open(false, false)
	_paint_turn_bar()


func _set_teams_open(open: bool, animate := true) -> void:
	_teams_open = open
	_paint_turn_bar()
	if _teams_slide == null:
		return
	var target_y := _teams_open_y if open else -TEAMS_ROW_H - 4.0
	if _teams_tween and _teams_tween.is_valid():
		_teams_tween.kill()
	if not animate:
		_teams_slide.offset_top = target_y
		_teams_slide.offset_bottom = target_y + TEAMS_ROW_H
		return
	_teams_tween = create_tween()
	_teams_tween.set_parallel(true)
	_teams_tween.tween_property(_teams_slide, "offset_top", target_y, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_teams_tween.tween_property(_teams_slide, "offset_bottom", target_y + TEAMS_ROW_H, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _on_turn_bar_input(event: InputEvent) -> void:
	var pressed := false
	if event is InputEventScreenTouch:
		pressed = (event as InputEventScreenTouch).pressed
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		pressed = mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	if not pressed:
		return
	# 触摸与鼠标模拟事件可能重复触发，做一次节流
	var now := Time.get_ticks_msec()
	if now - _turn_bar_ms < 250:
		return
	_turn_bar_ms = now
	_set_teams_open(not _teams_open)


func _paint_turn_bar() -> void:
	if _turn_bar == null or _turn_bar_label == null:
		return
	var arrow := "▴" if _teams_open else "▾"
	_turn_bar_label.text = "%s  %s" % [_turn_short, arrow]
	_turn_bar_label.add_theme_color_override("font_color", _turn_color)
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.035, 0.05, 0.085, 0.88)
	s.corner_radius_top_left = 0
	s.corner_radius_top_right = 0
	s.corner_radius_bottom_left = 12
	s.corner_radius_bottom_right = 12
	s.border_width_left = 1
	s.border_width_top = 0
	s.border_width_right = 1
	s.border_width_bottom = 1
	s.border_color = Color(_turn_color.r, _turn_color.g, _turn_color.b, 0.45)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 2
	s.content_margin_bottom = 2
	_turn_bar.add_theme_stylebox_override("panel", s)


# ---------------------------------------------------------------- 右上角战报

func _build_log() -> void:
	_log_button = _btn("战 报 ▾", Vector2(104, 38), 13)
	_log_button.anchor_left = 1.0
	_log_button.anchor_right = 1.0
	_log_button.offset_left = -126.0 - _safe.z
	_log_button.offset_right = -22.0 - _safe.z
	_log_button.offset_top = 22.0 + _safe.y
	_log_button.offset_bottom = 60.0 + _safe.y
	_log_button.pressed.connect(_toggle_log)
	_root.add_child(_log_button)
	_game_nodes.append(_log_button)

	_log_panel = PanelContainer.new()
	_log_panel.add_theme_stylebox_override("panel", _flat(Color(0.03, 0.045, 0.075, 0.9), 16, Color(1, 1, 1, 0.08)))
	_log_panel.anchor_left = 1.0
	_log_panel.anchor_right = 1.0
	_log_panel.offset_left = -352.0 - _safe.z
	_log_panel.offset_right = -22.0 - _safe.z
	_log_panel.offset_top = 68.0 + _safe.y
	_log_panel.offset_bottom = 250.0 + _safe.y
	_log_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_log_panel.visible = false
	_root.add_child(_log_panel)
	_game_nodes.append(_log_panel)

	_log_label = _label("", 13, Color(0.85, 0.9, 1.0, 0.88))
	_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_label.custom_minimum_size = Vector2(296, 0)
	_log_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_log_panel.add_child(_log_label)


func _toggle_log() -> void:
	_log_panel.visible = not _log_panel.visible
	_log_button.text = "战 报 ▴" if _log_panel.visible else "战 报 ▾"


# ---------------------------------------------------------------- 右下角道具抽屉

## 道具栏做成贴右边缘的抽屉：默认展开，点把手向右收起，再点滑出
func _build_cards() -> void:
	_items_panel = PanelContainer.new()
	_items_panel.anchor_left = 1.0
	_items_panel.anchor_top = 1.0
	_items_panel.anchor_right = 1.0
	_items_panel.anchor_bottom = 1.0
	_items_panel.offset_left = _items_edge - _items_w - _safe.z
	_items_panel.offset_right = _items_edge - _safe.z
	_items_panel.offset_top = -108.0 - _safe.w
	_items_panel.offset_bottom = -16.0 - _safe.w
	# 只圆左侧两角：右侧贴着屏幕边缘，像从边上推出来的抽屉
	var ps := _flat(Color(0.035, 0.05, 0.085, 0.9), 18, Color(1, 1, 1, 0.1), 1)
	ps.corner_radius_top_right = 4
	ps.corner_radius_bottom_right = 4
	ps.content_margin_left = 12
	ps.content_margin_right = 12
	ps.content_margin_top = 7
	ps.content_margin_bottom = 7
	_items_panel.add_theme_stylebox_override("panel", ps)
	_root.add_child(_items_panel)
	_game_nodes.append(_items_panel)

	_card_bar = VBoxContainer.new()
	_card_bar.add_theme_constant_override("separation", 4)
	_card_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_items_panel.add_child(_card_bar)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	_card_bar.add_child(head)
	var cap := _label("道 具", 11, Color(1, 1, 1, 0.5))
	cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(cap)
	var tip := _label("点卡使用", 10, Color(1, 1, 1, 0.3))
	head.add_child(tip)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_END
	_card_bar.add_child(row)

	for i in 4:
		var b := Button.new()
		b.custom_minimum_size = Vector2(78, 52)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_stylebox_override("normal", _btn_style(Color(1, 1, 1, 0.05), Color(1, 1, 1, 0.09), 14))
		b.add_theme_stylebox_override("hover", _btn_style(Color(1, 1, 1, 0.14), GOLD, 14))
		b.add_theme_stylebox_override("pressed", _btn_style(Color(1, 1, 1, 0.2), GOLD, 14))
		b.add_theme_stylebox_override("disabled", _btn_style(Color(1, 1, 1, 0.02), Color(1, 1, 1, 0.04), 14))
		b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.22))
		var idx := i
		b.pressed.connect(func(): card_pressed.emit(idx))
		row.add_child(b)

		var vb := VBoxContainer.new()
		vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_theme_constant_override("separation", 0)
		b.add_child(vb)
		var t1 := _label("空", 13, Color(1, 1, 1, 0.28))
		t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t1.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(t1)
		var t2 := _label("", 9, Color(1, 1, 1, 0.42))
		t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(t2)
		_card_buttons.append(b)
		_card_labels.append([t1, t2])

	# 抽屉把手：始终贴在右边缘，在抽屉之上
	_items_handle = Button.new()
	_items_handle.anchor_left = 1.0
	_items_handle.anchor_right = 1.0
	_items_handle.anchor_top = 0.5
	_items_handle.anchor_bottom = 0.5
	_items_handle.offset_left = -30.0 - _safe.z
	_items_handle.offset_right = -5.0 - _safe.z
	_items_handle.offset_top = -56.0
	_items_handle.offset_bottom = 56.0
	_items_handle.focus_mode = Control.FOCUS_NONE
	_items_handle.add_theme_font_size_override("font_size", 12)
	var hs := _btn_style(Color(0.05, 0.072, 0.115, 0.92), Color(GOLD.r, GOLD.g, GOLD.b, 0.55), 9)
	hs.corner_radius_top_right = 0
	hs.corner_radius_bottom_right = 0
	hs.content_margin_left = 2
	hs.content_margin_right = 2
	_items_handle.add_theme_stylebox_override("normal", hs)
	_items_handle.add_theme_stylebox_override("hover", _btn_style(Color(0.1, 0.085, 0.05, 0.95), GOLD, 9))
	_items_handle.add_theme_stylebox_override("pressed", _btn_style(Color(0.14, 0.11, 0.06, 0.98), GOLD, 9))
	_items_handle.add_theme_color_override("font_color", Color("ffe6b8"))
	_items_handle.pressed.connect(_toggle_items)
	_root.add_child(_items_handle)
	_game_nodes.append(_items_handle)

	_apply_items_position(false)


func _items_open_offset() -> Vector2:
	return Vector2(_items_edge - _items_w - _safe.z, _items_edge - _safe.z)


func _apply_items_position(animate: bool) -> void:
	if _items_panel == null:
		return
	var o := _items_open_offset()
	var target_left := o.x
	var target_right := o.y
	if not _items_open:
		# 收起：整体推到屏幕右侧外面，只在右边留一个把手
		target_left = 10.0 - _safe.z
		target_right = 10.0 - _safe.z + _items_w
	if _items_tween and _items_tween.is_valid():
		_items_tween.kill()
	if animate:
		_items_tween = create_tween()
		_items_tween.set_parallel(true)
		_items_tween.tween_property(_items_panel, "offset_left", target_left, 0.26) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_items_tween.tween_property(_items_panel, "offset_right", target_right, 0.26) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		_items_panel.offset_left = target_left
		_items_panel.offset_right = target_right
	if _items_handle:
		_items_handle.text = ("▶" if _items_open else "◀") + "\n道\n具"


func _toggle_items() -> void:
	set_items_open(not _items_open)


func set_items_open(open: bool, animate := true) -> void:
	_items_open = open
	_apply_items_position(animate)
	if _s_items_button != null:
		_s_items_button.text = "道具面板：开" if open else "道具面板：关"
	if not _applying_prefs:
		prefs_changed.emit()


# ---------------------------------------------------------------- 选择面板

func _build_pick() -> void:
	_pick_panel = PanelContainer.new()
	_pick_panel.add_theme_stylebox_override("panel", _flat(Color(0.035, 0.05, 0.085, 0.92), 16, GOLD, 2))
	_pick_panel.anchor_left = 0.0
	_pick_panel.anchor_top = 1.0
	_pick_panel.anchor_bottom = 1.0
	_pick_panel.offset_left = 18.0 + _safe.x
	_pick_panel.offset_right = 250.0 + _safe.x
	_pick_panel.offset_top = -206.0
	_pick_panel.offset_bottom = -46.0
	_pick_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_pick_panel.custom_minimum_size = Vector2(232, 0)
	_pick_panel.visible = false
	_root.add_child(_pick_panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	_pick_panel.add_child(vb)
	_pick_hint = _label("选择一枚棋子", 12, Color(1, 1, 1, 0.6))
	_pick_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_pick_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pick_hint.custom_minimum_size = Vector2(204, 0)
	vb.add_child(_pick_hint)
	_pick_box = VBoxContainer.new()
	_pick_box.add_theme_constant_override("separation", 6)
	_pick_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	vb.add_child(_pick_box)


# ---------------------------------------------------------------- 俄罗斯轮盘

func _build_roulette() -> void:
	_roulette_overlay = Control.new()
	_roulette_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_roulette_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_roulette_overlay.visible = false
	_root.add_child(_roulette_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.012, 0.025, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_roulette_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_roulette_overlay.add_child(center)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _flat(Color(0.035, 0.045, 0.08, 0.98), 26, GOLD, 3))
	card.custom_minimum_size = Vector2(460, 0)
	center.add_child(card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	card.add_child(vb)

	_roulette_title = _label("俄 罗 斯 轮 盘", 30, GOLD)
	_roulette_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_roulette_title)
	_roulette_sub = _label("命运之轮 · 掷出你的运气", 12, Color(1, 1, 1, 0.45))
	_roulette_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_roulette_sub)

	var wheel_holder := Control.new()
	wheel_holder.custom_minimum_size = Vector2(360, 360)
	wheel_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	wheel_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(wheel_holder)

	_roulette_wheel = Wheel.new()
	_roulette_wheel.position = Vector2(10, 10)
	_roulette_wheel.size = Vector2(340, 340)
	_roulette_wheel.pivot_offset = Vector2(170, 170)
	_roulette_wheel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wheel_holder.add_child(_roulette_wheel)

	var pointer := _label("▼", 30, Color("ffe0a0"))
	pointer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pointer.custom_minimum_size = Vector2(360, 0)
	pointer.position = Vector2(0, -10)
	pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wheel_holder.add_child(pointer)

	_roulette_result = _label("踩中道具格 / 事件格，转动命运之轮", 15, Color(0.9, 0.94, 1.0, 0.85))
	_roulette_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_roulette_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_roulette_result)

	_roulette_spin_btn = _btn("开 始 旋 转", Vector2(0, 52), 20)
	_roulette_spin_btn.add_theme_stylebox_override("normal", _btn_style(Color("c99a4e"), Color("f0cd8a"), 14))
	_roulette_spin_btn.add_theme_stylebox_override("hover", _btn_style(Color("e0b060"), Color("ffe0a0"), 14))
	_roulette_spin_btn.add_theme_stylebox_override("pressed", _btn_style(Color("b5863f"), Color("ffe0a0"), 14))
	_roulette_spin_btn.add_theme_color_override("font_color", Color("1a1206"))
	_roulette_spin_btn.pressed.connect(_spin_roulette)
	vb.add_child(_roulette_spin_btn)

	var hint := _label("轮盘是强制抽取：转到什么就拿什么", 11, Color(1, 1, 1, 0.38))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(hint)


## 显示轮盘：kind = "item"（道具轮盘） / "event"（事件轮盘）
func show_roulette(segments: Array, kind := "item") -> void:
	_roulette_segments = segments
	_roulette_spinning = false
	if kind == "event":
		_roulette_title.text = "命 运 事 件 轮 盘"
		_roulette_sub.text = "全屏事件 · 转到什么就发生什么"
	else:
		_roulette_title.text = "道 具 轮 盘"
		_roulette_sub.text = "随机道具 · 转到什么就拿到什么"
	_roulette_result.text = "点击下方按钮转动命运之轮"
	_roulette_result.add_theme_color_override("font_color", Color(0.9, 0.94, 1.0, 0.85))
	_roulette_spin_btn.disabled = false
	_roulette_wheel.labels.clear()
	_roulette_wheel.colors.clear()
	for s in segments:
		_roulette_wheel.labels.append(String(s.get("label", "?")))
		_roulette_wheel.colors.append(s.get("color", Color.WHITE))
	_roulette_wheel.rotation = 0.0
	_roulette_wheel.queue_redraw()
	_roulette_overlay.visible = true
	_roulette_overlay.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_roulette_overlay, "modulate:a", 1.0, 0.18)
	_roulette_wheel.scale = Vector2(0.82, 0.82)
	var pop := create_tween()
	pop.tween_property(_roulette_wheel, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 外部（AI 回合 / 自动演示）调用；force 用于客机复现房主的结果
func spin_roulette(force := -1) -> void:
	_spin_roulette(force)


## 客机：等待房主点击，禁用本地按钮，避免各转各的
func lock_roulette() -> void:
	_roulette_spin_btn.disabled = true
	_roulette_result.text = "等待房主转动轮盘…"


func hide_roulette() -> void:
	var was_spinning := _roulette_spinning
	_roulette_spinning = false
	if _roulette_tween and _roulette_tween.is_valid():
		_roulette_tween.kill()
	_roulette_overlay.visible = false
	# 若在旋转途中被关闭（例如重开对局），通知等待方结束本次抽取，避免协程永久挂起
	if was_spinning:
		roulette_done.emit(-1)


func _spin_roulette(force := -1) -> void:
	if _roulette_spinning or _roulette_segments.is_empty():
		return
	_roulette_spinning = true
	_roulette_spin_btn.disabled = true
	_roulette_result.text = "命运之轮转动中…"
	_roulette_result.add_theme_color_override("font_color", GOLD)
	var n := _roulette_segments.size()
	var seg := TAU / float(n)
	var idx := randi() % n
	if force >= 0:
		idx = clampi(force, 0, n - 1)
	var jitter := randf_range(-seg * 0.3, seg * 0.3)
	var target: float = -(float(idx) * seg + seg * 0.5) + jitter
	while target < _roulette_wheel.rotation + TAU * 4.0:
		target += TAU
	var ticks := create_tween()
	for k in 22:
		ticks.tween_callback(func(): roulette_tick.emit())
		ticks.tween_interval(0.055 + 0.008 * float(k))
	_roulette_tween = create_tween()
	_roulette_tween.tween_property(_roulette_wheel, "rotation", target, 2.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_roulette_tween.tween_callback(func(): _roulette_reveal(idx))


func _roulette_reveal(idx: int) -> void:
	_roulette_spinning = false
	if idx < 0 or idx >= _roulette_segments.size():
		hide_roulette()
		return
	var s: Dictionary = _roulette_segments[idx]
	var col: Color = s.get("color", GOLD)
	_roulette_result.text = "▶  %s  ◀" % s.get("label", "?")
	_roulette_result.add_theme_color_override("font_color", col.lightened(0.2))
	var pop := create_tween()
	_roulette_result.scale = Vector2(1.3, 1.3)
	pop.tween_property(_roulette_result, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(0.8).timeout
	roulette_done.emit(idx)


# ---------------------------------------------------------------- 播报 / 事件

func _build_toast() -> void:
	var holder := CenterContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	holder.offset_top = 86.0 + _safe.y
	holder.offset_bottom = 190.0 + _safe.y
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(holder)

	_toast = PanelContainer.new()
	_toast.add_theme_stylebox_override("panel", _flat(Color(0.04, 0.055, 0.095, 0.94), 20, GOLD, 3))
	_toast.custom_minimum_size = Vector2(420, 0)
	_toast.modulate.a = 0.0
	holder.add_child(_toast)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	_toast.add_child(vb)
	_toast_title = _label("道具", 30, GOLD)
	_toast_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_toast_title)
	_toast_desc = _label("", 14, Color(0.9, 0.94, 1.0, 0.85))
	_toast_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_toast_desc)


## 道具施放条：顶部居中、队伍状态栏下方，左侧队伍色块 + 施法者，右侧目标，第二行结果
func _build_cast_bar() -> void:
	_cast_base_top = 32.0 + _safe.y
	_cast_base_bottom = _cast_base_top + 56.0
	_cast_bar = PanelContainer.new()
	_cast_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_cast_bar.offset_left = -300.0
	_cast_bar.offset_right = 300.0
	_cast_bar.offset_top = _cast_base_top
	_cast_bar.offset_bottom = _cast_base_bottom
	_cast_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cast_bar.modulate.a = 0.0
	_cast_bar.add_theme_stylebox_override("panel", _flat(Color(0.04, 0.055, 0.095, 0.92), 14, GOLD, 2))
	_root.add_child(_cast_bar)
	_game_nodes.append(_cast_bar)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 1)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cast_bar.add_child(vb)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(hb)

	_cast_chip = ColorRect.new()
	_cast_chip.custom_minimum_size = Vector2(6, 28)
	_cast_chip.color = CAST_TEAM_COLORS[0]
	_cast_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(_cast_chip)

	_cast_left = _label("", 16, Color(1, 1, 1, 0.96))
	_cast_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(_cast_left)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(spacer)

	_cast_right = _label("", 14, Color(0.86, 0.92, 1.0, 0.92))
	_cast_right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_cast_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(_cast_right)

	_cast_effect = _label("", 13, GOLD)
	_cast_effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(_cast_effect)


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
	_event_card.custom_minimum_size = Vector2(540, 0)
	center.add_child(_event_card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	_event_card.add_child(vb)
	_event_title = _label("随机事件", 32, GOLD)
	_event_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_event_title)
	_event_desc = _label("", 16, Color(0.9, 0.94, 1.0, 0.9))
	_event_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_event_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_event_desc)


func _build_gesture() -> void:
	_gesture = _label("单指拖动旋转视角 · 双指捏合缩放 · 双指拖动平移棋盘 · 点击骰子投掷", 12, Color(1, 1, 1, 0.42))
	_gesture.position = Vector2(26.0 + _safe.x, 0.0)
	_gesture.anchor_top = 1.0
	_gesture.anchor_bottom = 1.0
	_gesture.offset_top = -46.0 - _safe.w
	_gesture.offset_bottom = -28.0 - _safe.w
	_root.add_child(_gesture)
	_game_nodes.append(_gesture)
	var tw := create_tween()
	tw.tween_interval(6.0)
	tw.tween_property(_gesture, "modulate:a", 0.0, 1.2)


# ---------------------------------------------------------------- 吃棋对决

func _build_duel() -> void:
	_duel_overlay = Control.new()
	_duel_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_duel_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_duel_overlay.visible = false
	_root.add_child(_duel_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.015, 0.03, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_duel_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_duel_overlay.add_child(center)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _flat(Color(0.04, 0.055, 0.095, 0.97), 24, GOLD, 3))
	card.custom_minimum_size = Vector2(560, 0)
	center.add_child(card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	card.add_child(vb)

	_duel_title = _label("吃 棋 对 决", 32, GOLD)
	_duel_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_duel_title)

	_duel_sub = _label("红队 → 蓝队 1号", 16, TEXT)
	_duel_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_duel_sub)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(row)
	for i in DUEL_GESTURES.size():
		var b := _btn(DUEL_GESTURES[i], Vector2(150, 104), 24)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var pick := i
		b.pressed.connect(func(): _choose_duel(pick))
		row.add_child(b)
		_duel_buttons.append(b)

	_duel_result = _label("选择你的出拳", 15, Color(1, 1, 1, 0.85))
	_duel_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_duel_result)

	_duel_bar = ProgressBar.new()
	_duel_bar.min_value = 0.0
	_duel_bar.max_value = 1.0
	_duel_bar.value = 1.0
	_duel_bar.show_percentage = false
	_duel_bar.custom_minimum_size = Vector2(0, 8)
	_duel_bar.add_theme_stylebox_override("background", _flat(Color(1, 1, 1, 0.08), 4))
	_duel_bar.add_theme_stylebox_override("fill", _flat(Color("f0cd8a"), 4))
	vb.add_child(_duel_bar)


## 弹出对决面板：attacker/target_team 为队伍下标，target_idx 为 0 基棋子序号
func show_duel(attacker: int, target_team: int, target_idx: int, seconds: float) -> void:
	_duel_token += 1
	var token := _duel_token
	_duel_locked = false
	_duel_pick_value = -1
	for b in _duel_buttons:
		b.disabled = false
	_duel_result.text = "选择你的出拳"
	_duel_result.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	_duel_sub.text = "%s → %s %s号" % [
		DUEL_TEAM_NAMES[clampi(attacker, 0, 3)],
		DUEL_TEAM_NAMES[clampi(target_team, 0, 3)],
		str(clampi(target_idx, 0, 3) + 1)]
	_duel_overlay.visible = true
	if _duel_tween and _duel_tween.is_valid():
		_duel_tween.kill()
	_duel_bar.value = 1.0
	_duel_tween = create_tween()
	_duel_tween.tween_property(_duel_bar, "value", 0.0, maxf(seconds, 1.0))
	_duel_tween.tween_callback(func():
		if token == _duel_token and not _duel_locked:
			_commit_duel(randi() % DUEL_GESTURES.size()))


func hide_duel() -> void:
	_duel_token += 1
	_duel_locked = true
	if _duel_tween and _duel_tween.is_valid():
		_duel_tween.kill()
	_duel_overlay.visible = false


## 展示双方出拳结果，0.8 秒后自动收起
func duel_result(atk_pick: int, def_pick: int, win: bool) -> void:
	if not _duel_overlay.visible:
		return
	_duel_token += 1
	var token := _duel_token
	_duel_locked = true
	for b in _duel_buttons:
		b.disabled = true
	if _duel_tween and _duel_tween.is_valid():
		_duel_tween.kill()
	_duel_result.text = "你出 %s · 对方出 %s · %s" % [
		DUEL_GESTURES[clampi(atk_pick, 0, 2)],
		DUEL_GESTURES[clampi(def_pick, 0, 2)],
		"胜利" if win else "失败"]
	_duel_result.add_theme_color_override("font_color", Color("8ff0c0") if win else Color("ff8f8f"))
	await get_tree().create_timer(0.8).timeout
	if token == _duel_token:
		hide_duel()


func _choose_duel(pick: int) -> void:
	if _duel_locked or not _duel_overlay.visible:
		return
	_commit_duel(pick)


func _commit_duel(pick: int) -> void:
	if _duel_locked or not _duel_overlay.visible:
		return
	_duel_locked = true
	_duel_pick_value = clampi(pick, 0, 2)
	for b in _duel_buttons:
		b.disabled = true
	if _duel_tween and _duel_tween.is_valid():
		_duel_tween.kill()
	_duel_result.text = "你出 %s · 等待对方…" % DUEL_GESTURES[_duel_pick_value]
	_duel_result.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	var token := _duel_token
	duel_chosen.emit(_duel_pick_value)
	# 兜底：调用方没有调用 duel_result 时，0.8 秒后自动收起（局域网客机场景）
	await get_tree().create_timer(0.8).timeout
	if token == _duel_token and _duel_overlay.visible:
		hide_duel()


# ---------------------------------------------------------------- 开始 / 结算

func _build_start() -> void:
	_start_overlay = Control.new()
	_start_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_start_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_start_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.015, 0.03, 0.80)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_start_overlay.add_child(dim)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 12
	scroll.offset_right = -12
	scroll.offset_top = 64
	scroll.offset_bottom = -12
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_start_overlay.add_child(scroll)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _flat(Color(0.04, 0.055, 0.095, 0.96), 24, Color(1, 1, 1, 0.1)))
	card.custom_minimum_size = Vector2(660, 0)
	center.add_child(card)

	var back := _btn("‹ 返回", Vector2(104, 40), 15)
	back.position = Vector2(24.0 + _safe.x, 14.0 + _safe.y)
	back.pressed.connect(show_home)
	_start_overlay.add_child(back)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	card.add_child(vb)

	var ttl := _label("创建对局", 38, GOLD)
	ttl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(ttl)
	var sub := _label("骑士飞行棋 3 · 对局设置", 12, Color(1, 1, 1, 0.45))
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

	vb.add_child(_label("棋盘场景（8 个独立场景 · 地形与光照各不相同）", 13, DIM))
	var theme_row := GridContainer.new()
	theme_row.columns = 4
	theme_row.add_theme_constant_override("h_separation", 8)
	theme_row.add_theme_constant_override("v_separation", 8)
	vb.add_child(theme_row)
	for i in THEME_IDS.size():
		var b3 := _btn(THEME_NAMES[i], Vector2(0, 38), 12)
		b3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tid: String = THEME_IDS[i]
		b3.pressed.connect(func(): _select_theme(tid))
		theme_row.add_child(b3)
		_start_theme_buttons.append(b3)

	vb.add_child(_label("棋盘大小（大棋盘可用双指拖动平移）", 13, DIM))
	var size_row := HBoxContainer.new()
	size_row.add_theme_constant_override("separation", 10)
	vb.add_child(size_row)
	for i in BOARD_SIZES.size():
		var bs := _btn(BOARD_SIZE_NAMES[i], Vector2(0, 40), 14)
		bs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var bi := i
		bs.pressed.connect(func(): _select_board_size(bi))
		size_row.add_child(bs)
		_board_buttons.append(bs)

	vb.add_child(_label("棋子角色（先选队伍，再点角色）", 13, DIM))
	var team_row := HBoxContainer.new()
	team_row.add_theme_constant_override("separation", 8)
	vb.add_child(team_row)
	for t in 4:
		var tb := _btn(["红队", "蓝队", "绿队", "黄队"][t], Vector2(0, 34), 13)
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var ti := t
		tb.pressed.connect(func(): _select_char_team(ti))
		team_row.add_child(tb)
		_char_team_buttons.append(tb)

	var char_grid := GridContainer.new()
	char_grid.columns = 4
	char_grid.add_theme_constant_override("h_separation", 8)
	char_grid.add_theme_constant_override("v_separation", 6)
	vb.add_child(char_grid)
	for i in 8:
		var cb := _btn(CHAR_NAMES[i], Vector2(0, 38), 14)
		cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var ci := i
		cb.pressed.connect(func(): _select_char(ci))
		char_grid.add_child(cb)
		_char_buttons.append(cb)

	vb.add_child(_spacer(6))
	var go := _btn("开 始 对 局", Vector2(0, 58), 24)
	go.add_theme_stylebox_override("normal", _btn_style(Color("c99a4e"), Color("f0cd8a"), 14))
	go.add_theme_stylebox_override("hover", _btn_style(Color("e0b060"), Color("ffe0a0"), 14))
	go.add_theme_stylebox_override("pressed", _btn_style(Color("b5863f"), Color("ffe0a0"), 14))
	go.add_theme_color_override("font_color", Color("1a1206"))
	go.pressed.connect(_start_clicked)
	vb.add_child(go)

	var hint := _label("17 种道具 · 16 种随机事件 · 踩格触发轮盘 · 随机掉落", 12, Color(1, 1, 1, 0.45))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(hint)
	var hint2 := _label("单指拖动旋转 · 双指捏合缩放 / 平移 · 点击骰子投掷 · 点棋子走子", 11, Color(1, 1, 1, 0.32))
	hint2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(hint2)

	_select_mode(0)
	_select_level(1)
	_select_theme("dusk")
	_select_board_size(1)
	_select_char_team(0)


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
	card.custom_minimum_size = Vector2(500, 0)
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
	again.add_theme_stylebox_override("normal", _btn_style(Color("c99a4e"), Color("f0cd8a"), 14))
	again.add_theme_stylebox_override("hover", _btn_style(Color("e0b060"), Color("ffe0a0"), 14))
	again.add_theme_stylebox_override("pressed", _btn_style(Color("b5863f"), Color("ffe0a0"), 14))
	again.add_theme_color_override("font_color", Color("1a1206"))
	again.pressed.connect(func(): restart_pressed.emit())
	vb.add_child(again)
	var home := _btn("返 回 主 菜 单", Vector2(0, 46), 17)
	home.pressed.connect(func(): home_pressed.emit())
	vb.add_child(home)


# ---------------------------------------------------------------- 启动画面 / 载入 / 设置 / 联机

func _page_base(alpha := 0.94) -> Array:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	_root.add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.015, 0.03, alpha)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	return [overlay, center]


func _page_card(center: CenterContainer, width: float) -> VBoxContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _flat(Color(0.04, 0.055, 0.095, 0.97), 24, Color(1, 1, 1, 0.1)))
	card.custom_minimum_size = Vector2(width, 0)
	center.add_child(card)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	card.add_child(vb)
	return vb


func _page_head(vb: VBoxContainer, title: String, right_text := "", back_action := Callable()) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	vb.add_child(row)
	var back := _btn("‹ 返回", Vector2(104, 40), 15)
	back.pressed.connect(back_action if back_action.is_valid() else show_home)
	row.add_child(back)
	var ttl := _label(title, 26, GOLD)
	ttl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ttl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(ttl)
	var tail := _label(right_text, 12, Color(1, 1, 1, 0.45))
	tail.custom_minimum_size = Vector2(104, 0)
	tail.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tail.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(tail)
	return tail


func _build_home() -> void:
	var pair := _page_base(0.72)
	_home_overlay = pair[0]
	var center: CenterContainer = pair[1]
	var vb := _page_card(center, 560)

	var ttl := _label("骑士飞行棋 3", 46, GOLD)
	ttl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(ttl)
	var sub := _label("KNIGHT'S GAMBIT · 局域网对战版", 12, Color(1, 1, 1, 0.45))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)
	vb.add_child(_spacer(18))

	var entries := [
		["创 建 对 局", true, func(): home_create.emit()],
		["载 入 游 戏", false, func(): home_load.emit()],
		["局 域 网 对 战", false, func(): home_lan.emit()],
		["设 置", false, func(): home_settings.emit()],
	]
	for e in entries:
		var b := _btn(e[0], Vector2(0, 62), 22)
		if bool(e[1]):
			b.add_theme_stylebox_override("normal", _btn_style(Color("c99a4e"), Color("f0cd8a"), 14))
			b.add_theme_stylebox_override("hover", _btn_style(Color("e0b060"), Color("ffe0a0"), 14))
			b.add_theme_stylebox_override("pressed", _btn_style(Color("b5863f"), Color("ffe0a0"), 14))
			b.add_theme_color_override("font_color", Color("1a1206"))
		b.pressed.connect(e[2])
		vb.add_child(b)

	vb.add_child(_spacer(10))
	var foot := _label("存档上限 20 个 · 每回合自动存档 · 同一 Wi-Fi 下可局域网联机", 11, Color(1, 1, 1, 0.35))
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(foot)

	_home_overlay.visible = true
	for n in _game_nodes:
		if is_instance_valid(n):
			n.visible = false


func _build_load() -> void:
	var pair := _page_base()
	_load_overlay = pair[0]
	var center: CenterContainer = pair[1]
	var vb := _page_card(center, 780)
	_load_hint = _page_head(vb, "载 入 游 戏")

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 400)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	_saves_box = VBoxContainer.new()
	_saves_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_saves_box.add_theme_constant_override("separation", 8)
	scroll.add_child(_saves_box)

	var tip := _label("自动存档每回合覆盖一次；手动存档在游戏中打开左上角控制台点击「保存进度」。", 12, Color(1, 1, 1, 0.4))
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(tip)


## 存档槽选择页：只列 1..19 号手动槽，0 号自动槽不出现
func _build_save() -> void:
	var pair := _page_base()
	_save_overlay = pair[0]
	var center: CenterContainer = pair[1]
	var vb := _page_card(center, 780)
	_save_hint = _page_head(vb, "保 存 进 度", "", hide_save_slots)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 400)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	_save_box = VBoxContainer.new()
	_save_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_save_box.add_theme_constant_override("separation", 8)
	scroll.add_child(_save_box)

	var tip := _label("0 号自动存档不会被覆盖，始终保留", 12, Color(1, 1, 1, 0.45))
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(tip)


func _build_settings() -> void:
	var pair := _page_base()
	_settings_overlay = pair[0]
	var center: CenterContainer = pair[1]
	var vb := _page_card(center, 600)
	_page_head(vb, "设 置")

	_s_sound_button = _btn("音效：开", Vector2(0, 46), 16)
	_s_sound_button.pressed.connect(_toggle_sound)
	vb.add_child(_s_sound_button)
	_s_music_button = _btn("主题音乐：开", Vector2(0, 46), 16)
	_s_music_button.pressed.connect(_toggle_music)
	vb.add_child(_s_music_button)
	_s_pick_button = _btn("走子列表：开", Vector2(0, 46), 16)
	_s_pick_button.pressed.connect(_toggle_pick_visible)
	vb.add_child(_s_pick_button)
	_s_items_button = _btn("道具面板：开", Vector2(0, 46), 16)
	_s_items_button.pressed.connect(_toggle_items)
	vb.add_child(_s_items_button)
	_s_duel_button = _btn("吃棋对决：关", Vector2(0, 46), 16)
	_s_duel_button.pressed.connect(_toggle_duel)
	vb.add_child(_s_duel_button)
	_paint_duel_button()
	var duel_tip := _label("开启后吃棋前先玩一局，输或平则退回原位", 11, Color(1, 1, 1, 0.4))
	duel_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(duel_tip)

	_s_rules_button = _btn("场景规则：开", Vector2(0, 46), 16)
	_s_rules_button.pressed.connect(_toggle_rules)
	vb.add_child(_s_rules_button)
	_paint_rules_button()
	var rules_tip := _label("关闭后 8 套场景只保留外观，不再附加掷骰/落点修正", 11, Color(1, 1, 1, 0.4))
	rules_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(rules_tip)

	var help_btn := _btn("玩 法 说 明", Vector2(0, 46), 16)
	help_btn.pressed.connect(show_help)
	vb.add_child(help_btn)

	_s_update_button = _btn("更新检查：开", Vector2(0, 46), 16)
	_s_update_button.pressed.connect(_toggle_update)
	vb.add_child(_s_update_button)
	_update_version_label = _label("当前版本 v%s" % UpdateFeedScript.current_version(), 12, DIM)
	_update_version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_update_version_label)
	_update_status_label = _label("", 11, Color(1, 1, 1, 0.45))
	_update_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_update_status_label)
	_paint_update_button()

	vb.add_child(_spacer(4))
	vb.add_child(_label("默认棋盘主题", 13, DIM))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	vb.add_child(grid)
	for i in THEME_IDS.size():
		var b := _btn(THEME_NAMES[i], Vector2(0, 40), 14)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tid: String = THEME_IDS[i]
		b.pressed.connect(func(): _pick_theme(tid))
		grid.add_child(b)

	var tip := _label("设置会立即保存，下次启动沿用。", 11, Color(1, 1, 1, 0.35))
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(tip)


func _build_lan() -> void:
	var pair := _page_base()
	_lan_overlay = pair[0]
	var center: CenterContainer = pair[1]
	var vb := _page_card(center, 780)
	_page_head(vb, "局 域 网 对 战", "同一 Wi-Fi · 4 人")

	# 玩家名称：房主房间名 / 客机入座名共用，随设置持久化
	var nrow := HBoxContainer.new()
	nrow.add_theme_constant_override("separation", 10)
	vb.add_child(nrow)
	var nl := _label("玩家名称", 14, DIM)
	nl.custom_minimum_size = Vector2(84, 0)
	nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nrow.add_child(nl)
	_lan_name_edit = LineEdit.new()
	_lan_name_edit.text = _lan_player_name
	_lan_name_edit.max_length = 12
	_lan_name_edit.placeholder_text = "输入昵称"
	_lan_name_edit.custom_minimum_size = Vector2(0, 42)
	_lan_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lan_name_edit.add_theme_stylebox_override("normal", _btn_style(Color(1, 1, 1, 0.07), Color(1, 1, 1, 0.12), 10))
	_lan_name_edit.add_theme_color_override("font_color", TEXT)
	_lan_name_edit.add_theme_color_override("caret_color", GOLD)
	_lan_name_edit.text_changed.connect(func(t: String):
		_lan_player_name = t.strip_edges()
		if not _applying_prefs:
			lan_name_changed.emit(_lan_player_name))
	nrow.add_child(_lan_name_edit)

	_lan_host_box = PanelContainer.new()
	_lan_host_box.add_theme_stylebox_override("panel", _flat(Color(1, 1, 1, 0.04), 14))
	vb.add_child(_lan_host_box)
	var hb := VBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	_lan_host_box.add_child(hb)
	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 10)
	hb.add_child(hrow)
	var hlabel := _label("作为房主", 15, TEXT)
	hlabel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hrow.add_child(hlabel)
	_lan_host_btn = _btn("创建房间", Vector2(130, 40), 16)
	_lan_host_btn.pressed.connect(func(): lan_host_pressed.emit(_lan_player_name))
	hrow.add_child(_lan_host_btn)
	_lan_leave_btn = _btn("解散房间", Vector2(110, 40), 15)
	_lan_leave_btn.visible = false
	_lan_leave_btn.pressed.connect(func(): lan_leave_pressed.emit())
	hrow.add_child(_lan_leave_btn)
	_lan_host_info = _label("创建后房号会自动出现在附近房间列表里", 12, Color(1, 1, 1, 0.45))
	hb.add_child(_lan_host_info)

	# 房间大厅：座位表 + 开始 / 准备 / 离开
	_lan_lobby_panel = PanelContainer.new()
	_lan_lobby_panel.add_theme_stylebox_override("panel", _flat(Color(1, 1, 1, 0.045), 14))
	_lan_lobby_panel.visible = false
	vb.add_child(_lan_lobby_panel)
	var lvb := VBoxContainer.new()
	lvb.add_theme_constant_override("separation", 8)
	_lan_lobby_panel.add_child(lvb)
	_lan_room_label = _label("房间", 15, GOLD)
	lvb.add_child(_lan_room_label)
	_lan_seats_box = VBoxContainer.new()
	_lan_seats_box.add_theme_constant_override("separation", 6)
	lvb.add_child(_lan_seats_box)
	var lrow := HBoxContainer.new()
	lrow.add_theme_constant_override("separation", 10)
	lvb.add_child(lrow)
	_lan_start_btn = _btn("开 始 对 局", Vector2(0, 44), 17)
	_lan_start_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lan_start_btn.visible = false
	_lan_start_btn.pressed.connect(func(): lan_start_pressed.emit())
	lrow.add_child(_lan_start_btn)
	_lan_ready_btn = _btn("准 备", Vector2(0, 44), 17)
	_lan_ready_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lan_ready_btn.visible = false
	_lan_ready_btn.pressed.connect(func(): lan_ready_pressed.emit(_lan_ready_btn.text == "准 备"))
	lrow.add_child(_lan_ready_btn)
	var exit_btn := _btn("离开", Vector2(96, 44), 15)
	exit_btn.pressed.connect(func(): lan_leave_pressed.emit())
	lrow.add_child(exit_btn)

	_lan_browse = VBoxContainer.new()
	_lan_browse.add_theme_constant_override("separation", 8)
	vb.add_child(_lan_browse)

	var jrow := HBoxContainer.new()
	jrow.add_theme_constant_override("separation", 10)
	_lan_browse.add_child(jrow)
	var jlabel := _label("附近的房间", 15, TEXT)
	jlabel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	jrow.add_child(jlabel)
	var refresh := _btn("刷新", Vector2(96, 40), 15)
	refresh.pressed.connect(func(): lan_refresh_pressed.emit())
	jrow.add_child(refresh)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 190)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_lan_browse.add_child(scroll)
	_lan_rooms_box = VBoxContainer.new()
	_lan_rooms_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lan_rooms_box.add_theme_constant_override("separation", 6)
	scroll.add_child(_lan_rooms_box)

	var mrow := HBoxContainer.new()
	mrow.add_theme_constant_override("separation", 8)
	_lan_browse.add_child(mrow)
	_lan_ip_edit = LineEdit.new()
	_lan_ip_edit.placeholder_text = "房主 IP（可留空）"
	_lan_ip_edit.custom_minimum_size = Vector2(0, 42)
	_lan_ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lan_ip_edit.add_theme_stylebox_override("normal", _btn_style(Color(1, 1, 1, 0.07), Color(1, 1, 1, 0.12), 10))
	_lan_ip_edit.add_theme_color_override("font_color", TEXT)
	_lan_ip_edit.add_theme_color_override("caret_color", GOLD)
	mrow.add_child(_lan_ip_edit)
	_lan_room_edit = LineEdit.new()
	_lan_room_edit.placeholder_text = "房号"
	_lan_room_edit.custom_minimum_size = Vector2(120, 42)
	_lan_room_edit.max_length = 4
	_lan_room_edit.add_theme_stylebox_override("normal", _btn_style(Color(1, 1, 1, 0.07), Color(1, 1, 1, 0.12), 10))
	_lan_room_edit.add_theme_color_override("font_color", TEXT)
	_lan_room_edit.add_theme_color_override("caret_color", GOLD)
	mrow.add_child(_lan_room_edit)
	var join := _btn("加入", Vector2(100, 42), 16)
	join.pressed.connect(_lan_join_clicked)
	mrow.add_child(join)

	var net_tip := _label("搜不到房间？确认两台设备在同一 Wi-Fi；iOS 首次启动请允许「本地网络」；电脑端请允许防火墙的专用网络访问。也可填房主 IP + 房号直连。",
		11, Color(1, 1, 1, 0.4))
	net_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	net_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(net_tip)

	_lan_status = _label("", 12, Color(1, 1, 1, 0.55))
	_lan_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_lan_status)
	_lan_rooms_box.add_child(_label("正在搜索附近房间…", 12, Color(1, 1, 1, 0.4)))


func _lan_join_clicked() -> void:
	var ip := _lan_ip_edit.text.strip_edges()
	var room := _lan_room_edit.text.strip_edges()
	lan_join_pressed.emit(ip, room)


func _select_mode(i: int) -> void:
	_mode = i
	_paint_choice(_mode_buttons, i)
	if not _applying_prefs:
		prefs_changed.emit()


func _select_level(i: int) -> void:
	_level = i
	_paint_choice(_level_buttons, i)
	if not _applying_prefs:
		prefs_changed.emit()


func _select_theme(id: String) -> void:
	_theme_id = id
	_paint_choice(_start_theme_buttons, THEME_IDS.find(id))
	_paint_theme_btns()
	theme_previewed.emit(id)
	if not _applying_prefs:
		prefs_changed.emit()


func _select_board_size(i: int) -> void:
	_board_cells = BOARD_SIZES[clampi(i, 0, BOARD_SIZES.size() - 1)]
	_paint_choice(_board_buttons, i)
	if not _applying_prefs:
		prefs_changed.emit()


func _select_char_team(t: int) -> void:
	_char_team = clampi(t, 0, 3)
	_paint_char_ui()


func _select_char(style: int) -> void:
	_char_styles[_char_team] = clampi(style, 0, CHAR_NAMES.size() - 1)
	var b: Button = _char_buttons[style]
	b.pivot_offset = b.size * 0.5
	b.scale = Vector2(1.18, 1.18)
	var tw := create_tween()
	tw.tween_property(b, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_paint_char_ui()
	if not _applying_prefs:
		prefs_changed.emit()


func _paint_char_ui() -> void:
	for t in _char_team_buttons.size():
		var tb: Button = _char_team_buttons[t]
		if t == _char_team:
			tb.add_theme_stylebox_override("normal", _btn_style(Color(0.5, 0.38, 0.18, 0.7), GOLD))
			tb.add_theme_color_override("font_color", Color("ffe6b8"))
		else:
			tb.add_theme_stylebox_override("normal", _btn_style(Color(1, 1, 1, 0.06), Color(1, 1, 1, 0.1)))
			tb.add_theme_color_override("font_color", TEXT)
	var active: int = _char_styles[_char_team]
	for i in _char_buttons.size():
		var b: Button = _char_buttons[i]
		if i == active:
			b.add_theme_stylebox_override("normal", _btn_style(Color(0.55, 0.42, 0.22, 0.75), Color("ffe0a0")))
			b.add_theme_color_override("font_color", Color("fff2d0"))
		else:
			b.add_theme_stylebox_override("normal", _btn_style(Color(1, 1, 1, 0.05), Color(1, 1, 1, 0.09)))
			b.add_theme_color_override("font_color", Color(0.85, 0.89, 0.96, 0.85))


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
	start_pressed.emit(_mode, _level, _theme_id, _board_cells, _char_styles.duplicate())


# ---------------------------------------------------------------- 对外接口

func _hide_pages() -> void:
	_start_overlay.visible = false
	_home_overlay.visible = false
	_load_overlay.visible = false
	_save_overlay.visible = false
	_settings_overlay.visible = false
	_help_overlay.visible = false
	_lan_overlay.visible = false
	_duel_overlay.visible = false
	if _update_overlay != null:
		_update_overlay.visible = false


func _hide_game_nodes() -> void:
	for n in _game_nodes:
		if is_instance_valid(n):
			n.visible = false


func _show_game_nodes() -> void:
	for n in _game_nodes:
		if is_instance_valid(n):
			n.visible = true


func show_home() -> void:
	_hide_pages()
	_hide_game_nodes()
	_home_overlay.visible = true
	_toast.modulate.a = 0.0
	if _cast_bar != null:
		_cast_bar.modulate.a = 0.0
	hide_win()
	hide_pick()
	hide_roulette()


func show_start() -> void:
	_hide_pages()
	_start_overlay.visible = true
	_menu_panel.visible = false
	_menu_open = false
	_menu_button.text = "≡"
	_hide_game_nodes()
	_toast.modulate.a = 0.0
	if _cast_bar != null:
		_cast_bar.modulate.a = 0.0
	hide_win()
	hide_pick()
	hide_roulette()


func show_load(records: Array) -> void:
	_hide_pages()
	_load_overlay.visible = true
	_hide_game_nodes()
	for c in _saves_box.get_children():
		c.queue_free()
	_load_hint.text = "%d / 20" % records.size()
	if records.is_empty():
		_saves_box.add_child(_label("还没有存档，先创建一局开始游戏吧。", 14, Color(1, 1, 1, 0.45)))
		return
	for rec in records:
		_saves_box.add_child(_make_save_row(rec))


func _make_save_row(rec: Dictionary) -> PanelContainer:
	var slot := int(rec.get("slot", 0))
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _flat(Color(1, 1, 1, 0.045), 12))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	var tag := _label("自动" if slot == 0 else "%02d" % slot, 14, GOLD if slot == 0 else DIM)
	tag.custom_minimum_size = Vector2(46, 0)
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(tag)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	row.add_child(info)
	info.add_child(_label(String(rec.get("title", "存档")), 15, TEXT))
	info.add_child(_label(String(rec.get("detail", "")), 11, Color(1, 1, 1, 0.45)))
	info.add_child(_label(String(rec.get("time_text", "")), 11, Color(1, 1, 1, 0.3)))

	var load := _btn("载入", Vector2(88, 40), 15)
	load.add_theme_stylebox_override("normal", _btn_style(Color("c99a4e"), Color("f0cd8a"), 12))
	load.add_theme_stylebox_override("hover", _btn_style(Color("e0b060"), Color("ffe0a0"), 12))
	load.add_theme_color_override("font_color", Color("1a1206"))
	load.pressed.connect(func(): load_slot_pressed.emit(slot))
	row.add_child(load)
	if slot != 0:
		var del := _btn("删除", Vector2(72, 40), 14)
		del.add_theme_stylebox_override("normal", _btn_style(Color(0.45, 0.16, 0.18, 0.55), Color(1, 1, 1, 0.18), 12))
		del.pressed.connect(func(): delete_slot_pressed.emit(slot))
		row.add_child(del)
	return panel


func show_settings() -> void:
	_hide_pages()
	_settings_overlay.visible = true
	_hide_game_nodes()


# ---------------------------------------------------------------- 更新检查

func _build_update_dialog() -> void:
	_update_overlay = Control.new()
	_update_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_update_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_update_overlay.visible = false
	_root.add_child(_update_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.015, 0.03, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_overlay.add_child(center)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _flat(Color(0.04, 0.055, 0.095, 0.98), 20, GOLD, 2))
	card.custom_minimum_size = Vector2(470, 0)
	center.add_child(card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	card.add_child(vb)

	_update_title = _label("发 现 新 版 本", 24, GOLD)
	_update_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_update_title)

	_update_body = _label("", 14, TEXT)
	_update_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_update_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_update_body.custom_minimum_size = Vector2(420, 0)
	vb.add_child(_update_body)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(row)

	_update_download_btn = _btn("下载更新", Vector2(0, 44), 16)
	_update_download_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_update_download_btn.pressed.connect(func(): update_download_pressed.emit())
	row.add_child(_update_download_btn)

	_update_retry_btn = _btn("重新检查", Vector2(0, 44), 15)
	_update_retry_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_update_retry_btn.visible = false
	_update_retry_btn.pressed.connect(func(): update_check_pressed.emit())
	row.add_child(_update_retry_btn)

	_update_browser_btn = _btn("用浏览器打开", Vector2(0, 44), 15)
	_update_browser_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_update_browser_btn.visible = false
	_update_browser_btn.pressed.connect(func(): update_browser_pressed.emit())
	row.add_child(_update_browser_btn)

	var later := _btn("以后再说", Vector2(0, 44), 15)
	later.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	later.pressed.connect(func():
		hide_update_dialog()
		update_later_pressed.emit())
	row.add_child(later)


func _toggle_update() -> void:
	_update_on = not _update_on
	_paint_update_button()
	if not _applying_prefs:
		update_toggled.emit(_update_on)


func _paint_update_button() -> void:
	if _s_update_button != null:
		_s_update_button.text = "更新检查：开" if _update_on else "更新检查：关"


func set_update_enabled(on: bool) -> void:
	_update_on = on
	_paint_update_button()


func set_app_version(v: String) -> void:
	if _update_version_label != null:
		_update_version_label.text = "当前版本 v%s" % v


func set_update_status(text: String, color := Color(1, 1, 1, 0.45)) -> void:
	if _update_status_label != null:
		_update_status_label.text = text
		_update_status_label.add_theme_color_override("font_color", color)


func show_update_found(latest: String) -> void:
	if _update_overlay == null:
		return
	_update_title.text = "发 现 新 版 本"
	_update_body.text = "当前 v%s，最新 v%s。\n是否现在下载更新？" % [UpdateFeedScript.current_version(), latest]
	_update_download_btn.visible = true
	_update_download_btn.disabled = false
	_update_retry_btn.visible = false
	_update_browser_btn.visible = false
	_update_overlay.visible = true


func show_update_error(msg: String) -> void:
	if _update_overlay == null:
		return
	_update_title.text = "检 查 更 新 失 败"
	_update_body.text = msg
	_update_download_btn.visible = false
	_update_retry_btn.visible = true
	_update_browser_btn.visible = true
	_update_overlay.visible = true


func show_update_note(msg: String, retry := false) -> void:
	if _update_overlay == null:
		return
	_update_title.text = "更 新"
	_update_body.text = msg
	_update_download_btn.visible = false
	_update_retry_btn.visible = retry
	_update_browser_btn.visible = retry
	_update_overlay.visible = true


func hide_update_dialog() -> void:
	if _update_overlay != null:
		_update_overlay.visible = false


func _build_help() -> void:
	var pair := _page_base()
	_help_overlay = pair[0]
	var center: CenterContainer = pair[1]
	var vb := _page_card(center, 880)
	_page_head(vb, "玩 法 说 明", "基础 · 地图 · 道具 · 事件", show_settings)

	_help_scroll = ScrollContainer.new()
	_help_scroll.custom_minimum_size = Vector2(0, 470)
	_help_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(_help_scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	_help_scroll.add_child(box)

	_help_section(box, "基础规则")
	for line in [
		"棋盘是环形跑道：棋子从基地出发，绕场一周后进入终点跑道，四枚棋子全部到达终点即获胜。",
		"出基地：必须掷出 6 点（原始骰面为 6；场景修正后为 6 也可以）。掷出 6 点后本回合还能再掷一次。",
		"进终点：点数必须正好，多出来的点数不能走，该棋子本回合留在原地。",
		"安全格：每 4 格出现一个，停在上面会获得护盾，护盾可以免疫一次被吃棋。",
		"吃棋：落到对手棋子所在的格子会把它吃回基地；开启「吃棋对决」后先猜拳，输或平则攻击方退回原位。",
		"场地格：宝箱格抽道具，问号格触发特殊事件，传送门与荆棘各有独立效果。",
		"场景规则可以在「设置 → 场景规则」整体关闭；关闭后 8 套地图只保留外观。",
	]:
		_help_line(box, line)

	_help_section(box, "八张地图的特殊规则")
	for i in THEME_NAMES.size():
		_help_line(box, "%s：%s" % [THEME_NAMES[i], HELP_THEME_RULES[i]])

	_help_section(box, "道具")
	for id in ITEM_INFO:
		var info: Array = ITEM_INFO[id]
		_help_line(box, "%s：%s" % [info[0], HELP_ITEM_DESC.get(id, info[1])])

	_help_section(box, "特殊事件")
	for e in HELP_EVENTS:
		_help_line(box, "%s：%s" % [e[0], e[1]])


func _help_section(box: VBoxContainer, title: String) -> void:
	box.add_child(_spacer(6))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var bar := ColorRect.new()
	bar.color = GOLD
	bar.custom_minimum_size = Vector2(4, 18)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	row.add_child(_label(title, 17, GOLD))
	box.add_child(row)


func _help_line(box: VBoxContainer, text: String) -> void:
	var l := _label(text, 13, Color(0.88, 0.9, 0.96))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(l)


func show_help() -> void:
	_hide_pages()
	_help_overlay.visible = true
	_hide_game_nodes()
	if _help_scroll != null:
		_help_scroll.scroll_vertical = 0


## 打开存档槽选择页：records 来自 Main._save_records()
func show_save_slots(records: Array) -> void:
	_hide_pages()
	_save_overlay.visible = true
	_hide_game_nodes()
	_reset_save_confirm()
	for c in _save_box.get_children():
		c.queue_free()
	var by_slot := {}
	for rec in records:
		if rec is Dictionary:
			var s := int(rec.get("slot", 0))
			if s >= 1 and s <= SAVE_SLOTS_MAX:
				by_slot[s] = rec
	_save_hint.text = "%d / %d" % [by_slot.size(), SAVE_SLOTS_MAX]
	for slot in range(1, SAVE_SLOTS_MAX + 1):
		_save_box.add_child(_make_save_slot_row(slot, by_slot.get(slot, {})))


func hide_save_slots() -> void:
	_save_overlay.visible = false
	_reset_save_confirm()
	_show_game_nodes()
	# 回到对局：收起控制台与战报，避免 _show_game_nodes 把它们一起点亮
	_menu_panel.visible = false
	_menu_open = false
	_menu_button.text = "≡"
	_log_panel.visible = false
	_log_button.text = "战 报 ▾"


## 载入页正在显示时刷新数据；未打开则什么都不做
func refresh_load(records: Array) -> void:
	if _load_overlay != null and _load_overlay.visible:
		show_load(records)


func _make_save_slot_row(slot: int, rec: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _flat(Color(1, 1, 1, 0.045), 12))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	var tag := _label("【%02d】" % slot, 14, GOLD)
	tag.custom_minimum_size = Vector2(52, 0)
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(tag)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	row.add_child(info)
	if rec.is_empty():
		info.add_child(_label("空槽 · 保存到此槽", 15, Color(1, 1, 1, 0.45)))
	else:
		info.add_child(_label(String(rec.get("detail", "存档")), 14, TEXT))
		info.add_child(_label(String(rec.get("time_text", "")), 11, Color(1, 1, 1, 0.35)))

	var b := _btn("保存到此槽" if rec.is_empty() else "覆盖", Vector2(118, 40), 14)
	if rec.is_empty():
		b.pressed.connect(func():
			_reset_save_confirm()
			save_slot_pressed.emit(slot))
	else:
		b.add_theme_stylebox_override("normal", _btn_style(Color(0.45, 0.16, 0.18, 0.55), Color(1, 1, 1, 0.18), 12))
		b.pressed.connect(func(): _confirm_save_slot(slot, b))
	row.add_child(b)
	return panel


## 已占用槽：第一次点变「确认覆盖?」，2.5 秒内再点才真正保存
func _confirm_save_slot(slot: int, b: Button) -> void:
	if _save_confirm_slot == slot and Time.get_ticks_msec() <= _save_confirm_until:
		_reset_save_confirm()
		save_slot_pressed.emit(slot)
		return
	_reset_save_confirm()
	_save_confirm_slot = slot
	_save_confirm_btn = b
	_save_confirm_until = Time.get_ticks_msec() + 2500
	b.text = "确认覆盖?"
	var token := _save_confirm_until
	await get_tree().create_timer(2.5).timeout
	if _save_confirm_slot == slot and _save_confirm_until == token:
		_reset_save_confirm()


func _reset_save_confirm() -> void:
	if _save_confirm_btn != null and is_instance_valid(_save_confirm_btn):
		_save_confirm_btn.text = "覆盖"
	_save_confirm_btn = null
	_save_confirm_slot = -1
	_save_confirm_until = 0


## 点别处时取消「确认覆盖?」
func _input(event: InputEvent) -> void:
	if _save_confirm_slot < 0 or _save_overlay == null or not _save_overlay.visible:
		return
	var pos := Vector2.ZERO
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
	elif event is InputEventScreenTouch and event.pressed:
		pos = event.position
	else:
		return
	if _save_confirm_btn != null and is_instance_valid(_save_confirm_btn) \
			and _save_confirm_btn.get_global_rect().has_point(pos):
		return
	_reset_save_confirm()


func show_lan() -> void:
	_hide_pages()
	_lan_overlay.visible = true
	_hide_game_nodes()


func set_lan_status(text: String, color := Color(1, 1, 1, 0.55)) -> void:
	_lan_status.text = text
	_lan_status.add_theme_color_override("font_color", color)


func set_lan_rooms(rooms: Array) -> void:
	for c in _lan_rooms_box.get_children():
		c.queue_free()
	if rooms.is_empty():
		_lan_rooms_box.add_child(_label("还没有发现房间。确认两台设备在同一 Wi-Fi，或直接填房主 IP 加入。", 12, Color(1, 1, 1, 0.4)))
		return
	for r in rooms:
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", _flat(Color(1, 1, 1, 0.045), 12))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		panel.add_child(row)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 1)
		row.add_child(info)
		var host_name := String(r.get("host", ""))
		info.add_child(_label("房号 %s%s" % [String(r.get("room", "")), " · " + host_name if host_name != "" else ""], 14, TEXT))
		info.add_child(_label("%s · %d/4 人 · %d 格棋盘" % [String(r.get("ip", "")), int(r.get("players", 1)), int(r.get("cells", 40))], 11, Color(1, 1, 1, 0.42)))
		var join := _btn("加入", Vector2(88, 38), 15)
		var ip := String(r.get("ip", ""))
		var room := String(r.get("room", ""))
		join.pressed.connect(func(): lan_join_pressed.emit(ip, room))
		row.add_child(join)
		_lan_rooms_box.add_child(panel)


func set_lan_hosting(text: String) -> void:
	_lan_host_info.text = text
	_lan_host_btn.disabled = true
	_lan_leave_btn.visible = true
	_lan_browse.visible = false


## 大厅座位表：房主看管理按钮（踢人 / AI 开关 / 开始），客机看准备与离开
func set_lan_lobby(lb: Dictionary, is_host: bool, my_seat: int) -> void:
	_lan_is_host = is_host
	_lan_my_seat = my_seat
	_lan_in_room = true
	_lan_lobby_panel.visible = true
	_lan_browse.visible = false
	_lan_host_box.visible = is_host
	_lan_host_btn.disabled = true
	_lan_leave_btn.visible = is_host
	var host_name2 := String(lb.get("host", ""))
	_lan_room_label.text = "房号 %s · 房主 %s" % [String(lb.get("room", "")), host_name2]
	for c in _lan_seats_box.get_children():
		c.queue_free()
	var seat_rows: Array = lb.get("seats", [])
	for s in 4:
		var st: Dictionary = seat_rows[s] if s < seat_rows.size() else {"seat": s, "name": "AI 补位", "ai": true}
		_lan_seats_box.add_child(_lan_seat_row(st))
	var humans := 0
	for st in seat_rows:
		if bool(st.get("connected", false)):
			humans += 1
	_lan_room_label.text += " · %d/4 人" % humans
	_lan_start_btn.visible = is_host
	_lan_ready_btn.visible = not is_host
	if is_host:
		var can := bool(lb.get("can_start", true))
		_lan_start_btn.disabled = not can
		_lan_start_btn.text = "开 始 对 局" if can else "等待所有玩家准备…"
	else:
		var mine_ready := false
		if my_seat >= 0 and my_seat < seat_rows.size():
			mine_ready = bool(seat_rows[my_seat].get("ready", false))
		_lan_ready_btn.text = "取消准备" if mine_ready else "准 备"


func _lan_seat_row(st: Dictionary) -> PanelContainer:
	var s := int(st.get("seat", 0))
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _flat(Color(1, 1, 1, 0.035), 10))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var dot := _label("●", 16, CAST_TEAM_COLORS[clampi(s, 0, 3)])
	dot.custom_minimum_size = Vector2(18, 0)
	dot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(dot)
	var nm := String(st.get("name", "AI 补位"))
	var title := "%d 号位 · %s" % [s + 1, nm]
	if bool(st.get("host", false)):
		title += "（房主）"
	if s == _lan_my_seat and not _lan_is_host:
		title += "（我）"
	var name_l := _label(title, 14, TEXT)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name_l)
	var state_text := "空闲"
	var state_color := Color(1, 1, 1, 0.4)
	if bool(st.get("connected", false)):
		if bool(st.get("host", false)):
			state_text = "房主"
			state_color = GOLD
		elif bool(st.get("ready", false)):
			state_text = "已准备"
			state_color = Color("8ff0c0")
		else:
			state_text = "未准备"
			state_color = Color("ffb86b")
	elif bool(st.get("ai", false)):
		state_text = "AI 补位"
		state_color = Color("9ec5ff")
	var state_l := _label(state_text, 12, state_color)
	state_l.custom_minimum_size = Vector2(62, 0)
	state_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	state_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(state_l)
	if _lan_is_host and s > 0:
		if bool(st.get("connected", false)):
			var kick := _btn("踢出", Vector2(66, 32), 13)
			kick.add_theme_stylebox_override("normal", _btn_style(Color(0.45, 0.16, 0.18, 0.55), Color(1, 1, 1, 0.18), 10))
			kick.pressed.connect(func(): lan_kick_pressed.emit(s))
			row.add_child(kick)
		else:
			var ai_on := bool(st.get("ai", true))
			var ai := _btn("AI：开" if ai_on else "AI：关", Vector2(76, 32), 13)
			ai.pressed.connect(func(): lan_seat_ai_pressed.emit(s, not ai_on))
			row.add_child(ai)
	return panel


func set_lan_idle() -> void:
	_lan_host_info.text = "创建后房号会自动出现在附近房间列表里"
	_lan_host_btn.disabled = false
	_lan_leave_btn.visible = false
	_lan_lobby_panel.visible = false
	_lan_browse.visible = true
	_lan_host_box.visible = true
	_lan_start_btn.visible = false
	_lan_ready_btn.visible = false
	_lan_in_room = false
	_lan_my_seat = -1


func hide_start() -> void:
	_hide_pages()
	_show_game_nodes()
	_set_teams_open(false, false)
	_menu_panel.visible = false
	_menu_open = false
	_menu_button.text = "≡"
	_log_panel.visible = false
	_log_button.text = "战 报 ▾"


func set_sound(on: bool) -> void:
	_sound_on = on
	_sound_button.text = "音效：开" if on else "音效：关"
	if _s_sound_button != null:
		_s_sound_button.text = _sound_button.text


func set_music(on: bool) -> void:
	_music_on = on
	_music_button.text = "主题音乐：开" if on else "主题音乐：关"
	if _s_music_button != null:
		_s_music_button.text = _music_button.text


## 当前所有可持久化的设定
func prefs() -> Dictionary:
	return {
		"mode": _mode,
		"level": _level,
		"theme": _theme_id,
		"cells": _board_cells,
		"styles": _char_styles.duplicate(),
		"sound": _sound_on,
		"music": _music_on,
		"pick_visible": _pick_visible,
		"items_open": _items_open,
		"duel": _duel_on,
		"rules": _rules_on,
		"update": _update_on,
		"player": _lan_player_name,
	}


## 套用本地存档的设定（不触发保存信号）
func apply_prefs(p: Dictionary) -> void:
	if p.is_empty():
		return
	_applying_prefs = true
	if p.has("mode"):
		_select_mode(clampi(int(p["mode"]), 0, 1))
	if p.has("level"):
		_select_level(clampi(int(p["level"]), 0, 2))
	if p.has("theme") and THEME_IDS.has(String(p["theme"])):
		_select_theme(String(p["theme"]))
	if p.has("cells"):
		_select_board_size(BOARD_SIZES.find(int(p["cells"])) if BOARD_SIZES.has(int(p["cells"])) else 0)
	if p.has("styles"):
		var st: Array = p["styles"]
		for t in mini(st.size(), 4):
			_char_styles[t] = clampi(int(st[t]), 0, CHAR_NAMES.size() - 1)
		_paint_char_ui()
	if p.has("sound"):
		set_sound(bool(p["sound"]))
		sound_toggled.emit(_sound_on)
	if p.has("music"):
		set_music(bool(p["music"]))
		music_toggled.emit(_music_on)
	if p.has("pick_visible"):
		_pick_visible = bool(p["pick_visible"])
		_pick_toggle.text = "走子列表：开" if _pick_visible else "走子列表：关"
	if p.has("items_open"):
		_items_open = bool(p["items_open"])
		_apply_items_position(false)
	if p.has("duel"):
		_duel_on = bool(p["duel"])
		_paint_duel_button()
	if p.has("rules"):
		_rules_on = bool(p["rules"])
		_paint_rules_button()
	if p.has("update"):
		_update_on = bool(p["update"])
		_paint_update_button()
	if p.has("player") and String(p["player"]).strip_edges() != "":
		_lan_player_name = String(p["player"]).strip_edges()
		if _lan_name_edit != null:
			_lan_name_edit.text = _lan_player_name
	_applying_prefs = false


func set_turn(text: String, color: Color) -> void:
	_turn_text = text
	_turn_short = text.replace("当前回合：", "")
	_turn_color = color
	_paint_turn_bar()


func set_dice(_value: int, _total := 0) -> void:
	pass


func set_roll_enabled(_on: bool, text := "") -> void:
	_hint_override = text


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
			panel.add_theme_stylebox_override("panel", _flat(Color(0.035, 0.05, 0.085, 0.7), 14))


func log(text: String) -> void:
	if _log_label == null:
		return
	var lines: Array = Array(_log_label.text.split("\n"))
	if lines.size() == 1 and lines[0] == "":
		lines.clear()
	lines.append(text)
	while lines.size() > 8:
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
			b.add_theme_stylebox_override("normal", _btn_style(Color(info[2].r * 0.2, info[2].g * 0.2, info[2].b * 0.2, 0.92), info[2].darkened(0.15), 14))
			b.disabled = not enabled
			if id != _card_ids[i]:
				_card_ids[i] = id
				_pop_card(b)
		else:
			labels[0].text = "空"
			labels[1].text = ""
			labels[0].add_theme_color_override("font_color", Color(1, 1, 1, 0.28))
			b.add_theme_stylebox_override("normal", _btn_style(Color(1, 1, 1, 0.04), Color(1, 1, 1, 0.07), 14))
			b.disabled = true
			_card_ids[i] = ""


## 新道具入栏：弹一下 + 金色描边闪光
func _pop_card(b: Button) -> void:
	b.pivot_offset = Vector2(39, 26)
	b.scale = Vector2(1.45, 1.45)
	var tw := create_tween()
	tw.tween_property(b, "scale", Vector2.ONE, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func show_pick(options: Array, hint := "选择一枚棋子") -> void:
	_last_options = options.duplicate()
	_last_hint = hint
	for c in _pick_box.get_children():
		c.queue_free()
	if _pick_hint:
		_pick_hint.text = hint
	for opt in options:
		var b := _btn(opt["label"], Vector2(204, 46), 15)
		var col: Color = opt["color"]
		b.add_theme_stylebox_override("normal", _btn_style(Color(col.r * 0.35, col.g * 0.35, col.b * 0.35, 0.9), col))
		b.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
		var idx: int = opt["index"]
		b.pressed.connect(func(): piece_pressed.emit(idx))
		_pick_box.add_child(b)
	_pick_panel.visible = _pick_visible


func hide_pick() -> void:
	_pick_panel.visible = false
	_last_options.clear()


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
	_event_tween.tween_property(_event_overlay, "modulate:a", 1.0, 0.14)
	_event_tween.tween_interval(1.9)
	_event_tween.tween_property(_event_overlay, "modulate:a", 0.0, 0.26)
	_event_tween.tween_callback(func(): _event_overlay.visible = false)


## 道具播报：不依赖战报，直接居中放大展示
func show_item_toast(title: String, desc: String, color: Color) -> void:
	_toast_title.text = title
	_toast_title.add_theme_color_override("font_color", color.lightened(0.2))
	_toast_desc.text = desc
	_toast.add_theme_stylebox_override("panel", _flat(Color(0.04, 0.055, 0.095, 0.95), 20, color, 3))
	_toast.pivot_offset = _toast.size * 0.5
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast.modulate.a = 0.0
	_toast.scale = Vector2(0.86, 0.86)
	_toast_tween = create_tween()
	_toast_tween.set_parallel(true)
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.14)
	_toast_tween.tween_property(_toast, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_toast_tween.set_parallel(false)
	_toast_tween.tween_interval(1.35)
	_toast_tween.set_parallel(true)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.30)
	_toast_tween.tween_property(_toast, "scale", Vector2(1.06, 1.06), 0.30)


## 道具施放信息条：顶部滑入 → 停留 → 淡出；只做动画的补充说明，不拦输入
func show_item_cast(team: int, item_id: String, target_text: String, effect_text: String) -> void:
	if _cast_bar == null:
		return
	var info: Array = ITEM_INFO.get(item_id, [item_id, "", Color("d8d8e8")])
	var accent: Color = info[2]
	var team_color: Color = CAST_TEAM_COLORS[clampi(team, 0, 3)]
	var team_name: String = DUEL_TEAM_NAMES[clampi(team, 0, 3)]
	_cast_left.text = "%s  使用了  %s" % [team_name, String(info[0])]
	_cast_right.text = target_text
	_cast_effect.text = effect_text
	_cast_effect.add_theme_color_override("font_color", accent.lightened(0.15))
	_cast_chip.color = team_color
	_cast_bar.add_theme_stylebox_override("panel", _flat(Color(0.04, 0.055, 0.095, 0.92), 14, team_color, 2))
	_cast_bar.visible = true
	if _cast_tween and _cast_tween.is_valid():
		_cast_tween.kill()
	_cast_bar.modulate.a = 0.0
	_cast_bar.offset_top = _cast_base_top - 16.0
	_cast_bar.offset_bottom = _cast_base_bottom - 16.0
	_cast_tween = create_tween()
	_cast_tween.set_parallel(true)
	_cast_tween.tween_property(_cast_bar, "modulate:a", 1.0, 0.2)
	_cast_tween.tween_property(_cast_bar, "offset_top", _cast_base_top, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_cast_tween.tween_property(_cast_bar, "offset_bottom", _cast_base_bottom, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_cast_tween.set_parallel(false)
	_cast_tween.tween_interval(1.4)
	_cast_tween.set_parallel(true)
	_cast_tween.tween_property(_cast_bar, "modulate:a", 0.0, 0.3)
	_cast_tween.tween_property(_cast_bar, "offset_top", _cast_base_top - 10.0, 0.3)
	_cast_tween.tween_property(_cast_bar, "offset_bottom", _cast_base_bottom - 10.0, 0.3)


func screen_flash(color: Color, strength := 0.32) -> void:
	_flash.color = Color(color.r, color.g, color.b, strength)
	var t := create_tween()
	t.tween_property(_flash, "color:a", 0.0, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func show_win(title: String, color: Color, stats: String) -> void:
	_win_title.text = title
	_win_title.add_theme_color_override("font_color", color)
	_win_stats.text = stats
	_win_overlay.visible = true


func hide_win() -> void:
	_win_overlay.visible = false


func set_start_visible(v: bool) -> void:
	_start_overlay.visible = v


## 轮盘绘制：八等分扇区 + 中心轴 + 金色外环（不依赖任何贴图）
class Wheel extends Control:
	var labels: Array = []
	var colors: Array = []

	func _draw() -> void:
		var c := size * 0.5
		var r: float = min(size.x, size.y) * 0.5 - 6.0
		var n := labels.size()
		if n <= 0:
			draw_circle(c, r, Color(0.08, 0.1, 0.15, 1.0))
			draw_arc(c, r, 0.0, TAU, 96, Color("f0cd8a"), 3.0, true)
			return
		var seg := TAU / float(n)
		for i in n:
			var a0 := -PI * 0.5 + seg * float(i)
			var col: Color = colors[i] if i < colors.size() else Color.WHITE
			var wedge := PackedVector2Array()
			wedge.append(c)
			var steps := 12
			for k in steps + 1:
				var a := a0 + seg * float(k) / float(steps)
				wedge.append(c + Vector2(cos(a), sin(a)) * r)
			var fill := Color(col.r * 0.42 + 0.04, col.g * 0.42 + 0.04, col.b * 0.42 + 0.05, 0.98)
			draw_colored_polygon(wedge, fill)
			var edge := c + Vector2(cos(a0), sin(a0)) * r
			draw_line(c, edge, Color(1, 1, 1, 0.16), 1.5)
			# 外缘高亮弧
			draw_arc(c, r - 2.0, a0, a0 + seg, 16, Color(col.r, col.g, col.b, 0.85), 3.0, true)
		var font := get_theme_default_font()
		if font:
			for i in n:
				var mid := -PI * 0.5 + seg * (float(i) + 0.5)
				var lp := c + Vector2(cos(mid), sin(mid)) * r * 0.66
				draw_string(font, lp + Vector2(-62.0, 6.0), String(labels[i]),
					HORIZONTAL_ALIGNMENT_CENTER, 124.0, 15, Color(1, 1, 1, 0.96))
		draw_circle(c, r * 0.24, Color(0.03, 0.04, 0.075, 1.0))
		draw_circle(c, r * 0.24, Color(0.95, 0.8, 0.45, 1.0), false, 2.5)
		draw_arc(c, r, 0.0, TAU, 96, Color("f0cd8a"), 3.0, true)
