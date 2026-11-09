extends Node
## ItemDB —— 物品数据库（迁移自 RMMZ data/Items.json）
## 原版备注标签 <ESC_size:WxH> <memoryValue:N> <ESC_color:#hex> <ESC_image:name>
## 在此解析为结构化字段；Godot 侧不再需要 note 正则之外的处理。

var items: Dictionary = {}
var _icon_cache: Dictionary = {}

func _ready() -> void:
	_load_items()

func _load_items() -> void:
	var path := "res://data/rmmz/Items.json"
	if not FileAccess.file_exists(path):
		push_error("ItemDB: 找不到 " + path)
		return
	var f := FileAccess.open(path, FileAccess.READ)
	var arr = JSON.parse_string(f.get_as_text())
	if arr == null or not (arr is Array):
		push_error("ItemDB: Items.json 解析失败")
		return
	for d in arr:
		if d == null:
			continue
		items[int(d.id)] = _parse_item(d)
	print("[ItemDB] 物品定义: %d 条" % items.size())

func _parse_item(d: Dictionary) -> Dictionary:
	var note: String = d.get("note", "")
	var size := Vector2i(1, 1)
	var m := RegEx.create_from_string("<ESC_size:(\\d+)x(\\d+)>").search(note)
	if m:
		size = Vector2i(int(m.get_string(1)), int(m.get_string(2)))
	var mv := 0
	m = RegEx.create_from_string("<memoryValue:(\\d+)>").search(note)
	if m:
		mv = int(m.get_string(1))
	var col := Color(0.30, 0.30, 0.40)
	m = RegEx.create_from_string("<ESC_color:(#[0-9a-fA-F]{6})>").search(note)
	if m:
		col = Color(m.get_string(1))
	var img := ""
	m = RegEx.create_from_string("<ESC_image:(\\S+)>").search(note)
	if m:
		img = m.get_string(1)
	return {
		"id": int(d.id),
		"name": d.get("name", ""),
		"description": d.get("description", ""),
		"size": size,
		"memory_value": mv,
		"color": col,
		"image": img,
	}

func get_item(id: int) -> Dictionary:
	return items.get(id, {})

func get_size(id: int) -> Vector2i:
	var it: Dictionary = items.get(id, {})
	if it.has("size"):
		return it.size
	return Vector2i(1, 1)

func get_icon(id: int) -> Texture2D:
	if _icon_cache.has(id):
		return _icon_cache[id]
	var it: Dictionary = items.get(id, {})
	var tex: Texture2D = null
	if it.has("image") and it.image != "":
		var p := "res://assets/items/%s.png" % it.image
		if ResourceLoader.exists(p):
			tex = load(p)
	_icon_cache[id] = tex
	return tex
