extends Node3D
## 骑士飞行棋 3 · 2026 重制版
## 场景：程序化天空竞技场（Arena.gd） / 界面：Hud.gd
## 规则：40 格环道 · 掷 6 出基地 · 精确终点 · 安全格 · 宝箱随机事件
##       8 种道具 · 三套主题 · 三档 AI · 1v3 人机 / 4 人热座

const TEAM_NAMES := ["红队", "蓝队", "绿队", "黄队"]
const TEAM_COLORS := [Color("e0503f"), Color("3d8ae0"), Color("3fb96a"), Color("e0a92f")]
const FIELDS := 40
const PIECES_PER_TEAM := 4
const BOARD_Y := 8.0

const ITEM_NAMES := {
	"boost": "加速", "shield": "护盾", "warp": "跃迁", "snipe": "狙击",
	"swap": "换位", "freeze": "冰冻", "double": "双倍", "teleport": "传送",
	"moonstep": "月影跃步", "frostlock": "极寒锁链", "inferno": "熔火冲锋",
}
const ITEM_DESC := {
	"boost": "本回合点数 +2", "shield": "免疫一次吃子", "warp": "前进 3 格",
	"snipe": "击退对手 3 格", "swap": "与对手交换位置", "freeze": "对手停一轮",
	"double": "本回合点数 ×2", "teleport": "前进 5 格",
	"moonstep": "前进 2 格并获得护盾", "frostlock": "对手后退 2 格并冻结",
	"inferno": "前进 4 格，落点附近对手全被炸退",
}
const ITEM_COLORS := {
	"boost": Color("ff9a3c"), "shield": Color("6cc6ff"), "warp": Color("b484ff"),
	"snipe": Color("ff5566"), "swap": Color("ffd166"), "freeze": Color("7fe6ff"),
	"double": Color("ffe066"), "teleport": Color("7cf0a8"),
	"moonstep": Color("cfd8ff"), "frostlock": Color("a8e6ff"), "inferno": Color("ff7a3c"),
}
## 共同道具池 + 每个主题的独占道具
const ITEM_POOL := ["boost", "shield", "warp", "snipe", "swap", "freeze", "double", "teleport"]
const THEME_ITEM := {
	"dusk": "moonstep", "frost": "frostlock", "ember": "inferno",
}

const EVENT_TITLES := {
	"treasure": "秘 宝", "meteor": "陨 石", "tailwind": "顺 风", "trap": "陷 阱",
	"portal": "传送门", "chaos": "混 沌", "bless": "祝 福",
	"starlight": "星辉之赐", "blizzard": "暴风雪", "eruption": "火山喷发",
}
const EVENT_COLORS := {
	"treasure": Color("ffd166"), "meteor": Color("ff6a3c"), "tailwind": Color("7cf0a8"),
	"trap": Color("ff5566"), "portal": Color("b484ff"), "chaos": Color("ff8ce0"),
	"bless": Color("6cc6ff"),
	"starlight": Color("e8ecff"), "blizzard": Color("a8e6ff"), "eruption": Color("ff8a3c"),
}
const EVENT_POOL := ["treasure", "meteor", "tailwind", "trap", "portal", "chaos", "bless"]
## 每个主题额外加入的独占事件
const THEME_EVENT := {
	"dusk": "starlight", "frost": "blizzard", "ember": "eruption",
}

var data: Dictionary = {}
var pts: Dictionary = {}
var paths: Array = []
var ring_index: Dictionary = {}
var pieces: Array = []

var arena: Arena
var hud: Hud

var current_team := 0
var busy := false
var awaiting_pick := false
var game_over := false
var winner := -1
var auto_mode := false
var shot_path := ""
var showcase := false
var menu_mode := false

var match_started := false
var game_mode := 0
var ai_level := 1
var theme_id := "dusk"
var human_teams: Array = [0]
var cards: Array = [[], [], [], []]
var captures: Array = [0, 0, 0, 0]
var rolls: Array = [0, 0, 0, 0]
var frozen: Array = [0, 0, 0, 0]
var boost_pending := -1
var double_team := -1
var last_dice := 0
var pending_total := 0
var card_mode := ""
var card_slot := -1
var card_stage := 0
var card_self := -1
var _pick_pool: Array = []

# 相机
var cam_yaw := deg_to_rad(34.0)
var cam_pitch := deg_to_rad(52.0)
var cam_dist := 2780.0
var cam_target := Vector3(0, -60, 0)
var camera: Camera3D
var dragging := false
var _touches: Dictionary = {}
var _pinch_dist := 0.0
var _using_touch := false

var dice_player: AudioStreamPlayer
var click_player: AudioStreamPlayer
var nope_player: AudioStreamPlayer
var ambient: AudioStreamPlayer


func _ready() -> void:
	var all_args: Array = []
	all_args.append_array(OS.get_cmdline_args())
	all_args.append_array(OS.get_cmdline_user_args())
	print("args: ", all_args)
	for a in all_args:
		if a.begins_with("--shot="):
			shot_path = a.substr(7)
		elif a.begins_with("--theme="):
			theme_id = a.substr(8)
		elif a == "--auto":
			auto_mode = true
		elif a == "--showcase":
			showcase = true
		elif a == "--menu":
			menu_mode = true

	_load_data()
	_setup_world()
	_setup_camera()
	_setup_audio()
	_spawn_pieces()
	_setup_hud()

	if (auto_mode or shot_path != "") and not menu_mode:
		_start_match(0, 1, theme_id)
		hud.hide_start()
		if showcase:
			_setup_showcase()
	else:
		hud.show_start()

	if auto_mode:
		_auto_play()
	if shot_path != "":
		# 截图调试：--menuopen 展开左上角控制台
		if all_args.has("--menuopen"):
			hud._toggle_menu()
		if all_args.has("--logopen"):
			hud._toggle_log()
		await _take_screenshot()


# ---------------------------------------------------------------- 数据 / 世界

func _load_data() -> void:
	var f := FileAccess.open("res://assets/data/board.json", FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed == null:
		push_error("board.json 解析失败")
		return
	data = parsed
	pts = data["points"]
	for i in 4:
		paths.append(data["paths"]["TEAMPATH%d" % (i + 1)])
	var ring: Array = paths[0]
	for i in ring.size():
		ring_index[ring[i]] = i


func _setup_world() -> void:
	arena = Arena.new()
	arena.name = "Arena"
	add_child(arena)
	arena.build(pts, paths[0], TEAM_COLORS, theme_id)


func _setup_camera() -> void:
	camera = Camera3D.new()
	camera.fov = 36.0
	camera.near = 2.0
	camera.far = 14000.0
	add_child(camera)
	_update_camera()


func _update_camera() -> void:
	var offset := Vector3(
		cos(cam_pitch) * sin(cam_yaw),
		sin(cam_pitch),
		cos(cam_pitch) * cos(cam_yaw)
	) * cam_dist
	camera.position = cam_target + offset
	camera.look_at(cam_target, Vector3.UP)


func _setup_audio() -> void:
	dice_player = _make_player("res://assets/sounds/dice_move.wav", -3.0)
	click_player = _make_player("res://assets/sounds/button_click.wav", -8.0)
	nope_player = _make_player("res://assets/sounds/cant_move.wav", -8.0)
	ambient = _make_player("res://assets/sounds/ambient.ogg", -22.0)
	if ambient.stream is AudioStreamOggVorbis:
		(ambient.stream as AudioStreamOggVorbis).loop = true
	if ambient.stream != null:
		ambient.play()


func _make_player(path: String, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	p.volume_db = db
	add_child(p)
	return p


func _play(p: AudioStreamPlayer) -> void:
	if p and p.stream:
		p.play()


func _spawn_pieces() -> void:
	for t in 4:
		for i in PIECES_PER_TEAM:
			var node := arena.make_piece(t)
			node.name = "P%d_%d" % [t + 1, i + 1]
			arena.add_child(node)
			node.position = _pt_pos("HM%d_%d" % [t + 1, i + 1])
			pieces.append({
				"team": t, "idx": i, "cell": -1, "finished": false,
				"shield": false, "node": node,
			})


func _setup_hud() -> void:
	hud = Hud.new()
	add_child(hud)
	hud.roll_pressed.connect(_on_roll_pressed)
	hud.restart_pressed.connect(func(): get_tree().reload_current_scene())
	hud.home_pressed.connect(func(): get_tree().reload_current_scene())
	hud.card_pressed.connect(_on_card_pressed)
	hud.piece_pressed.connect(_on_piece_pressed)
	hud.start_pressed.connect(_start_match)
	hud.theme_previewed.connect(func(id: String): arena.set_theme(id))
	hud.theme_selected.connect(func(id: String):
		theme_id = id
		arena.set_theme(id))
	hud.sound_toggled.connect(func(on: bool): AudioServer.set_bus_mute(0, not on))


# ---------------------------------------------------------------- 对局管理

func _start_match(mode: int, level: int, selected_theme: String) -> void:
	game_mode = mode
	ai_level = level
	theme_id = selected_theme
	arena.set_theme(theme_id)
	human_teams = [0] if mode == 0 else [0, 1, 2, 3]
	match_started = true
	game_over = false
	winner = -1
	busy = false
	awaiting_pick = false
	card_mode = ""
	card_slot = -1
	card_stage = 0
	card_self = -1
	_pick_pool = []
	boost_pending = -1
	double_team = -1
	frozen = [0, 0, 0, 0]
	last_dice = 0
	current_team = 0
	cards = [[], [], [], []]
	captures = [0, 0, 0, 0]
	rolls = [0, 0, 0, 0]
	for p in pieces:
		p["cell"] = -1
		p["finished"] = false
		p["shield"] = false
		p["node"].scale = Vector3.ONE
		p["node"].position = _pt_pos("HM%d_%d" % [p["team"] + 1, p["idx"] + 1])
		arena.remove_shield(p["node"])
	arena.clear_marks()
	arena.clear_piece_marks()
	arena.clear_movable()
	arena.clear_selection()
	if hud:
		hud.hide_win()
		hud.hide_pick()
		hud.set_dice(0)
	_update_all()
	_log("———— 新对局 ————")
	_log("主题：%s" % ["暮色竞技场", "霜封荒原", "熔火深渊"][["dusk", "frost", "ember"].find(theme_id)])
	_log("掷出 6 点出基地，精确点数进终点")
	if mode == 0:
		_log("AI 难度：%s" % ["简单", "普通", "困难"][ai_level])
	_maybe_ai_turn()


func _reset_view() -> void:
	cam_yaw = deg_to_rad(34.0)
	cam_pitch = deg_to_rad(52.0)
	cam_dist = 2780.0
	cam_target = Vector3(0, -60, 0)
	_update_camera()


# ---------------------------------------------------------------- 棋盘工具

func _pt_pos(name: String) -> Vector3:
	if not pts.has(name):
		return Vector3(0, BOARD_Y, 0)
	var p: Array = pts[name]
	return Vector3(float(p[0]), BOARD_Y, float(p[2]))


func _path_point(team: int, cell: int) -> String:
	return paths[team][clampi(cell, 0, FIELDS - 1)]


func _piece_cell_pos(p: Dictionary) -> Vector3:
	if p["cell"] < 0:
		return _pt_pos("HM%d_%d" % [p["team"] + 1, p["idx"] + 1])
	return _pt_pos(_path_point(p["team"], p["cell"]))


func _goal_pos(team: int, slot: int) -> Vector3:
	return _pt_pos("GL%d_%d" % [team + 1, clampi(slot, 1, 4)])


func _is_ai(team: int) -> bool:
	return not (team in human_teams)


func _team_display(team: int) -> String:
	return TEAM_NAMES[team] + ("（AI）" if _is_ai(team) else "")


func _ring_idx(p: Dictionary) -> int:
	if p["cell"] < 0:
		return -1
	return int(ring_index.get(_path_point(p["team"], p["cell"]), -1))


func _team_progress(team: int) -> int:
	var best := -1
	for p in pieces:
		if p["team"] == team and not p["finished"] and p["cell"] > best:
			best = p["cell"]
	return best


# ---------------------------------------------------------------- 规则

func _legal_moves(total: int) -> Array:
	var out: Array = []
	for i in pieces.size():
		var p: Dictionary = pieces[i]
		if p["team"] != current_team or p["finished"]:
			continue
		if p["cell"] < 0:
			if total == 6:
				out.append(i)
		elif p["cell"] + total <= FIELDS - 1:
			out.append(i)
	return out


func _is_safe_cell(cell: int) -> bool:
	return cell >= 0 and cell % 10 == 0


func _is_treasure_cell(cell: int) -> bool:
	return cell >= 0 and cell % 10 == 5


func _resolve_capture(p: Dictionary) -> bool:
	if _is_safe_cell(p["cell"]):
		return false
	var point := _path_point(p["team"], p["cell"])
	var hit_any := false
	for q in pieces:
		if q["team"] == p["team"] or q["finished"] or q["cell"] < 0:
			continue
		if _path_point(q["team"], q["cell"]) != point:
			continue
		hit_any = true
		if q["shield"]:
			q["shield"] = false
			arena.remove_shield(q["node"])
			_log("%s 的护盾挡下了攻击" % TEAM_NAMES[q["team"]])
			arena.pulse(q["node"].position, Color("8fe6ff"))
			continue
		var pos: Vector3 = q["node"].position
		q["cell"] = -1
		q["node"].position = _pt_pos("HM%d_%d" % [q["team"] + 1, q["idx"] + 1])
		arena.capture_blast(pos, TEAM_COLORS[q["team"]])
		arena.piece_celebrate(p["node"])
		hud.screen_flash(TEAM_COLORS[p["team"]], 0.30)
		_shake(0.34, 20.0)
		captures[p["team"]] += 1
		_log("%s 吃掉了 %s 的 %d 号棋子" % [TEAM_NAMES[p["team"]], TEAM_NAMES[q["team"]], q["idx"] + 1])
		# 吃子奖励：抽一张道具卡
		if cards[p["team"]].size() < 4:
			_draw_card(p["team"], false, Vector3(pos.x, BOARD_Y, pos.z))
	if hit_any:
		_play(click_player)
	return hit_any


func _advance(p: Dictionary, steps: int) -> bool:
	if p["cell"] < 0:
		p["cell"] = 0
		await _hop_to(p, _piece_cell_pos(p))
		arena.pulse(_piece_cell_pos(p), TEAM_COLORS[p["team"]])
	else:
		for _i in steps:
			if p["cell"] >= FIELDS - 1:
				break
			p["cell"] += 1
			await _hop_to(p, _piece_cell_pos(p))
	var captured := _resolve_capture(p)
	arena.pulse(_piece_cell_pos(p), TEAM_COLORS[p["team"]])
	if p["cell"] == FIELDS - 1:
		await _finish_piece(p)
	return captured


func _finish_piece(p: Dictionary) -> void:
	var done := 0
	for q in pieces:
		if q["team"] == p["team"] and q["finished"] and q["idx"] != p["idx"]:
			done += 1
	p["finished"] = true
	var slot := PIECES_PER_TEAM - done
	var pos := _goal_pos(p["team"], slot)
	await _hop_to(p, pos)
	arena.flash_piece(p["node"])
	arena.pulse(pos, TEAM_COLORS[p["team"]])
	arena.finish_beam(pos, TEAM_COLORS[p["team"]])
	_play(click_player)
	_log("%s 的 %d 号棋子抵达终点" % [TEAM_NAMES[p["team"]], p["idx"] + 1])


func _check_win(team: int) -> bool:
	for q in pieces:
		if q["team"] == team and not q["finished"]:
			return false
	game_over = true
	winner = team
	awaiting_pick = false
	_pick_pool = []
	arena.clear_marks()
	arena.clear_piece_marks()
	arena.clear_movable()
	arena.clear_selection()
	hud.show_win("%s 胜利" % TEAM_NAMES[team], TEAM_COLORS[team],
		"掷骰 %d 次 · 吃子 %d 次 · 抽卡 %d 张" % [rolls[team], captures[team], cards[team].size()])
	_log("★ %s 全部棋子到达终点，获胜！" % TEAM_NAMES[team])
	_update_all()
	return true


func _hop_to(p: Dictionary, target: Vector3) -> void:
	var node: Node3D = p["node"]
	var d := target - node.position
	d.y = 0.0
	if d.length() > 1.0:
		node.rotation.y = atan2(d.x, d.z)
	var t := create_tween()
	t.set_trans(Tween.TRANS_SINE)
	t.tween_property(node, "position", node.position + Vector3(0, 34, 0), 0.08)
	t.tween_property(node, "position", target, 0.08)
	await t.finished


# ---------------------------------------------------------------- 回合流程

func _on_roll_pressed() -> void:
	if busy or game_over or awaiting_pick or card_mode != "" or not match_started:
		return
	_do_roll()


func _do_roll() -> void:
	if busy or game_over or not match_started:
		return
	busy = true
	awaiting_pick = false
	card_mode = ""
	card_stage = 0
	_pick_pool = []
	hud.hide_pick()
	arena.clear_marks()
	arena.clear_piece_marks()
	arena.clear_movable()
	arena.clear_selection()
	hud.set_roll_enabled(false, "掷骰中…")
	_update_all()

	var raw := randi_range(1, 6)
	last_dice = raw
	rolls[current_team] += 1
	var total := raw
	if boost_pending == current_team:
		total += 2
		boost_pending = -1
	if double_team == current_team:
		total *= 2
		double_team = -1
	pending_total = total
	hud.set_dice(raw, total)
	_play(dice_player)
	_log("%s 掷出 %d 点%s" % [_team_display(current_team), raw,
		"（强化后 %d）" % total if total != raw else ""])
	await arena.roll_dice(raw)

	var legal := _legal_moves(total)
	if legal.is_empty():
		_play(nope_player)
		_log("没有可以移动的棋子")
		await get_tree().create_timer(0.7).timeout
		_finish_turn(raw == 6)
		return

	if legal.size() == 1:
		await _move_piece(legal[0], total)
		return

	if auto_mode:
		await get_tree().create_timer(0.15).timeout
		await _move_piece(_ai_choose(legal, total), total)
		return

	if _is_ai(current_team):
		var choice := _ai_choose(legal, total)
		await get_tree().create_timer(0.4).timeout
		await _move_piece(choice, total)
		return

	awaiting_pick = true
	_show_move_pick(legal, total)
	_update_all()


func _show_move_pick(legal: Array, total: int) -> void:
	var options: Array = []
	var dests: Array = []
	var nodes: Array = []
	for i in legal:
		var p: Dictionary = pieces[i]
		var label := ""
		if p["cell"] < 0:
			label = "%d号 · 基地出发" % (p["idx"] + 1)
		else:
			label = "%d号 · %d → %d" % [p["idx"] + 1, p["cell"] + 1, p["cell"] + total + 1]
		options.append({"index": i, "label": label, "color": TEAM_COLORS[p["team"]]})
		var dest: int = 0 if p["cell"] < 0 else int(p["cell"]) + total
		dests.append(_pt_pos(_path_point(p["team"], dest)))
		nodes.append(p["node"])
	_pick_pool = legal
	arena.mark_tiles(dests, TEAM_COLORS[current_team])
	arena.show_movable(nodes, TEAM_COLORS[current_team])
	hud.show_pick(options, "掷出 %d 点，点棋子或按钮选择" % total)


func _on_piece_pressed(idx: int) -> void:
	if card_mode != "":
		await _apply_card(idx)
		return
	if not awaiting_pick:
		return
	awaiting_pick = false
	_pick_pool = []
	hud.hide_pick()
	arena.clear_piece_marks()
	arena.clear_marks()
	arena.clear_movable()
	if idx >= 0 and idx < pieces.size():
		var p: Dictionary = pieces[idx]
		arena.select_piece(p["node"])
		await get_tree().create_timer(0.16).timeout
	arena.clear_selection()
	await _move_piece(idx, pending_total)


func _move_piece(idx: int, steps: int) -> void:
	var p: Dictionary = pieces[idx]
	var captured: bool = await _advance(p, steps)
	if not p["finished"]:
		# 安全区机制：踏入安全格自动获得一层护盾
		if not p["shield"] and _is_safe_cell(p["cell"]):
			p["shield"] = true
			arena.add_shield(p["node"])
			arena.item_cast(p["node"], Color("8fe6ff"), "shield")
			hud.show_item_toast("安全区", "踏入安全区，获得一层护盾", Color("8fe6ff"))
			_log("%s 的 %d 号棋子进入安全区，获得护盾" % [TEAM_NAMES[p["team"]], p["idx"] + 1])
		if _is_treasure_cell(p["cell"]):
			await _trigger_event(p)
		_check_win(p["team"])
	else:
		_check_win(p["team"])
	_update_all()
	if game_over:
		return
	_finish_turn(last_dice == 6 or captured)


func _finish_turn(extra: bool) -> void:
	busy = false
	awaiting_pick = false
	card_mode = ""
	card_stage = 0
	card_self = -1
	card_slot = -1
	_pick_pool = []
	boost_pending = -1
	double_team = -1
	hud.hide_pick()
	arena.clear_marks()
	arena.clear_piece_marks()
	arena.clear_movable()
	arena.clear_selection()
	if game_over:
		_update_all()
		return
	if extra:
		_log("%s 再掷一次" % _team_display(current_team))
	else:
		current_team = (current_team + 1) % 4
		_skip_frozen()
	hud.set_dice(0)
	_update_all()
	_maybe_ai_turn()


func _skip_frozen() -> void:
	var guard := 0
	while frozen[current_team] > 0 and guard < 8:
		frozen[current_team] -= 1
		guard += 1
		_log("%s 被冰冻，跳过本回合" % TEAM_NAMES[current_team])
		hud.show_event("冰 冻", "%s 本回合被冻结，无法行动" % TEAM_NAMES[current_team], Color("7fe6ff"))
		current_team = (current_team + 1) % 4


# ---------------------------------------------------------------- 道具卡

func _draw_card(team: int, quiet := false, at := Vector3(INF, INF, INF)) -> bool:
	if cards[team].size() >= 4:
		return false
	var pool: Array = ITEM_POOL.duplicate()
	var exclusive: String = THEME_ITEM.get(theme_id, "")
	if exclusive != "":
		pool.append(exclusive)
	var id: String = pool[randi() % pool.size()]
	cards[team].append(id)
	var col: Color = ITEM_COLORS.get(id, Color.WHITE)
	if at.is_finite():
		arena.item_pickup(Vector3(at.x, BOARD_Y, at.z), col)
		hud.screen_flash(col, 0.12)
	if not quiet:
		_log("%s 获得道具「%s」" % [TEAM_NAMES[team], ITEM_NAMES[id]])
		hud.show_item_toast("获得「%s」" % ITEM_NAMES[id], ITEM_DESC.get(id, ""), col)
	_play(click_player)
	_update_all()
	return true


func _on_card_pressed(slot: int) -> void:
	if busy or game_over or awaiting_pick or not match_started:
		return
	if _is_ai(current_team) or card_mode != "":
		return
	if slot < 0 or slot >= cards[current_team].size():
		return
	var id: String = cards[current_team][slot]
	if id == "boost" or id == "double" or id == "freeze":
		_use_instant_card(slot, id)
		return

	var pool: Array = []
	for i in pieces.size():
		var p: Dictionary = pieces[i]
		# 需要指定对手的道具
		if id == "snipe" or id == "frostlock":
			if p["team"] != current_team and not p["finished"] and p["cell"] >= 1:
				pool.append(i)
			continue
		if p["team"] != current_team or p["finished"] or p["cell"] < 0:
			continue
		var step := 0
		match id:
			"warp":
				step = 3
			"teleport":
				step = 5
			"moonstep":
				step = 2
			"inferno":
				step = 4
		if step > 0 and int(p["cell"]) + step > FIELDS - 1:
			continue
		pool.append(i)
	if pool.is_empty():
		_play(nope_player)
		_log("现在没有可以%s的棋子" % ITEM_NAMES[id])
		return
	_enter_card_pick(id, slot, pool, "选择要使用「%s」的棋子" % ITEM_NAMES[id])


func _use_instant_card(slot: int, id: String) -> void:
	var leader := _lead_piece(current_team)
	var c: Color = ITEM_COLORS.get(id, Color.WHITE)
	match id:
		"boost":
			if boost_pending == current_team:
				_log("本回合已经使用过加速")
				_play(nope_player)
				return
			cards[current_team].remove_at(slot)
			boost_pending = current_team
			hud.set_dice(last_dice, last_dice + 2 if last_dice > 0 else 0)
			_log("%s 使用「加速」，本回合点数 +2" % TEAM_NAMES[current_team])
		"double":
			if double_team == current_team:
				_play(nope_player)
				return
			cards[current_team].remove_at(slot)
			double_team = current_team
			_log("%s 使用「双倍」，本回合点数 ×2" % TEAM_NAMES[current_team])
		"freeze":
			var target := _most_dangerous_opponent(current_team)
			if target < 0:
				_play(nope_player)
				_log("没有可以冰冻的对手")
				return
			cards[current_team].remove_at(slot)
			frozen[target] = maxi(frozen[target], 1)
			_log("%s 使用「冰冻」，%s 下一回合被冻结" % [TEAM_NAMES[current_team], TEAM_NAMES[target]])
			hud.show_event("冰 冻", "%s 被冻结一轮" % TEAM_NAMES[target], Color("7fe6ff"))
			arena.set_active_team(current_team)
			var victim := _lead_piece(target)
			if victim >= 0:
				var vp: Dictionary = pieces[victim]
				arena.freeze_burst(Vector3(vp["node"].position.x, BOARD_Y, vp["node"].position.z), Color("9fe8ff"))
				arena.item_cast(vp["node"], Color("7fe6ff"), "freeze")
	if leader >= 0:
		var lp: Dictionary = pieces[leader]
		arena.item_cast(lp["node"], c, id)
		arena.piece_celebrate(lp["node"])
		hud.show_item_toast("使用「%s」" % ITEM_NAMES[id], ITEM_DESC.get(id, ""), c)
	hud.screen_flash(c, 0.20)
	_play(click_player)
	_update_all()
	if not game_over:
		_resume_after_card()


func _lead_piece(team: int) -> int:
	var best := -1
	var best_cell := -1
	for i in pieces.size():
		var p: Dictionary = pieces[i]
		if p["team"] != team or p["finished"]:
			continue
		if int(p["cell"]) > best_cell:
			best_cell = int(p["cell"])
			best = i
	return best


func _enter_card_pick(id: String, slot: int, pool: Array, hint: String) -> void:
	card_mode = id
	card_slot = slot
	card_stage = 0
	card_self = -1
	_pick_pool = pool
	_show_card_pick(pool, hint)
	busy = true
	hud.set_roll_enabled(false)
	_update_all()


func _show_card_pick(pool: Array, hint: String) -> void:
	var options: Array = []
	for i in pool:
		var p: Dictionary = pieces[i]
		var label := ""
		if card_mode == "swap" and card_stage == 1:
			label = "%s%d号 · 第 %d 格" % [TEAM_NAMES[p["team"]], p["idx"] + 1, p["cell"] + 1]
		elif p["team"] == current_team:
			label = "%d号 · 第 %d 格" % [p["idx"] + 1, p["cell"] + 1]
			var step := 0
			match card_mode:
				"warp":
					step = 3
				"teleport":
					step = 5
				"moonstep":
					step = 2
				"inferno":
					step = 4
			if step > 0 and int(p["cell"]) + step == FIELDS - 1:
				label += " · 直达终点"
		else:
			label = "%s%d号 · 第 %d 格" % [TEAM_NAMES[p["team"]], p["idx"] + 1, p["cell"] + 1]
		options.append({"index": i, "label": label, "color": TEAM_COLORS[p["team"]]})
		arena.mark_piece(p["node"])
	hud.show_pick(options, hint)


func _apply_card(idx: int) -> void:
	var p: Dictionary = pieces[idx]
	var id := card_mode

	# 换位：第一步先选自己的棋子，第二步选对手
	if id == "swap" and card_stage == 0:
		if p["team"] != current_team or p["finished"] or p["cell"] < 0:
			return
		card_self = idx
		card_stage = 1
		var pool: Array = []
		for i in pieces.size():
			var q: Dictionary = pieces[i]
			if q["team"] == current_team or q["finished"] or q["cell"] < 0:
				continue
			pool.append(i)
		if pool.is_empty():
			_log("没有可以换位的对手棋子")
			_cancel_card()
			return
		_pick_pool = pool
		arena.clear_piece_marks()
		arena.select_piece(p["node"])
		_show_card_pick(pool, "再选择一名对手棋子进行换位")
		return

	if id == "snipe":
		if p["team"] == current_team or p["finished"] or p["cell"] < 0:
			return
	elif id != "swap":
		if p["team"] != current_team or p["finished"] or p["cell"] < 0:
			return

	var slot := card_slot
	card_mode = ""
	card_stage = 0
	card_self = -1
	card_slot = -1
	_pick_pool = []
	hud.hide_pick()
	arena.clear_piece_marks()
	arena.clear_selection()
	busy = false
	if slot >= 0 and slot < cards[current_team].size():
		cards[current_team].remove_at(slot)

	match id:
		"shield":
			p["shield"] = true
			arena.add_shield(p["node"])
			arena.flash_piece(p["node"])
			arena.item_cast(p["node"], Color("6cc6ff"), "shield")
			hud.show_item_toast("使用「护盾」", ITEM_DESC.get("shield", ""), Color("6cc6ff"))
			hud.screen_flash(Color("6cc6ff"), 0.2)
			_log("%s 的 %d 号棋子获得护盾" % [TEAM_NAMES[p["team"]], p["idx"] + 1])
			_play(click_player)
			_update_all()
			return
		"warp", "teleport":
			var steps := 3 if id == "warp" else 5
			var captured: bool = await _advance(p, steps)
			arena.item_cast(p["node"], ITEM_COLORS[id], id)
			arena.piece_celebrate(p["node"])
			hud.show_item_toast("使用「%s」" % ITEM_NAMES[id], ITEM_DESC.get(id, ""), ITEM_COLORS[id])
			hud.screen_flash(ITEM_COLORS[id], 0.24)
			_shake(0.2, 10.0)
			_log("%s 的 %d 号棋子%s %d 格" % [TEAM_NAMES[p["team"]], p["idx"] + 1,
				"跃迁" if id == "warp" else "传送", steps])
			if captured:
				_log("落点吃掉了对手")
			_check_win(p["team"])
			_update_all()
			if not game_over:
				_finish_turn(false)
			return
		"snipe":
			var back := mini(3, int(p["cell"]))
			p["cell"] -= back
			arena.piece_hit(p["node"])
			await _hop_to(p, _piece_cell_pos(p))
			var origin := -1
			for i in pieces.size():
				var q0: Dictionary = pieces[i]
				if q0["team"] == current_team and not q0["finished"] and q0["cell"] >= 0:
					origin = i
					break
			if origin >= 0:
				var src: Dictionary = pieces[origin]
				arena.snipe_streak(src["node"].position, p["node"].position, Color("ff5566"))
			arena.item_cast(p["node"], Color("ff5566"), "snipe")
			arena.freeze_burst(Vector3(p["node"].position.x, BOARD_Y, p["node"].position.z), Color("ff5566"))
			hud.show_item_toast("使用「狙击」", "击退 %s 的棋子 %d 格" % [TEAM_NAMES[p["team"]], back], Color("ff5566"))
			hud.screen_flash(Color("ff5566"), 0.28)
			_shake(0.24, 12.0)
			_log("%s 狙击 %s 的 %d 号棋子，击退 %d 格" % [TEAM_NAMES[current_team],
				TEAM_NAMES[p["team"]], p["idx"] + 1, back])
			_play(click_player)
			_update_all()
			_resume_after_card()
			return
		"swap":
			var mine: Dictionary = pieces[card_self]
			var my_cell: int = mine["cell"]
			var op_cell: int = p["cell"]
			mine["cell"] = op_cell
			p["cell"] = my_cell
			await _hop_to(mine, _piece_cell_pos(mine))
			await _hop_to(p, _piece_cell_pos(p))
			arena.event_ring(mine["node"].position, Color("ffd166"))
			arena.event_ring(p["node"].position, Color("ffd166"))
			arena.item_cast(mine["node"], Color("ffd166"), "swap")
			arena.item_cast(p["node"], Color("ffd166"), "swap")
			hud.show_item_toast("使用「换位」", "与 %s 的棋子交换了位置" % TEAM_NAMES[p["team"]], Color("ffd166"))
			hud.screen_flash(Color("ffd166"), 0.24)
			_shake(0.2, 10.0)
			_log("%s 与 %s 交换了棋子位置" % [TEAM_NAMES[current_team], TEAM_NAMES[p["team"]]])
			_play(click_player)
			_update_all()
			_resume_after_card()
			return
		"moonstep":
			var steps_m := mini(2, FIELDS - 1 - int(p["cell"]))
			var cap_m: bool = await _advance(p, steps_m)
			if not p["finished"] and not p["shield"]:
				p["shield"] = true
				arena.add_shield(p["node"])
			arena.item_cast(p["node"], Color("cfd8ff"), "moonstep")
			arena.piece_celebrate(p["node"])
			hud.show_item_toast("使用「月影跃步」", ITEM_DESC.get("moonstep", ""), Color("cfd8ff"))
			hud.screen_flash(Color("cfd8ff"), 0.22)
			_log("%s 的 %d 号棋子月影跃步前进 %d 格并获得护盾" % [
				TEAM_NAMES[p["team"]], p["idx"] + 1, steps_m])
			_check_win(p["team"])
			_update_all()
			if not game_over:
				_finish_turn(cap_m)
			return
		"frostlock":
			var back_f := mini(2, int(p["cell"]))
			p["cell"] = int(p["cell"]) - back_f
			arena.piece_hit(p["node"])
			await _hop_to(p, _piece_cell_pos(p))
			arena.freeze_burst(Vector3(p["node"].position.x, BOARD_Y, p["node"].position.z), Color("a8e6ff"))
			arena.item_cast(p["node"], Color("a8e6ff"), "frostlock")
			frozen[p["team"]] = maxi(frozen[p["team"]], 1)
			hud.show_item_toast("使用「极寒锁链」", "击退并冻结 %s" % TEAM_NAMES[p["team"]], Color("a8e6ff"))
			hud.screen_flash(Color("a8e6ff"), 0.24)
			_shake(0.2, 9.0)
			_log("%s 用极寒锁链击退 %s 的棋子，并冻结其队伍" % [TEAM_NAMES[current_team], TEAM_NAMES[p["team"]]])
			_play(click_player)
			_update_all()
			_resume_after_card()
			return
		"inferno":
			var steps_i := mini(4, FIELDS - 1 - int(p["cell"]))
			var cap_i: bool = await _advance(p, steps_i)
			arena.item_cast(p["node"], Color("ff7a3c"), "inferno")
			hud.screen_flash(Color("ff7a3c"), 0.34)
			_shake(0.34, 22.0)
			var ti := _ring_idx(p)
			var hit := 0
			for q in pieces:
				if q["team"] == current_team or q["finished"] or q["cell"] < 0:
					continue
				var qi := _ring_idx(q)
				if qi < 0 or ti < 0:
					continue
				var gap := absi(qi - ti)
				gap = mini(gap, FIELDS - gap)
				if gap > 2:
					continue
				var back_i := mini(2, int(q["cell"]))
				if back_i <= 0:
					continue
				q["cell"] = int(q["cell"]) - back_i
				arena.piece_hit(q["node"])
				await _hop_to(q, _piece_cell_pos(q))
				arena.capture_blast(Vector3(q["node"].position.x, BOARD_Y, q["node"].position.z), Color("ff7a3c"))
				hit += 1
			hud.show_item_toast("使用「熔火冲锋」", "冲锋 %d 格，炸退 %d 枚对手棋子" % [steps_i, hit], Color("ff7a3c"))
			_log("%s 的 %d 号棋子熔火冲锋 %d 格，炸退 %d 枚对手棋子" % [
				TEAM_NAMES[p["team"]], p["idx"] + 1, steps_i, hit])
			_check_win(p["team"])
			_update_all()
			if not game_over:
				_finish_turn(cap_i)
			return


func _cancel_card() -> void:
	card_mode = ""
	card_stage = 0
	card_self = -1
	card_slot = -1
	_pick_pool = []
	hud.hide_pick()
	arena.clear_piece_marks()
	arena.clear_selection()
	busy = false
	_update_all()


func _resume_after_card() -> void:
	busy = false
	_update_all()
	_maybe_ai_turn()


# ---------------------------------------------------------------- 随机事件

func _trigger_event(p: Dictionary) -> void:
	var pool: Array = EVENT_POOL.duplicate()
	var exclusive: String = THEME_EVENT.get(theme_id, "")
	if exclusive != "":
		pool.append(exclusive)
		pool.append(exclusive)
	var id: String = pool[randi() % pool.size()]
	var team: int = p["team"]
	var title: String = EVENT_TITLES[id]
	var color: Color = EVENT_COLORS[id]
	var desc := ""
	var pos: Vector3 = p["node"].position
	arena.event_ring(pos, color)
	arena.item_aura(p["node"], color)
	hud.screen_flash(color, 0.18)
	match id:
		"treasure":
			if _draw_card(team, true, Vector3(pos.x, BOARD_Y, pos.z)):
				desc = "%s 获得一张「%s」道具卡" % [TEAM_NAMES[team], ITEM_NAMES[cards[team][cards[team].size() - 1]]]
			else:
				desc = "%s 卡槽已满，秘宝化为金币" % TEAM_NAMES[team]
		"meteor":
			var moved := 0
			for q in pieces:
				if q["team"] == team or q["finished"] or q["cell"] < 0:
					continue
				var back := mini(2, int(q["cell"]))
				if back <= 0:
					continue
				q["cell"] -= back
				arena.piece_hit(q["node"])
				await _hop_to(q, _piece_cell_pos(q))
				arena.capture_blast(Vector3(q["node"].position.x, BOARD_Y, q["node"].position.z), color)
				moved += 1
			_shake(0.30, 18.0)
			desc = "陨石砸落，%d 枚对手棋子后退 2 格" % moved
		"tailwind":
			var before: int = p["cell"]
			await _event_move(p, 2)
			desc = "%s 的 %d 号棋子顺风前进 %d 格" % [TEAM_NAMES[team], p["idx"] + 1, int(p["cell"]) - before]
		"trap":
			var before2: int = p["cell"]
			await _event_move(p, -3)
			arena.piece_hit(p["node"])
			desc = "%s 的 %d 号棋子踩中陷阱，后退 %d 格" % [TEAM_NAMES[team], p["idx"] + 1, before2 - int(p["cell"])]
		"portal":
			var target := -1
			for c in range(int(p["cell"]) + 1, FIELDS):
				if _is_safe_cell(c):
					target = c
					break
			if target < 0:
				desc = "传送门黯淡无光，什么也没发生"
			else:
				var before3: int = p["cell"]
				p["cell"] = target
				arena.item_cast(p["node"], color, "teleport")
				await _hop_to(p, _piece_cell_pos(p))
				desc = "%s 的 %d 号棋子被传送到第 %d 格安全区（+%d）" % [TEAM_NAMES[team],
					p["idx"] + 1, target + 1, target - before3]
		"chaos":
			var moved2 := 0
			for q in pieces:
				if q["finished"] or q["cell"] < 0:
					continue
				var d := randi_range(-2, 2)
				if d == 0:
					continue
				var before4: int = q["cell"]
				q["cell"] = clampi(int(q["cell"]) + d, 0, FIELDS - 1)
				if q["cell"] == before4:
					continue
				await _hop_to(q, _piece_cell_pos(q))
				arena.pulse(q["node"].position, Color("ff8ce0"))
				moved2 += 1
			desc = "时空扭曲，%d 枚棋子被随机挪动" % moved2
		"bless":
			p["shield"] = true
			arena.add_shield(p["node"])
			var got := _draw_card(team, true, Vector3(pos.x, BOARD_Y, pos.z))
			arena.item_aura(p["node"], Color("6cc6ff"))
			desc = "%s 的 %d 号棋子获得护盾%s" % [TEAM_NAMES[team], p["idx"] + 1,
				"，并获得一张道具卡" if got else "（卡槽已满）"]
		"starlight":
			var moved0 := 0
			for q in pieces:
				if q["team"] != team or q["finished"] or q["cell"] < 0:
					continue
				var tgt := mini(int(q["cell"]) + 1, FIELDS - 1)
				if tgt == int(q["cell"]):
					continue
				q["cell"] = tgt
				arena.item_aura(q["node"], color)
				await _hop_to(q, _piece_cell_pos(q))
				if tgt == FIELDS - 1:
					await _finish_piece(q)
				moved0 += 1
			desc = "星辉洒落，%d 枚己方棋子前进 1 格" % moved0
		"blizzard":
			var movedb := 0
			for q in pieces:
				if q["team"] == team or q["finished"] or q["cell"] < 1:
					continue
				var backb := mini(3, int(q["cell"]))
				q["cell"] = int(q["cell"]) - backb
				arena.piece_hit(q["node"])
				arena.freeze_burst(Vector3(q["node"].position.x, BOARD_Y, q["node"].position.z), color)
				await _hop_to(q, _piece_cell_pos(q))
				movedb += 1
			_shake(0.26, 12.0)
			desc = "暴风雪横扫棋盘，%d 枚对手棋子后退 3 格" % movedb
		"eruption":
			var hitn := 0
			var idxs: Array = []
			for i in pieces.size():
				var q: Dictionary = pieces[i]
				if not q["finished"] and q["cell"] >= 0:
					idxs.append(i)
			idxs.shuffle()
			for k in mini(2, idxs.size()):
				var q2: Dictionary = pieces[idxs[k]]
				var back2 := mini(2, int(q2["cell"]))
				if back2 <= 0:
					continue
				q2["cell"] = int(q2["cell"]) - back2
				arena.capture_blast(Vector3(q2["node"].position.x, BOARD_Y, q2["node"].position.z), color)
				arena.piece_hit(q2["node"])
				await _hop_to(q2, _piece_cell_pos(q2))
				hitn += 1
			_shake(0.34, 20.0)
			desc = "火山喷发，%d 枚棋子被冲击波掀退 2 格" % hitn

	hud.show_event(title, desc, color)
	_log("【%s】%s" % [title.replace(" ", ""), desc])
	_play(click_player)
	await get_tree().create_timer(0.9).timeout

	# 事件可能把棋子送到终点
	if p["cell"] >= FIELDS - 1 and not p["finished"]:
		await _finish_piece(p)


func _event_move(p: Dictionary, delta: int) -> void:
	var target := clampi(int(p["cell"]) + delta, 0, FIELDS - 1)
	if target == p["cell"]:
		return
	p["cell"] = target
	await _hop_to(p, _piece_cell_pos(p))
	arena.pulse(p["node"].position, TEAM_COLORS[p["team"]])


func _most_dangerous_opponent(team: int) -> int:
	var best := -1
	var best_cell := -1
	for t in 4:
		if t == team:
			continue
		var prog := _team_progress(t)
		if prog > best_cell:
			best_cell = prog
			best = t
	return best


# ---------------------------------------------------------------- AI

func _ai_choose(legal: Array, total: int) -> int:
	if ai_level == 0:
		return legal[randi() % legal.size()]
	var best: int = legal[0]
	var best_score := -1.0e9
	var out_count := 0
	for q in pieces:
		if q["team"] == current_team and not q["finished"] and q["cell"] >= 0:
			out_count += 1
	for i in legal:
		var p: Dictionary = pieces[i]
		var start: int = p["cell"]
		var target := 0 if start < 0 else start + total
		var score := float(target) * 3.0
		if start < 0:
			score += 140.0 if out_count > 0 else 360.0
		if target == FIELDS - 1:
			score += 760.0
		if _is_safe_cell(target):
			score += 80.0
		if _is_treasure_cell(target):
			score += 45.0
		score += float(start) * 0.4
		var point := _path_point(p["team"], target)
		for q in pieces:
			if q["team"] == p["team"] or q["finished"] or q["cell"] < 0:
				continue
			if _path_point(q["team"], q["cell"]) == point and not _is_safe_cell(target):
				score += 1000.0
		if ai_level >= 2 and not _is_safe_cell(target):
			var ti: int = int(ring_index.get(point, -1))
			for q in pieces:
				if q["team"] == p["team"] or q["finished"] or q["cell"] < 0:
					continue
				if q["shield"]:
					continue
				var qi := _ring_idx(q)
				if qi < 0:
					continue
				var gap := (ti - qi + FIELDS) % FIELDS
				if gap >= 1 and gap <= 6:
					score -= 180.0
		if score > best_score:
			best_score = score
			best = i
	return best


func _maybe_ai_turn() -> void:
	if auto_mode or game_over or busy or not match_started or not _is_ai(current_team):
		return
	var team := current_team
	await get_tree().create_timer(0.65).timeout
	if game_over or busy or current_team != team or not _is_ai(current_team):
		return
	if ai_level >= 1:
		await _ai_cards()
	if game_over or busy or current_team != team or not _is_ai(current_team):
		return
	await get_tree().create_timer(0.25).timeout
	if game_over or busy or current_team != team:
		return
	await _do_roll()


func _ai_cards() -> void:
	var t := current_team
	if cards[t].is_empty():
		return
	# 冰冻：对手已经快到终点
	var fi: int = cards[t].find("freeze")
	if fi >= 0:
		var target := _most_dangerous_opponent(t)
		if target >= 0 and _team_progress(target) >= 30:
			cards[t].remove_at(fi)
			frozen[target] = maxi(frozen[target], 1)
			_log("%s 使用「冰冻」冻结 %s" % [TEAM_NAMES[t], TEAM_NAMES[target]])
			hud.show_event("冰 冻", "%s 被冻结一轮" % TEAM_NAMES[target], Color("7fe6ff"))
			_update_all()
			await get_tree().create_timer(0.35).timeout

	# 双倍 / 加速：有棋子接近终点时使用
	var near_goal := false
	for p in pieces:
		if p["team"] == t and not p["finished"] and p["cell"] >= 0 and FIELDS - 1 - int(p["cell"]) <= 12:
			near_goal = true
	var di: int = cards[t].find("double")
	if di >= 0 and (near_goal or ai_level >= 2):
		cards[t].remove_at(di)
		double_team = t
		_log("%s 使用「双倍」" % TEAM_NAMES[t])
		_update_all()
		await get_tree().create_timer(0.25).timeout
	var bi: int = cards[t].find("boost")
	if bi >= 0 and (near_goal or ai_level >= 2):
		cards[t].remove_at(bi)
		boost_pending = t
		_log("%s 使用「加速」" % TEAM_NAMES[t])
		_update_all()
		await get_tree().create_timer(0.25).timeout

	# 传送 / 跃迁 / 冲锋 / 月影：能直达终点或吃子
	for spec in [["teleport", 5], ["inferno", 4], ["warp", 3], ["moonstep", 2]]:
		var cid: String = spec[0]
		var step: int = spec[1]
		var si: int = cards[t].find(cid)
		if si < 0:
			continue
		var pick := -1
		var best := -1
		for i in pieces.size():
			var p: Dictionary = pieces[i]
			if p["team"] != t or p["finished"] or p["cell"] < 0:
				continue
			if p["cell"] + step > FIELDS - 1:
				continue
			var target2: int = int(p["cell"]) + step
			var point := _path_point(t, target2)
			var score: int = target2
			if target2 == FIELDS - 1:
				score += 500
			for q in pieces:
				if q["team"] == t or q["finished"] or q["cell"] < 0:
					continue
				if _path_point(q["team"], q["cell"]) == point and not _is_safe_cell(target2):
					score += 800
			if score > best:
				best = score
				pick = i
		if pick >= 0 and best >= FIELDS - 1:
			cards[t].remove_at(si)
			card_mode = cid
			card_slot = -2
			_log("%s 使用「%s」" % [TEAM_NAMES[t], ITEM_NAMES[cid]])
			await get_tree().create_timer(0.3).timeout
			await _apply_ai_displace(pick, step)
			return

	# 极寒锁链（霜封主题独占）：对手领跑时击退并冻结
	var fzi: int = cards[t].find("frostlock")
	if fzi >= 0:
		var victim := -1
		var victim_cell := 24
		for i in pieces.size():
			var q: Dictionary = pieces[i]
			if q["team"] == t or q["finished"] or q["cell"] < victim_cell:
				continue
			victim_cell = q["cell"]
			victim = i
		if victim >= 0:
			cards[t].remove_at(fzi)
			_log("%s 使用「极寒锁链」" % TEAM_NAMES[t])
			var vp: Dictionary = pieces[victim]
			var back_f := mini(2, int(vp["cell"]))
			vp["cell"] = int(vp["cell"]) - back_f
			frozen[vp["team"]] = maxi(frozen[vp["team"]], 1)
			arena.freeze_burst(Vector3(vp["node"].position.x, BOARD_Y, vp["node"].position.z), Color("a8e6ff"))
			arena.piece_hit(vp["node"])
			await _hop_to(vp, _piece_cell_pos(vp))
			arena.item_cast(vp["node"], Color("a8e6ff"), "frostlock")
			hud.show_event("极寒锁链", "%s 被击退并冻结一轮" % TEAM_NAMES[vp["team"]], Color("a8e6ff"))
			hud.screen_flash(Color("a8e6ff"), 0.22)
			_update_all()
			await get_tree().create_timer(0.4).timeout

	# 狙击：对手快进终点，把他打回去
	var ni: int = cards[t].find("snipe")
	if ni >= 0:
		var best_i := -1
		var best_cell := 25
		for i in pieces.size():
			var q: Dictionary = pieces[i]
			if q["team"] == t or q["finished"] or q["cell"] < best_cell:
				continue
			best_cell = q["cell"]
			best_i = i
		if best_i >= 0:
			cards[t].remove_at(ni)
			_log("%s 使用「狙击」" % TEAM_NAMES[t])
			await _ai_snipe(best_i)
			return

	# 换位：自己最落后，对手最靠前
	var swi: int = cards[t].find("swap")
	if swi >= 0:
		var my_i := -1
		var my_cell := 999
		var op_i := -1
		var op_cell := -1
		for i in pieces.size():
			var q: Dictionary = pieces[i]
			if q["finished"] or q["cell"] < 0:
				continue
			if q["team"] == t:
				if q["cell"] < my_cell:
					my_cell = q["cell"]
					my_i = i
			elif q["cell"] > op_cell:
				op_cell = q["cell"]
				op_i = i
		if my_i >= 0 and op_i >= 0 and op_cell - my_cell >= 8:
			cards[t].remove_at(swi)
			_log("%s 使用「换位」" % TEAM_NAMES[t])
			await _ai_swap(my_i, op_i)
			return

	# 护盾：保护最靠前的棋子
	var hi: int = cards[t].find("shield")
	if hi >= 0:
		var lead := -1
		var lead_cell := -1
		for i in pieces.size():
			var p2: Dictionary = pieces[i]
			if p2["team"] != t or p2["finished"] or p2["cell"] < 0 or p2["shield"]:
				continue
			if p2["cell"] > lead_cell:
				lead_cell = p2["cell"]
				lead = i
		var danger := false
		if lead >= 0:
			var ti := _ring_idx(pieces[lead])
			for q in pieces:
				if q["team"] == t or q["finished"] or q["cell"] < 0:
					continue
				var qi := _ring_idx(q)
				if qi < 0:
					continue
				var gap := (qi - ti + FIELDS) % FIELDS
				if gap >= 1 and gap <= 6:
					danger = true
		if lead >= 0 and (danger or ai_level >= 2):
			cards[t].remove_at(hi)
			var pc: Dictionary = pieces[lead]
			pc["shield"] = true
			arena.add_shield(pc["node"])
			arena.flash_piece(pc["node"])
			arena.item_aura(pc["node"], Color("6cc6ff"))
			_log("%s 使用「护盾」" % TEAM_NAMES[t])
			_play(click_player)
			_update_all()
			await get_tree().create_timer(0.3).timeout


func _apply_ai_displace(idx: int, steps: int) -> void:
	var p: Dictionary = pieces[idx]
	var kind: String = card_mode
	var captured: bool = await _advance(p, steps)
	arena.item_cast(p["node"], ITEM_COLORS.get(kind, Color.WHITE), kind)
	arena.piece_celebrate(p["node"])
	hud.screen_flash(ITEM_COLORS.get(kind, Color.WHITE), 0.22)
	if kind == "moonstep" and not p["finished"] and not p["shield"]:
		p["shield"] = true
		arena.add_shield(p["node"])
	if kind == "inferno":
		# 冲锋落点：附近对手被炸退 2 格
		_shake(0.3, 18.0)
		var ti := _ring_idx(p)
		for q in pieces:
			if q["team"] == p["team"] or q["finished"] or q["cell"] < 0:
				continue
			var qi := _ring_idx(q)
			if qi < 0 or ti < 0:
				continue
			var gap := absi(qi - ti)
			gap = mini(gap, FIELDS - gap)
			if gap > 2:
				continue
			var back_i := mini(2, int(q["cell"]))
			if back_i <= 0:
				continue
			q["cell"] = int(q["cell"]) - back_i
			arena.piece_hit(q["node"])
			await _hop_to(q, _piece_cell_pos(q))
			arena.capture_blast(Vector3(q["node"].position.x, BOARD_Y, q["node"].position.z), ITEM_COLORS[kind])
	card_mode = ""
	_update_all()
	if game_over:
		return
	if p["cell"] == FIELDS - 1:
		_check_win(p["team"])
		if game_over:
			return
	_finish_turn(false)


func _ai_snipe(idx: int) -> void:
	var p: Dictionary = pieces[idx]
	var back := mini(3, int(p["cell"]))
	p["cell"] -= back
	arena.piece_hit(p["node"])
	await _hop_to(p, _piece_cell_pos(p))
	arena.item_cast(p["node"], Color("ff5566"), "snipe")
	arena.snipe_streak(_team_front_pos(current_team), p["node"].position, Color("ff5566"))
	hud.screen_flash(Color("ff5566"), 0.24)
	_shake(0.22, 10.0)
	_log("%s 的 %d 号棋子被狙击，后退 %d 格" % [TEAM_NAMES[p["team"]], p["idx"] + 1, back])
	_update_all()
	await get_tree().create_timer(0.35).timeout


func _team_front_pos(team: int) -> Vector3:
	var idx := _lead_piece(team)
	if idx < 0:
		return Vector3.ZERO
	return pieces[idx]["node"].position


func _ai_swap(a: int, b: int) -> void:
	var mine: Dictionary = pieces[a]
	var other: Dictionary = pieces[b]
	var my_cell: int = mine["cell"]
	mine["cell"] = other["cell"]
	other["cell"] = my_cell
	await _hop_to(mine, _piece_cell_pos(mine))
	await _hop_to(other, _piece_cell_pos(other))
	arena.item_cast(mine["node"], Color("ffd166"), "swap")
	arena.item_cast(other["node"], Color("ffd166"), "swap")
	hud.screen_flash(Color("ffd166"), 0.22)
	_log("%s 与 %s 交换了位置" % [TEAM_NAMES[mine["team"]], TEAM_NAMES[other["team"]]])
	_update_all()
	await get_tree().create_timer(0.35).timeout


# ---------------------------------------------------------------- HUD / 状态

func _update_all() -> void:
	if hud == null:
		return
	var color: Color = TEAM_COLORS[current_team]
	hud.set_turn("当前回合：%s" % _team_display(current_team), color)
	var status: Array = []
	for t in 4:
		var fin := 0
		for p in pieces:
			if p["team"] == t and p["finished"]:
				fin += 1
		status.append({
			"name": TEAM_NAMES[t], "color": TEAM_COLORS[t], "ai": _is_ai(t),
			"finished": fin, "captures": captures[t], "cards": cards[t].size(),
			"current": t == current_team,
		})
	hud.set_teams(status)
	var human := not _is_ai(current_team)
	var can_roll := human and not busy and not awaiting_pick and not game_over and card_mode == "" and match_started
	if can_roll:
		hud.set_roll_enabled(true)
	else:
		var txt := ""
		if not match_started or game_over:
			txt = ""
		elif awaiting_pick:
			txt = "请选择要移动的棋子"
		elif card_mode != "":
			txt = "选择道具目标"
		elif not human:
			txt = "%s AI 思考中…" % TEAM_NAMES[current_team]
		else:
			txt = "行动中…"
		hud.set_roll_enabled(false, txt)
	hud.set_cards(cards[current_team], human and not busy and not game_over and match_started)
	if arena:
		arena.set_active_team(current_team)


func _log(text: String) -> void:
	if auto_mode:
		print("[log] ", text)
	if hud:
		hud.log(text)


# ---------------------------------------------------------------- 选棋 / 相机

func _try_world_pick(screen_pos: Vector2) -> void:
	if not (awaiting_pick or card_mode != "") or _pick_pool.is_empty():
		return
	var origin := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.0001:
		return
	var t := (BOARD_Y + 46.0 - origin.y) / dir.y
	if t <= 0.0:
		return
	var hit := origin + dir * t
	var best := -1
	var best_d := 88.0
	for i in _pick_pool:
		var p: Dictionary = pieces[i]
		var node: Node3D = p["node"]
		var d := Vector2(node.position.x - hit.x, node.position.z - hit.z).length()
		if d < best_d:
			best_d = d
			best = i
	if best < 0:
		return
	if card_mode == "" or card_mode == "swap":
		arena.select_piece(pieces[best]["node"])
	_on_piece_pressed(best)


func _try_dice_click(pos: Vector2) -> bool:
	if not match_started or game_over:
		return false
	var wp := arena.dice_world_position()
	if camera.is_position_behind(wp):
		return false
	var sp := camera.unproject_position(wp)
	if sp.distance_to(pos) > 130.0:
		return false
	_on_roll_pressed()
	return true


func _handle_pinch() -> void:
	var keys := _touches.keys()
	if keys.size() < 2:
		return
	var a: Vector2 = _touches[keys[0]]
	var b: Vector2 = _touches[keys[1]]
	var d := a.distance_to(b)
	if _pinch_dist > 1.0:
		cam_dist = clampf(cam_dist * (_pinch_dist / maxf(d, 1.0)), 900.0, 4600.0)
		_update_camera()
	_pinch_dist = d


func _shake(duration := 0.26, amp := 12.0) -> void:
	if camera == null:
		return
	var tw := create_tween()
	var steps := 5
	var seg := duration / float(steps)
	for i in steps:
		var a := amp * (1.0 - float(i) / float(steps))
		tw.tween_property(camera, "v_offset", randf_range(-a, a), seg)
		tw.parallel().tween_property(camera, "h_offset", randf_range(-a, a), seg)
	tw.tween_property(camera, "v_offset", 0.0, 0.08)
	tw.parallel().tween_property(camera, "h_offset", 0.0, 0.08)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_using_touch = true
		if event.pressed:
			_touches[event.index] = event.position
			if _touches.size() == 1:
				if _try_dice_click(event.position):
					return
				_try_world_pick(event.position)
		else:
			_touches.erase(event.index)
			if _touches.size() < 2:
				_pinch_dist = 0.0
		return
	if event is InputEventScreenDrag:
		_using_touch = true
		_touches[event.index] = event.position
		if _touches.size() >= 2:
			_handle_pinch()
			return
		cam_yaw -= event.relative.x * 0.009
		cam_pitch = clampf(cam_pitch + event.relative.y * 0.007, deg_to_rad(16.0), deg_to_rad(86.0))
		_update_camera()
		return
	if _using_touch:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if _try_dice_click(event.position):
				return
			_try_world_pick(event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam_dist = clampf(cam_dist * 0.92, 900.0, 4600.0)
			_update_camera()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_dist = clampf(cam_dist * 1.08, 900.0, 4600.0)
			_update_camera()
		elif event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE:
			dragging = event.pressed
	elif event is InputEventMouseMotion and dragging:
		cam_yaw -= event.relative.x * 0.007
		cam_pitch = clampf(cam_pitch + event.relative.y * 0.005, deg_to_rad(16.0), deg_to_rad(86.0))
		_update_camera()


# ---------------------------------------------------------------- 自动 / 截图

func _auto_play() -> void:
	for _i in 160:
		await get_tree().create_timer(0.08).timeout
		if game_over:
			break
		if busy or awaiting_pick:
			await get_tree().create_timer(0.25).timeout
			continue
		var team := current_team
		if ai_level >= 1:
			await _ai_cards()
			if game_over or busy or current_team != team:
				continue
		await _do_roll()


func _setup_showcase() -> void:
	# 给截图/演示用的摆拍：让棋子分布在环道上
	var layout := [
		[6, 14, 23, -1],
		[3, 18, 28, -1],
		[9, 21, 33, -1],
		[12, 26, 36, -1],
	]
	for t in 4:
		for i in 4:
			var p: Dictionary = pieces[t * 4 + i]
			var cell: int = layout[t][i]
			if cell >= 0:
				p["cell"] = cell
				p["node"].position = _pt_pos(_path_point(t, cell))
	cards[0] = ["boost", "shield", "teleport", "snipe"]
	captures = [2, 1, 0, 3]
	rolls = [8, 8, 7, 9]
	# 摆出"轮到红队、可走棋子高亮"的状态
	var nodes: Array = []
	var dests: Array = []
	for i in 4:
		var p: Dictionary = pieces[i]
		if p["cell"] >= 0:
			nodes.append(p["node"])
			dests.append(_pt_pos(_path_point(0, int(p["cell"]) + 4)))
	arena.show_movable(nodes, TEAM_COLORS[0])
	arena.mark_tiles(dests, TEAM_COLORS[0])
	arena.select_piece(pieces[0]["node"])
	_update_all()


func _take_screenshot() -> void:
	for _i in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(shot_path)
	print("screenshot saved: ", shot_path)
	get_tree().quit()
