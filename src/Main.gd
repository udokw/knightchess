extends Node3D
## 骑士飞行棋 3 · 2026 重制版
## 场景：程序化天空竞技场（Arena.gd） / 界面：Hud.gd
## 规则：40 格环道 · 掷 6 出基地 · 精确终点 · 安全格 · 宝箱格 · 三种道具卡 · 三档 AI

const TEAM_NAMES := ["红队", "蓝队", "绿队", "黄队"]
const TEAM_COLORS := [Color("e0503f"), Color("3d8ae0"), Color("3fb96a"), Color("e0a92f")]
const FIELDS := 40
const PIECES_PER_TEAM := 4
const BOARD_Y := 8.0
const CARD_NAMES := {"boost": "加速", "shield": "护盾", "warp": "跃迁"}

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

var match_started := false
var ai_level := 1
var human_teams: Array = [0]
var cards: Array = [[], [], [], []]
var captures: Array = [0, 0, 0, 0]
var rolls: Array = [0, 0, 0, 0]
var boost_pending := -1
var last_dice := 0
var pending_total := 0
var card_mode := ""
var card_slot := -1

# 相机
var cam_yaw := deg_to_rad(34.0)
var cam_pitch := deg_to_rad(53.0)
var cam_dist := 2820.0
var cam_target := Vector3(0, -150, 0)
var camera: Camera3D
var dragging := false
var _cam_tween: Tween

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
		elif a == "--auto":
			auto_mode = true
		elif a == "--showcase":
			showcase = true

	_load_data()
	_setup_world()
	_setup_camera()
	_setup_audio()
	_spawn_pieces()
	_setup_hud()

	if auto_mode or shot_path != "":
		_start_match(0, 1)
		hud.hide_start()
		if showcase:
			_setup_showcase()
	else:
		hud.show_start()

	if auto_mode:
		_auto_play()
	if shot_path != "":
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
	arena.build(pts, paths[0], TEAM_COLORS)


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
	hud.camera_pressed.connect(_camera_action)
	hud.card_pressed.connect(_on_card_pressed)
	hud.piece_pressed.connect(_on_piece_pressed)
	hud.start_pressed.connect(_start_match)


# ---------------------------------------------------------------- 对局管理

func _start_match(mode: int, level: int) -> void:
	ai_level = level
	human_teams = [0] if mode == 0 else [0, 1, 2, 3]
	match_started = true
	game_over = false
	winner = -1
	busy = false
	awaiting_pick = false
	card_mode = ""
	card_slot = -1
	boost_pending = -1
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
	if hud:
		hud.hide_win()
		hud.hide_pick()
		hud.set_dice(0)
	_update_all()
	_log("———— 新对局 ————")
	_log("掷出 6 点出基地，精确点数进终点")
	if ai_level >= 0 and mode == 0:
		_log("AI 难度：%s" % ["简单", "普通", "困难"][ai_level])
	_maybe_ai_turn()


func _reset_view() -> void:
	cam_yaw = deg_to_rad(34.0)
	cam_pitch = deg_to_rad(53.0)
	cam_dist = 2820.0
	cam_target = Vector3(0, -150, 0)
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
		q["cell"] = -1
		q["node"].position = _pt_pos("HM%d_%d" % [q["team"] + 1, q["idx"] + 1])
		arena.burst(p["node"].position, TEAM_COLORS[q["team"]], 12)
		arena.pulse(p["node"].position, TEAM_COLORS[p["team"]])
		captures[p["team"]] += 1
		_log("%s 吃掉了 %s 的 %d 号棋子" % [TEAM_NAMES[p["team"]], TEAM_NAMES[q["team"]], q["idx"] + 1])
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
	arena.clear_marks()
	arena.clear_piece_marks()
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
	hud.hide_pick()
	arena.clear_marks()
	arena.clear_piece_marks()
	hud.set_roll_enabled(false, "掷骰中…")
	_update_all()

	var raw := randi_range(1, 6)
	last_dice = raw
	rolls[current_team] += 1
	var total := raw
	if boost_pending == current_team:
		total += 2
		boost_pending = -1
	pending_total = total
	hud.set_dice(raw, total)
	_play(dice_player)
	_log("%s 掷出 %d 点%s" % [_team_display(current_team), raw,
		"（加速 +2 → %d）" % total if total != raw else ""])
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
	for i in legal:
		var p: Dictionary = pieces[i]
		var label := ""
		if p["cell"] < 0:
			label = "%d号 · 基地出发" % (p["idx"] + 1)
		else:
			label = "%d号 · %d → %d" % [p["idx"] + 1, p["cell"] + 1, p["cell"] + total + 1]
		options.append({"index": i, "label": label, "color": TEAM_COLORS[p["team"]]})
		arena.mark_piece(p["node"])
		var dest: int = 0 if p["cell"] < 0 else int(p["cell"]) + total
		arena.mark_tiles([_pt_pos(_path_point(p["team"], dest))], TEAM_COLORS[p["team"]])
	hud.show_pick(options, "掷出 %d 点，选择棋子" % total)


func _on_piece_pressed(idx: int) -> void:
	if card_mode != "":
		await _apply_card(idx)
		return
	if not awaiting_pick:
		return
	awaiting_pick = false
	hud.hide_pick()
	arena.clear_piece_marks()
	arena.clear_marks()
	await _move_piece(idx, pending_total)


func _move_piece(idx: int, steps: int) -> void:
	var p: Dictionary = pieces[idx]
	var captured: bool = await _advance(p, steps)
	if p["finished"]:
		_check_win(p["team"])
	else:
		if _is_treasure_cell(p["cell"]):
			_draw_card(p["team"])
		_check_win(p["team"])
	_update_all()
	if game_over:
		return
	_finish_turn(last_dice == 6 or captured)


func _finish_turn(extra: bool) -> void:
	busy = false
	awaiting_pick = false
	card_mode = ""
	card_slot = -1
	hud.hide_pick()
	arena.clear_marks()
	arena.clear_piece_marks()
	if game_over:
		_update_all()
		return
	if extra:
		_log("%s 再掷一次" % _team_display(current_team))
	else:
		current_team = (current_team + 1) % 4
	hud.set_dice(0)
	_update_all()
	_maybe_ai_turn()


# ---------------------------------------------------------------- 道具卡

func _draw_card(team: int) -> bool:
	if cards[team].size() >= 2:
		return false
	var pool := ["boost", "shield", "warp"]
	var id: String = pool[randi() % pool.size()]
	cards[team].append(id)
	_log("%s 获得道具「%s」" % [TEAM_NAMES[team], CARD_NAMES[id]])
	_play(click_player)
	_update_all()
	return true


func _on_card_pressed(slot: int) -> void:
	if busy or game_over or awaiting_pick or not match_started:
		return
	if _is_ai(current_team) or card_mode != "":
		return
	if slot >= cards[current_team].size():
		return
	var id: String = cards[current_team][slot]
	if id == "boost":
		if boost_pending == current_team:
			_log("本回合已经使用过加速")
			return
		cards[current_team].remove_at(slot)
		boost_pending = current_team
		hud.set_dice(last_dice, last_dice + 2 if last_dice > 0 else 0)
		_log("%s 使用「加速」，本回合点数 +2" % TEAM_NAMES[current_team])
		_play(click_player)
		_update_all()
		return
	# 护盾 / 跃迁 需要选棋子
	var options: Array = []
	for i in pieces.size():
		var p: Dictionary = pieces[i]
		if p["team"] != current_team or p["finished"] or p["cell"] < 0:
			continue
		if id == "warp" and p["cell"] + 3 > FIELDS - 1:
			continue
		var label := "%d号 · 第 %d 格" % [p["idx"] + 1, p["cell"] + 1]
		if id == "warp" and p["cell"] + 3 == FIELDS - 1:
			label += " · 直达终点"
		options.append({"index": i, "label": label, "color": TEAM_COLORS[p["team"]]})
		arena.mark_piece(p["node"])
	if options.is_empty():
		_play(nope_player)
		_log("现在没有可以%s的棋子" % CARD_NAMES[id])
		return
	card_mode = id
	card_slot = slot
	hud.show_pick(options, "选择要使用「%s」的棋子" % CARD_NAMES[id])
	hud.set_roll_enabled(false)
	busy = true
	_update_all()


func _apply_card(idx: int) -> void:
	var p: Dictionary = pieces[idx]
	if p["team"] != current_team or p["finished"]:
		return
	var id := card_mode
	var slot := card_slot
	card_mode = ""
	card_slot = -1
	awaiting_pick = false
	hud.hide_pick()
	arena.clear_piece_marks()
	busy = false
	if slot >= 0 and slot < cards[current_team].size():
		cards[current_team].remove_at(slot)
	if id == "shield":
		p["shield"] = true
		arena.add_shield(p["node"])
		arena.flash_piece(p["node"])
		_log("%s 的 %d 号棋子获得护盾" % [TEAM_NAMES[p["team"]], p["idx"] + 1])
		_play(click_player)
		_update_all()
		return
	var captured: bool = await _advance(p, 3)
	_log("%s 的 %d 号棋子跃迁 3 格" % [TEAM_NAMES[p["team"]], p["idx"] + 1])
	if captured:
		_log("跃迁落点吃掉了对手")
	_check_win(p["team"])
	_update_all()
	if not game_over:
		_finish_turn(false)


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
	if game_over or busy or not match_started or not _is_ai(current_team):
		return
	await get_tree().create_timer(0.65).timeout
	if game_over or busy or not _is_ai(current_team):
		return
	if ai_level >= 1:
		await _ai_cards()
	if game_over or busy:
		return
	await get_tree().create_timer(0.25).timeout
	await _do_roll()


func _ai_cards() -> void:
	var t := current_team
	if cards[t].is_empty():
		return
	# 跃迁：能精确到终点，或能吃到对手
	var warp_slot: int = cards[t].find("warp")
	if warp_slot >= 0:
		var pick := -1
		var best := -1
		for i in pieces.size():
			var p: Dictionary = pieces[i]
			if p["team"] != t or p["finished"] or p["cell"] < 0:
				continue
			if p["cell"] + 3 > FIELDS - 1:
				continue
			var target: int = int(p["cell"]) + 3
			var point := _path_point(t, target)
			var score: int = target
			if target == FIELDS - 1:
				score += 500
			for q in pieces:
				if q["team"] == t or q["finished"] or q["cell"] < 0:
					continue
				if _path_point(q["team"], q["cell"]) == point and not _is_safe_cell(target):
					score += 800
			if score > best:
				best = score
				pick = i
		if pick >= 0 and best >= FIELDS - 1:
			card_mode = "warp"
			card_slot = warp_slot
			busy = true
			await get_tree().create_timer(0.35).timeout
			busy = false
			hud.log("%s 使用「跃迁」" % TEAM_NAMES[t])
			await _apply_card(pick)
			return
	# 加速：有棋子离终点 4~8 格，或困难难度直接用
	var boost_slot: int = cards[t].find("boost")
	if boost_slot >= 0:
		var useful := false
		for p in pieces:
			if p["team"] == t and not p["finished"] and p["cell"] >= 0:
				var d: int = FIELDS - 1 - p["cell"]
				if d >= 4 and d <= 8:
					useful = true
		if useful or ai_level >= 2:
			cards[t].remove_at(boost_slot)
			boost_pending = t
			hud.log("%s 使用「加速」" % TEAM_NAMES[t])
			_update_all()
			await get_tree().create_timer(0.3).timeout
	# 护盾：保护最靠前的棋子
	var shield_slot: int = cards[t].find("shield")
	if shield_slot >= 0:
		var lead := -1
		var lead_cell := -1
		for i in pieces.size():
			var p: Dictionary = pieces[i]
			if p["team"] != t or p["finished"] or p["cell"] < 0 or p["shield"]:
				continue
			if p["cell"] > lead_cell:
				lead_cell = p["cell"]
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
			cards[t].remove_at(shield_slot)
			var p: Dictionary = pieces[lead]
			p["shield"] = true
			arena.add_shield(p["node"])
			arena.flash_piece(p["node"])
			hud.log("%s 使用「护盾」" % TEAM_NAMES[t])
			_play(click_player)
			_update_all()
			await get_tree().create_timer(0.3).timeout


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
	hud.set_roll_enabled(can_roll)
	hud.set_cards(cards[current_team], human and not busy and not game_over and match_started)


func _log(text: String) -> void:
	if auto_mode:
		print("[log] ", text)
	if hud:
		hud.log(text)


# ---------------------------------------------------------------- 相机操作

func _camera_action(action: String) -> void:
	match action:
		"left":
			cam_yaw -= deg_to_rad(18.0)
		"right":
			cam_yaw += deg_to_rad(18.0)
		"in":
			cam_dist = clampf(cam_dist * 0.88, 850.0, 3200.0)
		"out":
			cam_dist = clampf(cam_dist * 1.14, 850.0, 3200.0)
		_:
			_reset_view()
	_update_camera()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam_dist = clampf(cam_dist * 0.92, 850.0, 3200.0)
			_update_camera()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_dist = clampf(cam_dist * 1.08, 850.0, 3200.0)
			_update_camera()
		elif event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE:
			dragging = event.pressed
	elif event is InputEventMouseMotion and dragging:
		cam_yaw -= event.relative.x * 0.007
		cam_pitch = clampf(cam_pitch + event.relative.y * 0.005, deg_to_rad(16.0), deg_to_rad(86.0))
		_update_camera()
	elif event is InputEventScreenDrag:
		cam_yaw -= event.relative.x * 0.009
		cam_pitch = clampf(cam_pitch + event.relative.y * 0.007, deg_to_rad(16.0), deg_to_rad(86.0))
		_update_camera()


# ---------------------------------------------------------------- 自动 / 截图

func _auto_play() -> void:
	for _i in 40:
		await get_tree().create_timer(0.1).timeout
		if game_over:
			break
		if busy or awaiting_pick:
			await get_tree().create_timer(0.3).timeout
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
	cards[0] = ["boost", "shield"]
	captures = [2, 1, 0, 3]
	rolls = [8, 8, 7, 9]
	_update_all()


func _take_screenshot() -> void:
	for _i in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(shot_path)
	print("screenshot saved: ", shot_path)
	get_tree().quit()
