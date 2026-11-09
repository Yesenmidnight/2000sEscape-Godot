extends Node3D
## 报亭 —— 营业玩法（3D 陈列 + 供应商/商品/审查系统后续在此展开）

var _hud: Label
var _toast: Label
var _toast_tween: Tween

func _ready() -> void:
	OverlayUI.close_all()
	VisualEffects.apply_preset("newsstand")

	# 3D 报亭：GLB 模型 + 相机（PS1 全亮 shader，明暗在 shader 内计算）
	var world := Node3D.new()
	add_child(world)
	PS1Look.add_night_env(world)
	world.add_child(PS1Look.spawn("res://assets/models/rooms/room_newsstand_shell.glb", 180.0))
	var cam := Camera3D.new()
	# 注意：look_at 必须在入树后才能调用；入树前用 look_at_from_position
	cam.look_at_from_position(Vector3(0, 1.32, -2.15), Vector3(0, 0.72, -0.25), Vector3.UP)
	world.add_child(cam)
	cam.current = true

	# UI 层（110）：按钮与文字不弯曲，判定精准
	var ui_layer := CanvasLayer.new()
	ui_layer.layer = 110
	add_child(ui_layer)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE # 全屏容器必须穿透
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 14)
	ui_layer.add_child(vb)

	var title := Label.new()
	title.text = "报亭 · 营业中"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color("ffb347"))
	vb.add_child(title)

	var sub := Label.new()
	sub.text = "贩卖玩法策划中——供应商解锁 / 商品陈列 / 营业审查将在此展开"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.modulate = Color(0.7, 0.65, 0.6)
	vb.add_child(sub)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vb.add_child(spacer)

	var sell_btn := Button.new()
	sell_btn.text = "摆摊（占位）"
	sell_btn.custom_minimum_size = Vector2(200, 46)
	sell_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sell_btn.pressed.connect(func(): _show_toast("顾客与商品系统开发中……"))
	vb.add_child(sell_btn)

	var home_btn := Button.new()
	home_btn.text = "收摊回家"
	home_btn.custom_minimum_size = Vector2(200, 46)
	home_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	home_btn.pressed.connect(func():
		GameState.travel = "to_home"
		get_tree().change_scene_to_file("res://scenes/street.tscn"))
	vb.add_child(home_btn)

	_hud = Label.new()
	_hud.position = Vector2(16, 12)
	_hud.add_theme_font_size_override("font_size", 22)
	ui_layer.add_child(_hud)

	_toast = Label.new()
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", 24)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.grow_vertical = Control.GROW_DIRECTION_BOTH
	_toast.offset_top = 120
	_toast.modulate.a = 0.0
	ui_layer.add_child(_toast)

func _show_toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.6)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.9)

func _process(_delta: float) -> void:
	_hud.text = "第 %d 天 · 回忆碎片 %d · B 背包" % [GameState.day, GameState.memory_coins]
