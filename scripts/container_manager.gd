extends Node
## ContainerManager —— 容器数据与运行时状态（迁移自 data/Containers.json
## + ESC_Containers.js 的 ESC.ContainerManager）

var defs: Dictionary = {}          # id -> 定义字典
var _inventories: Dictionary = {}  # id -> GridInventory（运行时状态，惰性创建）
var _opened: Dictionary = {}       # id -> true（已搜刮过）

func _ready() -> void:
	_load_defs()

func _load_defs() -> void:
	var path := "res://data/rmmz/Containers.json"
	if not FileAccess.file_exists(path):
		push_error("ContainerManager: 找不到 " + path)
		return
	var f := FileAccess.open(path, FileAccess.READ)
	var arr = JSON.parse_string(f.get_as_text())
	if arr == null or not (arr is Array):
		push_error("ContainerManager: Containers.json 解析失败")
		return
	for d in arr:
		if d == null:
			continue
		defs[int(d.id)] = {
			"id": int(d.id),
			"name": d.get("name", ""),
			"description": d.get("description", ""),
			"grid_cols": int(d.get("gridCols", 3)),
			"grid_rows": int(d.get("gridRows", 3)),
			"scene_id": str(d.get("sceneId", "")),
			"ctype": str(d.get("containerType", "")),
			"pos": Vector2i(int(d.get("posX", 0)), int(d.get("posY", 0))),
			"locked": bool(d.get("isLocked", false)),
			"lock_key": d.get("lockKeyItem"),
			"initial": d.get("items", []),
		}
	print("[ContainerManager] 容器定义: %d 个" % defs.size())

func get_def(id: int) -> Dictionary:
	return defs.get(id, {})

## 场景内的可搜刮容器（排除随身口袋/背包类定义）
func get_scene_containers(scene_id: String) -> Array:
	var out := []
	for id in defs:
		var d: Dictionary = defs[id]
		if d.scene_id == scene_id and not ["backpack", "pocket"].has(d.ctype):
			out.append(int(id))
	out.sort()
	return out

## 惰性创建容器运行时库存（首件状态来自 JSON 预置物品）
func get_inventory(id: int) -> GridInventory:
	if _inventories.has(id):
		return _inventories[id]
	var def: Dictionary = defs.get(id, {})
	var inv := GridInventory.new(int(def.get("grid_cols", 3)), int(def.get("grid_rows", 3)))
	for it in def.get("initial", []):
		if not inv.place_item(int(it.itemId), int(it.x), int(it.y)):
			push_warning("容器 %d 初始物品放置失败: itemId=%s" % [id, str(it.get("itemId"))])
	_inventories[id] = inv
	return inv

func mark_opened(id: int) -> void:
	_opened[id] = true

func is_opened(id: int) -> bool:
	return _opened.get(id, false)

func serialize_all() -> Dictionary:
	var out := {}
	for id in _inventories:
		out[str(id)] = _inventories[id].serialize()
	return out

func restore_all(data: Dictionary) -> void:
	_inventories.clear()
	for k in data:
		var inv := GridInventory.new(1, 1)
		inv.restore(data[k])
		_inventories[int(k)] = inv

func reset_all() -> void:
	_inventories.clear()
	_opened.clear()
