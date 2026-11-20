class_name LanPeer
extends Node

## 局域网联机通道 v2：一位房主 + 最多三位客机，共 4 个座位。
## 协议与清弈/麻将房同一套思路：
##   · 房主唯一权威，客机只发意图、只收快照
##   · TCP 帧 = 4 字节大端长度 + UTF-8 JSON，一条连接一个乘客
##   · 房号 4 位纯数字，发现用 UDP 广播，失败可填 IP 直连
##   · 大厅：座位/准备/AI 补位/踢人/开始全部由房主广播 lobby 快照
##   · 断线保留座位 60 秒，同一令牌可回座；超时后空位交给 AI
##   · 空位默认 AI 补位，保证四人局永远能开

signal rooms_changed(rooms: Array)
signal status(text: String, color: Color)
## 大厅快照：{room, host, seats:[{seat,name,ready,ai,human,connected,host}], started, you, role, can_start}
signal lobby_changed(lobby: Dictionary)
signal guest_joined(info: Dictionary)
signal guest_left(info: Dictionary)
signal connected_to_host(info: Dictionary)
signal match_started(payload: Dictionary)
signal state_received(payload: Dictionary)
signal intent_received(payload: Dictionary)
## 房主 → 客机的过程演出（骰子/走格/轮盘/播报），只影响表现，不承载权威状态
signal fx_received(kind: String, data: Dictionary)
signal log_received(text: String)
signal link_lost(final: bool)

const GAME := "knightchess"
const PROTO := 2
const MAX_GUESTS := 3
const DISCOVERY_PORT := 41235
const BASE_PORT := 41234
const MAX_FRAME := 65536
const ROOM_TTL := 12.0
const GRACE_SECONDS := 60.0

var role := ""              # "" / "host" / "guest"
var room_code := ""
var iid := ""
var tcp_port := 0
var host_name := ""
var seat := -1
var guest_name := ""
var discovery_port := DISCOVERY_PORT
var meta: Dictionary = {}   # 房主开房配置（主题/棋盘/角色/规则），随应答下发给客机
var seats: Array = []       # 房主：4 座权威状态；客机：最近一次 lobby 快照
var started := false

# ---- 房主
var _server: TCPServer = null
var _links: Array = []          # [{peer, buf, token, seat, name, ready, born, dead, no_reserve}]
var _reservations: Dictionary = {}  # token -> {seat, name, until}

# ---- 客机
var _peer: StreamPeerTCP = null
var _peer_buf := PackedByteArray()
var _peer_ready := false
var _guest_token := ""
var _my_name := "骑士"
var _want_room := ""
var _manual_ip := ""
var _direct_idx := 0
var _guest_state := ""      # connecting / handshaking / connected
var _connect_start := 0
var _last_connect_try := 0
var _reconnect_until := 0
var _auto_reconnect := false
var _last_ping := 0

# ---- 发现
var _udp_recv: PacketPeerUDP = null
var _udp_send: PacketPeerUDP = null
var _udp_ok := false
var _last_query := 0
var _last_announce := 0
var _last_prune := 0
var _rooms: Dictionary = {}
var _rooms_key := ""
var _bcast_cache: Array = []
var _hinted_no_room := false


func _ready() -> void:
	set_process(false)


func local_ipv4() -> String:
	# 优先展示真实局域网地址：虚拟网卡（VMware/Hyper-V/VPN）常排在前面
	var best := ""
	var best_score := -1
	for a in IP.get_local_addresses():
		if a.contains(":") or a.begins_with("127.") or a.begins_with("169.254."):
			continue
		var score := 1
		if a.begins_with("192.168."):
			score = 4
		elif a.begins_with("10."):
			score = 3
		elif a.begins_with("172."):
			score = 2
		if score > best_score:
			best_score = score
			best = a
	return best if best != "" else "127.0.0.1"


## 发现广播目标：每块网卡的子网定向广播 + 有限广播。
## 只发 255.255.255.255 时，Windows 多网卡环境常从虚拟网卡出去，手机收不到。
func discovery_targets() -> Array:
	if not _bcast_cache.is_empty():
		return _bcast_cache
	var out: Array = []
	for a in IP.get_local_addresses():
		if a.contains(":") or a.begins_with("127.") or a.begins_with("169.254."):
			continue
		var parts: PackedStringArray = String(a).split(".")
		if parts.size() != 4:
			continue
		for cand in ["%s.%s.%s.255" % [parts[0], parts[1], parts[2]],
				"%s.%s.255.255" % [parts[0], parts[1]]]:
			if not out.has(cand):
				out.append(cand)
	if not out.has("255.255.255.255"):
		out.append("255.255.255.255")
	_bcast_cache = out
	return _bcast_cache


func _discovery_send_socket() -> PacketPeerUDP:
	if _udp_send != null:
		return _udp_send
	return _udp_recv


func _send_discovery(sock: PacketPeerUDP, body: PackedByteArray, port: int) -> void:
	for t in discovery_targets():
		sock.set_dest_address(String(t), port)
		sock.put_packet(body)


func is_guest_connected() -> bool:
	if role == "host":
		return _ready_guest_count() > 0
	return _peer != null and _peer_ready


func _rand_hex(n: int) -> String:
	var s := ""
	for i in n:
		s += "%x" % randi_range(0, 15)
	return s


func _team_colors_fallback() -> void:
	pass


# ---------------------------------------------------------------- 房主

func start_host(config: Dictionary, display_name := "") -> bool:
	stop()
	role = "host"
	meta = config.duplicate(true)
	host_name = display_name if display_name.strip_edges() != "" else "骑士飞行棋房主"
	iid = _rand_hex(12)
	room_code = "%04d" % randi_range(1000, 9999)
	started = false
	seat = 0
	_init_seats()
	_server = TCPServer.new()
	var ok := false
	for i in 12:
		var p := BASE_PORT + i
		if _server.listen(p, "0.0.0.0") == OK:
			tcp_port = p
			ok = true
			break
	if not ok:
		_server = null
		role = ""
		status.emit("创建房间失败：端口区间被占用", Color("ff6b6b"))
		set_process(false)
		return false

	_udp_recv = PacketPeerUDP.new()
	_udp_ok = _udp_recv.bind(discovery_port, "0.0.0.0") == OK
	if _udp_ok:
		_udp_recv.set_broadcast_enabled(true)
	else:
		status.emit("发现端口被占用，房间通告可能收不到（可用填 IP 加入）", Color("ffb86b"))
	_udp_send = PacketPeerUDP.new()
	if _udp_send.bind(0, "0.0.0.0") == OK:
		_udp_send.set_broadcast_enabled(true)
	else:
		_udp_send = null
	if OS.is_debug_build():
		print("LAN_DISCOVERY host targets=", discovery_targets(), " port=", discovery_port)

	_last_announce = 0
	set_process(true)
	status.emit("房间已创建 · 房号 %s · 端口 %d" % [room_code, tcp_port], Color("8fe6ff"))
	lobby_changed.emit(lobby_snapshot())
	return true


func _init_seats() -> void:
	seats = []
	for s in 4:
		seats.append({
			"seat": s,
			"name": host_name if s == 0 else "AI 补位",
			"ready": true,
			"ai": s != 0,
			"human": s == 0,
			"connected": s == 0,
			"host": s == 0,
		})


func _seats_public() -> Array:
	var out: Array = []
	for st in seats:
		out.append({
			"seat": int(st["seat"]), "name": String(st["name"]),
			"ready": bool(st["ready"]), "ai": bool(st["ai"]),
			"human": bool(st["human"]), "connected": bool(st["connected"]),
			"host": bool(st["host"]),
		})
	return out


func lobby_snapshot() -> Dictionary:
	return {
		"room": room_code, "host": host_name, "seats": _seats_public(),
		"started": started, "role": role,
		"you": seat if role == "guest" else 0,
		"can_start": can_start(),
	}


## 房主：所有已连接的客机都点了准备才允许开局（AI 座位视为已准备）
func can_start() -> bool:
	if role != "host":
		return false
	for l in _links:
		if int(l["seat"]) >= 0 and not bool(l["ready"]):
			return false
	return true


func _ready_guest_count() -> int:
	var n := 0
	for l in _links:
		if int(l["seat"]) >= 0:
			n += 1
	return n


func _human_count() -> int:
	return 1 + _ready_guest_count()


func human_seats() -> Array:
	var out: Array = [0]
	for l in _links:
		if int(l["seat"]) >= 1:
			out.append(int(l["seat"]))
	out.sort()
	return out


func is_human_seat(s: int) -> bool:
	if s == 0:
		return role == "host"
	for l in _links:
		if int(l["seat"]) == s:
			return true
	return false


func _seat_link(s: int) -> Dictionary:
	for l in _links:
		if int(l["seat"]) == s:
			return l
	return {}


func _free_seat() -> int:
	for s in range(1, 4):
		if _seat_link(s).is_empty():
			return s
	return -1


func _init_seats_if_needed() -> void:
	if seats.size() != 4:
		_init_seats()


# ---------------------------------------------------------------- 客机

func join(ip: String, room: String, display_name := "") -> bool:
	stop()
	role = "guest"
	seat = -1
	_my_name = display_name.strip_edges() if display_name.strip_edges() != "" else "骑士"
	_want_room = room.strip_edges()
	_manual_ip = ip.strip_edges()
	_direct_idx = 0
	_guest_state = "connecting"
	_auto_reconnect = true
	_connect_start = Time.get_ticks_msec()
	_reconnect_until = _connect_start + int(GRACE_SECONDS * 1000.0)
	_last_connect_try = 0
	_seat_token_init()
	_open_discovery()
	_hinted_no_room = false
	set_process(true)
	if OS.is_debug_build():
		print("LAN_DISCOVERY join targets=", discovery_targets(), " port=", discovery_port)
	if _manual_ip != "":
		status.emit("正在连接 %s …" % _manual_ip, Color(1, 1, 1, 0.65))
	else:
		status.emit("正在搜索房号 %s …" % _want_room, Color(1, 1, 1, 0.65))
	return true


func _seat_token_init() -> void:
	if _guest_token == "":
		_guest_token = _rand_hex(16)


func _open_discovery() -> void:
	_udp_recv = PacketPeerUDP.new()
	_udp_ok = _udp_recv.bind(discovery_port, "0.0.0.0") == OK
	if _udp_ok:
		_udp_recv.set_broadcast_enabled(true)
	else:
		# 端口被占用时退到临时端口：仍能收到房主的单播应答
		_udp_ok = _udp_recv.bind(0, "0.0.0.0") == OK
		if _udp_ok:
			_udp_recv.set_broadcast_enabled(true)
	_udp_send = PacketPeerUDP.new()
	if _udp_send.bind(0, "0.0.0.0") == OK:
		_udp_send.set_broadcast_enabled(true)
	else:
		_udp_send = null
	_last_query = 0


func leave() -> void:
	stop()


func stop() -> void:
	_send_msg({"v": PROTO, "t": "bye"})
	for l in _links:
		_send_to(l, {"v": PROTO, "t": "bye"})
		var gp: StreamPeerTCP = l.get("peer", null)
		if gp != null:
			gp.disconnect_from_host()
	_links.clear()
	_reservations.clear()
	_close_peer(false)
	if _server != null:
		_server.stop()
		_server = null
	if _udp_recv != null:
		_udp_recv.close()
	if _udp_send != null:
		_udp_send.close()
	_udp_recv = null
	_udp_send = null
	_udp_ok = false
	role = ""
	room_code = ""
	iid = ""
	tcp_port = 0
	seat = -1
	started = false
	seats = []
	_peer_buf.clear()
	_peer_ready = false
	_guest_state = ""
	_auto_reconnect = false
	_want_room = ""
	_manual_ip = ""
	_rooms.clear()
	_rooms_key = ""
	_hinted_no_room = false
	set_process(false)


# ---------------------------------------------------------------- 主循环

func _process(_delta: float) -> void:
	if role == "host":
		_process_host()
	elif role == "guest":
		_process_guest()


func _process_host() -> void:
	var now := Time.get_ticks_msec()
	while _server != null and _server.is_connection_available():
		var incoming := _server.take_connection()
		if incoming == null:
			continue
		if _links.size() >= MAX_GUESTS:
			incoming.disconnect_from_host()
			status.emit("房间已满（4 人），拒绝新的连接", Color("ffb86b"))
			continue
		_add_link(incoming, now)

	var i := _links.size() - 1
	while i >= 0:
		var l: Dictionary = _links[i]
		if not _poll_link(l) or bool(l.get("dead", false)):
			_drop_link(i)
		i -= 1

	if _udp_recv != null:
		# 通告需要发送 socket；接收查询只看接收 socket，避免发送端失败就完全不应答
		if _discovery_send_socket() != null and now - _last_announce >= 2000:
			_last_announce = now
			_announce("room_announce")
		while _udp_recv.get_available_packet_count() > 0:
			var raw := _udp_recv.get_packet()
			var src := _udp_recv.get_packet_ip()
			var src_port := _udp_recv.get_packet_port()
			var parsed: Variant = JSON.parse_string(raw.get_string_from_utf8())
			if not (parsed is Dictionary):
				continue
			var t := _norm_kind(String(parsed.get("t", "")))
			if t == "room_query":
				_announce("room_reply", src, src_port)

	# 回座保留超时：空位正式交给 AI
	var expired: Array = []
	for token in _reservations.keys():
		var r: Dictionary = _reservations[token]
		if now > int(r.get("until", 0)):
			expired.append(token)
	for token in expired:
		var s := int(_reservations[token].get("seat", -1))
		_reservations.erase(token)
		if s >= 1 and s < seats.size():
			seats[s]["human"] = false
			seats[s]["connected"] = false
			seats[s]["ai"] = true
			seats[s]["name"] = "AI 补位"
			seats[s]["ready"] = true
			status.emit("%d 号座位回座超时，已交给 AI" % (s + 1), Color("ffb86b"))
			_flush_lobby()


func _process_guest() -> void:
	var now := Time.get_ticks_msec()
	if _peer != null:
		_poll_peer()
	if _guest_state != "connected":
		if _udp_recv != null:
			while _udp_recv.get_available_packet_count() > 0:
				var raw := _udp_recv.get_packet()
				var src := _udp_recv.get_packet_ip()
				var parsed: Variant = JSON.parse_string(raw.get_string_from_utf8())
				if parsed is Dictionary:
					_absorb_room(parsed, src)
			if now - _last_query >= 1500:
				_last_query = now
				_send_query()
		if not _hinted_no_room and _rooms.is_empty() and _manual_ip == "" \
				and now - _connect_start > 8000:
			_hinted_no_room = true
			status.emit("仍未搜到房间：请确认①同一 Wi-Fi ②iOS 已允许「本地网络」③电脑防火墙允许专用网络；也可填房主 IP + 房号直连",
				Color("ffb86b"))
		_try_auto_connect(now)
	elif _peer != null and now - _last_ping >= 4000:
		_last_ping = now
		_send_msg({"v": PROTO, "t": "ping"})
	_prune_rooms(now)


# ---------------------------------------------------------------- 连接管理（房主）

func _add_link(peer: StreamPeerTCP, now: int) -> void:
	peer.poll()
	_links.append({
		"peer": peer, "buf": PackedByteArray(), "token": "", "seat": -1,
		"name": "", "ready": false, "born": now, "dead": false, "no_reserve": false,
	})
	# 先回握手包下发房号与开房配置，客机收到后立刻回 hello 带名字与令牌
	_send_to(_links[_links.size() - 1], {
		"v": PROTO, "t": "hello_ack", "room": room_code, "iid": iid,
		"host": host_name, "meta": meta, "seats": _seats_public(),
	})


func _poll_link(l: Dictionary) -> bool:
	var peer: StreamPeerTCP = l.get("peer", null)
	if peer == null:
		return false
	peer.poll()
	var st := peer.get_status()
	if st == StreamPeerTCP.STATUS_ERROR or st == StreamPeerTCP.STATUS_NONE:
		return false
	if st == StreamPeerTCP.STATUS_CONNECTING:
		return true
	if st != StreamPeerTCP.STATUS_CONNECTED:
		return true
	var n := peer.get_available_bytes()
	if n > 0:
		var res: Array = peer.get_data(n)
		if int(res[0]) != OK:
			return false
		var buf: PackedByteArray = l.get("buf", PackedByteArray())
		buf.append_array(res[1])
		l["buf"] = buf
		if not _parse_link(l):
			return false
	return true


func _parse_link(l: Dictionary) -> bool:
	var buf: PackedByteArray = l.get("buf", PackedByteArray())
	while buf.size() >= 4:
		var length := buf.decode_u32(0)
		if length <= 0 or length > MAX_FRAME:
			return false
		if buf.size() < 4 + length:
			break
		var body := buf.slice(4, 4 + length)
		buf = buf.slice(4 + length)
		var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
		if parsed is Dictionary:
			_handle_host_msg(l, parsed)
		if bool(l.get("dead", false)):
			l["buf"] = buf
			return false
	l["buf"] = buf
	return true


func _handle_host_msg(l: Dictionary, msg: Dictionary) -> void:
	var t := String(msg.get("t", ""))
	match t:
		"hello":
			# 同一条连接重复 hello 只更新昵称，不再占新座位
			if int(l.get("seat", -1)) >= 1:
				var dup_name := String(msg.get("name", "")).strip_edges()
				if dup_name != "":
					l["name"] = dup_name
					seats[int(l["seat"])]["name"] = dup_name
					_flush_lobby()
				return
			var token := String(msg.get("token", ""))
			if token == "":
				token = _rand_hex(16)
			var nm := String(msg.get("name", "")).strip_edges()
			if nm == "":
				nm = "玩家"
			var target := -1
			var rejoin := false
			if _reservations.has(token):
				var r: Dictionary = _reservations[token]
				var rs := int(r.get("seat", -1))
				if rs >= 1 and rs < 4 and _seat_link(rs).is_empty() \
						and Time.get_ticks_msec() <= int(r.get("until", 0)):
					target = rs
					rejoin = true
				_reservations.erase(token)
			if target < 0:
				target = _free_seat()
			if target < 0:
				_send_to(l, {"v": PROTO, "t": "kick", "reason": "房间已满（4 人）"})
				l["dead"] = true
				return
			# 对局已开始时只接受原座位回座，新玩家等下一局
			if started and not rejoin:
				_send_to(l, {"v": PROTO, "t": "kick", "reason": "对局已经开始，请等下一局"})
				l["dead"] = true
				return
			l["token"] = token
			l["seat"] = target
			l["name"] = nm
			l["ready"] = false
			guest_name = nm
			var st: Dictionary = seats[target]
			st["name"] = nm
			st["human"] = true
			st["ai"] = false
			st["connected"] = true
			st["ready"] = false
			_send_to(l, {
				"v": PROTO, "t": "seat", "seat": target, "room": room_code,
				"host": host_name, "meta": meta, "seats": _seats_public(),
			})
			_flush_lobby()
			guest_joined.emit({"seat": target, "name": nm, "reconnect": rejoin})
			status.emit("%s %s（%d 号座位）" % [nm, "回座" if rejoin else "加入了房间", target + 1],
				Color("8fe6ff"))
		"lobby":
			var s := int(l.get("seat", -1))
			if s < 1:
				return
			var a := String(msg.get("a", ""))
			if a == "ready":
				var rdy := bool(msg.get("ready", true))
				l["ready"] = rdy
				seats[s]["ready"] = rdy
				_flush_lobby()
			elif a == "name":
				var nm2 := String(msg.get("name", "")).strip_edges()
				if nm2 == "":
					nm2 = "玩家"
				l["name"] = nm2
				seats[s]["name"] = nm2
				_flush_lobby()
		"intent":
			var p: Variant = msg.get("p", {})
			if p is Dictionary:
				var pp: Dictionary = (p as Dictionary).duplicate()
				pp["seat"] = int(l.get("seat", -1))
				intent_received.emit(pp)
		"ping":
			_send_to(l, {"v": PROTO, "t": "pong"})
		"bye":
			l["dead"] = true


func _drop_link(i: int) -> void:
	if i < 0 or i >= _links.size():
		return
	var l: Dictionary = _links[i]
	_links.remove_at(i)
	var peer: StreamPeerTCP = l.get("peer", null)
	if peer != null:
		peer.disconnect_from_host()
	var s := int(l.get("seat", -1))
	if s < 1:
		return
	var nm := String(seats[s]["name"])
	var token := String(l.get("token", ""))
	if not bool(l.get("no_reserve", false)) and token != "":
		_reservations[token] = {
			"seat": s, "name": nm,
			"until": Time.get_ticks_msec() + int(GRACE_SECONDS * 1000.0),
		}
		seats[s]["connected"] = false
		seats[s]["ai"] = true
		seats[s]["ready"] = true
		status.emit("%s 断开，AI 暂时接管 %d 号座位（60 秒内可回座）" % [nm, s + 1], Color("ffb86b"))
	else:
		seats[s]["connected"] = false
		seats[s]["human"] = false
		seats[s]["ai"] = true
		seats[s]["name"] = "AI 补位"
		seats[s]["ready"] = true
	guest_left.emit({"seat": s, "name": nm})
	_flush_lobby()


func _send_to(l: Dictionary, msg: Dictionary) -> void:
	var peer: StreamPeerTCP = l.get("peer", null)
	if peer == null:
		return
	if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return
	var body := JSON.stringify(msg).to_utf8_buffer()
	if body.size() > MAX_FRAME:
		return
	var frame := PackedByteArray()
	frame.resize(4)
	frame.encode_u32(0, body.size())
	frame.append_array(body)
	peer.put_data(frame)


func _broadcast(msg: Dictionary) -> void:
	for l in _links:
		if int(l.get("seat", -1)) >= 0 and not bool(l.get("dead", false)):
			_send_to(l, msg)


func _flush_lobby() -> void:
	if role != "host":
		return
	var lb := lobby_snapshot()
	var msg := lb.duplicate(true)
	msg["v"] = PROTO
	msg["t"] = "lobby"
	_broadcast(msg)
	lobby_changed.emit(lb)


# ---------------------------------------------------------------- 大厅操作

func set_ready(on: bool) -> void:
	if role == "guest":
		if seat >= 0 and seat < seats.size():
			seats[seat]["ready"] = on
		_send_msg({"v": PROTO, "t": "lobby", "a": "ready", "ready": on})
		lobby_changed.emit(lobby_snapshot())
	elif role == "host":
		pass


func update_name(new_name: String) -> void:
	var nm := new_name.strip_edges()
	if nm == "":
		nm = "骑士"
	_my_name = nm
	if role == "host":
		host_name = nm
		if seats.size() > 0:
			seats[0]["name"] = nm
		_flush_lobby()
	elif role == "guest":
		_send_msg({"v": PROTO, "t": "lobby", "a": "name", "name": nm})


## 房主：空位 AI 补位开关（off 时该队本局轮空）
func set_seat_ai(s: int, on: bool) -> void:
	if role != "host" or s < 1 or s >= 4:
		return
	if bool(seats[s]["connected"]):
		return
	seats[s]["ai"] = on
	seats[s]["name"] = "AI 补位" if on else "空闲"
	seats[s]["human"] = false
	seats[s]["ready"] = true
	_flush_lobby()


## 房主：把某位乘客请出房间，座位立刻交给 AI
func kick_seat(s: int) -> void:
	if role != "host" or s < 1 or s >= 4:
		return
	var l := _seat_link(s)
	if not l.is_empty():
		_send_to(l, {"v": PROTO, "t": "kick", "reason": "房主将你移出房间"})
		l["dead"] = true
		l["no_reserve"] = true


func start_match(state: Dictionary) -> void:
	if role != "host":
		return
	started = true
	_broadcast({"v": PROTO, "t": "start", "state": state})
	_flush_lobby()


## 房主：只给回座的那位乘客补发当前对局快照
func send_resume(s: int, state: Dictionary) -> void:
	if role != "host":
		return
	var l := _seat_link(s)
	if l.is_empty():
		return
	_send_to(l, {"v": PROTO, "t": "start", "state": state})


func send_state(state: Dictionary) -> void:
	if role != "host" or not is_guest_connected():
		return
	_broadcast({"v": PROTO, "t": "state", "state": state})


func send_intent(p: Dictionary) -> void:
	_send_msg({"v": PROTO, "t": "intent", "p": p})


func send_log(text: String) -> void:
	if role != "host":
		return
	_broadcast({"v": PROTO, "t": "log", "text": text})


## 房主：广播一次过程演出。协议只新增 t="fx"，旧客户端会忽略未知类型
func send_fx(kind: String, data: Dictionary) -> void:
	if role != "host" or not is_guest_connected():
		return
	_broadcast({"v": PROTO, "t": "fx", "k": kind, "d": data})


func refresh() -> void:
	if role == "guest" and _udp_send != null:
		_last_query = 0


# ---------------------------------------------------------------- 发现

func _send_query() -> void:
	# 查询统一从接收端 socket 发出：发现端口被占用退到临时端口时，
	# 房主会把应答回给查询源端口，只有这个 socket 收得到
	var sock := _udp_recv if _udp_recv != null else _udp_send
	if sock == null:
		return
	var q := {"v": PROTO, "t": "room_query", "game": GAME, "room": _want_room}
	var body := JSON.stringify(q).to_utf8_buffer()
	if _manual_ip != "":
		sock.set_dest_address(_manual_ip, discovery_port)
		sock.put_packet(body)
	_send_discovery(sock, body, discovery_port)


func _announce(kind: String, target := "", target_port := 0) -> void:
	var sock := _discovery_send_socket()
	if sock == null:
		return
	var pkt := {
		"v": PROTO, "t": kind, "game": GAME, "room": room_code, "port": tcp_port,
		"iid": iid, "host": host_name, "players": _human_count(),
		"cells": int(meta.get("cells", 40)),
	}
	var body := JSON.stringify(pkt).to_utf8_buffer()
	if target != "":
		sock.set_dest_address(target, target_port if target_port > 0 else discovery_port)
		sock.put_packet(body)
	else:
		_send_discovery(sock, body, discovery_port)


func _norm_kind(t: String) -> String:
	var k := t.strip_edges().to_lower().replace("_", "").replace("-", "").replace(" ", "")
	match k:
		"roomquery", "query":
			return "room_query"
		"roomreply", "reply":
			return "room_reply"
		"roomannounce", "announce":
			return "room_announce"
	return k


func _absorb_room(pkt: Dictionary, src: String) -> void:
	if String(pkt.get("game", "")) != GAME:
		return
	if int(pkt.get("v", PROTO)) != PROTO:
		return
	var kind := _norm_kind(String(pkt.get("t", "")))
	if kind != "room_reply" and kind != "room_announce":
		return
	var rid := String(pkt.get("room", ""))
	var rid_iid := String(pkt.get("iid", ""))
	var port := int(pkt.get("port", 0))
	if rid.length() != 4 or port <= 0:
		return
	if _manual_ip != "" and src != _manual_ip:
		return
	if _want_room != "" and rid != _want_room:
		return
	var prev: Dictionary = _rooms.get(rid, {})
	if not prev.is_empty() and String(prev.get("iid", "")) == rid_iid and String(prev.get("ip", "")) == src:
		prev["ts"] = Time.get_ticks_msec()
		prev["players"] = int(pkt.get("players", 1))
		_emit_rooms()
		return
	_rooms[rid] = {
		"room": rid, "ip": src, "port": port, "iid": rid_iid,
		"host": String(pkt.get("host", "")), "players": int(pkt.get("players", 1)),
		"cells": int(pkt.get("cells", 40)), "ts": Time.get_ticks_msec(),
	}
	if OS.is_debug_build():
		print("LAN_ROOM ", rid, " via=", kind, " src=", src, ":", port)
	_emit_rooms()


func _prune_rooms(now: int) -> void:
	if now - _last_prune < 1500:
		return
	_last_prune = now
	var stale: Array = []
	for rid in _rooms.keys():
		if now - int(_rooms[rid].get("ts", 0)) > int(ROOM_TTL * 1000.0):
			stale.append(rid)
	for rid in stale:
		_rooms.erase(rid)
	if not stale.is_empty():
		_emit_rooms()


func _emit_rooms() -> void:
	var list: Array = []
	for rid in _rooms.keys():
		var r: Dictionary = _rooms[rid]
		list.append({
			"room": rid, "ip": String(r["ip"]), "port": int(r["port"]),
			"host": String(r.get("host", "")), "players": int(r.get("players", 1)),
			"cells": int(r.get("cells", 40)),
		})
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a["room"]) < String(b["room"]))
	var key := JSON.stringify(list)
	if key == _rooms_key:
		return
	_rooms_key = key
	rooms_changed.emit(list)
	if _guest_state != "connected" and not list.is_empty() and _manual_ip == "":
		status.emit("发现 %d 个房间，点「加入」直接进入" % list.size(), Color("8fe6ff"))


func _try_auto_connect(now: int) -> void:
	if _peer != null and _peer.get_status() == StreamPeerTCP.STATUS_CONNECTING:
		if now - _connect_start > 8000:
			_close_peer(true)
		return
	if _peer != null and _peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		if not _peer_ready:
			if now - _connect_start > 6000:
				_close_peer(true)
		return
	if now - _last_connect_try < 1500:
		return
	_last_connect_try = now
	var target_ip := ""
	var target_port := 0
	if _want_room != "" and _rooms.has(_want_room):
		target_ip = String(_rooms[_want_room]["ip"])
		target_port = int(_rooms[_want_room]["port"])
	elif _want_room == "" and not _rooms.is_empty():
		var first: Dictionary = _rooms.values()[0]
		target_ip = String(first["ip"])
		target_port = int(first["port"])
		_want_room = String(first["room"])
	if target_ip == "" and _manual_ip != "":
		var direct_port := BASE_PORT + _direct_idx % 12
		_direct_idx += 1
		_try_connect(_manual_ip, direct_port)
		return
	if target_ip == "":
		return
	if _peer != null:
		return
	_try_connect(target_ip, target_port)


func _try_connect(ip: String, port: int) -> void:
	if _peer != null:
		return
	if _auto_reconnect and Time.get_ticks_msec() > _reconnect_until:
		_fail_reconnect()
		return
	_peer = StreamPeerTCP.new()
	var err := _peer.connect_to_host(ip, port)
	_peer_buf.clear()
	_peer_ready = false
	_connect_start = Time.get_ticks_msec()
	if err != OK:
		_peer = null
		return
	status.emit("正在连接房主 %s:%d …" % [ip, port], Color(1, 1, 1, 0.65))


func _fail_reconnect() -> void:
	_auto_reconnect = false
	_guest_state = ""
	status.emit("无法连接到房主，请确认同一 Wi-Fi 与房号", Color("ff6b6b"))
	link_lost.emit(true)


# ---------------------------------------------------------------- 帧收发（客机）

func _poll_peer() -> void:
	if _peer == null:
		return
	_peer.poll()
	var st := _peer.get_status()
	if st == StreamPeerTCP.STATUS_ERROR or st == StreamPeerTCP.STATUS_NONE:
		_close_peer(true)
		return
	if st != StreamPeerTCP.STATUS_CONNECTED:
		return
	if not _peer_ready and _guest_state != "handshaking":
		_guest_state = "handshaking"
		_send_msg({
			"v": PROTO, "t": "hello", "game": GAME, "room": _want_room,
			"token": _guest_token, "name": _my_name,
		})
	var n := _peer.get_available_bytes()
	if n > 0:
		var res: Array = _peer.get_data(n)
		if int(res[0]) == OK:
			_peer_buf.append_array(res[1])
			_parse_frames()
		else:
			_close_peer(true)


func _parse_frames() -> void:
	while _peer_buf.size() >= 4:
		var length := _peer_buf.decode_u32(0)
		if length <= 0 or length > MAX_FRAME:
			_close_peer(true)
			return
		if _peer_buf.size() < 4 + length:
			return
		var body := _peer_buf.slice(4, 4 + length)
		_peer_buf = _peer_buf.slice(4 + length)
		var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
		if parsed is Dictionary:
			_handle_guest_msg(parsed)


func _send_msg(msg: Dictionary) -> void:
	if _peer == null:
		return
	if _peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return
	var body := JSON.stringify(msg).to_utf8_buffer()
	if body.size() > MAX_FRAME:
		return
	var frame := PackedByteArray()
	frame.resize(4)
	frame.encode_u32(0, body.size())
	frame.append_array(body)
	_peer.put_data(frame)


func _handle_guest_msg(msg: Dictionary) -> void:
	var t := String(msg.get("t", ""))
	match t:
		"hello_ack":
			room_code = String(msg.get("room", room_code))
			iid = String(msg.get("iid", iid))
			host_name = String(msg.get("host", host_name))
			if msg.get("meta") is Dictionary:
				meta = msg["meta"]
			if not _peer_ready and _guest_state != "handshaking":
				_guest_state = "handshaking"
				_send_msg({
					"v": PROTO, "t": "hello", "game": GAME, "room": _want_room,
					"token": _guest_token, "name": _my_name,
				})
		"seat":
			seat = int(msg.get("seat", 0))
			if msg.get("seats") is Array:
				seats = msg["seats"]
			_peer_ready = true
			_guest_state = "connected"
			connected_to_host.emit(msg)
			status.emit("已加入房间 %s · 你坐在 %d 号座位" % [room_code, seat + 1], Color("8fe6ff"))
			lobby_changed.emit(lobby_snapshot())
		"lobby":
			if msg.get("seats") is Array:
				seats = msg["seats"]
			host_name = String(msg.get("host", host_name))
			if role == "guest" and not started:
				lobby_changed.emit(lobby_snapshot())
		"start":
			started = true
			if msg.get("state") is Dictionary:
				match_started.emit(msg["state"])
		"state":
			if msg.get("state") is Dictionary:
				state_received.emit(msg["state"])
		"fx":
			var k := String(msg.get("k", ""))
			var d: Variant = msg.get("d", {})
			if k != "" and d is Dictionary:
				fx_received.emit(k, d)
		"log":
			log_received.emit(String(msg.get("text", "")))
		"pong":
			pass
		"kick":
			status.emit(String(msg.get("reason", "被房主移出房间")), Color("ff6b6b"))
			_auto_reconnect = false
			_close_peer(false)
			link_lost.emit(true)
		"bye":
			_auto_reconnect = false
			_close_peer(false)
			status.emit("房主已解散房间", Color("ffb86b"))
			link_lost.emit(true)


func _close_peer(notify := true) -> void:
	var was_ready := _peer_ready
	if _peer != null:
		_peer.disconnect_from_host()
		_peer = null
	_peer_buf.clear()
	_peer_ready = false
	_guest_state = ""
	if notify and was_ready:
		if role == "host":
			pass
		elif role == "guest" and _auto_reconnect:
			_guest_state = "connecting"
			status.emit("连接断开，正在自动重连…", Color("ffb86b"))
			link_lost.emit(false)
