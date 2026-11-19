class_name SaveStore
extends RefCounted

## 存档仓库：最多 20 个槽位，0 号为自动存档，1..19 为用户手动存档。
## 文件结构刻意做成「版本号 + 分区字典」：
##   { "fmt": 1, "kind": "auto|manual", "game": {...}, "summary": {...},
##     "sections": { "turn": {...}, "teams": {...}, ... }, "extra": {...} }
## 读取时对缺失字段逐个给默认值，未知字段/未知分区原样保留，
## 后续加字段不会让旧存档一次性全部作废。

const DIR := "user://saves"
const FMT := 1
const MAX_SLOTS := 20
const AUTO_SLOT := 0
const MANUAL_SLOTS := 19

const _KNOWN_KEYS := [
	"fmt", "slot", "kind", "created", "updated", "name",
	"game", "summary", "sections", "extra",
]


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)


func slot_path(slot: int) -> String:
	return "%s/save_%02d.json" % [DIR, slot]


func exists(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot))


## 是否自动存档槽（0 号）
func is_auto_slot(slot: int) -> bool:
	return slot == AUTO_SLOT


func read_slot(slot: int) -> Dictionary:
	if not exists(slot):
		return {}
	var text := FileAccess.get_file_as_string(slot_path(slot))
	if text.strip_edges() == "":
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_warning("存档损坏：%s" % slot_path(slot))
		return {}
	return _normalize(parsed, slot)


## 读取并规整为固定形状：旧存档缺字段也能直接用
func _normalize(raw: Dictionary, slot: int) -> Dictionary:
	var rec := {
		"fmt": int(raw.get("fmt", 0)),
		"slot": slot,
		"kind": String(raw.get("kind", "auto" if slot == AUTO_SLOT else "manual")),
		"created": float(raw.get("created", 0.0)),
		"updated": float(raw.get("updated", 0.0)),
		"name": String(raw.get("name", "")),
		"game": _as_dict(raw.get("game")),
		"summary": _as_dict(raw.get("summary")),
		"sections": _as_dict(raw.get("sections")),
		"extra": _as_dict(raw.get("extra")),
	}
	# 将来版本新增的顶层字段不要丢，塞进 extra 里原样保留
	for k in raw.keys():
		if not _KNOWN_KEYS.has(String(k)):
			rec["extra"][String(k)] = raw[k]
	return rec


func _as_dict(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}


func write_slot(slot: int, state: Dictionary) -> bool:
	var now := Time.get_unix_time_from_system()
	var prev := read_slot(slot)
	var sections: Dictionary = _as_dict(state.get("sections")).duplicate(true)
	if not prev.is_empty():
		# 保留旧文件里本版本还不认识的分区
		for k in prev["sections"].keys():
			if not sections.has(k):
				sections[k] = prev["sections"][k]
	var rec := {
		"fmt": FMT,
		"slot": slot,
		"kind": "auto" if slot == AUTO_SLOT else "manual",
		"created": float(prev.get("created", now)) if not prev.is_empty() else now,
		"updated": now,
		"name": String(state.get("name", prev.get("name", ""))),
		"game": _as_dict(state.get("game")),
		"summary": _as_dict(state.get("summary")),
		"sections": sections,
		"extra": _as_dict(prev.get("extra")),
	}
	var text := JSON.stringify(rec, "\t")
	var tmp := slot_path(slot) + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("存档写入失败：%s" % tmp)
		return false
	f.store_string(text)
	f.close()
	var err := DirAccess.rename_absolute(tmp, slot_path(slot))
	if err != OK:
		push_error("存档重命名失败：%s (%d)" % [tmp, err])
		return false
	return true


## 自动存档：不占用手动槽位
func write_auto(state: Dictionary) -> bool:
	return write_slot(AUTO_SLOT, state)


## 手动存档：优先用空槽；19 个手动槽都满时覆盖最旧的一份
func next_manual_slot() -> int:
	var oldest := 1
	var oldest_time := INF
	for slot in range(1, MAX_SLOTS):
		if not exists(slot):
			return slot
		var rec := read_slot(slot)
		var t := float(rec.get("updated", 0.0))
		if t < oldest_time:
			oldest_time = t
			oldest = slot
	return oldest


func delete_slot(slot: int) -> bool:
	if not exists(slot):
		return false
	return DirAccess.remove_absolute(slot_path(slot)) == OK


## 自动存档在前，其余按更新时间倒序
func list_slots() -> Array:
	var auto_rec := read_slot(AUTO_SLOT)
	var manual: Array = []
	for slot in range(1, MAX_SLOTS):
		if not exists(slot):
			continue
		var rec := read_slot(slot)
		if rec.is_empty():
			continue
		manual.append(rec)
	manual.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("updated", 0.0)) > float(b.get("updated", 0.0)))
	var out: Array = []
	if not auto_rec.is_empty():
		out.append(auto_rec)
	out.append_array(manual)
	return out


func count() -> int:
	var n := 0
	for slot in range(MAX_SLOTS):
		if exists(slot):
			n += 1
	return n


static func time_text(unix_time: float) -> String:
	if unix_time <= 0.0:
		return "—"
	var d := Time.get_datetime_dict_from_unix_time(int(unix_time))
	return "%02d-%02d %02d:%02d" % [int(d["month"]), int(d["day"]), int(d["hour"]), int(d["minute"])]
