extends Control
## 背包浮层 —— 对应 RM 版 Scene_Backpack / Window_Backpack（6x5 网格）

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.09, 0.13, 0.98)
	sb.border_color = Color(0.35, 0.35, 0.5)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)

	var title := Label.new()
	title.text = "背包（6 × 5）"
	title.add_theme_font_size_override("font_size", 20)
	vb.add_child(title)

	var grid := GridView.new()
	grid.inventory = GameState.player_inventory
	grid.show_title = false
	vb.add_child(grid)

	var hint := Label.new()
	hint.text = "左键拖拽移动 · R 旋转 · 拖到别处转移 · B / ESC 关闭"
	hint.modulate = Color(0.6, 0.6, 0.75)
	vb.add_child(hint)
