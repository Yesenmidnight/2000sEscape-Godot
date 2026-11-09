extends CanvasLayer
## DragController —— 自定义拖拽控制器
## 对应 RM 版 Window_Backpack / Scene_Container 的拖拽逻辑：
## 左键按下开始拖拽 → 松手尝试放置 → 失败回原位；拖拽中按 R 旋转。

signal drag_started   # begin_drag 时发射
signal drag_ended     # _finish_drag 结束时发射（无论放置成功与否）

var dragging := false
var drag_entry: Dictionary = {}   # 源库存中的 entry 引用（跨容器转移时会失效）
var drag_source: GridInventory = null
var drag_id := 0
var drag_rot := 0
var drop_cell := Vector2i(-1, -1)     # 悬停视图上的预计落点格（供放置预览与落地）
var origin_pos := Vector2i.ZERO   # 原位置（放置失败回退用）
var origin_rot := 0
var hover_view: Control = null    # 当前悬停的 GridView
var hover_cell := Vector2i(-1, -1)

var _ghost: Control

func _ready() -> void:
	layer = 150 # 高于浮层(140)：拖拽幽灵跟随网格视图；低于颗粒层(160)会带上扫描线质感
	_ghost = Control.new()
	_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ghost.visible = false
	_ghost.draw.connect(_on_ghost_draw)
	add_child(_ghost)

func drag_size() -> Vector2i:
	var s: Vector2i = ItemDB.get_size(drag_id)
	if drag_rot == 1:
		return Vector2i(s.y, s.x)
	return s

## 开始拖拽：物品图片中心钉在鼠标指针下，R 旋转时绕中心转动
func begin_drag(source: GridInventory, entry: Dictionary) -> void:
	dragging = true
	drag_source = source
	drag_entry = entry
	drag_id = entry.id
	drag_rot = entry.rot
	origin_rot = entry.rot
	origin_pos = Vector2i(entry.x, entry.y)
	_ghost.position = get_viewport().get_mouse_position()
	_ghost.visible = true
	_ghost.queue_redraw()
	drag_started.emit()

func _process(_delta: float) -> void:
	if dragging:
		_ghost.position = get_viewport().get_mouse_position()
		_update_hover()
	else:
		hover_view = null

func _update_hover() -> void:
	hover_view = null
	hover_cell = Vector2i(-1, -1)
	drop_cell = Vector2i(-1, -1)
	if not dragging:
		return
	var mp := get_viewport().get_mouse_position()
	for v in get_tree().get_nodes_in_group("grid_views"):
		if is_instance_valid(v) and v.is_visible_in_tree() and v.get_global_rect().has_point(mp):
			hover_view = v
			hover_cell = v.global_to_cell(mp)
			drop_cell = _compute_drop_cell(v)
			break

## 由当前鼠标位置计算放置落点：占位区中心钉在指针下 → 左上角 round 对齐到格
func _compute_drop_cell(view: Control) -> Vector2i:
	var mouse_local: Vector2 = get_viewport().get_mouse_position() - view.global_position
	var origin_in_grid: Vector2 = mouse_local - view.grid_offset() - Vector2(drag_size()) * 24.0
	return Vector2i(
		int(round(origin_in_grid.x / 48.0)),
		int(round(origin_in_grid.y / 48.0)))

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and not event.pressed and dragging:
		_finish_drag()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		if dragging:
			drag_rot = 1 - drag_rot
			_ghost.queue_redraw()
			get_viewport().set_input_as_handled()
		else:
			# 非拖拽时：旋转鼠标悬停处的物品
			var mp := get_viewport().get_mouse_position()
			for v in get_tree().get_nodes_in_group("grid_views"):
				if is_instance_valid(v) and v.is_visible_in_tree() and v.get_global_rect().has_point(mp):
					var cell: Vector2i = v.global_to_cell(mp)
					var e = v.inventory.item_at(cell.x, cell.y)
					if e != null:
						v.inventory.rotate_item(e)
						get_viewport().set_input_as_handled()
					break

func _finish_drag() -> void:
	if not dragging:
		return
	var ok := false
	if hover_view != null and is_instance_valid(hover_view):
		var target: GridInventory = hover_view.inventory
		var dc := _compute_drop_cell(hover_view)
		var nx: int = dc.x
		var ny: int = dc.y
		if target == drag_source:
			ok = drag_source.move_item_rotated(drag_entry, nx, ny, drag_rot)
		else:
			var s := drag_size()
			if target.can_place_at(nx, ny, s.x, s.y):
				drag_source.remove_item(drag_entry)
				ok = target.place_item(drag_id, nx, ny, drag_rot)
				if not ok:
					# 理论上不会发生，兜底回源
					ok = drag_source.place_item(drag_id, origin_pos.x, origin_pos.y, origin_rot)
	if not ok:
		# 放置失败 → 回到原位原方向（对应 RM 版 startReturnAnimation 的简化版）
		if drag_source.items.has(drag_entry):
			drag_source.move_item_rotated(drag_entry, origin_pos.x, origin_pos.y, origin_rot)
		else:
			drag_source.place_item(drag_id, origin_pos.x, origin_pos.y, origin_rot)
	dragging = false
	drag_entry = {}
	_ghost.visible = false
	hover_view = null
	drag_ended.emit()

func _on_ghost_draw() -> void:
	if not dragging:
		return
	var tex := ItemDB.get_icon(drag_id)
	var s := drag_size()
	var footprint := Rect2(Vector2.ZERO, Vector2(s.x, s.y) * 48.0 - Vector2(4, 4))
	if tex != null:
		var dr := GridView.fitted_rect(tex, footprint, drag_rot == 1)
		dr.position = -dr.size * 0.5 # 图片中心钉在指针下
		if drag_rot == 1:
			dr.size = Vector2(dr.size.y, dr.size.x) # Godot 的 transpose 会再交换一次宽高
		_ghost.draw_texture_rect(tex, dr, false, Color.WHITE, drag_rot == 1)
	else:
		_ghost.draw_rect(Rect2(-footprint.size * 0.5, footprint.size), Color(0.4, 0.45, 0.6, 0.8), true)
