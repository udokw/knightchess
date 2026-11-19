class_name LanPeer
extends Node

## 局域网联机通道：mDNS 不可用时用 UDP 广播发现 + TCP 定长帧传输。
## 协议与清弈保持同一套思路：
##   · 房主唯一权威，客机只发意图、只收快照
##   · TCP 帧 = 4 字节大端长度 + UTF-8 JSON
##   · 房号 4 位纯数字，实际端口由房主应答回传
##   · 发现失败可用「填 IP 直连」兜底
##   · 房主为房间生成 iid，客机按 iid 去重并做 TTL 清理，避免僵尸房间
##   · 断线后客机按「房号 + 座位令牌」自动重连，房主保留对局快照等待回座

signal rooms_changed(rooms: Array)
signal status(text: String, color: Color)
signal guest_joined(info: Dictionary)
signal guest_left()
signal connected_to_host(info: Dictionary)
signal match_started(payload: Dictionary)
signal state_received(payload: Dictionary)
signal intent_received(payload: Dictionary)
signal log_received(text: String)
signal link_lost(final: bool)

const GAME := "knightchess"
const PROTO := 1
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
var seat := 1
var guest_name := ""
var discovery_port := DISCOVERY_PORT
var meta: Dictionary = {}   # 房主开房配置（主题/棋盘/角色），随应答下发给客机

var _server: TCPServer = null
var _peer: StreamPeerTCP = null
var _peer_buf := PackedByteArray()
var _peer_ready := false
var _guest_token := ""
var _had_guest := false
var _grace_until := 0

var _udp_recv: PacketPeerUDP = null
var _udp_send: PacketPeerUDP = null
var _udp_ok := false
var _last_query := 0
var _last_announce := 0
var _last_prune := 0
var _rooms: Dictionary = {}
var _rooms_key := ""

var _want_room := ""
var _manual_ip := ""
var _direct_idx := 0
var _guest_state := ""      # connecting / handshaking / connected
var _connect_start := 0
var _last_connect_try := 0
var _reconnect_until := 0
var _auto_reconnect := false
var _last_ping := 0


func _ready() -> void:
	set_process(false)


func local_ipv4() -> String:
	for a in IP.get_local_addresses():
		if a.contains(":") or a.begins_with("127."):
			continue
		if a.begins_with("169.254."):
			continue
		return a
	return "127.0.0.1"


func is_guest_connected() -> bool:
	return _peer != null and _peer_ready


func _rand_hex(n: int) -> String:
	var s := ""
	for i in n:
		s += "%x" % randi_range(0, 15)
	return s


# ---------------------------------------------------------------- 房主

func start_host(config: Dictionary, display_name := "") -> bool:
	stop()
	role = "host"
	meta = config.duplicate(true)
	host_name = display_name if display_name != "" else "骑士飞行棋房主"
	iid = _rand_hex(12)
	room_code = "%04d" % randi_range(1000, 9999)
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

	_last_announce = 0
	set_process(true)
	status.emit("房间已创建 · 房号 %s · 端口 %d" % [room_code, tcp_port], Color("8fe6ff"))
	return true


func stop_host() -> void:
	stop()


# ---------------------------------------------------------------- 客机

func join(ip: String, room: String) -> bool:
	stop()
	role = "guest"
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
	set_process(true)
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
	_close_peer()
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
	_peer_buf.clear()
	_peer_ready = false
	_guest_state = ""
	_auto_reconnect = false
	_want_room = ""
	_manual_ip = ""
	_rooms.clear()
	_rooms_key = ""
	_had_guest = false
	_grace_until = 0
	set_process(false)


# ---------------------------------------------------------------- 主循环

func _process(_delta: float) -> void:
	if role == "host":
		_process_host()
	elif role == "guest":
		_process_guest()


func _process_host() -> void:
	var now := Time.get_ticks_msec()
	if _server != null and _server.is_connection_available():
		var incoming := _server.take_connection()
		if incoming == null:
			pass
		elif _peer != null and _peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			# 已有客机：新连接直接断开，避免抢占唯一座位
			incoming.disconnect_from_host()
			status.emit("房间已有对手，拒绝新的连接", Color("ffb86b"))
		else:
			_close_peer(false)
			_peer = incoming
			_peer.poll()
			_peer_buf.clear()
			_peer_ready = false
			_last_ping = now
			_send_msg({
				"v": PROTO, "t": "hello_ack", "room": room_code, "iid": iid,
				"seat": seat, "meta": meta, "host": host_name,
			})
	_poll_peer()
	# 通告
	if _udp_ok and (_udp_send != null):
		if now - _last_announce >= 2000:
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
	if _had_guest and _peer == null and _grace_until > 0 and now > _grace_until:
		_grace_until = 0
		status.emit("对手超过 %d 秒未回座，房间仍在等待" % int(GRACE_SECONDS), Color("ffb86b"))


func _process_guest() -> void:
	var now := Time.get_ticks_msec()
	if _peer != null:
		_poll_peer()
	if _guest_state != "connected":
		# 发现包
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
		_try_auto_connect(now)
	elif _peer != null and now - _last_ping >= 4000:
		_last_ping = now
		_send_msg({"v": PROTO, "t": "ping"})
	_prune_rooms(now)


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
	sock.set_dest_address("255.255.255.255", discovery_port)
	sock.put_packet(body)


func _announce(kind: String, target := "", target_port := 0) -> void:
	if _udp_send == null:
		return
	var pkt := {
		"v": PROTO, "t": kind, "game": GAME, "room": room_code, "port": tcp_port,
		"iid": iid, "host": host_name, "players": 2 if is_guest_connected() else 1,
		"cells": int(meta.get("cells", 40)),
	}
	var body := JSON.stringify(pkt).to_utf8_buffer()
	if target != "":
		_udp_send.set_dest_address(target, target_port if target_port > 0 else discovery_port)
	else:
		_udp_send.set_dest_address("255.255.255.255", discovery_port)
	_udp_send.put_packet(body)


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
	if not prev.is_empty() and String(prev.get("iid", "")) == rid_iid and prev.get("_src", "") == src:
		prev["ts"] = Time.get_ticks_msec()
		prev["players"] = int(pkt.get("players", 1))
		_emit_rooms()
		return
	_rooms[rid] = {
		"room": rid, "ip": src, "port": port, "iid": rid_iid,
		"host": String(pkt.get("host", "")), "players": int(pkt.get("players", 1)),
		"cells": int(pkt.get("cells", 40)), "ts": Time.get_ticks_msec(),
	}
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
			# 已建立 TCP，等待 hello_ack
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
		# 发现通道不可用（跨网段 / 禁广播）时按房主常见端口直连兜底
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


# ---------------------------------------------------------------- 帧收发

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
	if not _peer_ready and role == "guest":
		# TCP 已通，发送 hello
		if _guest_state != "handshaking":
			_guest_state = "handshaking"
			_send_msg({
				"v": PROTO, "t": "hello", "game": GAME, "room": _want_room,
				"token": _guest_token, "name": "",
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
			_handle_message(parsed)


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


func _handle_message(msg: Dictionary) -> void:
	var t := String(msg.get("t", ""))
	if role == "host":
		match t:
			"hello":
				var token := String(msg.get("token", ""))
				if token == "":
					token = _rand_hex(16)
				if _guest_token != "" and token != _guest_token and is_guest_connected():
					_send_msg({"v": PROTO, "t": "kick", "reason": "座位已被占用"})
					return
				var rejoin: bool = _had_guest and token == _guest_token
				_guest_token = token
				guest_name = String(msg.get("name", ""))
				_peer_ready = true
				_had_guest = true
				_grace_until = 0
				_send_msg({
					"v": PROTO, "t": "hello_ack", "room": room_code, "iid": iid,
					"seat": seat, "meta": meta, "host": host_name,
				})
				guest_joined.emit({"name": guest_name, "token": token, "reconnect": rejoin})
			"intent":
				var p: Variant = msg.get("p", {})
				if p is Dictionary:
					intent_received.emit(p)
			"ping":
				_send_msg({"v": PROTO, "t": "pong"})
			"bye":
				_close_peer(true)
	elif role == "guest":
		match t:
			"hello_ack":
				_peer_ready = true
				_guest_state = "connected"
				seat = int(msg.get("seat", 1))
				meta = msg.get("meta", {}) if msg.get("meta") is Dictionary else {}
				room_code = String(msg.get("room", ""))
				connected_to_host.emit(msg)
			"start":
				if msg.get("state") is Dictionary:
					match_started.emit(msg["state"])
			"state":
				if msg.get("state") is Dictionary:
					state_received.emit(msg["state"])
			"log":
				log_received.emit(String(msg.get("text", "")))
			"pong":
				pass
			"kick":
				status.emit(String(msg.get("reason", "被房主移出房间")), Color("ff6b6b"))
				_auto_reconnect = false
				_close_peer(false)
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
			_grace_until = Time.get_ticks_msec() + int(GRACE_SECONDS * 1000.0)
			guest_left.emit()
			status.emit("对手断开，保留房间等待回座（%d 秒）" % int(GRACE_SECONDS), Color("ffb86b"))
		elif role == "guest" and _auto_reconnect:
			_guest_state = "connecting"
			status.emit("连接断开，正在自动重连…", Color("ffb86b"))
			link_lost.emit(false)


# ---------------------------------------------------------------- 下行

func send_start(state: Dictionary) -> void:
	_send_msg({"v": PROTO, "t": "start", "state": state})


func send_state(state: Dictionary) -> void:
	if not _peer_ready:
		return
	_send_msg({"v": PROTO, "t": "state", "state": state})


func send_intent(p: Dictionary) -> void:
	_send_msg({"v": PROTO, "t": "intent", "p": p})


func send_log(text: String) -> void:
	if not _peer_ready:
		return
	_send_msg({"v": PROTO, "t": "log", "text": text})


func refresh() -> void:
	if role == "guest" and _udp_send != null:
		_last_query = 0
