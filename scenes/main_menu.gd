extends Control
## 主菜单 —— 新的一天 / 继续 / 退出

func _ready() -> void:
	OverlayUI.close_all()
	VisualEffects.apply_preset("menu")

	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.09, 0.16)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# UI 层（110）：高于世界弯曲层，菜单内容不弯曲、判定精准
	var ui_layer := CanvasLayer.new()
	ui_layer.layer = 110
	add_child(ui_layer)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE # 全屏容器必须穿透，否则挡住下层输入
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 14)
	ui_layer.add_child(vb)

	var title := Label.new()
	title.text = "逃离千禧年"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Color("00ff88"))
	vb.add_child(title)

	var sub := Label.new()
	sub.text = "Godot 重制版 · 核心系统原型（网格背包 / 容器搜刮 / CRT 滤镜）"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.modulate = Color(0.7, 0.7, 0.85)
	vb.add_child(sub)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	vb.add_child(spacer)

	if GameState.has_save():
		_add_button(vb, "继续上一天", func():
			if not GameState.load_game():
				GameState.new_game()
			get_tree().change_scene_to_file("res://scenes/home.tscn"))
	_add_button(vb, "开始新的一天", func():
		GameState.new_game()
		get_tree().change_scene_to_file("res://scenes/home.tscn"))
	_add_button(vb, "退出", func(): get_tree().quit())

	var credit := Label.new()
	credit.text = "数据与美术资产来自 RPG Maker 版《逃离千禧年》(2000sEscape)"
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credit.modulate = Color(0.45, 0.48, 0.6)
	vb.add_child(credit)

func _add_button(parent: Control, text: String, on_pressed: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(280, 46)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(on_pressed)
	parent.add_child(b)
