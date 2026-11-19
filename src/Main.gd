extends Node3D
## 骑士飞行棋 3 · 2026 重制版
## 场景：程序化天空竞技场（Arena.gd） / 界面：Hud.gd
## 规则：40 格环道 · 掷 6 出基地 · 精确终点 · 安全格 · 宝箱随机事件
##       8 种道具 · 三套主题 · 三档 AI · 1v3 人机 / 4 人热座

const TEAM_NAMES := ["红队", "蓝队", "绿队", "黄队"]
const TEAM_COLORS := [Color("e0503f"), Color("3d8ae0"), Color("3fb96a"), Color("e0a92f")]
const BASE_FIELDS := 40
var FIELDS := 40
const PIECES_PER_TEAM := 4
const BOARD_Y := 8.0
## 全局节奏：整体动画放慢约 10%，吃棋慢动作结束后回到这个基准
const BASE_TIME_SCALE := 0.9

const ITEM_NAMES := {
	"boost": "加速", "shield": "护盾", "warp": "跃迁", "snipe": "狙击",
	"swap": "换位", "freeze": "冰冻", "double": "双倍", "teleport": "传送",
	"moonstep": "月影跃步", "frostlock": "极寒锁链", "inferno": "熔火冲锋",
	"vortex": "漩涡", "steal": "窃取", "bomb": "炸弹", "gale": "疾风",
	"jadeguard": "玉灵护体", "voidstep": "虚空牵引",
}
const ITEM_DESC := {
	"boost": "本回合点数 +2", "shield": "免疫一次吃子", "warp": "前进 3 格",
	"snipe": "击退对手 3 格", "swap": "与对手交换位置", "freeze": "对手停一轮",
	"double": "本回合点数 ×2", "teleport": "前进 5 格",
	"moonstep": "前进 2 格并获得护盾", "frostlock": "对手后退 2 格并冻结",
	"inferno": "前进 4 格，落点附近对手全被炸退",
	"vortex": "所有对手棋子后退 1 格", "steal": "从道具最多的对手手中抢一张",
	"bomb": "把一名对手棋子炸回基地", "gale": "前进 2 格并再掷一次",
	"jadeguard": "己方在场棋子全部获得护盾", "voidstep": "随机放逐一枚对手棋子回基地",
}
const ITEM_COLORS := {
	"boost": Color("ff9a3c"), "shield": Color("6cc6ff"), "warp": Color("b484ff"),
	"snipe": Color("ff5566"), "swap": Color("ffd166"), "freeze": Color("7fe6ff"),
	"double": Color("ffe066"), "teleport": Color("7cf0a8"),
	"moonstep": Color("cfd8ff"), "frostlock": Color("a8e6ff"), "inferno": Color("ff7a3c"),
	"vortex": Color("9a7bff"), "steal": Color("ffb84a"), "bomb": Color("ff6a3c"),
	"gale": Color("8ff0c0"), "jadeguard": Color("8ff0c0"), "voidstep": Color("c8b8ff"),
}
## 共同道具池 + 每个主题的独占道具
const ITEM_POOL := [
	"boost", "shield", "warp", "snipe", "swap", "freeze", "double", "teleport",
	"vortex", "steal", "bomb", "gale",
]
const THEME_ITEM := {
	"dusk": "moonstep", "frost": "frostlock", "ember": "inferno",
	"jade": "jadeguard", "void": "voidstep", "cozy": "gale",
}

const EVENT_TITLES := {
	"treasure": "秘 宝", "meteor": "陨 石", "tailwind": "顺 风", "trap": "陷 阱",
	"portal": "传送门", "chaos": "混 沌", "bless": "祝 福",
	"starlight": "星辉之赐", "blizzard": "暴风雪", "eruption": "火山喷发",
	"ambush": "伏 击", "goldrain": "金 雨", "earthquake": "地 震", "curse": "诅 咒",
	"jadeserpent": "翠 蛇 缠 绕", "voidrift": "虚 空 裂 隙",
}
const EVENT_COLORS := {
	"treasure": Color("ffd166"), "meteor": Color("ff6a3c"), "tailwind": Color("7cf0a8"),
	"trap": Color("ff5566"), "portal": Color("b484ff"), "chaos": Color("ff8ce0"),
	"bless": Color("6cc6ff"),
	"starlight": Color("e8ecff"), "blizzard": Color("a8e6ff"), "eruption": Color("ff8a3c"),
	"ambush": Color("ff7a92"), "goldrain": Color("ffd166"), "earthquake": Color("c9a06a"),
	"curse": Color("b98cff"), "jadeserpent": Color("8ff0c0"), "voidrift": Color("c8b8ff"),
}
const EVENT_SYMBOLS := {
	"treasure": "宝", "meteor": "陨", "tailwind": "风", "trap": "陷",
	"portal": "门", "chaos": "混", "bless": "福",
	"starlight": "星", "blizzard": "雪", "eruption": "火",
	"ambush": "伏", "goldrain": "金", "earthquake": "震", "curse": "咒",
	"jadeserpent": "蛇", "voidrift": "裂",
}
const EVENT_POOL := [
	"treasure", "meteor", "tailwind", "trap", "portal", "chaos", "bless",
	"ambush", "goldrain", "earthquake", "curse",
]
## 每个主题额外加入的独占事件
const THEME_EVENT := {
	"dusk": "starlight", "frost": "blizzard", "ember": "eruption",
	"jade": "jadeserpent", "void": "voidrift", "cozy": "goldrain",
}
const THEME_LABELS := {
	"dusk": "暮色竞技场", "frost": "霜封荒原", "ember": "熔火深渊",
	"jade": "翠玉遗迹", "void": "虚空星海", "cozy": "晴日草地",
}

var base_points: Dictionary = {}
var board_cells := 40
var char_styles: Array = [0, 1, 2, 3]
var drops: Dictionary = {}
var event_cells: Dictionary = {}
var turn_count := 0
var roulette_open := false
var _roulette_segments: Array = []
var six_streak := 0

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
## 参与轮转的队伍：单机 4 队，局域网对局只用红/蓝两队
var active_teams: Array = [0, 1, 2, 3]
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
var _pick_options: Array = []

# 相机
var cam_yaw := deg_to_rad(34.0)
var cam_pitch := deg_to_rad(52.0)
var cam_dist := 2780.0
var cam_target := Vector3(0, -60, 0)
var camera: Camera3D
var dragging := false
var _touches: Dictionary = {}
var _pinch_dist := 0.0
var _pinch_mid := Vector2.ZERO
var _using_touch := false

var dice_player: AudioStreamPlayer
var click_player: AudioStreamPlayer
var nope_player: AudioStreamPlayer
var theme_amb: AudioStreamPlayer
var sfx_event: AudioStreamPlayer
var sfx_boom: AudioStreamPlayer
var sfx_tick: AudioStreamPlayer
var sfx_win: AudioStreamPlayer
var sfx_drop: AudioStreamPlayer
var _amb_streams: Dictionary = {}
## 程序化合成音效：吃棋 / 道具 / 事件全部自带独立音色
const SfxScript := preload("res://src/Sfx.gd")
const SaveStoreScript := preload("res://src/SaveStore.gd")
const LanScript := preload("res://src/Lan.gd")
var sfx: Node = null
var _sfx_on := true
var _music_on := true
var _cli_theme := false
var _cli_cells := false
var _saved_prefs: Dictionary = {}
var saves: RefCounted = SaveStoreScript.new()
var net_role := ""          # "" 单机 / "host" 房主 / "guest" 客机
var net_guest_team := 1     # 局域网客机使用的队伍
var _restoring := false
var _debug_page := ""       # 截图调试：--page=start|load|settings|lan
var _selftest_save := false
var _selftest_swap := false
var _selftest_save_slots := false
var _selftest_duel := false
## 自测专用：0 正常随机，1 强制胜，2 强制负
var _duel_force := 0
var _debug_load := -1
var _cli_lan_host := false
var _cli_lan_join := ""
var _cli_lan_ip := ""
var _cli_lan_autoquit := false
var lan: Node = null
var _net_dirty := false
var _net_push_ms := 0
var _net_pick_hint := ""
var _lan_testplay := -1
var _lan_last_sig := ""
## 吃棋对决：开启后先玩一局石头剪刀布，输/平则攻击方退回吃棋前的格子
var duel_enabled := false
var _duel_active := false
var _duel_pick := -1
var _duel_until := 0
var _duel_team := 0
var _duel_target_team := 0
var _duel_target_idx := 0
var _duel_shown := false


func _ready() -> void:
	Engine.time_scale = BASE_TIME_SCALE
	var mobile := OS.has_feature("mobile")
	# 移动端省电：锁 30 帧，配合关闭实时阴影与减半粒子，长时间对局也不烫手
	Engine.max_fps = 30 if mobile else 60
	# PC 端直接跑满画质：渲染比例 1.0 + 2x MSAA。移动端用 FXAA 抗锯齿，边缘更干净
	if not mobile:
		var vp := get_viewport()
		vp.scaling_3d_scale = 1.0
		vp.msaa_3d = Viewport.MSAA_2X
	else:
		get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	var all_args: Array = []
	all_args.append_array(OS.get_cmdline_args())
	all_args.append_array(OS.get_cmdline_user_args())
	print("args: ", all_args)
	for a in all_args:
		if a.begins_with("--shot="):
			shot_path = a.substr(7)
		elif a.begins_with("--theme="):
			theme_id = a.substr(8)
			_cli_theme = true
		elif a.begins_with("--cells="):
			board_cells = clampi(int(a.substr(8)), 20, 60)
			_cli_cells = true
		elif a == "--auto":
			auto_mode = true
		elif a == "--showcase":
			showcase = true
		elif a == "--menu":
			menu_mode = true
		elif a.begins_with("--page="):
			_debug_page = a.substr(7)
		elif a == "--selftest-save":
			_selftest_save = true
		elif a == "--selftest-swap":
			_selftest_swap = true
		elif a == "--selftest-save-slots":
			_selftest_save_slots = true
		elif a == "--selftest-duel":
			_selftest_duel = true
		elif a.begins_with("--load="):
			_debug_load = int(a.substr(7))
		elif a == "--lan-host":
			_cli_lan_host = true
		elif a.begins_with("--lan-join="):
			_cli_lan_join = a.substr(11)
		elif a.begins_with("--lan-ip="):
			_cli_lan_ip = a.substr(9)
		elif a == "--lan-autoquit":
			_cli_lan_autoquit = true
		elif a.begins_with("--lan-testplay="):
			_lan_testplay = int(a.substr(14))

	# 先读本地设定，主题/棋盘/角色要在建场之前生效
	_saved_prefs = _load_prefs()
	_load_data()
	_apply_board_size(FIELDS)
	_setup_world()
	_setup_camera()
	_setup_audio()
	_spawn_pieces()
	lan = LanScript.new()
	lan.name = "Lan"
	add_child(lan)
	_setup_hud()
	_lan_wire()

	if _debug_load >= 0:
		_load_slot(_debug_load)
	elif (auto_mode or shot_path != "") and not menu_mode and _debug_page == "" \
			and not _cli_lan_host and _cli_lan_join == "":
		_start_match(0, 1, theme_id, board_cells, char_styles)
		hud.hide_start()
		if showcase:
			_setup_showcase()
	else:
		hud.show_home()
		match _debug_page:
			"start":
				hud.show_start()
			"load":
				hud.show_load(_save_records())
			"settings":
				hud.show_settings()
			"lan":
				hud.show_lan()

	if _selftest_save:
		_run_save_selftest()
		return

	if _selftest_swap:
		_run_swap_selftest()
		return

	if _selftest_save_slots:
		_run_save_slots_selftest()
		return

	if _selftest_duel:
		_run_duel_selftest()
		return

	if _cli_lan_host:
		hud.show_lan()
		_lan_host_clicked()
	elif _cli_lan_join != "":
		hud.show_lan()
		_lan_join_clicked(_cli_lan_ip, _cli_lan_join)

	if auto_mode:
		_auto_play()
	if shot_path != "":
		# 截图调试：--menuopen 展开左上角控制台
		if all_args.has("--menuopen"):
			hud._toggle_menu()
		if all_args.has("--logopen"):
			hud._toggle_log()
		if all_args.has("--wheel"):
			roulette_open = true
			_roulette_segments = _build_roulette_segments("item")
			hud.show_roulette(_roulette_segments, "item")
			await get_tree().create_timer(0.9).timeout
		if all_args.has("--blast"):
			var bc: Color = arena.theme_accent()
			arena.roulette_blast(Vector3(0, BOARD_Y, 0), bc)
			hud.screen_flash(bc, 0.5)
			await get_tree().create_timer(0.4).timeout
		if all_args.has("--fxdemo-capture"):
			# 截图调试：把两枚棋子摆到一起，连拍吃棋动画
			var na: Node3D = pieces[0]["node"]
			var nb: Node3D = pieces[4]["node"]
			var base: Vector3 = _pt_pos(paths[0][clampi(10, 0, FIELDS - 1)])
			na.position = base
			nb.position = base + Vector3(26, 0, 8)
			arena.capture_stomp(na, nb, TEAM_COLORS[0])
			await _fx_frame_burst(shot_path, 8, 0.22)
			return
		var fxid := ""
		for a in all_args:
			if String(a).begins_with("--fxdemo-item="):
				fxid = String(a).substr(14)
		if fxid != "":
			# 截图调试：播放指定道具的 3D 演出
			var p0: Dictionary = pieces[0]
			var p1: Dictionary = pieces[4]
			p0["cell"] = 10
			p1["cell"] = 22
			p0["node"].position = _piece_cell_pos(p0)
			p1["node"].position = _piece_cell_pos(p1)
			_play_item_fx(p0, fxid, p1, {})
			await _fx_frame_burst(shot_path, 8, 0.22)
			return
		await _take_screenshot()


# ---------------------------------------------------------------- 数据 / 世界

func _load_data() -> void:
	var f := FileAccess.open("res://assets/data/board.json", FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed == null:
		push_error("board.json 解析失败")
		return
	data = parsed
	base_points = data["points"]
	_apply_board_size(board_cells)


## 在 40 格原始环线上按弧长重采样出任意格数的棋盘
func _apply_board_size(n: int) -> void:
	n = clampi(n, 40, 64)
	board_cells = n
	FIELDS = n
	if base_points.is_empty():
		return
	# 格数增加时棋盘整体外扩：坐标按 n/40 放大，格子世界尺寸保持 100 不变
	var grow := float(n) / float(BASE_FIELDS)
	pts = {}
	# 环道：正圆均匀分布（参照原作），半径随格数增大，格子间距恒定
	var ring_r := 940.0 * grow
	# 起始角由格数反推：让每队路径末格正好落在对应终点跑道轴（180/270/0/90°）上。
	# 末格索引 = (t*n/4 + n-1) mod n，角度 = a0 + 90t + 360 - 360/n；取 a0 = 360/n - 180 即得 180+90t。
	var a0 := deg_to_rad(360.0 / float(n) - 180.0)
	for k in n:
		var ang := a0 + TAU * float(k) / float(n)
		pts["BS%02d" % k] = [cos(ang) * ring_r, 1.0, sin(ang) * ring_r]
	# 终点跑道：从中心指向环内侧，始终贴到新的环道上
	for k in base_points.keys():
		var key := String(k)
		if not key.begins_with("GL"):
			continue
		var bp: Array = base_points[key]
		var fg := grow * 2.04
		pts[key] = [float(bp[0]) * fg, float(bp[1]), float(bp[2]) * fg]
	# 四角基地：两行 1+3 的紧凑弧形。前排那颗正对各队起始格的方位，
	# 后排三颗沿环等弧距排开，整块基地贴着环道外沿
	var front_r := ring_r + 118.0
	var back_r := ring_r + 228.0
	for t in 4:
		var ba: float = a0 + TAU * float(t) / 4.0
		var bd := Vector3(cos(ba), 0.0, sin(ba))
		var bt := Vector3(-bd.z, 0.0, bd.x)
		var front := bd * front_r
		pts["HM%d_1" % (t + 1)] = [front.x, 1.0, front.z]
		for i in 3:
			var off := (float(i) - 1.0) * 0.108
			var back := bd * back_r + bt * (sin(off) * back_r)
			pts["HM%d_%d" % [t + 1, i + 2]] = [back.x, 1.0, back.z]
	paths = []
	var step := n / 4
	for t in 4:
		var path: Array = []
		for k in n:
			path.append("BS%02d" % ((k + t * step) % n))
		paths.append(path)
	ring_index = {}
	var ring: Array = paths[0]
	for i in ring.size():
		ring_index[ring[i]] = i


## 棋盘整体缩放：格数越多竞技台越大（28 → 0.7 倍，52 → 1.3 倍）
func _board_scale() -> float:
	return float(FIELDS) / float(BASE_FIELDS)


func _setup_world() -> void:
	arena = Arena.new()
	arena.name = "Arena"
	add_child(arena)
	arena.build(pts, paths[0], TEAM_COLORS, theme_id, 100.0, _board_scale())


func _rebuild_arena() -> void:
	for p in pieces:
		if is_instance_valid(p["node"]):
			p["node"].queue_free()
	pieces = []
	if is_instance_valid(arena):
		remove_child(arena)
		arena.queue_free()
	arena = Arena.new()
	arena.name = "Arena"
	add_child(arena)
	arena.build(pts, paths[0], TEAM_COLORS, theme_id, 100.0, _board_scale())
	arena.set_active_team(current_team)
	_spawn_pieces(char_styles)


func _rebuild_pieces() -> void:
	for p in pieces:
		if is_instance_valid(p["node"]):
			p["node"].queue_free()
	pieces = []
	_spawn_pieces(char_styles)


func _setup_camera() -> void:
	camera = Camera3D.new()
	camera.fov = 34.0
	camera.near = 2.0
	camera.far = 14000.0
	add_child(camera)
	_fit_camera()


## 相机默认取景：按可玩区外接半径取景，让环道/基地尽量占满屏幕且不出屏
func _fit_camera() -> void:
	cam_yaw = deg_to_rad(34.0)
	cam_pitch = deg_to_rad(50.0)
	var grow := float(FIELDS) / float(BASE_FIELDS)
	# 取景公式：可见竖向世界高度 = 2*d*tan(fov/2)；棋盘投影竖向高度 ≈ 2*R*sin(pitch)。
	# R≈1250（环道 940 + 基地外沿），fov 34° 时留约 8% 安全边，d 取 3040 起随格数放大。
	cam_dist = 3040.0 * (1.0 + 0.55 * (grow - 1.0))
	# 目标点向相机侧平移，整体画面上移，避开底部道具栏与骰子提示
	cam_target = Vector3(0, 40.0, 0) + Vector3(sin(cam_yaw), 0.0, cos(cam_yaw)) * 85.0
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
	sfx = SfxScript.new()
	sfx.name = "Sfx"
	sfx.enabled = _sfx_on
	add_child(sfx)
	if arena != null:
		arena.sfx = sfx
	dice_player = _make_player("res://assets/sounds/dice_move.wav", -3.0)
	click_player = _make_player("res://assets/sounds/button_click.wav", -8.0)
	nope_player = _make_player("res://assets/sounds/cant_move.wav", -8.0)
	sfx_event = _make_player("res://assets/sounds/sfx_event.wav", -6.0)
	sfx_boom = _make_player("res://assets/sounds/sfx_bigboom.wav", -5.0)
	sfx_tick = _make_player("res://assets/sounds/sfx_roulette.wav", -4.0)
	sfx_win = _make_player("res://assets/sounds/sfx_win.wav", -6.0)
	sfx_drop = _make_player("res://assets/sounds/sfx_drop.wav", -7.0)
	_amb_streams = {
		"dusk": load("res://assets/sounds/amb_dusk.wav"),
		"frost": load("res://assets/sounds/amb_frost.wav"),
		"ember": load("res://assets/sounds/amb_ember.wav"),
		"jade": load("res://assets/sounds/amb_jade.wav"),
		"void": load("res://assets/sounds/amb_void.wav"),
	}
	for k in _amb_streams.keys():
		_prepare_loop(_amb_streams[k])
	theme_amb = _make_player("res://assets/sounds/amb_dusk.wav", -19.0)
	_apply_theme_audio()


func _prepare_loop(s: AudioStream) -> void:
	if s is AudioStreamWAV:
		var w := s as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(w.get_length() * float(w.mix_rate))
	elif s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true


## 每个主题切换专属环境音
func _apply_theme_audio() -> void:
	if theme_amb == null:
		return
	if not _music_on:
		theme_amb.stop()
		return
	var s: AudioStream = _amb_streams.get(theme_id, null)
	if s == null:
		return
	if theme_amb.stream == s and theme_amb.playing:
		return
	theme_amb.stream = s
	theme_amb.play()


func _make_player(path: String, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	p.volume_db = db
	add_child(p)
	return p


func _play(p: AudioStreamPlayer) -> void:
	if not _sfx_on:
		return
	if p and p.stream:
		p.play()


func _spawn_pieces(styles: Array = []) -> void:
	for t in 4:
		var style := t
		if t < styles.size():
			style = clampi(int(styles[t]), 0, 7)
		for i in PIECES_PER_TEAM:
			var node := arena.make_piece(t, style)
			node.name = "P%d_%d" % [t + 1, i + 1]
			arena.add_child(node)
			node.position = _pt_pos("HM%d_%d" % [t + 1, i + 1])
			pieces.append({
				"team": t, "idx": i, "cell": -1, "finished": false,
				"lane": -1, "lslot": 0,
				"shield": false, "style": style, "node": node,
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
	hud.roulette_tick.connect(func(): _play(sfx_tick))
	hud.theme_previewed.connect(func(id: String): arena.set_theme(id))
	hud.theme_selected.connect(func(id: String):
		theme_id = id
		arena.set_theme(id)
		_apply_theme_audio())
	hud.sound_toggled.connect(func(on: bool):
		_sfx_on = on
		if sfx != null:
			sfx.enabled = on)
	hud.music_toggled.connect(func(on: bool):
		_music_on = on
		_apply_theme_audio())
	hud.prefs_changed.connect(_save_prefs)
	# 启动画面 → 四个入口
	hud.home_create.connect(func(): hud.show_start())
	hud.home_load.connect(func(): hud.show_load(_save_records()))
	hud.home_settings.connect(func(): hud.show_settings())
	hud.home_lan.connect(func(): hud.show_lan())
	hud.save_pressed.connect(_manual_save)
	hud.save_slot_pressed.connect(_on_save_slot)
	hud.load_slot_pressed.connect(_load_slot)
	hud.delete_slot_pressed.connect(_delete_slot)
	hud.duel_chosen.connect(_on_duel_chosen)
	hud.duel_toggled.connect(_on_duel_toggled)
	hud.lan_host_pressed.connect(_lan_host_clicked)
	hud.lan_join_pressed.connect(_lan_join_clicked)
	hud.lan_leave_pressed.connect(_lan_leave_clicked)
	hud.lan_refresh_pressed.connect(func():
		if lan != null:
			lan.refresh())
	# 套用上次保存的设定
	if not _saved_prefs.is_empty():
		var p := _saved_prefs.duplicate()
		if _cli_theme:
			p.erase("theme")
		if _cli_cells:
			p.erase("cells")
		hud.apply_prefs(p)


# ---------------------------------------------------------------- 本地设定持久化

const SAVE_PATH := "user://settings.cfg"


func _load_prefs() -> Dictionary:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return {}
	var p := {
		"mode": cf.get_value("game", "mode", 0),
		"level": cf.get_value("game", "level", 1),
		"theme": cf.get_value("game", "theme", theme_id),
		"cells": cf.get_value("game", "cells", board_cells),
		"styles": cf.get_value("game", "styles", char_styles),
		"sound": cf.get_value("game", "sound", true),
		"music": cf.get_value("game", "music", true),
		"pick_visible": cf.get_value("game", "pick_visible", true),
		"items_open": cf.get_value("game", "items_open", true),
		"duel": cf.get_value("game", "duel", false),
	}
	# 开局前就要用到的字段（主题、棋盘、角色）先落到内存
	if not _cli_theme and THEME_LABELS.has(String(p["theme"])):
		theme_id = String(p["theme"])
	if not _cli_cells:
		board_cells = clampi(int(p["cells"]), 40, 64)
	if p["styles"] is Array and p["styles"].size() == 4:
		var st: Array = []
		for s in p["styles"]:
			st.append(clampi(int(s), 0, 7))
		char_styles = st
	_sfx_on = bool(p["sound"])
	_music_on = bool(p["music"])
	duel_enabled = bool(p["duel"])
	return p


func _save_prefs() -> void:
	if hud == null:
		return
	var p: Dictionary = hud.prefs()
	var cf := ConfigFile.new()
	cf.set_value("game", "mode", p["mode"])
	cf.set_value("game", "level", p["level"])
	cf.set_value("game", "theme", p["theme"])
	cf.set_value("game", "cells", p["cells"])
	cf.set_value("game", "styles", p["styles"])
	cf.set_value("game", "sound", p["sound"])
	cf.set_value("game", "music", p["music"])
	cf.set_value("game", "pick_visible", p["pick_visible"])
	cf.set_value("game", "items_open", p["items_open"])
	cf.set_value("game", "duel", p["duel"])
	cf.save(SAVE_PATH)


# ---------------------------------------------------------------- 对局存档

## 存档列表给 UI 用的展示数据（UI 只负责渲染，不解析存档结构）
func _save_records() -> Array:
	var mode_names := ["人机 · 1v3", "4 人热座", "局域网对战"]
	var out: Array = []
	for rec in saves.list_slots():
		var g: Dictionary = rec.get("game", {})
		var s: Dictionary = rec.get("summary", {})
		var slot := int(rec.get("slot", 0))
		var mode := clampi(int(g.get("mode", 0)), 0, 2)
		var team := clampi(int(s.get("team", 0)), 0, 3)
		out.append({
			"slot": slot,
			"kind": String(rec.get("kind", "manual")),
			"title": ("自动存档" if slot == 0 else "手动存档 %02d" % slot),
			"detail": "%s · %d 格 · 第 %d 回合 · %s行动 · %d/16 子到终点" % [
				mode_names[mode], int(g.get("cells", 40)), int(s.get("turn", 0)),
				TEAM_NAMES[team], int(s.get("finished", 0))],
			"time_text": "保存于 " + SaveStoreScript.time_text(float(rec.get("updated", 0.0))),
		})
	return out


func _capture_state() -> Dictionary:
	var piece_rows: Array = []
	var finished := 0
	for p in pieces:
		var fin := bool(p["finished"])
		if fin:
			finished += 1
		piece_rows.append({
			"t": int(p["team"]), "i": int(p["idx"]), "c": int(p["cell"]),
			"f": fin, "s": bool(p["shield"]),
			"l": int(p.get("lane", -1)), "ls": int(p.get("lslot", 0)),
		})
	var drop_rows: Array = []
	for ri in drops.keys():
		drop_rows.append(int(ri))
	var event_rows: Array = []
	for ri in event_cells.keys():
		event_rows.append({"r": int(ri), "id": String(event_cells[ri].get("id", ""))})
	return {
		"game": {
			"mode": game_mode, "ai_level": ai_level, "theme": theme_id,
			"cells": board_cells, "styles": char_styles.duplicate(),
			"human_teams": human_teams.duplicate(),
			"active_teams": active_teams.duplicate(),
		},
		"summary": {
			"turn": turn_count, "team": current_team, "finished": finished,
			"winner": winner, "game_over": game_over,
		},
		"sections": {
			"turn": {
				"current_team": current_team, "turn_count": turn_count,
				"six_streak": six_streak, "last_dice": last_dice,
				"game_over": game_over, "winner": winner,
			},
			"teams": {
				"cards": cards.duplicate(true), "captures": captures.duplicate(),
				"rolls": rolls.duplicate(), "frozen": frozen.duplicate(),
				"boost_pending": boost_pending, "double_team": double_team,
			},
			"pieces": piece_rows,
			"board": {"drops": drop_rows, "events": event_rows},
		},
	}


func _auto_save() -> void:
	if not match_started or _restoring or net_role == "guest":
		return
	if auto_mode or shot_path != "":
		return
	saves.write_auto(_capture_state())


func _manual_save() -> void:
	if not match_started:
		hud.show_item_toast("无法保存", "先创建一局再保存", Color("ff9f68"))
		return
	if net_role == "guest":
		hud.show_item_toast("无法保存", "客机不落存档，由房主统一保存", Color("ff9f68"))
		return
	# 手动存档由玩家自己挑槽位，0 号自动槽不出现在选择页里
	hud.show_save_slots(_save_records())


## 手动写入指定槽位（保持 fmt/extra 结构不变，由 SaveStore 负责）
func _write_manual_slot(slot: int) -> bool:
	return saves.write_slot(slot, _capture_state())


## 存档槽选择页回传的槽号：只接受 1..19，0 号自动槽永远不写
func _on_save_slot(slot: int) -> void:
	if slot < 1 or slot > SaveStoreScript.MAX_SLOTS - 1:
		return
	if not match_started:
		hud.hide_save_slots()
		hud.show_item_toast("无法保存", "先创建一局再保存", Color("ff9f68"))
		return
	if _write_manual_slot(slot):
		hud.hide_save_slots()
		_log("进度已保存到存档 %02d" % slot)
		hud.show_item_toast("保存成功", "已保存到 %02d 号槽" % slot, Color("8fe6ff"))
		hud.refresh_load(_save_records())
	else:
		hud.show_item_toast("保存失败", "写入存档文件失败", Color("ff5566"))


func _delete_slot(slot: int) -> void:
	if slot == 0:
		return
	saves.delete_slot(slot)
	hud.show_load(_save_records())


func _load_slot(slot: int) -> void:
	var rec: Dictionary = saves.read_slot(slot)
	if rec.is_empty():
		hud.show_load(_save_records())
		return
	_apply_save(rec)
	hud.hide_start()
	_log("已载入%s" % ("自动存档" if slot == 0 else "存档 %02d" % slot))


func _int_array(v: Variant, n: int, def: int) -> Array:
	var out: Array = []
	for i in n:
		out.append(def)
	if v is Array:
		for i in mini(n, v.size()):
			out[i] = int(v[i])
	return out


## 读档：对缺字段逐个给默认值，旧版本存档也能直接载入
func _apply_save(rec: Dictionary) -> void:
	var g: Dictionary = rec.get("game", {})
	var sec: Dictionary = rec.get("sections", {})
	_restoring = true
	_start_match(
		clampi(int(g.get("mode", 0)), 0, 2),
		clampi(int(g.get("ai_level", 1)), 0, 2),
		String(g.get("theme", theme_id)),
		clampi(int(g.get("cells", 40)), 40, 64),
		g.get("styles", char_styles))
	var ht: Variant = g.get("human_teams", [])
	if ht is Array and not ht.is_empty():
		human_teams = []
		for t in ht:
			human_teams.append(clampi(int(t), 0, 3))
	var at: Variant = g.get("active_teams", [])
	if at is Array and not at.is_empty():
		active_teams = []
		for t in at:
			active_teams.append(clampi(int(t), 0, 3))

	# 棋子
	_apply_sections(sec)
	_restoring = false
	_update_all()
	if game_over and winner >= 0 and winner < 4:
		hud.show_win("%s 胜利" % TEAM_NAMES[winner], TEAM_COLORS[winner],
			"掷骰 %d 次 · 吃子 %d 次 · 抽卡 %d 张" % [rolls[winner], captures[winner], cards[winner].size()])
	else:
		_log("载入进度：第 %d 回合 · %s行动" % [turn_count, _team_display(current_team)])
		_maybe_ai_turn()


## 把存档/联机快照里的对局分区落到内存与场景上（不负责开局参数）
func _apply_sections(sec: Dictionary) -> void:
	var turn: Dictionary = sec.get("turn", {})
	var teams: Dictionary = sec.get("teams", {})
	var rows: Variant = sec.get("pieces", [])
	if rows is Array:
		for row in rows:
			if not (row is Dictionary):
				continue
			var t := int(row.get("t", -1))
			var i := int(row.get("i", -1))
			if t < 0 or t > 3 or i < 0 or i > 3:
				continue
			var idx := t * PIECES_PER_TEAM + i
			if idx >= pieces.size():
				continue
			var p: Dictionary = pieces[idx]
			p["cell"] = clampi(int(row.get("c", -1)), -1, FIELDS - 1)
			p["finished"] = bool(row.get("f", false))
			p["shield"] = bool(row.get("s", false))
			p["lane"] = clampi(int(row.get("l", -1)), -1, 3)
			p["lslot"] = clampi(int(row.get("ls", 0)), 0, PIECES_PER_TEAM)
			# 旧存档没有 lane 字段：按 finished 推断回本方通道并分配空槽
			if p["finished"] and int(p["lane"]) < 0:
				p["lane"] = int(p["team"])
				p["lslot"] = _free_goal_slot(int(p["team"]))
			p["finished"] = int(p["lane"]) == int(p["team"])

	# 队伍数据
	var card_rows: Variant = teams.get("cards", [])
	for t in 4:
		cards[t] = []
		if card_rows is Array and t < card_rows.size() and card_rows[t] is Array:
			for id in card_rows[t]:
				cards[t].append(String(id))
	captures = _int_array(teams.get("captures", []), 4, 0)
	rolls = _int_array(teams.get("rolls", []), 4, 0)
	frozen = _int_array(teams.get("frozen", []), 4, 0)
	boost_pending = int(teams.get("boost_pending", -1))
	double_team = int(teams.get("double_team", -1))

	# 回合状态
	current_team = clampi(int(turn.get("current_team", 0)), 0, 3)
	turn_count = maxi(0, int(turn.get("turn_count", 0)))
	six_streak = maxi(0, int(turn.get("six_streak", 0)))
	last_dice = clampi(int(turn.get("last_dice", 0)), 0, 6)
	game_over = bool(turn.get("game_over", false))
	winner = int(turn.get("winner", -1))

	# 棋盘随机标记
	arena.clear_random_marks()
	drops.clear()
	event_cells.clear()
	var board: Dictionary = sec.get("board", {})
	var ring_path: Array = paths[0] if not paths.is_empty() else []
	var drop_rows: Variant = board.get("drops", [])
	if drop_rows is Array:
		for r in drop_rows:
			var ri := int(r)
			if ri < 0 or ri >= ring_path.size():
				continue
			var node := arena.spawn_drop(_pt_pos(String(ring_path[ri])), arena.theme_accent())
			drops[ri] = {"node": node}
	var event_rows: Variant = board.get("events", [])
	if event_rows is Array:
		for row in event_rows:
			if not (row is Dictionary):
				continue
			var ri := int(row.get("r", -1))
			if ri < 0 or ri >= ring_path.size():
				continue
			var id := String(row.get("id", ""))
			var node := arena.spawn_event_cell(_pt_pos(String(ring_path[ri])),
				EVENT_COLORS.get(id, Color.WHITE), String(EVENT_SYMBOLS.get(id, "?")))
			event_cells[ri] = {"node": node, "id": id}

	# 棋子外观与位置
	for p in pieces:
		var node: Node3D = p["node"]
		arena.remove_shield(node)
		if p["shield"]:
			arena.add_shield(node)
		node.scale = Vector3.ONE
		if int(p.get("lane", -1)) >= 0:
			node.position = _goal_pos(int(p["lane"]), int(p.get("lslot", 1)))
		elif int(p["cell"]) >= 0:
			node.position = _piece_cell_pos(p)
		else:
			node.position = _pt_pos("HM%d_%d" % [p["team"] + 1, p["idx"] + 1])

	busy = false
	awaiting_pick = false
	card_mode = ""
	card_stage = 0
	card_slot = -1
	card_self = -1
	_pick_pool = []
	arena.clear_marks()
	arena.clear_piece_marks()
	arena.clear_movable()
	arena.clear_selection()
	hud.hide_pick()
	hud.hide_win()
	hud.hide_roulette()
	hud.set_dice(0)


# ---------------------------------------------------------------- 局域网联机

func _lan_wire() -> void:
	if lan == null:
		return
	lan.rooms_changed.connect(func(rooms: Array): hud.set_lan_rooms(rooms))
	lan.status.connect(func(text: String, color: Color): hud.set_lan_status(text, color))
	lan.guest_joined.connect(_on_lan_guest_joined)
	lan.guest_left.connect(_on_lan_guest_left)
	lan.match_started.connect(_on_lan_match_start)
	lan.state_received.connect(_on_lan_state)
	lan.intent_received.connect(_on_lan_intent)
	lan.log_received.connect(func(text: String): hud.log(text))
	lan.connected_to_host.connect(func(_info: Dictionary):
		hud.set_lan_status("已连上房主，正在同步对局…", Color("8fe6ff")))
	lan.link_lost.connect(_on_lan_link_lost)


func _lan_host_clicked(_name := "") -> void:
	if lan == null:
		return
	if lan.role == "host":
		hud.set_lan_hosting("房号 %s · %s:%d" % [lan.room_code, lan.local_ipv4(), lan.tcp_port])
		return
	var cfg := {
		"mode": 2, "theme": theme_id, "cells": board_cells,
		"styles": char_styles.duplicate(), "host": "骑士飞行棋房主",
	}
	if lan.start_host(cfg):
		hud.set_lan_hosting("房号 %s · %s:%d" % [lan.room_code, lan.local_ipv4(), lan.tcp_port])
		hud.set_lan_status("房间已创建，等待对手加入（房号 %s）" % lan.room_code, Color("8fe6ff"))
		print("LAN_HOST room=%s port=%d" % [lan.room_code, lan.tcp_port])


func _lan_join_clicked(ip: String, room: String) -> void:
	if lan == null:
		return
	if ip == "" and room == "":
		hud.set_lan_status("先选择一个附近房间，或填写房主 IP 与房号", Color("ffb86b"))
		return
	lan.join(ip, room)


func _lan_leave_clicked() -> void:
	if lan != null:
		lan.stop()
	net_role = ""
	match_started = false
	game_over = false
	busy = false
	hud.set_lan_idle()
	hud.set_lan_status("已离开联机", Color(1, 1, 1, 0.55))
	hud.set_dice(0)
	hud.show_lan()


func _on_lan_guest_joined(info: Dictionary) -> void:
	if net_role == "guest":
		return
	var rejoin: bool = bool(info.get("reconnect", false)) and match_started and game_mode == 2
	net_role = "host"
	net_guest_team = 1
	if not rejoin:
		_start_match(2, 1, theme_id, board_cells, char_styles)
		human_teams = [0, 1]
		active_teams = [0, 1]
		game_mode = 2
		net_role = "host"
	hud.hide_start()
	_net_dirty = false
	lan.send_start(_net_payload())
	if not rejoin:
		_log("对手已加入，开始局域网对局")
		hud.show_item_toast("联机开始", "你执红队，对手执蓝队", TEAM_COLORS[0])
	else:
		_log("对手已回座")
		hud.show_item_toast("对手已回座", "对局从断开处继续", Color("8fe6ff"))
	if _lan_testplay > 0 and not rejoin:
		_lan_testplay_loop()


## 联机自测：按回合轮流自动行动，打印两端状态签名用于对拍
func _lan_testplay_loop() -> void:
	var acts := 0
	while acts < _lan_testplay:
		await get_tree().create_timer(1.4).timeout
		if not match_started or game_over:
			break
		if awaiting_pick and not _pick_pool.is_empty():
			_on_piece_pressed(_pick_pool[0])
			acts += 1
			continue
		if card_mode == "" and _is_local_actor(current_team) and not busy:
			_on_roll_pressed()
			acts += 1
	if _cli_lan_autoquit:
		await get_tree().create_timer(1.0).timeout
		print("LAN_TEST_DONE ", net_role)
		get_tree().quit()


func _state_signature() -> String:
	var s := "t%d/%d:" % [turn_count, current_team]
	for p in pieces:
		s += "%d%s%s," % [int(p["cell"]), "F" if p["finished"] else "", "S" if p["shield"] else ""]
	return s.md5_text().substr(0, 10)


func _on_lan_guest_left() -> void:
	if net_role != "host":
		return
	hud.show_item_toast("对手断开", "保留房间 60 秒等待回座，可继续本地操作", Color("ffb86b"))


func _on_lan_match_start(payload: Dictionary) -> void:
	net_role = "guest"
	net_guest_team = int(lan.seat)
	_apply_net(payload)
	hud.hide_start()
	hud.show_item_toast("联机开始", "你执蓝队，等待房主行动", TEAM_COLORS[1])
	print("LAN_JOINED seat=", net_guest_team, " cells=", board_cells)
	if _lan_testplay > 0:
		_lan_testplay_loop()
	elif _cli_lan_autoquit and shot_path == "":
		await get_tree().create_timer(0.2).timeout
		get_tree().quit()


func _on_lan_state(payload: Dictionary) -> void:
	if net_role != "guest":
		return
	_apply_net(payload)


func _on_lan_intent(p: Dictionary) -> void:
	# 对决出拳要抢在 busy 判定之前：房主此时正阻塞等待客机出拳
	if String(p.get("a", "")) == "duel":
		if net_role == "host" and _duel_active:
			_duel_pick = clampi(int(p.get("pick", 0)), 0, 2)
		return
	if net_role != "host" or current_team != net_guest_team:
		return
	if busy or game_over or not match_started:
		return
	var a := String(p.get("a", ""))
	if a == "roll":
		if awaiting_pick or card_mode != "":
			return
		_do_roll()
	elif a == "pick":
		if awaiting_pick or card_mode != "":
			_on_piece_pressed(int(p.get("i", -1)))
	elif a == "card":
		if not awaiting_pick and card_mode == "":
			_on_card_pressed(int(p.get("s", -1)))


func _on_lan_link_lost(final: bool) -> void:
	if not final or net_role != "guest":
		return
	net_role = ""
	match_started = false
	game_over = false
	busy = false
	hud.show_lan()
	hud.set_lan_status("与房主的连接已断开，请重新加入", Color("ff6b6b"))


## 房主下行快照：对局分区 + 客机可操作项
func _net_payload() -> Dictionary:
	var st := _capture_state()
	var pick: Array = []
	for o in _pick_options:
		if not (o is Dictionary):
			continue
		var col: Color = o.get("color", Color.WHITE) if o.get("color") is Color else Color.WHITE
		pick.append({
			"index": int(o.get("index", -1)),
			"label": String(o.get("label", "")),
			"color": col.to_html(false),
		})
	st["net"] = {
		"team": current_team, "awaiting": awaiting_pick, "card_mode": card_mode,
		"pick": pick, "hint": _net_pick_hint, "dice": last_dice, "busy": busy,
		"guest_team": net_guest_team,
		"duel": {
			"active": _duel_active, "team": _duel_team,
			"target_team": _duel_target_team, "target_idx": _duel_target_idx,
			"until": _duel_until,
		},
	}
	return st


## 客机应用房主快照：只显示，不自行计算
func _apply_net(st: Dictionary) -> void:
	var g: Dictionary = st.get("game", {})
	var need_rebuild := (not match_started) or int(g.get("cells", board_cells)) != board_cells \
		or String(g.get("theme", theme_id)) != theme_id
	_restoring = true
	if need_rebuild:
		_start_match(2, 1, String(g.get("theme", theme_id)),
			clampi(int(g.get("cells", 40)), 40, 64), g.get("styles", char_styles))
		human_teams = [net_guest_team]
		net_role = "guest"
	var at: Variant = g.get("active_teams", [])
	if at is Array and not at.is_empty():
		active_teams = []
		for t in at:
			active_teams.append(clampi(int(t), 0, 3))
	_apply_sections(st.get("sections", {}))
	var net: Dictionary = st.get("net", {})
	current_team = clampi(int(net.get("team", current_team)), 0, 3)
	awaiting_pick = bool(net.get("awaiting", false))
	card_mode = String(net.get("card_mode", ""))
	_net_pick_hint = String(net.get("hint", ""))
	_pick_pool = []
	_pick_options = []
	var opts: Array = []
	for o in net.get("pick", []):
		if not (o is Dictionary):
			continue
		var idx := int(o.get("index", -1))
		if idx < 0:
			continue
		_pick_pool.append(idx)
		var col := Color.from_string(String(o.get("color", "")), TEAM_COLORS[0])
		opts.append({"index": idx, "label": String(o.get("label", "")), "color": col})
	_pick_options = opts
	# 对决：客机作为攻击方时，房主推送 duel.active，客机弹面板出拳
	var duel: Dictionary = net.get("duel", {})
	var dactive := bool(duel.get("active", false)) and int(duel.get("team", -1)) == net_guest_team
	if dactive:
		if not _duel_shown:
			_duel_shown = true
			var until_ms := int(duel.get("until", 0))
			var secs := 4.0
			if until_ms > 0:
				secs = clampf(float(until_ms - Time.get_ticks_msec()) / 1000.0, 1.0, 6.0)
			hud.show_duel(net_guest_team,
				clampi(int(duel.get("target_team", 0)), 0, 3),
				clampi(int(duel.get("target_idx", 0)), 0, 3), secs)
	elif _duel_shown:
		_duel_shown = false
		hud.hide_duel()
	if current_team == net_guest_team and not opts.is_empty():
		hud.show_pick(opts, _net_pick_hint)
	else:
		hud.hide_pick()
	_restoring = false
	hud.set_dice(int(net.get("dice", 0)))
	_update_all()
	if game_over and winner >= 0 and winner < 4:
		hud.show_win("%s 胜利" % TEAM_NAMES[winner], TEAM_COLORS[winner],
			"掷骰 %d 次 · 吃子 %d 次" % [rolls[winner], captures[winner]])


func _process(_delta: float) -> void:
	if net_role != "host" or lan == null or not _net_dirty:
		return
	var now := Time.get_ticks_msec()
	if now - _net_push_ms < 120:
		return
	_net_push_ms = now
	_net_dirty = false
	lan.send_state(_net_payload())


## 立即推送一次状态（对决等需要即时同步的场合）
func _net_push_now() -> void:
	if net_role != "host" or lan == null:
		return
	_net_push_ms = Time.get_ticks_msec()
	_net_dirty = false
	lan.send_state(_net_payload())


# ---------------------------------------------------------------- 对局管理

## 存档自测：写入 → 打乱内存 → 读回 → 校验（headless 可跑）
func _run_save_selftest() -> void:
	_start_match(0, 1, theme_id, board_cells, char_styles)
	pieces[0]["cell"] = 5
	pieces[1]["cell"] = 9
	pieces[1]["shield"] = true
	pieces[2]["finished"] = true
	cards[0] = ["boost", "warp"]
	captures = [2, 1, 0, 3]
	current_team = 2
	turn_count = 7
	var auto_ok: bool = saves.write_auto(_capture_state())
	var slot: int = saves.next_manual_slot()
	var man_ok: bool = saves.write_slot(slot, _capture_state())
	for p in pieces:
		p["cell"] = -1
		p["finished"] = false
		p["shield"] = false
	cards = [[], [], [], []]
	captures = [0, 0, 0, 0]
	current_team = 0
	turn_count = 0
	var rec: Dictionary = saves.read_slot(slot)
	_apply_save(rec)
	var ok: bool = int(pieces[0]["cell"]) == 5 and int(pieces[1]["cell"]) == 9 \
		and bool(pieces[1]["shield"]) and bool(pieces[2]["finished"]) \
		and cards[0].size() == 2 and String(cards[0][0]) == "boost" \
		and captures[0] == 2 and current_team == 2 and turn_count == 7 \
		and int(rec.get("fmt", 0)) == SaveStoreScript.FMT
	print("SELFTEST ", "OK" if ok else "FAIL", " auto=", auto_ok, " manual=", man_ok,
		" slots=", saves.count(), " cell=", int(pieces[0]["cell"]),
		" team=", current_team, " turn=", turn_count)
	saves.delete_slot(slot)
	saves.delete_slot(0)
	get_tree().quit()


## 换位自测：只跑占位试算，不依赖真实对局与节点（headless 可跑）
func _run_swap_selftest() -> void:
	var all_ok := true
	# 1. 普通格 ↔ 普通格
	var a1 := {"team": 0, "idx": 0, "cell": 5, "lane": -1, "lslot": 0}
	var b1 := {"team": 1, "idx": 0, "cell": 22, "lane": -1, "lslot": 0}
	var r1 := _swap_plan(a1, b1)
	var ok1: bool = String(r1["mode"]) == "full" \
		and int(r1["a"]["cell"]) == 22 and int(r1["a"]["lane"]) == -1 \
		and int(r1["b"]["cell"]) == 5 and int(r1["b"]["lane"]) == -1
	all_ok = _report_swap_case("plain", ok1) and all_ok
	# 2. 对方在自己通道：只能把对方拽出
	var a2 := {"team": 0, "idx": 0, "cell": 12, "lane": -1, "lslot": 0}
	var b2 := {"team": 1, "idx": 0, "cell": 39, "lane": 1, "lslot": 2}
	var r2 := _swap_plan(a2, b2)
	var ok2: bool = String(r2["mode"]) == "pull" \
		and int(r2["a"]["cell"]) == 12 and int(r2["a"]["lane"]) == -1 \
		and int(r2["b"]["cell"]) == 12 and int(r2["b"]["lane"]) == -1
	all_ok = _report_swap_case("enemy_lane", ok2) and all_ok
	# 3. 对方在我方通道：双方都能落到合法占位，真换
	var a3 := {"team": 0, "idx": 0, "cell": 12, "lane": -1, "lslot": 0}
	var b3 := {"team": 1, "idx": 0, "cell": 30, "lane": 0, "lslot": 3}
	var r3 := _swap_plan(a3, b3)
	var ok3: bool = String(r3["mode"]) == "full" \
		and int(r3["a"]["cell"]) == 30 and int(r3["a"]["lane"]) == 0 and int(r3["a"]["lslot"]) == 3 \
		and int(r3["b"]["cell"]) == 12 and int(r3["b"]["lane"]) == -1
	all_ok = _report_swap_case("my_lane", ok3) and all_ok
	# 4. 我方在对方通道：真换，我方回环道、对方回自己的通道
	var a4 := {"team": 0, "idx": 0, "cell": 30, "lane": 1, "lslot": 1}
	var b4 := {"team": 1, "idx": 0, "cell": 12, "lane": -1, "lslot": 0}
	var r4 := _swap_plan(a4, b4)
	var ok4: bool = String(r4["mode"]) == "full" \
		and int(r4["a"]["cell"]) == 12 and int(r4["a"]["lane"]) == -1 \
		and int(r4["b"]["cell"]) == 30 and int(r4["b"]["lane"]) == 1 and int(r4["b"]["lslot"]) == 1
	all_ok = _report_swap_case("other_lane", ok4) and all_ok
	if not all_ok:
		push_error("SWAP_SELFTEST FAIL")
	print("SWAP_SELFTEST DONE")
	get_tree().quit()


func _report_swap_case(case_name: String, ok: bool) -> bool:
	print("SWAP_CASE ", case_name, " ", "OK" if ok else "FAIL")
	if not ok:
		push_error("SWAP_CASE %s FAIL" % case_name)
	return ok


## 手动选槽自测：验证任意槽可写、自动槽 0 不被手动占用、多槽互不影响
func _run_save_slots_selftest() -> void:
	_start_match(0, 1, theme_id, board_cells, char_styles)
	for s in [0, 3, 4]:
		saves.delete_slot(s)
	var ok_auto: bool = saves.write_auto(_capture_state())
	var ok_man: bool = saves.write_slot(3, _capture_state())
	var kind3 := String(saves.read_slot(3).get("kind", ""))
	var kind0 := String(saves.read_slot(0).get("kind", ""))
	var ok_pick: bool = saves.exists(3) and saves.exists(0) \
		and kind3 == "manual" and kind0 == "auto"
	# 再存 4 号，3 号必须还在：证明可选任意槽且互不覆盖
	saves.write_slot(4, _capture_state())
	var ok_both: bool = saves.exists(3) and saves.exists(4) \
		and String(saves.read_slot(4).get("kind", "")) == "manual"
	# 自动存档必须落在 0 号，不能跑去手动槽
	var ok: bool = ok_auto and ok_man and ok_pick and ok_both
	print("SELFTEST_SLOTS ", "OK" if ok else "FAIL", " auto=", ok_auto, " manual=", ok_man,
		" slot3=", kind3, " slot0=", kind0, " both=", ok_both)
	for s in [0, 3, 4]:
		saves.delete_slot(s)
	get_tree().quit()


## 对决自测：强制胜/负两条路径，验证失败退回吃棋前格、胜利才真正吃子
func _run_duel_selftest() -> void:
	_start_match(0, 1, theme_id, board_cells, char_styles)
	duel_enabled = true
	var atk: Dictionary = pieces[0]
	var def: Dictionary = pieces[4]
	var red_cell := -1
	var blue_cell := -1
	for i in range(2, FIELDS):
		if _is_safe_cell(i):
			continue
		var pt: Vector3 = _pt_pos(_path_point(0, i))
		for j in FIELDS:
			if _pt_pos(_path_point(1, j)) == pt:
				red_cell = i
				blue_cell = j
				break
		if red_cell >= 0:
			break
	var ok_pos: bool = red_cell >= 2 and blue_cell >= 0
	# 强制失败：攻击方退回 from_cell，守方原地
	_duel_force = 2
	atk["cell"] = red_cell
	def["cell"] = blue_cell
	await _resolve_capture(atk, red_cell - 1)
	var ok_lose: bool = int(atk["cell"]) == red_cell - 1 and int(def["cell"]) == blue_cell
	# 强制胜利：守方回基地
	_duel_force = 1
	atk["cell"] = red_cell
	def["cell"] = blue_cell
	await _resolve_capture(atk, red_cell - 1)
	var ok_win: bool = int(def["cell"]) == -1 and int(atk["cell"]) == red_cell
	_duel_force = 0
	duel_enabled = false
	var ok: bool = ok_pos and ok_lose and ok_win
	print("SELFTEST_DUEL ", "OK" if ok else "FAIL", " pos=", ok_pos,
		" lose=", ok_lose, " win=", ok_win)
	get_tree().quit()


func _start_match(mode: int, level: int, selected_theme: String, cells := 40, styles: Array = []) -> void:
	Engine.time_scale = BASE_TIME_SCALE
	game_mode = mode
	ai_level = level
	theme_id = selected_theme
	board_cells = clampi(cells, 40, 64)
	var new_styles: Array = []
	for t in 4:
		var s := t
		if t < styles.size():
			s = int(styles[t])
		new_styles.append(clampi(s, 0, 7))
	var styles_changed := new_styles != char_styles
	char_styles = new_styles
	if board_cells != FIELDS:
		_apply_board_size(board_cells)
		_rebuild_arena()
	elif styles_changed:
		_rebuild_pieces()
	arena.set_theme(theme_id)
	_fit_camera()
	human_teams = [0] if mode == 0 else [0, 1, 2, 3]
	active_teams = [0, 1, 2, 3]
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
	turn_count = 0
	six_streak = 0
	roulette_open = false
	_roulette_segments = []
	cards = [[], [], [], []]
	captures = [0, 0, 0, 0]
	rolls = [0, 0, 0, 0]
	drops = {}
	event_cells = {}
	arena.clear_random_marks()
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
		hud.hide_roulette()
		hud.set_dice(0)
	_apply_theme_audio()
	_seed_random_marks()
	_update_all()
	_log("———— 新对局 ————")
	_log("主题：%s · 棋盘：%d 格" % [String(THEME_LABELS.get(theme_id, "暮色竞技场")), FIELDS])
	_log("掷出 6 点出基地，精确点数进终点")
	_log("踩中道具格 / 事件格会自动开启俄罗斯轮盘，转出什么拿什么")
	if mode == 0:
		_log("AI 难度：%s" % ["简单", "普通", "困难"][ai_level])
	_auto_save()
	_maybe_ai_turn()


func _reset_view() -> void:
	_fit_camera()


# ---------------------------------------------------------------- 棋盘工具

func _pt_pos(name: String) -> Vector3:
	if not pts.has(name):
		return Vector3(0, BOARD_Y, 0)
	var p: Array = pts[name]
	return Vector3(float(p[0]), BOARD_Y, float(p[2]))


func _path_point(team: int, cell: int) -> String:
	return paths[team][clampi(cell, 0, FIELDS - 1)]


func _piece_cell_pos(p: Dictionary) -> Vector3:
	if int(p.get("lane", -1)) >= 0:
		return _goal_pos(int(p["lane"]), int(p.get("lslot", 1)))
	if p["cell"] < 0:
		return _pt_pos("HM%d_%d" % [p["team"] + 1, p["idx"] + 1])
	return _pt_pos(_path_point(p["team"], p["cell"]))


func _goal_pos(team: int, slot: int) -> Vector3:
	return _pt_pos("GL%d_%d" % [team + 1, clampi(slot, 1, 4)])


func _is_ai(team: int) -> bool:
	return not (team in human_teams)


func _team_is_human(team: int) -> bool:
	if net_role == "host":
		return team == 0
	if net_role == "guest":
		return team == net_guest_team
	return team in human_teams


## 吃棋对决（石头剪刀布）：攻击方出拳、守方随机；返回攻击方是否胜利
func _duel_attack(p: Dictionary, q: Dictionary) -> bool:
	if _duel_force != 0:
		return _duel_force == 1
	var atk_team: int = p["team"]
	var def_team: int = q["team"]
	var pick := -1
	var local_human := false
	_duel_team = atk_team
	_duel_target_team = def_team
	_duel_target_idx = int(q["idx"])
	if net_role == "host" and atk_team == net_guest_team:
		# 房主权威：客机出拳通过 intent 回传，5 秒未回则随机
		_duel_active = true
		_duel_pick = -1
		_duel_until = Time.get_ticks_msec() + 5200
		_net_dirty = true
		_net_push_now()
		var t0 := Time.get_ticks_msec()
		while _duel_pick < 0 and Time.get_ticks_msec() - t0 < 5400:
			await get_tree().create_timer(0.08).timeout
		pick = _duel_pick if _duel_pick >= 0 else randi() % 3
		_duel_active = false
		_duel_until = 0
		_net_dirty = true
		_net_push_now()
	elif auto_mode or shot_path != "" or not _team_is_human(atk_team):
		pick = randi() % 3
	else:
		# 本地人类攻方：弹面板等出拳
		local_human = true
		_duel_pick = -1
		hud.show_duel(atk_team, def_team, int(q["idx"]), 4.0)
		pick = clampi(int(await hud.duel_chosen), 0, 2)
	var dpick := randi() % 3
	var names := ["石头", "剪刀", "布"]
	var win := (int(pick) - dpick + 3) % 3 == 1
	if local_human:
		hud.duel_result(int(pick), dpick, win)
	_log("吃棋对决：%s %s vs %s %s → %s" % [
		TEAM_NAMES[atk_team], names[int(pick)],
		TEAM_NAMES[def_team], names[dpick], "胜利" if win else "失败"])
	return win


## 设置页开关：吃棋对决总开关
func _on_duel_toggled(on: bool) -> void:
	duel_enabled = on
	_save_prefs()


## 对决面板回传的出拳；客机通过 intent 交给房主判定
func _on_duel_chosen(pick: int) -> void:
	_duel_pick = clampi(pick, 0, 2)
	if net_role == "guest" and lan != null:
		lan.send_intent({"a": "duel", "pick": _duel_pick})


## 按参与队伍轮转（局域网只有红蓝两队时自动跳过绿/黄）
func _next_team(team: int) -> int:
	var i := active_teams.find(team)
	if i < 0:
		i = 0
	return int(active_teams[(i + 1) % active_teams.size()])


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
		if p["team"] != current_team or p["finished"] or int(p.get("lane", -1)) >= 0:
			continue
		if p["cell"] < 0:
			if total == 6:
				out.append(i)
		elif p["cell"] + total <= FIELDS - 1:
			out.append(i)
	return out


func _cell_step() -> int:
	return maxi(FIELDS / 4, 1)


func _is_safe_cell(cell: int) -> bool:
	return cell >= 0 and cell % _cell_step() == 0


func _is_treasure_cell(cell: int) -> bool:
	return cell >= 0 and cell % _cell_step() == _cell_step() / 2


func _is_portal_cell(cell: int) -> bool:
	return cell >= 0 and cell % _cell_step() == _cell_step() * 3 / 10


func _is_thorn_cell(cell: int) -> bool:
	return cell >= 0 and cell % _cell_step() == _cell_step() * 7 / 10


## 固定道具拾取格：每两段出现一次（整盘约 2 个），踩中即开道具轮盘
func _is_item_cell(cell: int) -> bool:
	if cell < 0:
		return false
	var step := _cell_step()
	var quarter: int = cell / step
	return quarter % 2 == 0 and cell % step == step * 2 / 10


func _resolve_capture(p: Dictionary, from_cell := -1) -> bool:
	if _is_safe_cell(p["cell"]):
		return false
	var point := _path_point(p["team"], p["cell"])
	var hit_any := false
	for q in pieces:
		if q["team"] == p["team"] or q["finished"] or int(q.get("lane", -1)) >= 0 or q["cell"] < 0:
			continue
		if _path_point(q["team"], q["cell"]) != point:
			continue
		hit_any = true
		# 吃棋对决：攻击方出拳、守方随机；输或平则发起吃棋的一方退回吃棋前的格子
		if duel_enabled and not await _duel_attack(p, q):
			if from_cell >= 0:
				p["cell"] = from_cell
				arena.piece_recoil(p["node"], p["node"].position - q["node"].position, 1.4)
				await _hop_to(p, _piece_cell_pos(p))
			_log("对决失利：%s 的 %d 号棋子退回第 %d 格" % [
				TEAM_NAMES[p["team"]], p["idx"] + 1, int(p["cell"]) + 1])
			_play(click_player)
			return false
		if q["shield"]:
			q["shield"] = false
			arena.remove_shield(q["node"])
			_log("%s 的护盾挡下了攻击" % TEAM_NAMES[q["team"]])
			arena.pulse(q["node"].position, Color("8fe6ff"))
			arena.fx_sound("cap_block")
			continue
		var pos: Vector3 = q["node"].position
		q["cell"] = -1
		q["lane"] = -1
		q["lslot"] = 0
		q["finished"] = false
		# 慢动作踩爆：整段过程把时间放慢，读得清跳跃、滞空与压扁（音效由 capture_stomp 内部按阶段播放）
		Engine.time_scale = 0.65
		await arena.capture_stomp(p["node"], q["node"], TEAM_COLORS[p["team"]])
		Engine.time_scale = BASE_TIME_SCALE
		q["node"].position = _pt_pos("HM%d_%d" % [q["team"] + 1, q["idx"] + 1])
		q["node"].scale = Vector3.ONE
		q["node"].rotation = Vector3.ZERO
		q["node"].visible = true
		hud.screen_flash(TEAM_COLORS[p["team"]], 0.26)
		_shake(0.30, 18.0)
		captures[p["team"]] += 1
		_log("%s 吃掉了 %s 的 %d 号棋子" % [TEAM_NAMES[p["team"]], TEAM_NAMES[q["team"]], q["idx"] + 1])
		# 吃子奖励：抽一张道具卡
		if cards[p["team"]].size() < 4:
			_draw_card(p["team"], false, Vector3(pos.x, BOARD_Y, pos.z))
	if hit_any:
		_play(click_player)
	return hit_any


func _advance(p: Dictionary, steps: int) -> bool:
	var from_cell := -1
	if p["cell"] < 0:
		p["cell"] = 0
		await _hop_to(p, _piece_cell_pos(p))
		arena.pulse(_piece_cell_pos(p), TEAM_COLORS[p["team"]])
	else:
		for _i in steps:
			if p["cell"] >= FIELDS - 1:
				break
			from_cell = p["cell"]
			p["cell"] += 1
			await _hop_to(p, _piece_cell_pos(p))
	var captured: bool = await _resolve_capture(p, from_cell)
	arena.pulse(_piece_cell_pos(p), TEAM_COLORS[p["team"]])
	if p["cell"] == FIELDS - 1:
		await _finish_piece(p)
	return captured


func _finish_piece(p: Dictionary) -> void:
	var slot := _free_goal_slot(int(p["team"]))
	p["finished"] = true
	p["lane"] = int(p["team"])
	p["lslot"] = slot
	p["cell"] = FIELDS - 1
	var pos := _goal_pos(p["team"], slot)
	await _hop_to(p, pos)
	arena.flash_piece(p["node"])
	arena.pulse(pos, TEAM_COLORS[p["team"]])
	arena.finish_beam(pos, TEAM_COLORS[p["team"]])
	_play(click_player)
	_log("%s 的 %d 号棋子抵达终点" % [TEAM_NAMES[p["team"]], p["idx"] + 1])


func _free_goal_slot(team: int) -> int:
	var used := {}
	for q in pieces:
		if int(q.get("lane", -1)) == team:
			used[int(q.get("lslot", 0))] = true
	for s in range(PIECES_PER_TEAM, 0, -1):
		if not used.has(s):
			return s
	return 1


func _check_win(team: int) -> bool:
	for q in pieces:
		if q["team"] == team and int(q.get("lane", -1)) != team:
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
	t.tween_property(node, "position", node.position + Vector3(0, 34, 0), 0.10)
	t.tween_property(node, "position", target, 0.12)
	await t.finished


# ---------------------------------------------------------------- 回合流程

func _on_roll_pressed() -> void:
	if net_role == "guest":
		if _is_local_actor(current_team) and not busy and not awaiting_pick and card_mode == "" and match_started:
			lan.send_intent({"a": "roll"})
		return
	if net_role == "host" and current_team != 0:
		return
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
	# 功能拓展：连续两次掷出 6 点触发「双六连击」，额外抽一张道具卡
	if raw == 6:
		six_streak += 1
	else:
		six_streak = 0
	if six_streak >= 2:
		six_streak = 0
		var lead_i := _lead_piece(current_team)
		var drop_pos := Vector3.ZERO
		if lead_i >= 0:
			var lp: Dictionary = pieces[lead_i]
			drop_pos = Vector3(lp["node"].position.x, BOARD_Y, lp["node"].position.z)
		if _draw_card(current_team, true, drop_pos):
			hud.show_item_toast("双六连击", "%s 连续两次掷出 6 点，额外获得一张道具卡" % TEAM_NAMES[current_team],
				Color("ffe066"))
			hud.screen_flash(Color("ffe066"), 0.3)
			_log("%s 连续两次掷出 6 点，额外抽到「%s」" % [TEAM_NAMES[current_team],
				ITEM_NAMES.get(cards[current_team][cards[current_team].size() - 1], "道具")])
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
	_pick_options = options
	_net_pick_hint = "掷出 %d 点，点棋子或按钮选择" % total
	arena.mark_tiles(dests, TEAM_COLORS[current_team])
	arena.show_movable(nodes, TEAM_COLORS[current_team])
	if _is_local_actor(current_team):
		hud.show_pick(options, _net_pick_hint)


func _on_piece_pressed(idx: int) -> void:
	if net_role == "guest":
		if _pick_pool.has(idx):
			lan.send_intent({"a": "pick", "i": idx})
		return
	if net_role == "host" and current_team != 0:
		return
	if card_mode != "":
		await _apply_card(idx)
		return
	if not awaiting_pick:
		return
	awaiting_pick = false
	_pick_pool = []
	_pick_options = []
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
		await _on_land(p, 0)
	else:
		_check_win(p["team"])
	_update_all()
	if game_over:
		return
	_finish_turn(last_dice == 6 or captured)


## 落点结算：随机掉落 → 随机事件格 → 固定道具格 → 固定地形（秘宝/传送/荆棘/安全）
func _on_land(p: Dictionary, depth: int) -> void:
	if p["finished"] or p["cell"] < 0:
		return
	var ri := _ring_idx(p)
	if ri >= 0 and drops.has(ri):
		await _collect_drop(p, ri)
		if p["finished"]:
			return
	if p["cell"] < 0:
		return
	ri = _ring_idx(p)
	if ri >= 0 and event_cells.has(ri):
		await _consume_event_cell(p, ri)
		if p["finished"]:
			return
	if p["cell"] < 0:
		return
	# 固定道具拾取格：转道具轮盘
	if _is_item_cell(p["cell"]):
		await _run_roulette("item", p)
		if p["finished"] or p["cell"] < 0:
			return
	var cell: int = p["cell"]
	if _is_treasure_cell(cell):
		await _run_roulette("event", p)
		if p["finished"] or p["cell"] < 0:
			return
	if _is_portal_cell(p["cell"]):
		await _portal_jump(p)
		if p["finished"] or p["cell"] < 0:
			return
		if depth < 1:
			await _on_land(p, depth + 1)
		return
	if _is_thorn_cell(p["cell"]):
		await _thorn_punish(p)
	if p["finished"] or p["cell"] < 0:
		return
	# 安全格：踏入自动获得一层护盾
	if not p["shield"] and _is_safe_cell(p["cell"]):
		p["shield"] = true
		arena.add_shield(p["node"])
		arena.item_cast(p["node"], Color("8fe6ff"), "shield")
		hud.show_item_toast("安全区", "踏入安全区，获得一层护盾", Color("8fe6ff"))
		_log("%s 的 %d 号棋子进入安全区，获得护盾" % [TEAM_NAMES[p["team"]], p["idx"] + 1])


func _collect_drop(p: Dictionary, ri: int) -> void:
	var info: Dictionary = drops.get(ri, {})
	drops.erase(ri)
	if info.has("node"):
		arena.remove_drop(info["node"])
	var pos: Vector3 = p["node"].position
	arena.item_pickup(Vector3(pos.x, BOARD_Y, pos.z), Color("ffe066"))
	arena.piece_celebrate(p["node"])
	_play(sfx_drop)
	hud.screen_flash(Color("ffe066"), 0.16)
	_log("%s 拾取了随机掉落的宝箱，转动道具轮盘" % TEAM_NAMES[p["team"]])
	await _run_roulette("item", p)
	await get_tree().create_timer(0.15).timeout
	if drops.size() < 3:
		_spawn_random_drop()


func _consume_event_cell(p: Dictionary, ri: int) -> void:
	var info: Dictionary = event_cells.get(ri, {})
	event_cells.erase(ri)
	if info.has("node"):
		arena.remove_event_cell(info["node"])
	arena.event_ring(p["node"].position, arena.theme_accent())
	_log("%s 踩中命运之格，转动事件轮盘" % TEAM_NAMES[p["team"]])
	await _run_roulette("event", p)
	await get_tree().create_timer(0.15).timeout
	if event_cells.size() < 3:
		_spawn_random_event_cell()


func _portal_jump(p: Dictionary) -> void:
	var from: int = p["cell"]
	var to := mini(from + 4, FIELDS - 1)
	if to == from:
		return
	var node: Node3D = p["node"]
	var purple := Color("b484ff")
	arena.fx_sound("it_teleport")
	# 1. 起点：旋转缩小被吸入，脚下紫色光环爆发（0.22s）
	arena.event_ring(node.position, purple)
	var suck := create_tween()
	suck.set_parallel(true)
	suck.tween_property(node, "scale", Vector3.ONE * 0.06, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	suck.tween_property(node, "rotation:y", node.rotation.y + TAU, 0.22)
	await suck.finished
	# 2. 消失瞬间写数据，此后棋子暂不可见
	p["cell"] = to
	node.visible = false
	# 3. 目标点：光环再爆发一次，棋子从 0.06 放大回 1.0 并反向旋转落位（0.28s）
	var target := _piece_cell_pos(p)
	node.position = target
	node.visible = true
	arena.event_ring(target, purple)
	var pop := create_tween()
	pop.set_parallel(true)
	pop.tween_property(node, "scale", Vector3.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(node, "rotation:y", node.rotation.y - TAU, 0.28)
	await pop.finished
	# 4. 落点补一次原地小跳，保持与原有落点 / 终点判定兼容
	await _hop_to(p, _piece_cell_pos(p))
	hud.show_item_toast("传 送 门", "%s 的 %d 号棋子被传送到第 %d 格" % [
		TEAM_NAMES[p["team"]], p["idx"] + 1, to + 1], purple)
	hud.screen_flash(purple, 0.22)
	_log("%s 的 %d 号棋子踏入传送门，前进 4 格" % [TEAM_NAMES[p["team"]], p["idx"] + 1])
	if p["cell"] >= FIELDS - 1:
		await _finish_piece(p)


func _thorn_punish(p: Dictionary) -> void:
	var back := mini(2, int(p["cell"]))
	if back <= 0:
		return
	var node: Node3D = p["node"]
	var base_y := node.position.y
	# 1. 棋子脚下荆棘窜起
	arena.spike_burst(Vector3(node.position.x, BOARD_Y, node.position.z), Color("ff5566"))
	# 2. 镜头震动
	_shake(0.22, 14.0)
	# 等尖刺钻出地面再顶棋子，两件事错开才看得清
	await get_tree().create_timer(0.12).timeout
	# 3. 被荆棘顶起再落下（一次小跳，0.30s）
	var lift := create_tween()
	lift.tween_property(node, "position:y", base_y + 26.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	lift.tween_property(node, "position:y", base_y, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await lift.finished
	arena.piece_hit(node)
	# 4. 逐格后退：先改数据再跳格，格与格之间留 0.06s 间隔
	for _i in back:
		p["cell"] = int(p["cell"]) - 1
		await _hop_to(p, _piece_cell_pos(p))
		await get_tree().create_timer(0.06).timeout
	# 5. 提示与其余反馈
	hud.show_item_toast("荆 棘 地", "被荆棘缠住，后退 %d 格" % back, Color("ff5566"))
	hud.screen_flash(Color("ff5566"), 0.20)
	_play(sfx_event)
	_log("%s 的 %d 号棋子踩中荆棘，后退 %d 格" % [TEAM_NAMES[p["team"]], p["idx"] + 1, back])
	await get_tree().create_timer(0.3).timeout


# ---------------------------------------------------------------- 随机掉落 / 事件格

func _random_free_ring() -> int:
	var candidates: Array = []
	for i in FIELDS:
		if drops.has(i) or event_cells.has(i):
			continue
		if _is_safe_cell(i) or _is_treasure_cell(i) or _is_portal_cell(i) or _is_thorn_cell(i):
			continue
		if _is_item_cell(i):
			continue
		candidates.append(i)
	if candidates.is_empty():
		return -1
	return int(candidates[randi() % candidates.size()])


func _spawn_random_drop() -> void:
	if drops.size() >= 4:
		return
	var ri := _random_free_ring()
	if ri < 0:
		return
	var pname: String = paths[0][ri]
	var node := arena.spawn_drop(_pt_pos(pname), arena.theme_accent())
	drops[ri] = {"node": node}


func _spawn_random_event_cell(forced := "") -> void:
	if event_cells.size() >= 5:
		return
	var ri := _random_free_ring()
	if ri < 0:
		return
	var id := forced
	if id == "":
		var pool := _roulette_event_pool()
		id = pool[randi() % pool.size()]
	var node := arena.spawn_event_cell(_pt_pos(paths[0][ri]),
		EVENT_COLORS.get(id, Color.WHITE), String(EVENT_SYMBOLS.get(id, "?")))
	event_cells[ri] = {"node": node, "id": id}


## 每个回合开始都随机补充掉落与事件格：随机回合 → 随机空格
func _maybe_spawn_random() -> void:
	if randf() < 0.7:
		_spawn_random_drop()
	if randf() < 0.55:
		_spawn_random_event_cell()
	if randf() < 0.28:
		_spawn_random_event_cell()


func _seed_random_marks() -> void:
	_spawn_random_drop()
	_spawn_random_drop()
	_spawn_random_drop()
	_spawn_random_event_cell()
	_spawn_random_event_cell()


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
		current_team = _next_team(current_team)
		_skip_frozen()
		turn_count += 1
		_maybe_spawn_random()
		_auto_save()
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
		current_team = _next_team(current_team)


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
	if net_role == "guest":
		if _is_local_actor(current_team) and not busy and not awaiting_pick and card_mode == "" and match_started:
			lan.send_intent({"a": "card", "s": slot})
		return
	if net_role == "host" and current_team != 0:
		return
	if busy or game_over or awaiting_pick or not match_started:
		return
	if _is_ai(current_team) or card_mode != "":
		return
	if slot < 0 or slot >= cards[current_team].size():
		return
	var id: String = cards[current_team][slot]
	if id == "boost" or id == "double" or id == "freeze" or id == "vortex" or id == "steal" \
			or id == "jadeguard" or id == "voidstep":
		_use_instant_card(slot, id)
		return

	var pool: Array = []
	for i in pieces.size():
		var p: Dictionary = pieces[i]
		# 需要指定对手的道具
		if id == "snipe" or id == "frostlock" or id == "bomb":
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
			"gale":
				step = 2
		if step > 0 and int(p["cell"]) + step > FIELDS - 1:
			continue
		pool.append(i)
	if pool.is_empty():
		_play(nope_player)
		_log("现在没有可以%s的棋子" % ITEM_NAMES[id])
		return
	_enter_card_pick(id, slot, pool, "选择要使用「%s」的棋子" % ITEM_NAMES[id])


# ---------------------------------------------------------------- 道具 3D 演出
# 四段式：施法动作 → 传递 → 受击反应 → 结果。
# 这里只演，不改 cell / frozen / cards / shield；数据由主流程在 await 返回后写。

func _item_pos(p: Dictionary, cell: int) -> Vector3:
	var q := p.duplicate()
	q["cell"] = cell
	q["lane"] = -1
	q["lslot"] = 0
	return _piece_cell_pos(q)


## 演出把节点临时挪走后，用真实数据把节点对齐，避免与主流程写入的格子脱节
func _snap_piece(p: Dictionary) -> void:
	if p.has("node") and is_instance_valid(p["node"]):
		(p["node"] as Node3D).position = _piece_cell_pos(p)


func _cast_hud(team: int, item_id: String, target_text: String, effect_text: String) -> void:
	if hud != null:
		hud.show_item_cast(team, item_id, target_text, effect_text)


## 护盾罩默认冰蓝，玉灵护体要染成玉色以区分
func _tint_shield(node: Node3D, color: Color) -> void:
	if node == null or not is_instance_valid(node):
		return
	var sh := node.get_node_or_null("Shield")
	if sh == null:
		return
	var mat := (sh as MeshInstance3D).material_override as StandardMaterial3D
	if mat == null:
		return
	mat.albedo_color = Color(color.r, color.g, color.b, 0.17)
	mat.emission = color


func _play_item_fx(caster: Dictionary, item_id: String, target: Dictionary, params: Dictionary) -> Dictionary:
	var color: Color = ITEM_COLORS.get(item_id, Color.WHITE)
	var team := int(params.get("team", caster.get("team", current_team)))
	var spd := 0.5 if _is_ai(team) else 1.0
	var cnode: Node3D = null
	if not caster.is_empty() and caster.has("node") and is_instance_valid(caster["node"]):
		cnode = caster["node"]
	var tnode: Node3D = null
	if not target.is_empty() and target.has("node") and is_instance_valid(target["node"]):
		tnode = target["node"]
	var target_text := String(params.get("target_text", "→ 自己"))
	var effect_text := String(params.get("effect", ITEM_DESC.get(item_id, "")))
	var hits: Array = []
	var changed := 0
	match item_id:
		"boost":
			if cnode != null:
				await arena.anim_windup(cnode, color, 0.18 * spd)
				await arena.speed_lines(cnode, color, 3, 0.3 * spd)
				await arena.anim_release(cnode, color, 0.12 * spd)
				arena.event_ring(cnode.position, color)
				arena.fx_sound("it_boost")
			else:
				await get_tree().create_timer(0.3 * spd).timeout
			_cast_hud(team, item_id, target_text, effect_text)
		"double":
			if cnode != null:
				var c := cnode.position + Vector3(0, 62, 0)
				arena.orb_fly(c + Vector3(-130, 30, -50), c, color, "spark", 0.34 * spd)
				arena.orb_fly(c + Vector3(130, 30, 50), c, color, "spark", 0.34 * spd)
				await get_tree().create_timer(0.36 * spd).timeout
				await arena.anim_windup(cnode, color, 0.18 * spd)
				arena.item_glyph(cnode, "double", color, Vector3(0.25, 0, 0.2))
				arena.item_glyph(cnode, "double", color, Vector3(-0.2, 0, 0.1))
				arena.fx_sound("it_double")
			else:
				await get_tree().create_timer(0.3 * spd).timeout
			_cast_hud(team, item_id, target_text, effect_text)
		"shield":
			if cnode != null:
				await arena.shield_build(cnode, color, 12, 0.35 * spd)
				arena.add_shield(cnode)
				arena.fx_sound("it_shield")
				var sh := cnode.get_node_or_null("Shield")
				if sh != null:
					var bt := create_tween()
					bt.tween_property(sh, "scale", Vector3(1.07, 1.07, 1.07), 0.32 * spd)
					bt.tween_property(sh, "scale", Vector3.ONE, 0.32 * spd)
					await bt.finished
			else:
				await get_tree().create_timer(0.3 * spd).timeout
			_cast_hud(team, item_id, target_text, effect_text)
		"warp":
			var steps_w := int(params.get("steps", 3))
			if cnode != null:
				var from_w := int(caster["cell"])
				await arena.anim_windup(cnode, color, 0.18 * spd)
				for i in steps_w:
					var pt := _item_pos(caster, from_w + i + 1)
					arena._spawn_swap_ghost(cnode, cnode.position, color)
					var t := create_tween()
					t.tween_property(cnode, "position", pt, 0.14 * spd).set_trans(Tween.TRANS_SINE)
					await t.finished
				await arena.anim_release(cnode, color, 0.12 * spd)
				arena.event_ring(cnode.position, color)
				arena.fx_sound("it_warp")
			else:
				await get_tree().create_timer(0.3 * spd).timeout
			_cast_hud(team, item_id, target_text, effect_text)
		"teleport":
			var steps_t := int(params.get("steps", 5))
			if cnode != null:
				var from_t := int(caster["cell"])
				var s0 := cnode.scale
				arena.finish_beam(cnode.position, color)
				var shrink := create_tween()
				shrink.set_parallel(true)
				shrink.tween_property(cnode, "scale", Vector3(0.06, 0.06, 0.06), 0.26 * spd)
				shrink.tween_property(cnode, "rotation:y", cnode.rotation.y + TAU, 0.26 * spd)
				await shrink.finished
				cnode.visible = false
				var to_t := _item_pos(caster, from_t + steps_t)
				arena.snipe_streak(cnode.position, to_t + Vector3(0, 60, 0), color)
				arena.orb_fly(cnode.position + Vector3(0, 60, 0), to_t + Vector3(0, 60, 0), color, "spark", 0.2 * spd)
				await get_tree().create_timer(0.22 * spd).timeout
				cnode.position = to_t
				cnode.visible = true
				var grow := create_tween()
				grow.tween_property(cnode, "scale", s0, 0.18 * spd).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				await grow.finished
				arena.event_ring(to_t, color)
				arena.impact_kind("ice", to_t, color)
				arena.fx_sound("it_teleport")
			else:
				await get_tree().create_timer(0.3 * spd).timeout
			_cast_hud(team, item_id, target_text, effect_text)
		"gale":
			var steps_g := int(params.get("steps", 2))
			if cnode != null:
				var from_g := int(caster["cell"])
				await arena.anim_windup(cnode, color, 0.16 * spd)
				await arena.wind_rings(cnode, color, 3, 0.4 * spd)
				arena._fx_spiral(cnode.position, color, 16, 54.0, 96.0, false)
				arena.speed_lines(cnode, color, 3, 0.32 * spd, cnode.position - Vector3(40, 0, 40))
				await get_tree().create_timer(0.12 * spd).timeout
				for i in steps_g:
					var pt2 := _item_pos(caster, from_g + i + 1)
					arena._spawn_swap_ghost(cnode, cnode.position, color)
					var tg := create_tween()
					tg.tween_property(cnode, "position", pt2, 0.15 * spd).set_trans(Tween.TRANS_SINE)
					await tg.finished
				arena._spawn_swap_ghost(cnode, cnode.position, color)
				arena.event_ring(cnode.position, color)
				arena.fx_sound("it_gale")
			else:
				await get_tree().create_timer(0.3 * spd).timeout
			_cast_hud(team, item_id, target_text, effect_text)
		"snipe":
			var back_s := int(params.get("back", 3))
			var from_s := int(target.get("cell", 0))
			if cnode != null:
				if tnode != null:
					cnode.rotation.y = atan2(tnode.position.x - cnode.position.x, tnode.position.z - cnode.position.z)
				await arena.anim_windup(cnode, color, 0.18 * spd)
			if tnode != null:
				await arena.lock_on(tnode, color, 0.2 * spd)
				arena.orb_fly(cnode.position + Vector3(0, 68, 0) if cnode != null else tnode.position + Vector3(0, 120, 0),
					tnode.position + Vector3(0, 58, 0), color, "spark", 0.16 * spd)
				await get_tree().create_timer(0.17 * spd).timeout
				arena.impact_kind("hit", tnode.position, color)
				arena.piece_hit(tnode)
				await arena.piece_recoil(tnode, tnode.position - (cnode.position if cnode != null else tnode.position), 1.1)
				for i in back_s:
					var pt3 := _item_pos(target, from_s - i - 1)
					arena.event_ring(pt3, Color("c9b89a"))
					var ts := create_tween()
					ts.tween_property(tnode, "position", pt3, 0.1 * spd)
					await ts.finished
				arena.impact_kind("hit", tnode.position, color)
				hits.append(target)
				changed += back_s
				arena.fx_sound("it_snipe")
			_cast_hud(team, item_id, target_text, effect_text)
		"freeze":
			if cnode != null:
				await arena.anim_windup(cnode, color, 0.18 * spd)
				if tnode != null:
					await arena.tether(cnode, tnode, color, 0.35 * spd)
					arena.impact_kind("ice", tnode.position, color)
					await arena.ice_shell(tnode, color, 0.45 * spd)
					hits.append(target)
				arena.fx_sound("it_freeze")
			else:
				await get_tree().create_timer(0.3 * spd).timeout
			_cast_hud(team, item_id, target_text, effect_text)
		"frostlock":
			var back_f := int(params.get("back", 2))
			var from_f := int(target.get("cell", 0))
			if cnode != null:
				await arena.anim_windup(cnode, color, 0.18 * spd)
			if tnode != null:
				if cnode != null:
					await arena.tether(cnode, tnode, color, 0.32 * spd)
				arena._fx_chains(tnode.position, color)
				_cast_hud(team, item_id, target_text, effect_text)
				await get_tree().create_timer(0.22 * spd).timeout
				await arena.piece_recoil(tnode, tnode.position - (cnode.position if cnode != null else tnode.position), 0.8)
				for i in back_f:
					var pt4 := _item_pos(target, from_f - i - 1)
					arena.event_ring(pt4, color)
					var tf := create_tween()
					tf.tween_property(tnode, "position", pt4, 0.11 * spd)
					await tf.finished
				await arena.ice_shell(tnode, color, 0.4 * spd)
				hits.append(target)
				changed += back_f
				arena.fx_sound("it_frostlock")
			else:
				_cast_hud(team, item_id, target_text, effect_text)
		"vortex":
			if cnode != null:
				await arena.anim_windup(cnode, color, 0.16 * spd)
				await arena.anim_release(cnode, color, 0.12 * spd)
				arena.event_ring(Vector3(0, BOARD_Y, 0), color)
				arena.impact_kind("gravity", Vector3(0, BOARD_Y, 0), color)
				arena.fx_sound("it_vortex")
			_cast_hud(team, item_id, target_text, effect_text)
			var victims_v: Array = params.get("victims", [])
			for v in victims_v:
				await get_tree().create_timer(0.1 * spd).timeout
				var qv: Dictionary = v["p"]
				var vn: Node3D = qv["node"]
				if vn == null or not is_instance_valid(vn):
					continue
				var squash := create_tween()
				squash.tween_property(vn, "scale", Vector3(1.2, 0.74, 1.2), 0.08)
				squash.tween_property(vn, "scale", Vector3.ONE, 0.1)
				await squash.finished
				var dest_v := _item_pos(qv, int(qv["cell"]) - 1)
				var mv := create_tween()
				mv.tween_property(vn, "position", dest_v, 0.13 * spd).set_trans(Tween.TRANS_QUAD)
				await mv.finished
				arena.event_ring(dest_v, color)
				hits.append(qv)
				changed += 1
		"steal":
			if cnode != null:
				await arena.anim_windup(cnode, color, 0.16 * spd)
				var dir_s := (tnode.position - cnode.position) if tnode != null else Vector3(0, 0, 1)
				await arena.speed_lines(cnode, color, 3, 0.3 * spd, dir_s)
				if tnode != null:
					await arena.tether(cnode, tnode, color, 0.3 * spd)
					arena.card_arc(tnode.position + Vector3(0, 60, 0), cnode.position + Vector3(0, 72, 0))
					await get_tree().create_timer(0.42 * spd).timeout
					arena.piece_recoil(tnode, cnode.position - tnode.position, 0.9)
					hits.append(target)
				arena.fx_sound("it_steal")
			else:
				await get_tree().create_timer(0.3 * spd).timeout
			_cast_hud(team, item_id, target_text, effect_text)
		"bomb":
			var blocked_b := bool(params.get("blocked", false))
			if cnode != null:
				await arena.anim_windup(cnode, color, 0.18 * spd)
			if tnode != null:
				var to_b := tnode.position
				await arena.bomb_throw(cnode.position if cnode != null else to_b + Vector3(0, 0, -80), to_b, color)
				_cast_hud(team, item_id, target_text, effect_text)
				if blocked_b:
					arena.remove_shield(tnode)
					arena.piece_recoil(tnode, (cnode.position - tnode.position) if cnode != null else Vector3.BACK, 1.2)
					arena.freeze_burst(tnode.position, color)
					changed += 1
				else:
					arena.capture_blast(tnode.position, color)
					var base_b := _pt_pos("HM%d_%d" % [int(target["team"]) + 1, int(target["idx"]) + 1])
					if cnode != null:
						var smoke := create_tween()
						for k in 4:
							smoke.tween_interval(0.11 * spd)
							var sp := tnode.position.lerp(base_b, float(k + 1) / 4.0) + Vector3(0, 46, 0)
							smoke.tween_callback(arena._spawn_trail_dot.bind(sp, Color("3a3436"), "smoke"))
					await arena.piece_launch(tnode, base_b, 150.0)
					arena.impact_kind("hit", base_b, Color("ff8a5c"))
					hits.append(target)
					changed += 1
					arena.fx_sound("it_bomb")
			else:
				_cast_hud(team, item_id, target_text, effect_text)
		"inferno":
			var steps_i := int(params.get("steps", 4))
			var from_i := int(caster.get("cell", 0))
			if cnode != null:
				var land_i := _item_pos(caster, from_i + steps_i)
				cnode.rotation.y = atan2(land_i.x - cnode.position.x, land_i.z - cnode.position.z)
				await arena.anim_windup(cnode, color, 0.16 * spd)
				arena.impact_kind("fire", cnode.position, color)
				for i in steps_i:
					var pt5 := _item_pos(caster, from_i + i + 1)
					arena._fx_shards(pt5, color, 4, 30.0, 60.0, 4.0, 0.3)
					var ti := create_tween()
					ti.tween_property(cnode, "position", pt5, 0.14 * spd).set_trans(Tween.TRANS_QUAD)
					await ti.finished
					arena._spawn_swap_ghost(cnode, pt5, color)
				arena.impact_kind("fire", land_i, color)
				arena.event_ring(land_i, color)
				arena.decal_scorch(Vector3(land_i.x, BOARD_Y, land_i.z))
				arena.fx_sound("it_inferno")
			_cast_hud(team, item_id, target_text, effect_text)
			var commit := params.get("commit", Callable()) as Callable
			if commit.is_valid():
				await commit.call()
			var fetch := params.get("fetch_victims", Callable()) as Callable
			var victims_i: Array = fetch.call() if fetch.is_valid() else []
			for v2 in victims_i:
				await get_tree().create_timer(0.08 * spd).timeout
				var qi2: Dictionary = v2["p"]
				var vn2: Node3D = qi2["node"]
				if vn2 == null or not is_instance_valid(vn2):
					continue
				arena.impact_kind("fire", vn2.position, color)
				await arena.piece_recoil(vn2, vn2.position - (cnode.position if cnode != null else vn2.position), 1.3)
				var back_i2 := int(v2["back"])
				if back_i2 > 0:
					var dst := _item_pos(qi2, int(qi2["cell"]) - back_i2)
					arena.event_ring(dst, Color("ff9a5c"))
					var tv := create_tween()
					tv.tween_property(vn2, "position", dst, 0.14 * spd)
					await tv.finished
				hits.append(qi2)
				changed += 1
		"moonstep":
			var steps_m := int(params.get("steps", 2))
			if cnode != null:
				var from_m := int(caster["cell"])
				var dst_m := _item_pos(caster, from_m + steps_m)
				await arena.anim_windup(cnode, color, 0.16 * spd)
				arena._fx_moon(cnode.position, color)
				await arena.piece_launch(cnode, dst_m, 120.0)
				arena._fx_moon(dst_m, color)
				arena.event_ring(dst_m, color)
				arena.fx_sound("it_moonstep")
			else:
				await get_tree().create_timer(0.3 * spd).timeout
			_cast_hud(team, item_id, target_text, effect_text)
		"jadeguard":
			if cnode != null:
				await arena.anim_windup(cnode, color, 0.16 * spd)
				arena.event_ring(cnode.position, color)
				arena.impact_kind("hit", cnode.position, color)
				arena.fx_sound("it_jadeguard")
			_cast_hud(team, item_id, target_text, effect_text)
			var allies: Array = params.get("victims", [])
			for a in allies:
				var qa: Dictionary = a["p"] if a.has("p") else a
				var an: Node3D = qa["node"]
				if an == null or not is_instance_valid(an):
					continue
				arena.aura_bind(an, color)
				hits.append(qa)
				changed += 1
				await get_tree().create_timer(0.12 * spd).timeout
		"voidstep":
			var blocked_v := bool(params.get("blocked", false))
			if cnode != null:
				await arena.anim_windup(cnode, color, 0.16 * spd)
				if tnode != null:
					await arena.tether(cnode, tnode, color, 0.32 * spd)
			if tnode != null:
				await arena.void_crack(tnode.position, color)
				_cast_hud(team, item_id, target_text, effect_text)
				if blocked_v:
					arena.remove_shield(tnode)
					arena.impact_kind("ice", tnode.position, color)
					await arena.piece_recoil(tnode, (cnode.position - tnode.position) if cnode != null else Vector3.BACK, 1.2)
					changed += 1
				else:
					await arena.piece_dissolve(tnode, color)
					var base_v := _pt_pos("HM%d_%d" % [int(target["team"]) + 1, int(target["idx"]) + 1])
					arena.impact_kind("gravity", Vector3(base_v.x, BOARD_Y, base_v.z), color)
					arena._fx_rift(Vector3(base_v.x, BOARD_Y, base_v.z), color)
					tnode.position = base_v + Vector3(0, 230, 0)
					tnode.visible = true
					await arena.piece_reassemble(tnode, color)
					var fall := create_tween()
					fall.tween_property(tnode, "position", base_v, 0.3 * spd).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
					await fall.finished
					arena._fx_shards(Vector3(base_v.x, BOARD_Y + 2, base_v.z), Color("c9b89a"), 8, 40.0, 30.0, 4.0, 0.4)
					hits.append(target)
					changed += 1
					arena.fx_sound("it_voidstep")
			else:
				_cast_hud(team, item_id, target_text, effect_text)
	return {"hits": hits, "changed": changed}


func _use_instant_card(slot: int, id: String) -> void:
	var leader := _lead_piece(current_team)
	var c: Color = ITEM_COLORS.get(id, Color.WHITE)
	var caster: Dictionary = pieces[leader] if leader >= 0 else {}
	match id:
		"boost":
			if boost_pending == current_team:
				_log("本回合已经使用过加速")
				_play(nope_player)
				return
			cards[current_team].remove_at(slot)
			await _play_item_fx(caster, "boost", {}, {"team": current_team,
				"target_text": "→ 自己", "effect": "本回合点数 +2"})
			boost_pending = current_team
			hud.set_dice(last_dice, last_dice + 2 if last_dice > 0 else 0)
			_log("%s 使用「加速」，本回合点数 +2" % TEAM_NAMES[current_team])
		"double":
			if double_team == current_team:
				_play(nope_player)
				return
			cards[current_team].remove_at(slot)
			await _play_item_fx(caster, "double", {}, {"team": current_team,
				"target_text": "→ 自己", "effect": "本回合点数 ×2"})
			double_team = current_team
			_log("%s 使用「双倍」，本回合点数 ×2" % TEAM_NAMES[current_team])
		"freeze":
			var target := _most_dangerous_opponent(current_team)
			if target < 0:
				_play(nope_player)
				_log("没有可以冰冻的对手")
				return
			cards[current_team].remove_at(slot)
			var victim := _lead_piece(target)
			var vpiece: Dictionary = pieces[victim] if victim >= 0 else {}
			arena.set_active_team(current_team)
			await _play_item_fx(caster, "freeze", vpiece, {"team": current_team,
				"target_text": "→ %s" % TEAM_NAMES[target], "effect": "冻结 1 回合"})
			frozen[target] = maxi(frozen[target], 1)
			_log("%s 使用「冰冻」，%s 下一回合被冻结" % [TEAM_NAMES[current_team], TEAM_NAMES[target]])
			hud.show_event("冰 冻", "%s 被冻结一轮" % TEAM_NAMES[target], Color("7fe6ff"))
		"vortex":
			cards[current_team].remove_at(slot)
			var victims: Array = []
			for q in pieces:
				if q["team"] == current_team or q["finished"] or q["cell"] <= 0:
					continue
				victims.append({"p": q})
			await _play_item_fx(caster, "vortex", {}, {"team": current_team, "victims": victims,
				"target_text": "→ 全体对手", "effect": "全体后退 1 格"})
			var pushed := 0
			for v in victims:
				var qv: Dictionary = v["p"]
				qv["cell"] = int(qv["cell"]) - 1
				_snap_piece(qv)
				pushed += 1
			hud.screen_flash(Color("9a7bff"), 0.3)
			_shake(0.3, 16.0)
			_log("%s 使用「漩涡」，卷退 %d 枚对手棋子" % [TEAM_NAMES[current_team], pushed])
		"steal":
			var victim_t := -1
			var most := 0
			for t in 4:
				if t == current_team:
					continue
				if cards[t].size() > most:
					most = cards[t].size()
					victim_t = t
			if victim_t < 0 or most <= 0:
				_play(nope_player)
				hud.show_item_toast("窃取失败", "对手手中没有道具卡", Color("ffb84a"))
				return
			if cards[current_team].size() >= 4:
				_play(nope_player)
				hud.show_item_toast("窃取失败", "你的卡槽已满", Color("ffb84a"))
				return
			cards[current_team].remove_at(slot)
			var pick: int = randi() % cards[victim_t].size()
			var got: String = cards[victim_t][pick]
			var vp2 := _lead_piece(victim_t)
			var vdict: Dictionary = pieces[vp2] if vp2 >= 0 else {}
			await _play_item_fx(caster, "steal", vdict, {"team": current_team,
				"target_text": "→ %s" % TEAM_NAMES[victim_t],
				"effect": "抢到「%s」" % ITEM_NAMES.get(got, got)})
			cards[victim_t].remove_at(pick)
			cards[current_team].append(got)
			hud.screen_flash(Color("ffb84a"), 0.26)
			_log("%s 使用「窃取」，从 %s 手中抢到「%s」" % [TEAM_NAMES[current_team],
				TEAM_NAMES[victim_t], ITEM_NAMES.get(got, got)])
		"jadeguard":
			cards[current_team].remove_at(slot)
			var allies: Array = []
			for q in pieces:
				if q["team"] != current_team or q["finished"] or q["cell"] < 0:
					continue
				if q["shield"]:
					continue
				allies.append({"p": q})
			await _play_item_fx(caster, "jadeguard", {}, {"team": current_team, "victims": allies,
				"target_text": "→ 己方全体", "effect": "披上翠玉护盾"})
			var shielded := 0
			for a in allies:
				var qa: Dictionary = a["p"]
				if not qa["shield"]:
					qa["shield"] = true
					arena.add_shield(qa["node"])
					_tint_shield(qa["node"], Color("8ff0c0"))
					shielded += 1
			hud.screen_flash(Color("8ff0c0"), 0.3)
			_log("%s 使用「玉灵护体」，%d 枚棋子获得护盾" % [TEAM_NAMES[current_team], shielded])
		"voidstep":
			var cands: Array = []
			for i in pieces.size():
				var q2: Dictionary = pieces[i]
				if q2["team"] != current_team and not q2["finished"] and int(q2["cell"]) >= 0:
					cands.append(i)
			if cands.is_empty():
				_play(nope_player)
				hud.show_item_toast("虚空牵引失败", "没有可放逐的对手棋子", Color("c8b8ff"))
				return
			cards[current_team].remove_at(slot)
			var victim2: Dictionary = pieces[cands[randi() % cands.size()]]
			var vname := "%s%d号" % [TEAM_NAMES[int(victim2["team"])], int(victim2["idx"]) + 1]
			var blocked_v := bool(victim2["shield"])
			await _play_item_fx(caster, "voidstep", victim2, {"team": current_team, "blocked": blocked_v,
				"target_text": "→ %s" % vname,
				"effect": "护盾抵消" if blocked_v else "被放逐回基地"})
			var desc_line := ""
			if blocked_v:
				victim2["shield"] = false
				arena.remove_shield(victim2["node"])
				desc_line = "%s 的护盾被虚空吞噬，但保住了位置" % vname
			else:
				victim2["cell"] = -1
				victim2["lane"] = -1
				victim2["lslot"] = 0
				_snap_piece(victim2)
				desc_line = "%s 被虚空裂隙吞没，回到基地" % vname
			hud.screen_flash(Color("c8b8ff"), 0.34)
			_shake(0.35, 20.0)
			_log("%s 使用「虚空牵引」：%s" % [TEAM_NAMES[current_team], desc_line])
	if leader >= 0:
		arena.piece_celebrate(pieces[leader]["node"])
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
			if int(p.get("lane", -1)) >= 0:
				label = "%s%d号 · 已到达终点区" % [TEAM_NAMES[p["team"]], p["idx"] + 1]
			else:
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
				"gale":
					step = 2
			if step > 0 and int(p["cell"]) + step == FIELDS - 1:
				label += " · 直达终点"
		else:
			label = "%s%d号 · 第 %d 格" % [TEAM_NAMES[p["team"]], p["idx"] + 1, p["cell"] + 1]
		options.append({"index": i, "label": label, "color": TEAM_COLORS[p["team"]]})
		arena.mark_piece(p["node"])
	_pick_options = options
	_net_pick_hint = hint
	if _is_local_actor(current_team):
		hud.show_pick(options, hint)


## 换位试算：只读字典，不碰节点。返回双方最终占位与结算方式
## mode: full = 真换；pull = 对方被拽出、我方不动；shift = 我方位移、对方不动；none = 谁也动不了
func _swap_plan(a: Dictionary, b: Dictionary) -> Dictionary:
	var a_team := int(a["team"])
	var b_team := int(b["team"])
	var a_slot := {
		"cell": int(a["cell"]), "lane": int(a.get("lane", -1)), "lslot": int(a.get("lslot", 0)),
	}
	var b_slot := {
		"cell": int(b["cell"]), "lane": int(b.get("lane", -1)), "lslot": int(b.get("lslot", 0)),
	}
	# 通道格为队伍私有：lane >= 0 的格只允许通道所属队伍的棋子占据
	var mine_can: bool = int(b_slot["lane"]) < 0 or int(b_slot["lane"]) == a_team
	var enemy_can: bool = int(a_slot["lane"]) < 0 or int(a_slot["lane"]) == b_team
	var a_out: Dictionary = a_slot.duplicate()
	var b_out: Dictionary = b_slot.duplicate()
	var mode := "none"
	if mine_can and enemy_can:
		mode = "full"
		a_out = b_slot.duplicate()
		b_out = a_slot.duplicate()
	elif enemy_can:
		mode = "pull"
		b_out = a_slot.duplicate()
	elif mine_can:
		mode = "shift"
		a_out = b_slot.duplicate()
	return {"a": a_out, "b": b_out, "mode": mode}


## 按占位算落点：借道 _piece_cell_pos，但不改动棋子字典
func _swap_slot_pos(p: Dictionary, slot: Dictionary) -> Vector3:
	return _piece_cell_pos({
		"team": int(p["team"]), "idx": int(p["idx"]),
		"cell": int(slot["cell"]), "lane": int(slot["lane"]), "lslot": int(slot["lslot"]),
	})


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
			# 跳过同队与基地棋子；通道内的敌方棋子允许选中
			if q["team"] == current_team or (int(q["cell"]) < 0 and int(q.get("lane", -1)) < 0):
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

	if id == "snipe" or id == "bomb" or id == "frostlock":
		if p["team"] == current_team or p["finished"] or p["cell"] < 0:
			return
	elif id != "swap":
		if p["team"] != current_team or p["finished"] or p["cell"] < 0:
			return

	var slot := card_slot
	var swap_self := card_self  # card_self 随后会被清空，换位结算仍要用到自己那枚棋子
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
			await _play_item_fx(p, "shield", {}, {"team": int(p["team"]),
				"target_text": "→ 自己", "effect": "免疫一次吃子"})
			p["shield"] = true
			arena.add_shield(p["node"])
			hud.screen_flash(Color("6cc6ff"), 0.2)
			_log("%s 的 %d 号棋子获得护盾" % [TEAM_NAMES[p["team"]], p["idx"] + 1])
			_play(click_player)
			_update_all()
			return
		"warp", "teleport":
			var steps := 3 if id == "warp" else 5
			var start_cell := int(p["cell"])
			await _play_item_fx(p, id, {}, {"team": int(p["team"]), "steps": steps,
				"target_text": "→ 自己", "effect": "前进 %d 格" % steps})
			p["cell"] = mini(start_cell + steps, FIELDS - 1)
			_snap_piece(p)
			var captured: bool = await _resolve_capture(p, start_cell)
			if int(p["cell"]) == FIELDS - 1:
				await _finish_piece(p)
			arena.piece_celebrate(p["node"])
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
			var caster_p: Dictionary = {}
			for i in pieces.size():
				var q0: Dictionary = pieces[i]
				if q0["team"] == current_team and not q0["finished"] and q0["cell"] >= 0:
					caster_p = q0
					break
			await _play_item_fx(caster_p, "snipe", p, {"team": current_team, "back": back,
				"target_text": "→ %s%d号" % [TEAM_NAMES[p["team"]], p["idx"] + 1],
				"effect": "击退 %d 格" % back})
			p["cell"] = int(p["cell"]) - back
			_snap_piece(p)
			_shake(0.24, 12.0)
			_log("%s 狙击 %s 的 %d 号棋子，击退 %d 格" % [TEAM_NAMES[current_team],
				TEAM_NAMES[p["team"]], p["idx"] + 1, back])
			_play(click_player)
			_update_all()
			_resume_after_card()
			return
		"swap":
			var mine: Dictionary = pieces[swap_self]
			# 先算后演：占位三元组 (cell, lane, lslot) 由 _swap_plan 一次定格
			var plan := _swap_plan(mine, p)
			var mode := String(plan["mode"])
			var note := ""
			if mode == "full":
				# 双方都能落到合法占位：同时起飞、镜像弧线交叉互换
				await arena.piece_swap_arc(mine["node"], p["node"], Color("ffd166"),
					_swap_slot_pos(mine, plan["a"]), _swap_slot_pos(p, plan["b"]))
				note = "与 %s 的棋子交换了位置" % TEAM_NAMES[p["team"]]
			elif mode == "pull":
				# 对方站在自己的通道里：只能把对方拽出到我这格，我原地不动
				await _hop_to(p, _swap_slot_pos(p, plan["b"]))
				note = "把 %s 的棋子从终点通道拽了出来" % TEAM_NAMES[p["team"]]
			elif mode == "shift":
				# 我方位移过去、对方原地不动
				await _hop_to(mine, _swap_slot_pos(mine, plan["a"]))
				note = "位移到 %s 的棋子旁" % TEAM_NAMES[p["team"]]
			else:
				note = "双方都占着对方通道，换位失败"
			# 动画落地后才写数据
			mine["cell"] = int(plan["a"]["cell"])
			mine["lane"] = int(plan["a"]["lane"])
			mine["lslot"] = int(plan["a"]["lslot"])
			p["cell"] = int(plan["b"]["cell"])
			p["lane"] = int(plan["b"]["lane"])
			p["lslot"] = int(plan["b"]["lslot"])
			mine["finished"] = int(mine.get("lane", -1)) == int(mine["team"])
			p["finished"] = int(p.get("lane", -1)) == int(p["team"])
			arena.item_cast(mine["node"], Color("ffd166"), "swap")
			arena.item_cast(p["node"], Color("ffd166"), "swap")
			arena.event_ring(mine["node"].position, Color("ffd166"))
			arena.event_ring(p["node"].position, Color("ffd166"))
			hud.show_item_toast("使用「换位」", note, Color("ffd166"))
			hud.screen_flash(Color("ffd166"), 0.24)
			_shake(0.2, 10.0)
			_log("%s 使用了换位：%s" % [TEAM_NAMES[current_team], note])
			_play(click_player)
			_update_all()
			_check_win(current_team)
			if not game_over:
				_resume_after_card()
			return
		"moonstep":
			var steps_m := mini(2, FIELDS - 1 - int(p["cell"]))
			var start_m := int(p["cell"])
			await _play_item_fx(p, "moonstep", {}, {"team": int(p["team"]), "steps": steps_m,
				"target_text": "→ 自己", "effect": "跃 2 格并获得护盾"})
			p["cell"] = start_m + steps_m
			_snap_piece(p)
			var cap_m: bool = await _resolve_capture(p, start_m)
			if int(p["cell"]) == FIELDS - 1:
				await _finish_piece(p)
			if not p["finished"] and not p["shield"]:
				p["shield"] = true
				arena.add_shield(p["node"])
				_tint_shield(p["node"], Color("cfd8ff"))
			arena.piece_celebrate(p["node"])
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
			var caster_f: Dictionary = {}
			for i in pieces.size():
				var qf: Dictionary = pieces[i]
				if qf["team"] == current_team and not qf["finished"] and qf["cell"] >= 0:
					caster_f = qf
					break
			await _play_item_fx(caster_f, "frostlock", p, {"team": current_team, "back": back_f,
				"target_text": "→ %s%d号" % [TEAM_NAMES[p["team"]], p["idx"] + 1],
				"effect": "击退 2 格并冻结"})
			p["cell"] = int(p["cell"]) - back_f
			_snap_piece(p)
			frozen[p["team"]] = maxi(frozen[p["team"]], 1)
			hud.screen_flash(Color("a8e6ff"), 0.24)
			_shake(0.2, 9.0)
			_log("%s 用极寒锁链击退 %s 的棋子，并冻结其队伍" % [TEAM_NAMES[current_team], TEAM_NAMES[p["team"]]])
			_play(click_player)
			_update_all()
			_resume_after_card()
			return
		"inferno":
			var steps_i := mini(4, FIELDS - 1 - int(p["cell"]))
			var start_i := int(p["cell"])
			var cap_holder := [false]
			var commit := func() -> void:
				p["cell"] = start_i + steps_i
				_snap_piece(p)
				cap_holder[0] = await _resolve_capture(p, start_i)
				if int(p["cell"]) == FIELDS - 1:
					await _finish_piece(p)
			var fetch := func() -> Array:
				var ti := _ring_idx(p)
				var arr: Array = []
				if ti < 0:
					return arr
				for q in pieces:
					if q["team"] == current_team or q["finished"] or q["cell"] < 0:
						continue
					var qi := _ring_idx(q)
					if qi < 0:
						continue
					var gap := absi(qi - ti)
					gap = mini(gap, FIELDS - gap)
					if gap > 2:
						continue
					var back_i := mini(2, int(q["cell"]))
					if back_i <= 0:
						continue
					arr.append({"p": q, "back": back_i})
				return arr
			var fx: Dictionary = await _play_item_fx(p, "inferno", {}, {"team": int(p["team"]),
				"steps": steps_i, "commit": commit, "fetch_victims": fetch,
				"target_text": "→ 自己", "effect": "冲锋 %d 格并炸退周围" % steps_i})
			var hit := 0
			for v in fx.get("hits", []):
				var qv: Dictionary = v["p"]
				qv["cell"] = int(qv["cell"]) - int(v["back"])
				_snap_piece(qv)
				hit += 1
			hud.screen_flash(Color("ff7a3c"), 0.34)
			_shake(0.34, 22.0)
			_log("%s 的 %d 号棋子熔火冲锋 %d 格，炸退 %d 枚对手棋子" % [
				TEAM_NAMES[p["team"]], p["idx"] + 1, steps_i, hit])
			_check_win(p["team"])
			_update_all()
			if not game_over:
				_finish_turn(cap_holder[0])
			return
		"gale":
			var steps_g := mini(2, FIELDS - 1 - int(p["cell"]))
			var start_g := int(p["cell"])
			await _play_item_fx(p, "gale", {}, {"team": int(p["team"]), "steps": steps_g,
				"target_text": "→ 自己", "effect": "滑行 2 格并获得额外掷骰"})
			p["cell"] = start_g + steps_g
			_snap_piece(p)
			var cap_g: bool = await _resolve_capture(p, start_g)
			if int(p["cell"]) == FIELDS - 1:
				await _finish_piece(p)
			arena.piece_celebrate(p["node"])
			hud.screen_flash(Color("8ff0c0"), 0.22)
			_log("%s 的 %d 号棋子乘风前进 %d 格，将再掷一次" % [
				TEAM_NAMES[p["team"]], p["idx"] + 1, steps_g])
			_check_win(p["team"])
			_update_all()
			if not game_over:
				_finish_turn(true)
			return
		"bomb":
			var blocked := bool(p["shield"])
			var caster_b: Dictionary = {}
			for i in pieces.size():
				var qb: Dictionary = pieces[i]
				if qb["team"] == current_team and not qb["finished"] and qb["cell"] >= 0:
					caster_b = qb
					break
			await _play_item_fx(caster_b, "bomb", p, {"team": current_team, "blocked": blocked,
				"target_text": "→ %s%d号" % [TEAM_NAMES[p["team"]], p["idx"] + 1],
				"effect": "护盾挡下" if blocked else "炸回基地"})
			if blocked:
				p["shield"] = false
				arena.remove_shield(p["node"])
				_log("%s 的 %d 号棋子用护盾挡下了炸弹" % [TEAM_NAMES[p["team"]], p["idx"] + 1])
			else:
				p["cell"] = -1
				p["lane"] = -1
				p["lslot"] = 0
				_snap_piece(p)
				hud.screen_flash(Color("ff6a3c"), 0.4)
				_shake(0.45, 26.0)
				_log("%s 用炸弹把 %s 的 %d 号棋子炸回基地" % [TEAM_NAMES[current_team],
					TEAM_NAMES[p["team"]], p["idx"] + 1])
			_update_all()
			_resume_after_card()
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

func _trigger_event(p: Dictionary, forced := "", dramatic := false) -> void:
	var pool: Array = _roulette_event_pool()
	var id := forced
	if id == "":
		id = pool[randi() % pool.size()]
	var team: int = p["team"]
	var title: String = EVENT_TITLES[id]
	var color: Color = EVENT_COLORS[id]
	var desc := ""
	# 轮盘触发时若己方没有棋子在场，自动改判为全局事件
	if p["cell"] < 0 and (id in ["tailwind", "trap", "portal", "bless", "starlight"]):
		var globals := ["meteor", "chaos", "goldrain", "earthquake", "ambush"]
		id = globals[randi() % globals.size()]
		title = EVENT_TITLES[id]
		color = EVENT_COLORS[id]
	var pos: Vector3 = p["node"].position
	var pi := _ring_idx(p)
	arena.event_fx(id, pos, color)
	arena.item_aura(p["node"], color)
	if dramatic:
		arena.sky_sigil(Vector3(pos.x, BOARD_Y, pos.z), color)
		hud.screen_flash(color, 0.42)
		_shake(0.52, 26.0)
	else:
		hud.screen_flash(color, 0.16)
	# 重事件补一点镜头震动；音效由 event_fx 按事件类型各自播放
	if not dramatic and id in ["meteor", "eruption", "earthquake", "voidrift", "ambush"]:
		_shake(0.3, 14.0)
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
		"ambush":
			var victims: Array = []
			for i in pieces.size():
				var q: Dictionary = pieces[i]
				if q["team"] == team or q["finished"] or q["cell"] <= 0:
					continue
				if pi >= 0:
					var qi := _ring_idx(q)
					if qi >= 0:
						var gap := absi(qi - pi)
						gap = mini(gap, FIELDS - gap)
						if gap > 4:
							continue
				victims.append(i)
			victims.shuffle()
			var hitc := 0
			for k in mini(3, victims.size()):
				var q3: Dictionary = pieces[victims[k]]
				var back3 := mini(3, int(q3["cell"]))
				if back3 <= 0:
					continue
				q3["cell"] = int(q3["cell"]) - back3
				arena.piece_hit(q3["node"])
				arena.capture_blast(Vector3(q3["node"].position.x, BOARD_Y, q3["node"].position.z), color)
				await _hop_to(q3, _piece_cell_pos(q3))
				hitc += 1
			_shake(0.36, 24.0)
			desc = "伏兵四起！%d 枚对手棋子被突袭后退 3 格" % hitc
		"goldrain":
			var got := 0
			for t in 4:
				if _draw_card(t, true):
					got += 1
			arena.item_pickup(Vector3(pos.x, BOARD_Y, pos.z), color)
			desc = "金色暴雨倾泻而下，全场共获得 %d 张道具卡" % got
		"earthquake":
			var moved_q := 0
			for q in pieces:
				if q["finished"] or q["cell"] <= 0:
					continue
				q["cell"] = int(q["cell"]) - 1
				arena.piece_hit(q["node"])
				await _hop_to(q, _piece_cell_pos(q))
				moved_q += 1
			_shake(0.55, 28.0)
			desc = "地动山摇，全场 %d 枚棋子被震退 1 格" % moved_q
		"curse":
			frozen[team] = maxi(frozen[team], 1)
			var lead := _lead_piece(team)
			var dragged := 0
			if lead >= 0:
				var q4: Dictionary = pieces[lead]
				var back4 := mini(2, int(q4["cell"]))
				if back4 > 0:
					q4["cell"] = int(q4["cell"]) - back4
					if q4["shield"]:
						q4["shield"] = false
						arena.remove_shield(q4["node"])
					arena.piece_hit(q4["node"])
					await _hop_to(q4, _piece_cell_pos(q4))
					dragged = back4
			_shake(0.3, 16.0)
			desc = "诅咒降临，%s 下一回合被冻结，领先棋子被拖后 %d 格" % [TEAM_NAMES[team], dragged]
		"jadeserpent":
			var bites := 0
			for q in pieces:
				if q["team"] == team or q["finished"] or q["cell"] <= 0:
					continue
				var back5 := mini(2, int(q["cell"]))
				q["cell"] = int(q["cell"]) - back5
				if q["shield"]:
					q["shield"] = false
					arena.remove_shield(q["node"])
				arena.piece_hit(q["node"])
				arena.freeze_burst(Vector3(q["node"].position.x, BOARD_Y, q["node"].position.z), color)
				await _hop_to(q, _piece_cell_pos(q))
				bites += 1
			p["shield"] = true
			arena.add_shield(p["node"])
			_shake(0.3, 15.0)
			desc = "翠蛇破土缠住 %d 枚对手棋子，全体后退 2 格；落点获得护盾" % bites
		"voidrift":
			var swallowed := 0
			for q in pieces:
				if q["finished"] or q["cell"] < 0:
					continue
				var d2 := randi_range(-3, 4)
				if q["team"] == team:
					d2 = absi(d2)
				var before5: int = q["cell"]
				q["cell"] = clampi(int(q["cell"]) + d2, 0, FIELDS - 2)
				if q["cell"] == before5:
					continue
				arena.item_cast(q["node"], color, "teleport")
				await _hop_to(q, _piece_cell_pos(q))
				arena.capture_blast(Vector3(q["node"].position.x, BOARD_Y, q["node"].position.z), color)
				swallowed += 1
			_shake(0.5, 26.0)
			desc = "虚空裂隙撕开棋盘，%d 枚棋子被空间乱流抛动" % swallowed

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


# ---------------------------------------------------------------- 俄罗斯轮盘
## 轮盘只在踩中「道具格 / 事件格」时自动开启：8 个扇区全是随机道具或随机事件，
## 转到什么拿什么，不能跳过。

func _roulette_event_pool() -> Array:
	var pool: Array = EVENT_POOL.duplicate()
	var ex: String = THEME_EVENT.get(theme_id, "")
	if ex != "":
		pool.append(ex)
		pool.append(ex)
	return pool


func _roulette_item_pool() -> Array:
	var pool: Array = ITEM_POOL.duplicate()
	var ex: String = THEME_ITEM.get(theme_id, "")
	if ex != "":
		pool.append(ex)
		pool.append(ex)
	return pool


func _build_roulette_segments(kind := "item") -> Array:
	var segs: Array = []
	var pool: Array = _roulette_item_pool() if kind == "item" else _roulette_event_pool()
	var uniq: Array = []
	for v in pool:
		if not uniq.has(v):
			uniq.append(v)
	uniq.shuffle()
	for id in uniq:
		if segs.size() >= 8:
			break
		if kind == "item":
			segs.append({
				"kind": "item", "id": id,
				"label": String(ITEM_NAMES.get(id, id)),
				"color": ITEM_COLORS.get(id, Color.WHITE),
			})
		else:
			segs.append({
				"kind": "event", "id": id,
				"label": String(EVENT_TITLES.get(id, id)).replace(" ", ""),
				"color": EVENT_COLORS.get(id, Color.WHITE),
			})
	while segs.size() < 8 and not segs.is_empty():
		segs.append(segs[randi() % segs.size()])
	segs.shuffle()
	return segs


## 踩格触发：开轮盘 → 等待旋转结果 → 发道具 / 触发全屏事件
func _run_roulette(kind: String, p: Dictionary) -> void:
	if game_over:
		return
	roulette_open = true
	_roulette_segments = _build_roulette_segments(kind)
	hud.show_roulette(_roulette_segments, kind)
	_play(click_player)
	if _is_ai(p["team"]) or auto_mode:
		await get_tree().create_timer(0.6).timeout
		hud.spin_roulette()
	var idx: int = await hud.roulette_done
	roulette_open = false
	if idx < 0 or idx >= _roulette_segments.size():
		_roulette_segments = []
		hud.hide_roulette()
		return
	var seg: Dictionary = _roulette_segments[idx]
	_roulette_segments = []
	var id := String(seg.get("id", ""))
	_log("【轮盘】%s 转出「%s」" % [TEAM_NAMES[p["team"]], String(seg.get("label", "?"))])
	if kind == "item":
		_grant_item(p, id)
		await get_tree().create_timer(0.8).timeout
		hud.hide_roulette()
	else:
		await get_tree().create_timer(0.55).timeout
		hud.hide_roulette()
		await _trigger_event(p, id, true)
	await get_tree().create_timer(0.2).timeout


## 轮盘抽中的道具直接进卡槽（满 4 张时替换最旧的一张）
func _grant_item(p: Dictionary, id: String) -> void:
	if not ITEM_NAMES.has(id):
		return
	var team: int = p["team"]
	var replaced := false
	if cards[team].size() >= 4:
		cards[team].remove_at(0)
		replaced = true
	cards[team].append(id)
	var col: Color = ITEM_COLORS.get(id, Color.WHITE)
	var pos: Vector3 = p["node"].position
	arena.item_pickup(Vector3(pos.x, BOARD_Y, pos.z), col)
	arena.item_cast(p["node"], col, "item")
	arena.piece_celebrate(p["node"])
	hud.screen_flash(col, 0.26)
	_play(sfx_drop)
	var extra := "（卡槽已满，替换最旧的一张）" if replaced else ""
	hud.show_item_toast("轮盘奖励 ·「%s」" % String(ITEM_NAMES[id]),
		String(ITEM_DESC.get(id, "")) + extra, col)
	_log("%s 获得道具「%s」%s" % [TEAM_NAMES[team], String(ITEM_NAMES[id]), extra])
	_update_all()


func _pick_event_piece(team: int) -> Dictionary:
	var lead := _lead_piece(team)
	if lead >= 0:
		return pieces[lead]
	for p in pieces:
		if p["team"] == team:
			return p
	return pieces[0]


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
	if auto_mode or game_over or busy or not match_started or _restoring or net_role == "guest":
		return
	if not _is_ai(current_team):
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
			var ai_caster: Dictionary = pieces[_lead_piece(t)] if _lead_piece(t) >= 0 else {}
			var ai_victim: Dictionary = pieces[_lead_piece(target)] if _lead_piece(target) >= 0 else {}
			await _play_item_fx(ai_caster, "freeze", ai_victim, {"team": t,
				"target_text": "→ %s" % TEAM_NAMES[target], "effect": "冻结 1 回合"})
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
		var dc: Dictionary = pieces[_lead_piece(t)] if _lead_piece(t) >= 0 else {}
		await _play_item_fx(dc, "double", {}, {"team": t,
			"target_text": "→ 自己", "effect": "本回合点数 ×2"})
		double_team = t
		_log("%s 使用「双倍」" % TEAM_NAMES[t])
		_update_all()
		await get_tree().create_timer(0.25).timeout
	var bi: int = cards[t].find("boost")
	if bi >= 0 and (near_goal or ai_level >= 2):
		cards[t].remove_at(bi)
		var bc2: Dictionary = pieces[_lead_piece(t)] if _lead_piece(t) >= 0 else {}
		await _play_item_fx(bc2, "boost", {}, {"team": t,
			"target_text": "→ 自己", "effect": "本回合点数 +2"})
		boost_pending = t
		_log("%s 使用「加速」" % TEAM_NAMES[t])
		_update_all()
		await get_tree().create_timer(0.25).timeout

	# 传送 / 跃迁 / 冲锋 / 月影 / 疾风：能直达终点或吃子
	for spec in [["teleport", 5], ["inferno", 4], ["warp", 3], ["moonstep", 2], ["gale", 2]]:
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
			var fc: Dictionary = pieces[_lead_piece(t)] if _lead_piece(t) >= 0 else {}
			await _play_item_fx(fc, "frostlock", vp, {"team": t, "back": back_f,
				"target_text": "→ %s%d号" % [TEAM_NAMES[vp["team"]], int(vp["idx"]) + 1],
				"effect": "击退 2 格并冻结"})
			vp["cell"] = int(vp["cell"]) - back_f
			_snap_piece(vp)
			frozen[vp["team"]] = maxi(frozen[vp["team"]], 1)
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

	# 炸弹：把对手最靠前的棋子炸回基地
	var boi: int = cards[t].find("bomb")
	if boi >= 0:
		var bi2 := -1
		var bc := 22
		for i in pieces.size():
			var q: Dictionary = pieces[i]
			if q["team"] == t or q["finished"] or q["cell"] < bc:
				continue
			bc = q["cell"]
			bi2 = i
		if bi2 >= 0:
			cards[t].remove_at(boi)
			var bp: Dictionary = pieces[bi2]
			_log("%s 使用「炸弹」" % TEAM_NAMES[t])
			var bcaster: Dictionary = pieces[_lead_piece(t)] if _lead_piece(t) >= 0 else {}
			var bblocked := bool(bp["shield"])
			await _play_item_fx(bcaster, "bomb", bp, {"team": t, "blocked": bblocked,
				"target_text": "→ %s%d号" % [TEAM_NAMES[bp["team"]], int(bp["idx"]) + 1],
				"effect": "护盾挡下" if bblocked else "炸回基地"})
			if bblocked:
				bp["shield"] = false
				arena.remove_shield(bp["node"])
			else:
				bp["cell"] = -1
				bp["lane"] = -1
				bp["lslot"] = 0
				_snap_piece(bp)
			hud.screen_flash(Color("ff6a3c"), 0.32)
			_shake(0.4, 22.0)
			_update_all()
			await get_tree().create_timer(0.4).timeout

	# 漩涡：多名对手领先时全体后退 1 格
	var voi: int = cards[t].find("vortex")
	if voi >= 0:
		var ahead := 0
		for q in pieces:
			if q["team"] != t and not q["finished"] and q["cell"] > 8:
				ahead += 1
		if ahead >= 2:
			cards[t].remove_at(voi)
			_log("%s 使用「漩涡」" % TEAM_NAMES[t])
			var vvics: Array = []
			for q in pieces:
				if q["team"] == t or q["finished"] or q["cell"] <= 0:
					continue
				vvics.append({"p": q})
			var vc: Dictionary = pieces[_lead_piece(t)] if _lead_piece(t) >= 0 else {}
			await _play_item_fx(vc, "vortex", {}, {"team": t, "victims": vvics,
				"target_text": "→ 全体对手", "effect": "全体后退 1 格"})
			for v in vvics:
				var qv: Dictionary = v["p"]
				qv["cell"] = int(qv["cell"]) - 1
				_snap_piece(qv)
			hud.screen_flash(Color("9a7bff"), 0.28)
			_shake(0.26, 14.0)
			_update_all()
			await get_tree().create_timer(0.3).timeout

	# 窃取：对手卡多时抢一张
	var sti: int = cards[t].find("steal")
	if sti >= 0 and cards[t].size() < 4:
		var vt := -1
		var vmost := 0
		for ot in 4:
			if ot == t:
				continue
			if cards[ot].size() > vmost:
				vmost = cards[ot].size()
				vt = ot
		if vt >= 0 and vmost >= 2:
			cards[t].remove_at(sti)
			var pk: int = randi() % cards[vt].size()
			var stole: String = cards[vt][pk]
			var sc: Dictionary = pieces[_lead_piece(t)] if _lead_piece(t) >= 0 else {}
			var svp: Dictionary = pieces[_lead_piece(vt)] if _lead_piece(vt) >= 0 else {}
			await _play_item_fx(sc, "steal", svp, {"team": t,
				"target_text": "→ %s" % TEAM_NAMES[vt],
				"effect": "抢到「%s」" % ITEM_NAMES.get(stole, stole)})
			cards[vt].remove_at(pk)
			cards[t].append(stole)
			_log("%s 使用「窃取」，抢到「%s」" % [TEAM_NAMES[t], ITEM_NAMES.get(stole, stole)])
			hud.show_event("窃 取", "%s 从 %s 手中抢走一张道具卡" % [TEAM_NAMES[t], TEAM_NAMES[vt]], Color("ffb84a"))
			_update_all()
			await get_tree().create_timer(0.3).timeout

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
			await _play_item_fx(pc, "shield", {}, {"team": t,
				"target_text": "→ 自己", "effect": "免疫一次吃子"})
			pc["shield"] = true
			arena.add_shield(pc["node"])
			arena.fx_sound("it_shield")
			_log("%s 使用「护盾」" % TEAM_NAMES[t])
			_play(click_player)
			_update_all()
			await get_tree().create_timer(0.3).timeout


func _apply_ai_displace(idx: int, steps: int) -> void:
	var p: Dictionary = pieces[idx]
	var kind: String = card_mode
	var start := int(p["cell"])
	var captured := false
	if kind == "inferno":
		var cap_holder := [false]
		var team_i := int(p["team"])
		var commit := func() -> void:
			p["cell"] = start + steps
			_snap_piece(p)
			cap_holder[0] = await _resolve_capture(p, start)
			if int(p["cell"]) == FIELDS - 1:
				await _finish_piece(p)
		var fetch := func() -> Array:
			var ti := _ring_idx(p)
			var arr: Array = []
			if ti < 0:
				return arr
			for q in pieces:
				if q["team"] == team_i or q["finished"] or q["cell"] < 0:
					continue
				var qi := _ring_idx(q)
				if qi < 0:
					continue
				var gap := absi(qi - ti)
				gap = mini(gap, FIELDS - gap)
				if gap > 2:
					continue
				var back_i := mini(2, int(q["cell"]))
				if back_i <= 0:
					continue
				arr.append({"p": q, "back": back_i})
			return arr
		var fx: Dictionary = await _play_item_fx(p, "inferno", {}, {"team": team_i, "steps": steps,
			"commit": commit, "fetch_victims": fetch,
			"target_text": "→ 自己", "effect": "冲锋 %d 格" % steps})
		for v in fx.get("hits", []):
			var qv: Dictionary = v["p"]
			qv["cell"] = int(qv["cell"]) - int(v["back"])
			_snap_piece(qv)
		captured = cap_holder[0]
		_shake(0.3, 18.0)
	else:
		await _play_item_fx(p, kind, {}, {"team": int(p["team"]), "steps": steps,
			"target_text": "→ 自己", "effect": "前进 %d 格" % steps})
		p["cell"] = start + steps
		_snap_piece(p)
		captured = await _resolve_capture(p, start)
		if int(p["cell"]) == FIELDS - 1:
			await _finish_piece(p)
		if kind == "moonstep" and not p["finished"] and not p["shield"]:
			p["shield"] = true
			arena.add_shield(p["node"])
	arena.piece_celebrate(p["node"])
	hud.screen_flash(ITEM_COLORS.get(kind, Color.WHITE), 0.22)
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
	var caster: Dictionary = {}
	for q in pieces:
		if q["team"] == current_team and not q["finished"] and q["cell"] >= 0:
			caster = q
			break
	await _play_item_fx(caster, "snipe", p, {"team": current_team, "back": back,
		"target_text": "→ %s%d号" % [TEAM_NAMES[p["team"]], int(p["idx"]) + 1],
		"effect": "击退 %d 格" % back})
	p["cell"] = int(p["cell"]) - back
	_snap_piece(p)
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
	if net_role == "host":
		_net_dirty = true
	if net_role != "" and _lan_testplay > 0:
		var sig := _state_signature()
		if sig != _lan_last_sig:
			_lan_last_sig = sig
			print("LAN_STATE ", net_role, " ", sig)
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
	var human := _is_local_actor(current_team)
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
		elif net_role == "host" and current_team == net_guest_team:
			txt = "等待对手行动…"
		elif net_role == "guest" and current_team != net_guest_team:
			txt = "%s 行动中…" % TEAM_NAMES[current_team]
		elif not human:
			txt = "%s AI 思考中…" % TEAM_NAMES[current_team]
		else:
			txt = "行动中…"
		hud.set_roll_enabled(false, txt)
	hud.set_cards(cards[current_team], human and not busy and not game_over and match_started)
	if arena:
		arena.set_active_team(current_team)


func _log(text: String) -> void:
	if auto_mode or _lan_testplay > 0:
		print("[log] ", text)
	if hud:
		hud.log(text)
	if net_role == "host" and lan != null:
		lan.send_log(text)


## 当前设备能不能替这支队伍操作（热座/单机全放行，局域网只看自己的座位）
func _is_local_actor(team: int) -> bool:
	if net_role == "guest":
		return team == net_guest_team
	if net_role == "host":
		return team == 0
	return not _is_ai(team)


# ---------------------------------------------------------------- 选棋 / 相机

func _try_world_pick(screen_pos: Vector2) -> void:
	if not (awaiting_pick or card_mode != "") or _pick_pool.is_empty():
		return
	var origin := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.0001:
		return
	# 棋子模型世界尺寸恒定，拾取平面取棋子腰高
	var hit_y := BOARD_Y + 78.0
	var t := (hit_y - origin.y) / dir.y
	if t <= 0.0:
		return
	var hit := origin + dir * t
	var best := -1
	var best_d := 88.0
	for i in _pick_pool:
		var p: Dictionary = pieces[i]
		var node: Node3D = p["node"]
		var wp := node.global_position
		var d := Vector2(wp.x - hit.x, wp.z - hit.z).length()
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
	var mid := (a + b) * 0.5
	if _pinch_dist <= 1.0:
		_pinch_dist = d
		_pinch_mid = mid
		return
	# 双指捏合缩放
	cam_dist = clampf(cam_dist * (_pinch_dist / maxf(d, 1.0)), 900.0, 4600.0)
	# 双指拖动：平移相机锚点（棋盘整体移动）
	var delta := mid - _pinch_mid
	if delta.length() > 0.5:
		var k := cam_dist * 0.0016
		var fwd := Vector3(-sin(cam_yaw), 0.0, -cos(cam_yaw))
		var right := Vector3(cos(cam_yaw), 0.0, -sin(cam_yaw))
		cam_target += (fwd * delta.y - right * delta.x) * k
		cam_target.x = clampf(cam_target.x, -1600.0, 1600.0)
		cam_target.z = clampf(cam_target.z, -1600.0, 1600.0)
	_update_camera()
	_pinch_dist = d
	_pinch_mid = mid


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
				_pinch_mid = Vector2.ZERO
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
	# 展示随机掉落与随机事件格
	drops = {}
	event_cells = {}
	arena.clear_random_marks()
	_spawn_random_drop()
	_spawn_random_event_cell()
	_spawn_random_event_cell()
	var eid: String = String(THEME_EVENT.get(theme_id, "starlight"))
	for ri in [2, 26]:
		if event_cells.has(ri) or ri >= FIELDS:
			continue
		var node := arena.spawn_event_cell(_pt_pos(paths[0][ri]), EVENT_COLORS[eid], String(EVENT_SYMBOLS[eid]))
		event_cells[ri] = {"node": node, "id": eid}
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
	if hud:
		var opts: Array = []
		for i in 2:
			var pp: Dictionary = pieces[i]
			var cell_i: int = pp["cell"]
			opts.append({
				"index": i,
				"label": "%d号 · %d → %d" % [i + 1, cell_i + 1, cell_i + 5],
				"color": TEAM_COLORS[0],
			})
		hud.show_pick(opts, "掷出 4 点，点棋子或按钮选择")
	_update_all()


## 连拍：每隔 interval 秒存一帧，用于核对动画过程
func _fx_frame_burst(path: String, count: int, interval: float) -> void:
	var stem := path
	if stem.ends_with(".png"):
		stem = stem.substr(0, stem.length() - 4)
	for k in count:
		await get_tree().create_timer(interval).timeout
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s_%d.png" % [stem, k])
	print("fx frames saved: ", stem)
	get_tree().quit()


func _take_screenshot() -> void:
	for _i in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(shot_path)
	print("screenshot saved: ", shot_path)
	get_tree().quit()
