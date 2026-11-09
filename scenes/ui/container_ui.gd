extends Control
## 容器搜刮浮层 —— 对应 RM 版 Scene_Container 双网格界面
## 左：容器（按定义的 CxR 自适应）· 右：玩家背包 · 拖拽跨窗口转移

var container_id := 0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var def := ContainerManager.get_def(container_id)
	if def.is_empty():
		var err := Label.new()
		err.text = "容器 %d 不存在" % container_id
		err.set_anchors_preset(Control.PRESET_CENTER)
		add_child(err)
		return
	var inv := ContainerManager.get_inventory(container_id)
	ContainerManager.mark_opened(container_id)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.08, 0.12, 0.98)
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
	title.text = "%s（%d × %d）" % [def.name, def.grid_cols, def.grid_rows]
	title.add_theme_font_size_override("font_size", 20)
	vb.add_child(title)

	var desc := Label.new()
	desc.text = str(def.description)
	desc.modulate = Color(0.65, 0.65, 0.78)
	vb.add_child(desc)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 22)
	vb.add_child(hb)

	# 左：容器
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 4)
	hb.add_child(left)
	var lt := Label.new()
	lt.text = "容器"
	lt.modulate = Color(0.6, 0.7, 0.9)
	left.add_child(lt)
	var cgrid := GridView.new()
	cgrid.inventory = inv
	cgrid.show_title = false
	left.add_child(cgrid)

	# 分隔线
	var sep := ColorRect.new()
	sep.color = Color(0.3, 0.3, 0.42)
	sep.custom_minimum_size = Vector2(1, 0)
	hb.add_child(sep)

	# 右：背包
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 4)
	hb.add_child(right)
	var rt := Label.new()
	rt.text = "背包"
	rt.modulate = Color(0.6, 0.9, 0.7)
	right.add_child(rt)
	var bgrid := GridView.new()
	bgrid.inventory = GameState.player_inventory
	bgrid.show_title = false
	right.add_child(bgrid)

	var hint := Label.new()
	hint.text = "左键按住拖拽转移物品 · R 旋转 · ESC 关闭"
	hint.modulate = Color(0.6, 0.6, 0.75)
	vb.add_child(hint)
