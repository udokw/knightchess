class_name UpdateFeed
extends Node

## 更新检查：直接走小飞机网盘（feijipan）分享目录的公开接口。
## 分享目录结构：根 → 「骑士飞行棋」→「安卓」/「ios」→ 安装包
##   · 列表：POST /ws/share/list，公共参数里的 timestamp 由 AES-128-ECB 加密
##   · 直链：GET /ws/file/redirect 返回 302，Location 即带签名的下载地址
## 接口来自分享页前端 JS，非官方文档；任何一步失败都返回可读错误给 UI 兜底。

signal check_finished(result: Dictionary)

const SHARE_ID := "S7zlQG68"
const SHARE_URL := "https://share.feijipan.com/s/S7zlQG68"
const API_HOST := "https://api.feijipan.com"
const APP_PREFIX := "骑士飞行棋"
const AES_KEY := "dingHao-disk-app"
const LIST_LIMIT := 100

## 形如「骑士飞行棋-1.0.2.apk」/「骑士飞行棋-v1.0.2.ipa」；容忍空格、破折号与 (1) 后缀
const FILE_PATTERN := "^骑士飞行棋[-_－— ]*[vV]?(\\d+(?:\\.\\d+){1,3})(?:\\(\\d+\\))?\\.(apk|ipa)$"


func _ready() -> void:
	set_process(false)


## 平台对应的子目录名：安卓读「安卓」，iOS 读「ios」
static func platform_folder() -> String:
	if OS.has_feature("ios"):
		return "ios"
	return "安卓"


static func package_ext() -> String:
	return "ipa" if OS.has_feature("ios") else "apk"


static func current_version() -> String:
	return String(ProjectSettings.get_setting("application/config/version", "1.0.0"))


## 版本号比较：a > b 返回 true
static func version_greater(a: String, b: String) -> bool:
	var pa: PackedStringArray = a.split(".")
	var pb: PackedStringArray = b.split(".")
	var n: int = maxi(pa.size(), pb.size())
	for i in n:
		var va: int = int(pa[i]) if i < pa.size() else 0
		var vb: int = int(pb[i]) if i < pb.size() else 0
		if va != vb:
			return va > vb
	return false


## 在文件名里解析出版本号；不匹配返回空串
static func parse_version(file_name: String, want_ext: String) -> String:
	var re := RegEx.new()
	re.compile(FILE_PATTERN)
	var m := re.search(file_name.strip_edges())
	if m == null:
		return ""
	if m.get_string(2).to_lower() != want_ext:
		return ""
	return m.get_string(1)


## 检查更新。current 为空时读 ProjectSettings。
func check(current := "") -> Dictionary:
	var want := current if current.strip_edges() != "" else current_version()
	var trace: Array = []
	var result := {
		"ok": false, "latest": "", "file": {}, "error": "",
		"trace": trace, "current": want, "platform": platform_folder(),
	}
	var root := await _list("")
	trace.append("root:%s" % _brief(root))
	if not root["ok"]:
		result["error"] = String(root["error"])
		check_finished.emit(result)
		return result

	# 根目录优先找「骑士飞行棋」文件夹；找不到就把根目录当文件列表（兼容旧分享结构）
	var app_id := _find_folder(root["list"], [APP_PREFIX])
	var entries: Array = root["list"]
	if app_id != "":
		trace.append("app_folder=%s" % app_id)
		var app := await _list(app_id)
		trace.append("app:%s" % _brief(app))
		if not app["ok"]:
			result["error"] = String(app["error"])
			check_finished.emit(result)
			return result
		var plat_name := platform_folder()
		var plat_id := _find_folder(app["list"], ["ios"] if plat_name == "ios" else ["安卓", "android"])
		entries = app["list"]
		if plat_id != "":
			trace.append("platform_folder=%s" % plat_id)
			var sub := await _list(plat_id)
			trace.append("%s:%s" % [plat_name, _brief(sub)])
			if not sub["ok"]:
				result["error"] = String(sub["error"])
				check_finished.emit(result)
				return result
			entries = sub["list"]
		else:
			result["error"] = "分享目录里没有找到「%s」子文件夹，请确认分享结构。" % plat_name
			check_finished.emit(result)
			return result
	else:
		trace.append("no_app_folder:use_root")

	# 只认对应平台的扩展名；取版本号最大且大于当前版本
	var want_ext := package_ext()
	var best: Dictionary = {}
	var best_ver := ""
	for it in entries:
		if _is_folder(it):
			continue
		var name := _name_of(it)
		var ver := parse_version(name, want_ext)
		if ver == "" or not version_greater(ver, want):
			continue
		if best_ver == "" or version_greater(ver, best_ver):
			best_ver = ver
			best = it
	result["entries"] = entries.size()
	if best_ver == "":
		result["ok"] = true
		result["error"] = "" if entries.size() > 0 else "分享目录里还没有安装包。"
		check_finished.emit(result)
		return result
	result["ok"] = true
	result["latest"] = best_ver
	result["file"] = {
		"fileId": _text(_id_of(best)),
		"name": _name_of(best),
		"size": int(best.get("fileSize", 0)),
		"version": best_ver,
	}
	check_finished.emit(result)
	return result


## 自测用：把分享目录逐层打印出来（名称 / folderId / fileId / 类型 / 可解析版本）
func debug_dump() -> void:
	var root := await _list("")
	print("UPDATE_DIR root ok=%s total=%d" % [bool(root["ok"]), int(root.get("total", 0))])
	_dump(root["list"], "  ")
	var app_id := _find_folder(root["list"], [APP_PREFIX])
	if app_id == "":
		print("UPDATE_DIR app_folder=NOT_FOUND")
		return
	print("UPDATE_DIR app_folder folderId=%s" % app_id)
	var app := await _list(app_id)
	print("UPDATE_DIR app ok=%s total=%d" % [bool(app["ok"]), int(app.get("total", 0))])
	_dump(app["list"], "  ")
	for plat in ["安卓", "ios"]:
		var pid := _find_folder(app["list"], [plat])
		if pid == "":
			print("UPDATE_DIR platform %s=NOT_FOUND" % plat)
			continue
		print("UPDATE_DIR platform %s folderId=%s" % [plat, pid])
		var sub := await _list(pid)
		print("UPDATE_DIR %s ok=%s total=%d entries=%d" % [
			plat, bool(sub["ok"]), int(sub.get("total", 0)), (sub["list"] as Array).size()])
		_dump(sub["list"], "    ")


func _dump(list: Array, indent: String) -> void:
	for it in list:
		var n := _name_of(it)
		print("%s- %s | fileType=%s folderId=%s fileId=%s size=%s | apk=%s ipa=%s" % [
			indent, n, _text(it.get("fileType", "")),
			_text(it.get("folderId", "")), _text(it.get("fileId", "")),
			_text(it.get("fileSize", "")),
			parse_version(n, "apk"), parse_version(n, "ipa")])


## 解析直链：返回 {ok, url, error}
func resolve_link(file: Dictionary) -> Dictionary:
	var file_id := _text(file.get("fileId", ""))
	if file_id == "":
		return {"ok": false, "url": "", "error": "安装包信息缺失，请重新检查更新。"}
	var ms := int(Time.get_unix_time_from_system() * 1000.0)
	var ts := str(ms)
	var query := "downloadId=%s&enable=1&devType=3&uuid=%s&timestamp=%s&auth=%s&shareId=%s" % [
		_encrypt(file_id + "|"),
		_random_hex(32),
		_encrypt(ts),
		_encrypt(file_id + "|" + ts),
		SHARE_ID,
	]
	var res := await _request(API_HOST + "/ws/file/redirect?" + query, HTTPClient.METHOD_GET, "", 0)
	if int(res["result"]) != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "url": "", "error": "网络异常（%d），可改用浏览器打开分享页。" % int(res["result"])}
	var headers: PackedStringArray = res["headers"]
	for h in headers:
		if String(h).to_lower().begins_with("location:"):
			var url := String(h).substr(9).strip_edges()
			if url != "":
				return {"ok": true, "url": url, "error": ""}
	return {"ok": false, "url": "", "error": "没有拿到下载跳转地址（接口可能已变化）。"}


func open_share_page() -> void:
	OS.shell_open(SHARE_URL)


# ---------------------------------------------------------------- 网络

func _headers() -> PackedStringArray:
	return PackedStringArray([
		"User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
		"Accept: application/json, text/plain, */*",
		"Origin: https://share.feijipan.com",
		"Referer: https://share.feijipan.com/",
		"Content-Type: application/json",
	])


func _request(url: String, method: int, body := "", max_redirects := 8) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 12.0
	if max_redirects >= 0:
		http.max_redirects = max_redirects
	add_child(http)
	var err := http.request(url, _headers(), method, body)
	if err != OK:
		http.queue_free()
		return {"result": HTTPRequest.RESULT_CANT_CONNECT, "code": 0, "headers": PackedStringArray(), "body": PackedByteArray()}
	var done: Array = await http.request_completed
	http.queue_free()
	return {
		"result": int(done[0]), "code": int(done[1]),
		"headers": done[2], "body": done[3],
	}


func _list(folder_id: String) -> Dictionary:
	var query := "devType=3&devModel=Windows&uuid=%s&extra=2&timestamp=%s&shareId=%s&offset=1&limit=%d" % [
		_random_hex(32), _encrypt(str(int(Time.get_unix_time_from_system() * 1000.0))),
		SHARE_ID, LIST_LIMIT,
	]
	if folder_id != "":
		query += "&folderId=" + folder_id
	var res := await _request(API_HOST + "/ws/share/list?" + query, HTTPClient.METHOD_POST)
	if int(res["result"]) != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "list": [], "error": "网络异常（%d），请检查网络后重试。" % int(res["result"])}
	var text := (res["body"] as PackedByteArray).get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return {"ok": false, "list": [], "error": "接口返回格式异常，可能已改版。"}
	var dict: Dictionary = parsed
	var list: Array = dict.get("list", []) if dict.get("list") is Array else []
	var msg := _text(dict.get("msg", ""))
	var ok_msg := msg == "" or msg == "成功" or msg.to_lower() == "success" or msg.to_lower() == "ok"
	if not ok_msg and list.is_empty():
		return {"ok": false, "list": [], "error": "接口提示：%s" % msg}
	return {"ok": true, "list": list, "total": int(dict.get("total", list.size())), "error": ""}


# ---------------------------------------------------------------- 工具

func _brief(r: Dictionary) -> String:
	if not bool(r["ok"]):
		return "ERR(%s)" % _text(r["error"])
	return "ok total=%d" % int(r.get("total", 0))


func _name_of(it: Dictionary) -> String:
	return _text(it.get("fileName", it.get("name", "")))


func _id_of(it: Dictionary) -> String:
	var v: Variant = it.get("folderId", it.get("fileId", ""))
	return _text(v)


func _is_folder(it: Dictionary) -> bool:
	if int(it.get("fileType", 0)) == 2:
		return true
	var name := _name_of(it)
	return _text(it.get("folderId", "")) != "" and not (name.ends_with(".apk") or name.ends_with(".ipa"))


## JSON 里的字段可能是 null，直接 String(null) 会报错
func _text(v: Variant) -> String:
	if v == null:
		return ""
	return str(v)


## names 任一命中即返回 folderId（大小写不敏感，支持 contains）
func _find_folder(list: Array, names: Array) -> String:
	for it in list:
		if not _is_folder(it):
			continue
		var n := _name_of(it).to_lower()
		for key in names:
			if n.contains(String(key).to_lower()):
				return _id_of(it)
	return ""


func _random_hex(n: int) -> String:
	var s := ""
	for i in n:
		s += "%x" % randi_range(0, 15)
	return s


## AES-128-ECB + PKCS7，输出大写 hex（与网页端 encryptHex 一致）
func _encrypt(text: String) -> String:
	var data := text.to_utf8_buffer()
	var pad := 16 - (data.size() % 16)
	for i in pad:
		data.append(pad)
	var ctx := AESContext.new()
	if ctx.start(AESContext.MODE_ECB_ENCRYPT, AES_KEY.to_utf8_buffer()) != OK:
		return ""
	var out: PackedByteArray = ctx.update(data)
	ctx.finish()
	return out.hex_encode().to_upper()
