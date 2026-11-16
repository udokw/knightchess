extends Node3D
## 骑士飞行棋 3（Knight Flight Chess）Godot 4 复刻 —— 场景1 / 经典布局 / 经典模式
## 4 名玩家本地轮流，掷骰子、绕 40 格、吃子、精确点数进终点。

const TEAM_NAMES := ["红队", "蓝队", "绿队", "黄队"]
const TEAM_COLORS := [Color("d9473c"), Color("3d7ec9"), Color("4aa75a"), Color("e2b23c")]
const FIELDS := 40
const PIECES_PER_TEAM := 4
const BOARD_Y := 3.6
const PIECE_HEIGHT := 62.0

var data: Dictionary = {}
var pts: Dictionary = {}
var paths: Array = []            # 每个队伍 40 个点位名
var pieces: Array = []           # {team, idx, cell, finished, node, color}

var current_team := 0
var busy := false
var awaiting_pick := false
var game_over := false
var winner := -1
var auto_mode := false
var shot_path := ""

# 相机
var cam_yaw := deg_to_rad(38.0)
var cam_pitch := deg_to_rad(60.0)
var cam_dist := 1560.0
var cam_target := Vector3(0, 0, 0)
var camera: Camera3D
var dragging := false
var dice_player: AudioStreamPlayer

# UI
var dice_label: Label
var turn_label: Label
var msg_label: Label
var roll_button: Button
var pick_box: HBoxContainer
var log_lines: Array = []


func _ready() -> void:
	var all_args: Array = []
	all_args.append_array(OS.get_cmdline_args())
	all_args.append_array(OS.get_cmdline_user_args())
	print("args: ", all_args)
	for a in all_args:
		if a.begins_with("--shot="):
			shot_path = a.substr(7)
		elif a == "--auto":
			auto_mode = true
	_load_data()
	_setup_environment()
	_setup_camera()
	_setup_audio()
	_spawn_level()
	if "--nopieces" not in all_args:
		_spawn_pieces()
	_build_ui()
	_update_hud()
	_log("游戏开始，%s 先手" % TEAM_NAMES[0])
	if auto_mode:
		await _auto_play()
	if "--top" in all_args:
		cam_pitch = deg_to_rad(88.0)
		cam_dist = 1450.0
		cam_target = Vector3(0, BOARD_Y, 0)
		_update_camera()
	if "--close" in all_args:
		cam_pitch = deg_to_rad(28.0)
		cam_dist = 620.0
		cam_target = Vector3(-430, 40, -430)
		_update_camera()
	if shot_path != "":
		await _take_screenshot()


# ---------------------------------------------------------------- 数据 / 场景

func _load_data() -> void:
	var f := FileAccess.open("res://assets/data/board.json", FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed == null:
		push_error("board.json 解析失败")
		return
	data = parsed
	pts = data["points"]
	for i in range(4):
		paths.append(data["paths"]["TEAMPATH%d" % (i + 1)])


func _setup_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("6fa8dc")
	sky_mat.sky_horizon_color = Color("cfe3f5")
	sky_mat.ground_bottom_color = Color("4a6b3a")
	sky_mat.ground_horizon_color = Color("9fbf8a")
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.05
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = false
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = false
	add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25, 140, 0)
	fill.light_energy = 0.35
	add_child(fill)


func _setup_camera() -> void:
	camera = Camera3D.new()
	camera.fov = 52.0
	camera.near = 1.0
	camera.far = 9000.0
	add_child(camera)
	_update_camera()


func _setup_audio() -> void:
	dice_player = AudioStreamPlayer.new()
	dice_player.stream = load("res://assets/sounds/dice_move.wav")
	dice_player.volume_db = -4.0
	add_child(dice_player)

	var amb := AudioStreamPlayer.new()
	var st: AudioStream = load("res://assets/sounds/ambient.ogg")
	if st is AudioStreamOggVorbis:
		(st as AudioStreamOggVorbis).loop = true
	amb.stream = st
	amb.volume_db = -18.0
	add_child(amb)
	amb.play()


func _spawn_level() -> void:
	var ps := load("res://assets/levels/scene1.gltf")
	if ps == null:
		push_error("关卡加载失败")
		return
	var level: Node3D = ps.instantiate()
	add_child(level)
	# 棋盘面与地面网格共面会 z-fighting, 稍微抬高一点
	var layout := level.find_child("Layout", true, false)
	if layout is Node3D:
		(layout as Node3D).position.y += 2.6
		if layout is MeshInstance3D:
			_layout_unshaded(layout as MeshInstance3D)


func _layout_unshaded(m3: MeshInstance3D) -> void:
	if m3.mesh == null or m3.mesh.get_surface_count() == 0:
		return
	var src := m3.mesh.surface_get_material(0)
	if src is not BaseMaterial3D:
		return
	# 棋盘贴图是"黑底 + 草地十字 + 白色路径"的贴花, 黑底需要变成透明
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;
uniform sampler2D board_tex : source_color, filter_linear_mipmap;

void fragment() {
	vec4 c = texture(board_tex, UV);
	float lum = max(c.r, max(c.g, c.b));
	ALBEDO = c.rgb;
	ALPHA = clamp((lum - 0.02) * 6.0, 0.0, 1.0);
}
"""
	var sm := ShaderMaterial.new()
	sm.shader = sh
	sm.set_shader_parameter("board_tex", (src as BaseMaterial3D).albedo_texture)
	m3.material_override = sm
	m3.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _spawn_pieces() -> void:
	for t in range(4):
		for i in range(PIECES_PER_TEAM):
			var node := _make_piece_node(t, i)
			add_child(node)
			var base_name := "HM%d_%d" % [t + 1, i + 1]
			node.position = _pt_pos(base_name)
			pieces.append({
				"team": t, "idx": i, "cell": -1, "finished": false,
				"node": node, "color": TEAM_COLORS[t],
			})


func _make_piece_node(team: int, idx: int) -> Node3D:
	var root := Node3D.new()
	root.name = "P%d_%d" % [team + 1, idx + 1]

	var ring := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 26.0
	cyl.bottom_radius = 26.0
	cyl.height = 3.0
	cyl.radial_segments = 20
	ring.mesh = cyl
	ring.position = Vector3(0, 1.5, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = TEAM_COLORS[team]
	mat.emission_enabled = true
	mat.emission = TEAM_COLORS[team]
	mat.emission_energy_multiplier = 0.5
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = mat
	root.add_child(ring)

	var fig_path := "res://assets/figures/fig%d.gltf" % (team + 1)
	var fig := load(fig_path)
	if fig != null:
		var model: Node3D = fig.instantiate()
		root.add_child(model)
		# 等模型进入场景树后再测量尺寸
		call_deferred("_normalize_model", model)
	else:
		var body := MeshInstance3D.new()
		var cap := CapsuleMesh.new()
		cap.radius = 18.0
		cap.height = 70.0
		body.mesh = cap
		body.position = Vector3(0, 35.0, 0)
		var bmat := StandardMaterial3D.new()
		bmat.albedo_color = TEAM_COLORS[team]
		body.material_override = bmat
		root.add_child(body)
	return root


func _normalize_model(model: Node3D) -> void:
	var root := model.get_parent() as Node3D
	if root == null:
		return
	var inv := root.global_transform.affine_inverse()
	var box := AABB()
	var first := true
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m3 := mi as MeshInstance3D
		var local := inv * m3.global_transform
		var b: AABB = local * m3.get_aabb()
		box = b if first else box.merge(b)
		first = false
	if box.size.y <= 0.001:
		return
	var s := PIECE_HEIGHT / box.size.y
	model.scale = Vector3(s, s, s)
	var c := box.get_center()
	model.position = Vector3(-c.x * s, -box.position.y * s, -c.z * s)


# ---------------------------------------------------------------- 相机控制

func _update_camera() -> void:
	var offset := Vector3(
		cos(cam_pitch) * sin(cam_yaw),
		sin(cam_pitch),
		cos(cam_pitch) * cos(cam_yaw)
	) * cam_dist
	camera.position = cam_target + offset
	camera.look_at(cam_target, Vector3.UP)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam_dist = clampf(cam_dist * 0.9, 420.0, 4200.0)
			_update_camera()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_dist = clampf(cam_dist * 1.1, 420.0, 4200.0)
			_update_camera()
		elif event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE:
			dragging = event.pressed
	elif event is InputEventMouseMotion and dragging:
		cam_yaw -= event.relative.x * 0.008
		cam_pitch = clampf(cam_pitch + event.relative.y * 0.006, deg_to_rad(12.0), deg_to_rad(88.0))
		_update_camera()
	elif event is InputEventScreenDrag:
		cam_yaw -= event.relative.x * 0.01
		cam_pitch = clampf(cam_pitch + event.relative.y * 0.008, deg_to_rad(12.0), deg_to_rad(88.0))
		_update_camera()


# ---------------------------------------------------------------- 棋盘工具

func _pt_pos(name: String) -> Vector3:
	if not pts.has(name):
		return Vector3(0, BOARD_Y, 0)
	var p: Array = pts[name]
	return Vector3(p[0], BOARD_Y, p[2])


func _path_point(team: int, cell: int) -> String:
	return paths[team][clampi(cell, 0, FIELDS - 1)]


func _piece_cell_pos(p: Dictionary) -> Vector3:
	if p["cell"] < 0:
		return _pt_pos("HM%d_%d" % [p["team"] + 1, p["idx"] + 1])
	return _pt_pos(_path_point(p["team"], p["cell"]))


func _goal_pos(team: int, slot: int) -> Vector3:
	return _pt_pos("GL%d_%d" % [team + 1, clampi(slot, 1, 4)])


# ---------------------------------------------------------------- 回合逻辑

func _legal_moves(dice: int) -> Array:
	var out: Array = []
	var team := current_team
	for i in range(pieces.size()):
		var p: Dictionary = pieces[i]
		if p["team"] != team or p["finished"]:
			continue
		if p["cell"] < 0:
			if dice == 6:
				out.append(i)
		elif p["cell"] + dice <= FIELDS - 1:
			out.append(i)
	return out


func _on_roll_pressed() -> void:
	if busy or game_over or awaiting_pick:
		return
	_do_roll()


func _do_roll() -> void:
	busy = true
	var dice := randi_range(1, 6)
	dice_label.text = "点数  %d" % dice
	if dice_player and dice_player.stream:
		dice_player.play()
	_log("%s 掷出 %d 点" % [TEAM_NAMES[current_team], dice])
	_update_hud()
	var legal := _legal_moves(dice)
	await get_tree().create_timer(0.35).timeout
	if legal.is_empty():
		_log("没有可以移动的棋子")
		await get_tree().create_timer(0.6).timeout
		_finish_turn(dice == 6)
		return
	if legal.size() == 1:
		await _move_piece(legal[0], dice)
		return
	if auto_mode:
		await get_tree().create_timer(0.2).timeout
		await _move_piece(legal[0], dice)
		return
	awaiting_pick = true
	_show_pick_buttons(legal, dice)
	_update_hud()


func _show_pick_buttons(legal: Array, dice: int) -> void:
	_clear_pick()
	for i in legal:
		var p: Dictionary = pieces[i]
		var b := Button.new()
		b.text = "棋子 %d" % (p["idx"] + 1)
		b.custom_minimum_size = Vector2(110, 44)
		b.modulate = TEAM_COLORS[p["team"]]
		b.pressed.connect(_on_pick.bind(i, dice))
		pick_box.add_child(b)
	pick_box.visible = true


func _on_pick(idx: int, dice: int) -> void:
	if not awaiting_pick:
		return
	awaiting_pick = false
	_clear_pick()
	_update_hud()
	await _move_piece(idx, dice)


func _clear_pick() -> void:
	if pick_box == null:
		return
	for c in pick_box.get_children():
		c.queue_free()
	pick_box.visible = false


func _move_piece(idx: int, dice: int) -> void:
	var p: Dictionary = pieces[idx]
	var had_capture := false
	if p["cell"] < 0:
		p["cell"] = 0
		await _hop_to(p, _piece_cell_pos(p))
	else:
		for _s in range(dice):
			p["cell"] += 1
			await _hop_to(p, _piece_cell_pos(p))

	had_capture = _resolve_capture(p)
	if p["cell"] == FIELDS - 1:
		await _finish_piece(p)
	_log("%s 棋子 %d 走到 %s" % [TEAM_NAMES[p["team"]], p["idx"] + 1, _path_point(p["team"], p["cell"])])
	if p["finished"]:
		_log("%s 棋子 %d 抵达终点" % [TEAM_NAMES[p["team"]], p["idx"] + 1])
	_finish_turn(dice == 6 or had_capture)


func _resolve_capture(p: Dictionary) -> bool:
	var cell_name := _path_point(p["team"], p["cell"])
	var captured := false
	for q in pieces:
		if q["team"] == p["team"] or q["finished"] or q["cell"] < 0:
			continue
		if _path_point(q["team"], q["cell"]) == cell_name:
			q["cell"] = -1
			q["node"].position = _pt_pos("HM%d_%d" % [q["team"] + 1, q["idx"] + 1])
			captured = true
			_log("%s 吃掉了 %s 的棋子 %d" % [TEAM_NAMES[p["team"]], TEAM_NAMES[q["team"]], q["idx"] + 1])
	return captured


func _finish_piece(p: Dictionary) -> void:
	p["finished"] = true
	var slot := 1
	for q in pieces:
		if q["team"] == p["team"] and q["finished"] and q["idx"] != p["idx"]:
			slot += 1
	await _hop_to(p, _goal_pos(p["team"], slot))
	var done := true
	for q in pieces:
		if q["team"] == p["team"] and not q["finished"]:
			done = false
	if done:
		game_over = true
		winner = p["team"]
		_log("★ %s 全部棋子到达终点，获胜！" % TEAM_NAMES[winner])


func _hop_to(p: Dictionary, target: Vector3) -> void:
	var node: Node3D = p["node"]
	var d := target - node.position
	d.y = 0
	if d.length() > 1.0:
		node.rotation.y = atan2(-d.z, d.x)
	var t := create_tween()
	t.tween_property(node, "position", node.position + Vector3(0, 36, 0), 0.08)
	t.tween_property(node, "position", target, 0.1)
	await t.finished


func _finish_turn(extra: bool) -> void:
	busy = false
	awaiting_pick = false
	if game_over:
		_update_hud()
		return
	if extra:
		_log("%s 掷出 6 点，再掷一次" % TEAM_NAMES[current_team])
	else:
		current_team = (current_team + 1) % 4
	_update_hud()


# ---------------------------------------------------------------- UI

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "PingFang SC", "Noto Sans CJK SC", "Heiti SC", "Sans-Serif"])
	theme.default_font = font
	theme.default_font_size = 19
	root.theme = theme

	# 左上标题
	var panel := PanelContainer.new()
	panel.position = Vector2(18, 16)
	panel.custom_minimum_size = Vector2(300, 0)
	root.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)
	var title := Label.new()
	title.text = "骑士飞行棋 3"
	title.add_theme_font_size_override("font_size", 26)
	vb.add_child(title)
	var sub := Label.new()
	sub.text = "经典布局 · 经典模式 · 4 人本地"
	sub.add_theme_font_size_override("font_size", 14)
	sub.modulate = Color(1, 1, 1, 0.7)
	vb.add_child(sub)
	turn_label = Label.new()
	turn_label.text = "当前回合：红队"
	vb.add_child(turn_label)
	dice_label = Label.new()
	dice_label.text = "点数  -"
	vb.add_child(dice_label)

	# 右上消息
	var log_panel := PanelContainer.new()
	log_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	log_panel.position = Vector2(-392, 16)
	log_panel.custom_minimum_size = Vector2(374, 0)
	root.add_child(log_panel)
	var lvb := VBoxContainer.new()
	log_panel.add_child(lvb)
	var lt := Label.new()
	lt.text = "战报"
	lt.add_theme_font_size_override("font_size", 15)
	lt.modulate = Color(1, 1, 1, 0.6)
	lvb.add_child(lt)
	msg_label = Label.new()
	msg_label.text = ""
	msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg_label.custom_minimum_size = Vector2(350, 120)
	msg_label.add_theme_font_size_override("font_size", 15)
	lvb.add_child(msg_label)

	# 底部操作栏
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.position.y = -70
	bar.add_theme_constant_override("separation", 12)
	root.add_child(bar)

	var cam_l := Button.new()
	cam_l.text = "◀ 转"
	cam_l.custom_minimum_size = Vector2(64, 46)
	cam_l.pressed.connect(func(): cam_yaw += 0.25; _update_camera())
	bar.add_child(cam_l)

	var cam_r := Button.new()
	cam_r.text = "转 ▶"
	cam_r.custom_minimum_size = Vector2(64, 46)
	cam_r.pressed.connect(func(): cam_yaw -= 0.25; _update_camera())
	bar.add_child(cam_r)

	var zoom_in := Button.new()
	zoom_in.text = "＋"
	zoom_in.custom_minimum_size = Vector2(52, 46)
	zoom_in.pressed.connect(func(): cam_dist = clampf(cam_dist * 0.85, 420, 4200); _update_camera())
	bar.add_child(zoom_in)

	var zoom_out := Button.new()
	zoom_out.text = "－"
	zoom_out.custom_minimum_size = Vector2(52, 46)
	zoom_out.pressed.connect(func(): cam_dist = clampf(cam_dist * 1.18, 420, 4200); _update_camera())
	bar.add_child(zoom_out)

	roll_button = Button.new()
	roll_button.text = "掷骰子"
	roll_button.custom_minimum_size = Vector2(180, 52)
	roll_button.add_theme_font_size_override("font_size", 22)
	roll_button.pressed.connect(_on_roll_pressed)
	bar.add_child(roll_button)

	var restart := Button.new()
	restart.text = "重新开始"
	restart.custom_minimum_size = Vector2(120, 46)
	restart.pressed.connect(func(): get_tree().reload_current_scene())
	bar.add_child(restart)

	# 选子按钮行
	pick_box = HBoxContainer.new()
	pick_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	pick_box.position = Vector2(-200, -136)
	pick_box.custom_minimum_size = Vector2(400, 0)
	pick_box.alignment = BoxContainer.ALIGNMENT_CENTER
	pick_box.add_theme_constant_override("separation", 10)
	pick_box.visible = false
	root.add_child(pick_box)


func _update_hud() -> void:
	if turn_label == null:
		return
	if game_over:
		turn_label.text = "%s 获胜！" % TEAM_NAMES[winner]
		turn_label.modulate = TEAM_COLORS[winner] if winner >= 0 else Color.WHITE
	else:
		turn_label.text = "当前回合：%s" % TEAM_NAMES[current_team]
		turn_label.modulate = TEAM_COLORS[current_team]
	roll_button.disabled = busy or game_over or awaiting_pick


func _log(text: String) -> void:
	log_lines.append(text)
	while log_lines.size() > 7:
		log_lines.pop_front()
	if msg_label != null:
		msg_label.text = "\n".join(log_lines)


# ---------------------------------------------------------------- 自动 / 截图

func _auto_play() -> void:
	for i in range(24):
		await get_tree().create_timer(0.25).timeout
		if game_over:
			break
		if busy:
			await get_tree().create_timer(0.4).timeout
			continue
		await _do_roll()


func _take_screenshot() -> void:
	for i in range(20):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(shot_path)
	print("screenshot saved: ", shot_path)
	get_tree().quit()
