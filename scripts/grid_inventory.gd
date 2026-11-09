class_name GridInventory
extends RefCounted
## 统一网格库存算法 —— 合并迁移自 ESC_Backpack.js（ESC.Backpack）与
## ESC_Containers.js（ContainerGrid）。两处原本重复实现的
## placeOnGrid / canPlaceAt / findPlacePosition / moveItem 在此只写一遍。
## entry 结构: { id:int, x:int, y:int, rot:int }  rot: 0=原方向 1=旋转90°

signal inventory_changed

var cols: int
var rows: int
var items: Array[Dictionary] = []
var _grid: Array = [] # _grid[y][x] -> entry 引用或 null

func _init(p_cols: int = 6, p_rows: int = 5) -> void:
	cols = p_cols
	rows = p_rows
	_rebuild_empty()

func _rebuild_empty() -> void:
	_grid = []
	for y in rows:
		var row := []
		row.resize(cols)
		_grid.append(row)

func _rebuild_grid() -> void:
	_rebuild_empty()
	for e in items:
		_place_on_grid(e)

## 物品占用尺寸（考虑旋转交换宽高，对应 BackpackItem.getWidth/getHeight）
func size_of(id: int, rot: int = 0) -> Vector2i:
	var s: Vector2i = ItemDB.get_size(id)
	if rot == 1:
		return Vector2i(s.y, s.x)
	return s

## 对应 canPlaceAt：边界 + 逐格占用检查（exclude 用于移动自身时忽略）
func can_place_at(x: int, y: int, w: int, h: int, exclude = null) -> bool:
	if x < 0 or y < 0 or x + w > cols or y + h > rows:
		return false
	for dy in h:
		for dx in w:
			var c = _grid[y + dy][x + dx]
			if c != null and c != exclude:
				return false
	return true

## 对应 findPlacePosition：从左上到右下找第一个可放位置
func find_place_position(w: int, h: int):
	for y in rows - h + 1:
		for x in cols - w + 1:
			if can_place_at(x, y, w, h):
				return Vector2i(x, y)
	return null

func _place_on_grid(e: Dictionary) -> void:
	var s := size_of(e.id, e.rot)
	for dy in s.y:
		for dx in s.x:
			var gx: int = e.x + dx
			var gy: int = e.y + dy
			if gy < rows and gx < cols:
				_grid[gy][gx] = e

func _remove_from_grid(e: Dictionary) -> void:
	var s := size_of(e.id, e.rot)
	for dy in s.y:
		for dx in s.x:
			var gx: int = e.x + dx
			var gy: int = e.y + dy
			if gy < rows and gx < cols and _grid[gy][gx] == e:
				_grid[gy][gx] = null

## 拾取：自动寻找连续空格放入（失败 = 背包已满）
func add_item(id: int) -> bool:
	var s := size_of(id)
	var pos = find_place_position(s.x, s.y)
	if pos == null:
		return false
	var e := {"id": id, "x": pos.x, "y": pos.y, "rot": 0}
	items.append(e)
	_place_on_grid(e)
	inventory_changed.emit()
	return true

## 指定坐标放入（容器初始物品 / 跨容器转移用）
func place_item(id: int, x: int, y: int, rot: int = 0) -> bool:
	var s := size_of(id, rot)
	if not can_place_at(x, y, s.x, s.y):
		return false
	var e := {"id": id, "x": x, "y": y, "rot": rot}
	items.append(e)
	_place_on_grid(e)
	inventory_changed.emit()
	return true

func remove_item(e: Dictionary) -> bool:
	var idx := items.find(e)
	if idx < 0:
		return false
	_remove_from_grid(e)
	items.remove_at(idx)
	inventory_changed.emit()
	return true

## 对应 moveItem：先校验（排除自身），再摘除 → 更新 → 铺回
func move_item(e: Dictionary, nx: int, ny: int) -> bool:
	return move_item_rotated(e, nx, ny, e.rot)

## 移动 + 可选换向（对应拖拽松手时旋转已改变的情况）
func move_item_rotated(e: Dictionary, nx: int, ny: int, rot: int) -> bool:
	var s := size_of(e.id, rot)
	if not can_place_at(nx, ny, s.x, s.y, e):
		# 换向后放不下、但按原方向能放下且位置确实变了 → 只移动不换向
		var s0 := size_of(e.id, e.rot)
		if rot != e.rot and (nx != e.x or ny != e.y) and can_place_at(nx, ny, s0.x, s0.y, e):
			rot = e.rot
		else:
			return false
	_remove_from_grid(e)
	e.x = nx
	e.y = ny
	e.rot = rot
	_place_on_grid(e)
	inventory_changed.emit()
	return true

## 对应 rotateItem：旋转受挤压校验，失败转回并返回 false
func rotate_item(e: Dictionary) -> bool:
	var old: int = e.rot
	e.rot = 1 - old
	var s := size_of(e.id, e.rot)
	if not can_place_at(e.x, e.y, s.x, s.y, e):
		e.rot = old
		return false
	_rebuild_grid()
	inventory_changed.emit()
	return true

func item_at(x: int, y: int):
	if x < 0 or y < 0 or x >= cols or y >= rows:
		return null
	return _grid[y][x]

func is_full() -> bool:
	for y in rows:
		for x in cols:
			if _grid[y][x] == null:
				return false
	return true

func empty_cells() -> int:
	var count := 0
	for y in rows:
		for x in cols:
			if _grid[y][x] == null:
				count += 1
	return count

func serialize() -> Dictionary:
	var list := []
	for e in items:
		list.append({"id": e.id, "x": e.x, "y": e.y, "rot": e.rot})
	return {"cols": cols, "rows": rows, "items": list}

func restore(data: Dictionary) -> void:
	cols = int(data.get("cols", cols))
	rows = int(data.get("rows", rows))
	items.clear()
	_rebuild_empty()
	for d in data.get("items", []):
		place_item(int(d.get("id", 0)), int(d.get("x", 0)), int(d.get("y", 0)), int(d.get("rot", 0)))
