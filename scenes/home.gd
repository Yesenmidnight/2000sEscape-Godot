extends Node3D
## 家 —— 第一人称探索（3D 房间 + 鼠标环视）
## 鼠标左右移动可环视房间（对应「恶魔轮盘赌」式视角转动的简化版），
## 出门上班进入街道；睡觉推进到下一天并自动存档。

var _cam: Camera3D
var _base_rot := Vector3.ZERO
var _hud: Label
var _toast: Label
var _toast_tween: Tween

func _ready() -> void:
	OverlayUI.close_all()
	VisualEffects.apply_preset("home")

	# 3D 家场景：GLB 房间 + 相机（鼠标环视 = 第一人称视角左右转）
	# 家具按绝对坐标摆放且不对称 → 不转 180°，相机放 +Z 侧（门口位）看向房内
	var world := Node3D.new()
	add_child(world)
	PS1Look.add_night_env(world)
	world.add_child(PS1Look.spawn("res://assets/models/rooms/room_home.glb", 0.0))
	_cam = Camera3D.new()
	# look_at 必须在入树后调用；入树前用 look_at_from_position
	_cam.look_at_from_position(Vector3(0.2, 1.45, 1.4), Vector3(0, 0.9, -0.2), Vector3.UP)
	world.add_child(_cam)
	_cam.current = true
	_base_rot = _cam.rotation_degrees

	# UI 层（110）：HUD/按钮/浮层文字不弯曲，点击判定与视觉一致
	var ui_layer := CanvasLayer.new()
	ui_layer.layer = 110
	add_child(ui_layer)

	# 顶部 HUD
	_hud = Label.new()
	_hud.position = Vector2(16, 12)
	_hud.add_theme_font_size_override("font_size", 22)
	ui_layer.add_child(_hud)

	# 底部按钮区：全宽 VBox + 底部对齐（与主菜单相同的可靠布局模式，
	# 避免「点锚点容器」导致的可见位置与点击热区错位）
	var bottom := VBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_FULL_RECT)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE # 全屏容器必须穿透
	bottom.alignment = BoxContainer.ALIGNMENT_END
	bottom.add_theme_constant_override("separation", 10)
	bottom.offset_bottom = -20
	ui_layer.add_child(bottom)

	var hint := Label.new()
	hint.text = "挪动鼠标环视房间（第一人称 3D） · B 背包 · F1 滤镜开关"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hint.modulate = Color(0.65, 0.65, 0.8)
	bottom.add_child(hint)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 18)
	hb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bottom.add_child(hb)

	var go_btn := Button.new()
	go_btn.text = "出门上班"
	go_btn.custom_minimum_size = Vector2(200, 50)
	go_btn.pressed.connect(func():
		GameState.travel = "to_work"
		get_tree().change_scene_to_file("res://scenes/street.tscn"))
	hb.add_child(go_btn)

	var sleep_btn := Button.new()
	sleep_btn.text = "睡觉"
	sleep_btn.custom_minimum_size = Vector2(150, 50)
	sleep_btn.pressed.connect(_on_sleep)
	hb.add_child(sleep_btn)

	# Toast
	_toast = Label.new()
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", 24)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.grow_vertical = Control.GROW_DIRECTION_BOTH
	_toast.modulate.a = 0.0
	ui_layer.add_child(_toast)

func _on_sleep() -> void:
	GameState.go_to_sleep()
	_show_toast("睡了一觉——第 %d 天的早晨。" % GameState.day)

func _show_toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.6)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.9)

func _process(_delta: float) -> void:
	_hud.text = "第 %d 天 · 回忆碎片 %d" % [GameState.day, GameState.memory_coins]
	if _cam == null:
		return
	# 鼠标横向位置 → 相机 yaw 环视（-50°..+50°，保留 look_at 基准俯仰）
	var vp := get_viewport().get_visible_rect().size
	var mouse := get_viewport().get_mouse_position()
	var ratio := clampf(mouse.x / max(vp.x, 1.0), 0.0, 1.0)
	var yaw := lerpf(-50.0, 50.0, ratio)
	_cam.rotation_degrees = Vector3(_base_rot.x, _base_rot.y + yaw, _base_rot.z)
