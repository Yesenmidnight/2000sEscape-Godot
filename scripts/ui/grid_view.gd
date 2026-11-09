class_name GridView
extends Control
## 网格视图 —— 对应 RM 版 Window_Backpack / Window_Container 的绘制与交互层。
## 负责画格子/物品/悬停高亮/拖拽放置预览；拖拽本身交给 DragController。

const CELL := 48
const PAD := 6
const TITLE_H := 34

var inventory: GridInventory
var title := ""
var show_title := true

func _ready() -> void:
	add_to_group("grid_views")
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_apply_size()

func _apply_size() -> void:
	if inventory == null:
		return
	var th := TITLE_H if show_title else 0
	custom_minimum_size = Vector2(
		inventory.cols * CELL + PAD * 2,
		inventory.rows * CELL + PAD * 2 + th)

func grid_offset() -> Vector2:
	return Vector2(PAD, PAD + (TITLE_H if show_title else 0))

func local_to_cell(lp: Vector2) -> Vector2i:
	var p := (lp - grid_offset()) / CELL
	return Vector2i(int(floor(p.x)), int(floor(p.y)))

func global_to_cell(gp: Vector2) -> Vector2i:
	return local_to_cell(gp - global_position)

func cell_rect(cell: Vector2i, size_cells: Vector2i) -> Rect2:
	return Rect2(
		grid_offset() + Vector2(cell.x, cell.y) * CELL + Vector2(2, 2),
		Vector2(size_cells.x, size_cells.y) * CELL - Vector2(4, 4))

## 等比缩放绘制矩形：把物品图按比例放进格子占位（旋转时按旋转后的宽高比计算），
## 避免 draw_texture_rect 的 transpose 非等比拉伸导致的「变矮变胖」
static func fitted_rect(tex: Texture2D, footprint: Rect2, rotated: bool) -> Rect2:
	if tex == null:
		return footprint
	var ts := tex.get_size()
	if ts.x <= 0.0 or ts.y <= 0.0:
		return footprint
	var aspect := ts.y / ts.x if rotated else ts.x / ts.y # 旋转后显示的宽高比
	var fp_aspect := footprint.size.x / maxf(footprint.size.y, 1.0)
	var draw_size: Vector2
	if aspect > fp_aspect:
		draw_size = Vector2(footprint.size.x, footprint.size.x / aspect)
	else:
		draw_size = Vector2(footprint.size.y * aspect, footprint.size.y)
	return Rect2(footprint.position + (footprint.size - draw_size) * 0.5, draw_size)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if inventory == null:
		return
	var th := TITLE_H if show_title else 0
	var w := inventory.cols * CELL
	var h := inventory.rows * CELL
	# 面板底
	draw_rect(Rect2(Vector2.ZERO, Vector2(w + PAD * 2, h + PAD * 2 + th)),
		Color(0.07, 0.07, 0.11, 0.97))
	if show_title and title != "":
		draw_string(ThemeDB.fallback_font, Vector2(PAD, 24), title,
			HORIZONTAL_ALIGNMENT_LEFT, w, 20, Color(0.75, 0.75, 0.88))
	# 格子
	for y in inventory.rows:
		for x in inventory.cols:
			var r := Rect2(grid_offset() + Vector2(x, y) * CELL, Vector2(CELL, CELL))
			draw_rect(r, Color(0.11, 0.11, 0.16, 1.0), true)
			draw_rect(r, Color(0.32, 0.32, 0.45, 1.0), false, 1.0)
	# 物品
	for e in inventory.items:
		var s: Vector2i = inventory.size_of(e.id, e.rot)
		var rect := cell_rect(Vector2i(e.x, e.y), s)
		var it: Dictionary = ItemDB.get_item(e.id)
		var base: Color = it.get("color", Color(0.3, 0.3, 0.4)) if it.has("color") else Color(0.3, 0.3, 0.4)
		draw_rect(rect, Color(base.r, base.g, base.b, 0.35))
		var tex := ItemDB.get_icon(e.id)
		if tex != null:
			var fr := GridView.fitted_rect(tex, rect, e.rot == 1)
			if e.rot == 1:
				fr.size = Vector2(fr.size.y, fr.size.x) # Godot 的 transpose 会再交换一次宽高
			draw_texture_rect(tex, fr, false, Color.WHITE, e.rot == 1)
		else:
			draw_string(ThemeDB.fallback_font, rect.position + Vector2(4, 18),
				it.get("name", "?"), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, 14,
				Color(0.9, 0.9, 0.9))
	# 拖拽放置预览（绿=可放 / 红=不可放）：落点=幽灵左上角对齐的格
	if DragController.dragging and DragController.hover_view == self:
		var s2: Vector2i = DragController.drag_size()
		var dc: Vector2i = DragController.drop_cell
		var valid: bool
		if DragController.drag_source == inventory:
			valid = inventory.can_place_at(dc.x, dc.y, s2.x, s2.y, DragController.drag_entry)
		else:
			valid = inventory.can_place_at(dc.x, dc.y, s2.x, s2.y)
		var prect := Rect2(grid_offset() + Vector2(dc.x, dc.y) * CELL, Vector2(s2.x, s2.y) * CELL)
		var fill := Color(0.2, 0.9, 0.4, 0.30) if valid else Color(0.9, 0.25, 0.25, 0.35)
		var line := Color(0.4, 1.0, 0.55, 0.9) if valid else Color(1.0, 0.35, 0.35, 0.9)
		draw_rect(prect, fill, true)
		draw_rect(prect, line, false, 2.0)
	elif not DragController.dragging:
		# 悬停高亮（对应 RM 版 _hoveredItem）
		var mp := get_global_mouse_position()
		if get_global_rect().has_point(mp):
			var cell := global_to_cell(mp)
			var e2 = inventory.item_at(cell.x, cell.y)
			if e2 != null:
				var s3: Vector2i = inventory.size_of(e2.id, e2.rot)
				var hr := cell_rect(Vector2i(e2.x, e2.y), s3)
				draw_rect(hr, Color(1, 1, 1, 0.10), true)
				draw_rect(hr, Color(1, 1, 1, 0.55), false, 1.5)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var cell := local_to_cell(event.position)
		var e = inventory.item_at(cell.x, cell.y)
		if e != null:
			DragController.begin_drag(inventory, e) # 物品中心钉在指针下
			accept_event()
