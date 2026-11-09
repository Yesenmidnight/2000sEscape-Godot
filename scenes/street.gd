extends Node3D
## 横版街道 —— 节点制自主移动（3D 夜街版）
## 角色不可直接操控：每按一次「探索」自动前移一个节点；
## 到达节点可搜刮容器（双栏拖拽界面）并可能触发随机事件；
## 上/下班两条路线可选，走满 5 段到达目的地。
## 3D 呈现：夜色街景 + 节点旁摆放真实容器 GLB + 相机跟随 + 右上角小地图。

const TOTAL := 5
const LANES := {
	"大街": [37, 40, 18, 23],  # 小巷熊猫垃圾桶 / 小卖部柜台 / 楼道杂物堆 / 班级储物柜
	"小巷": [43, 29, 31, 24],  # 楼梯间杂物 / 走廊熊猫垃圾桶2F / 清洁工具柜 / 读书角书架
}
const LANE_Z := {"大街": 1.6, "小巷": -1.6}
const NODE_X0 := -6.0
const NODE_DX := 2.4
const EVENTS := [
	{"text": "捡到一枚亮闪闪的硬币。", "coins": 5},
	{"text": "一只橘猫从墙头悄悄路过。", "coins": 0},
	{"text": "远处收音机放着千禧年的流行歌。", "coins": 0},
	{"text": "风把一张旧传单吹到脚边。", "coins": 0},
	{"text": "自行车铃声响过，唤醒了一段记忆。", "coins": 3},
]
# containerType -> godot/assets/models/containers/<file>
const TYPE_MODEL := {
	"wardrobe": "container_wardrobe.glb", "shelf": "container_shelf.glb",
	"cabinet": "container_cabinet.glb", "fridge": "container_fridge.glb",
	"desk": "container_desk.glb", "drawer": "container_drawer_bedside.glb",
	"locker": "container_locker.glb", "mailbox": "container_mailbox.glb",
	"pile": "container_pile.glb", "trashcan": "container_trashcan.glb",
	"box": "container_box.glb", "backpack": "container_backpack.glb",
	"counter": "container_counter.glb",
}

var lane_name := ""
var step := 0
var _busy := false
var _lane_btns: Array[Button] = []
var _action_btn: Button
var _loot_btn: Button
var _title: Label
var _progress: Label
var _hud: Label
var _toast: Label
var _toast_tween: Tween
var _pending_container := 0
var _player: Node3D
var _cam: Camera3D
var _minimap: Control

func _ready() -> void:
	OverlayUI.close_all()
	VisualEffects.apply_preset("street")

	_build_world()

	# UI 层（110）：标题/HUD/按钮不弯曲，判定与视觉一致
	var ui_layer := CanvasLayer.new()
	ui_layer.layer = 110
	add_child(ui_layer)

	_title = Label.new()
	_title.position = Vector2(16, 12)
	_title.add_theme_font_size_override("font_size", 26)
	ui_layer.add_child(_title)

	_hud = Label.new()
	_hud.position = Vector2(16, 46)
	_hud.add_theme_font_size_override("font_size", 18)
	_hud.modulate = Color(0.8, 0.8, 0.9)
	ui_layer.add_child(_hud)

	_progress = Label.new()
	_progress.add_theme_font_size_override("font_size", 22)
	_progress.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_progress.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_progress.offset_top = 14
	ui_layer.add_child(_progress)

	_toast = Label.new()
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", 22)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.grow_vertical = Control.GROW_DIRECTION_BOTH
	_toast.modulate.a = 0.0
	ui_layer.add_child(_toast)

	# 小地图（右上角）
	_minimap = preload("res://scenes/street_minimap.gd").new()
	_minimap.position = Vector2(-246, 14)
	_minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	ui_layer.add_child(_minimap)

	# 底部按钮区：全宽 VBox + 底部对齐（可靠布局模式，热区与可见位置一致）
	var bottom := VBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_FULL_RECT)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE # 全屏容器必须穿透
	bottom.alignment = BoxContainer.ALIGNMENT_END
	bottom.add_theme_constant_override("separation", 10)
	bottom.offset_bottom = -20
	ui_layer.add_child(bottom)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	hb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bottom.add_child(hb)

	for lane in LANES:
		var b := Button.new()
		b.text = "走%s" % lane
		b.custom_minimum_size = Vector2(160, 50)
		b.pressed.connect(_on_lane_chosen.bind(lane))
		hb.add_child(b)
		_lane_btns.append(b)

	_action_btn = Button.new()
	_action_btn.text = "探索"
	_action_btn.custom_minimum_size = Vector2(180, 50)
	_action_btn.pressed.connect(_on_action)
	hb.add_child(_action_btn)

	_loot_btn = Button.new()
	_loot_btn.text = "搜刮容器"
	_loot_btn.custom_minimum_size = Vector2(220, 50)
	_loot_btn.pressed.connect(func(): OverlayUI.open_container(_pending_container))
	hb.add_child(_loot_btn)

	_refresh_ui()

func _node_pos(lane: String, i: int) -> Vector3:
	return Vector3(NODE_X0 + i * NODE_DX, 0.0, LANE_Z[lane])

func _build_world() -> void:
	PS1Look.add_night_env(self)

	# 沥青路面
	var ground := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(44, 0.2, 16)
	gm.material = _mat(Color(0.10, 0.10, 0.12), 0.9)
	ground.mesh = gm
	ground.position = Vector3(0, -0.1, 0)
	add_child(ground)

	# 两侧楼群剪影 + 亮窗（确定性伪随机）
	for side in [-1, 1]:
		for i in range(11):
			var h := 4.0 + ((i * 37) % 50) * 0.12
			var bx := -20.0 + i * 4.0 + ((i * 13) % 10) * 0.1
			var bz: float = side * (9.0 + ((i * 7) % 30) * 0.08)
			var b := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(3.6, h, 4.0)
			bm.material = _mat(Color(0.06, 0.07, 0.11), 0.9)
			b.mesh = bm
			b.position = Vector3(bx, h / 2.0, bz)
			add_child(b)
			# 亮窗
			for wy in range(int(h) / 14):
				if (i + wy) % 3 == 0:
					var win := MeshInstance3D.new()
					var wm := BoxMesh.new()
					wm.size = Vector3(0.5, 0.6, 0.05)
					wm.material = _win_mat()
					win.mesh = wm
					win.position = Vector3(bx - 1.0 + (wy % 3) * 1.0, 1.6 + wy * 1.3, bz - side * 2.05)
					add_child(win)

	# 路线光带
	for lane in LANES:
		var strip := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(NODE_DX * TOTAL + 3.0, 0.03, 0.55)
		var col := Color(0.22, 0.24, 0.34) if lane == "大街" else Color(0.16, 0.18, 0.26)
		sm.material = _mat(col, 0.8)
		strip.mesh = sm
		strip.position = Vector3(NODE_X0 + TOTAL * NODE_DX / 2.0, 0.02, LANE_Z[lane])
		add_child(strip)

	# 路灯（杆 + 灯头 + 点光）
	for i in range(4):
		var lx := -6.0 + i * 4.0
		var lz := 0.9 if i % 2 == 0 else -0.9
		var pole := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.05
		pm.bottom_radius = 0.07
		pm.height = 3.4
		pm.material = _mat(Color(0.15, 0.16, 0.18), 0.7)
		pole.mesh = pm
		pole.position = Vector3(lx, 1.7, lz)
		add_child(pole)
		var head := MeshInstance3D.new()
		var hm := SphereMesh.new()
		hm.radius = 0.14
		hm.height = 0.28
		var lm := StandardMaterial3D.new()
		lm.albedo_color = Color(1.0, 0.92, 0.65)
		lm.emission_enabled = true
		lm.emission = Color(1.0, 0.9, 0.6)
		lm.emission_energy_multiplier = 2.2
		hm.material = lm
		head.mesh = hm
		head.position = Vector3(lx, 3.45, lz)
		add_child(head)
		var ol := OmniLight3D.new()
		ol.position = Vector3(lx, 3.3, lz)
		ol.light_color = Color(1.0, 0.9, 0.65)
		ol.light_energy = 1.6
		ol.omni_range = 7.0
		add_child(ol)

	# 节点旁的容器 GLB（两条路线全摆出来）
	for lane in LANES:
		var behind: float = 1.3 if lane == "大街" else -1.3
		for i in range(LANES[lane].size()):
			var id := int(LANES[lane][i])
			var def := ContainerManager.get_def(id)
			var file: String = TYPE_MODEL.get(str(def.get("ctype", "")), "")
			if file == "":
				continue
			var model := PS1Look.spawn("res://assets/models/containers/" + file, 0.0)
			model.position = Vector3(NODE_X0 + (i + 1) * NODE_DX, 0.0, LANE_Z[lane] + behind)
			add_child(model)

	# 月光
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-48, 22, 0)
	moon.light_color = Color(0.62, 0.68, 0.9)
	moon.light_energy = 0.55
	add_child(moon)

	# 玩家标记（发光绿胶囊）
	_player = Node3D.new()
	_player.position = _node_pos("大街", 0)
	add_child(_player)
	var body := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.18
	cm.height = 0.9
	var pm2 := StandardMaterial3D.new()
	pm2.albedo_color = Color(0.05, 0.25, 0.12)
	pm2.emission_enabled = true
	pm2.emission = Color(0.0, 1.0, 0.55)
	pm2.emission_energy_multiplier = 0.9
	cm.material = pm2
	body.mesh = cm
	body.position.y = 0.45
	_player.add_child(body)

	# 相机（跟随玩家）
	_cam = Camera3D.new()
	_cam.position = Vector3(_player.position.x * 0.82, 5.4, _player.position.z - 7.4)
	_cam.look_at(_player.position + Vector3(0, 0.4, 2.6), Vector3.UP)
	add_child(_cam)
	_cam.current = true

func _mat(col: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	return m

func _win_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.95, 0.85, 0.5)
	m.emission_enabled = true
	m.emission = Color(0.95, 0.82, 0.45)
	m.emission_energy_multiplier = 1.6
	return m

func _on_lane_chosen(lane: String) -> void:
	lane_name = lane
	_player.position = _node_pos(lane, 0)
	_refresh_ui()

func _on_action() -> void:
	if _busy:
		return
	if step >= TOTAL:
		# 到达目的地
		if GameState.travel == "to_work":
			get_tree().change_scene_to_file("res://scenes/newsstand.tscn")
		else:
			get_tree().change_scene_to_file("res://scenes/home.tscn")
		return
	# 前移一个节点（角色自主移动）
	_busy = true
	step += 1
	var target := _node_pos(lane_name, step)
	var tw := create_tween()
	tw.tween_property(_player, "position", target, 0.7)
	await tw.finished
	_busy = false
	# 节点容器
	var pool: Array = LANES[lane_name]
	_pending_container = int(pool[step - 1]) if step - 1 < pool.size() else 0
	# 随机事件
	if randi() % 100 < 45:
		var ev: Dictionary = EVENTS[randi() % EVENTS.size()]
		var coins := int(ev.get("coins", 0))
		if coins > 0:
			GameState.add_coins(coins)
		_show_toast(str(ev.text) + (("（回忆碎片 +%d）" % coins) if coins > 0 else ""))
	_refresh_ui()

func _refresh_ui() -> void:
	_title.text = "上班路上" if GameState.travel == "to_work" else "回家路上"
	_progress.text = "第 %d / %d 段" % [step, TOTAL]
	var lane_chosen := lane_name != ""
	for b in _lane_btns:
		b.visible = not lane_chosen
	_action_btn.visible = lane_chosen
	if step >= TOTAL:
		_action_btn.text = "进入报亭" if GameState.travel == "to_work" else "进入家门"
	else:
		_action_btn.text = "继续探索"
	_loot_btn.visible = _pending_container != 0 and step > 0 and step < TOTAL
	if _loot_btn.visible:
		var def := ContainerManager.get_def(_pending_container)
		_loot_btn.text = "搜刮：%s" % def.get("name", "?")
	_sync_minimap()

func _show_toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.6)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.9)

func _sync_minimap() -> void:
	if _minimap == null:
		return
	_minimap.set("lane_name", lane_name)
	_minimap.set("step", step)
	_minimap.set("token_world", _player.position)
	_minimap.queue_redraw()

func _process(delta: float) -> void:
	_hud.text = "回忆碎片 %d · B 背包" % GameState.memory_coins
	if _cam != null and _player != null:
		var target := _player.position
		var cam_pos := Vector3(target.x * 0.82, 5.4, target.z - 7.4)
		_cam.global_position = _cam.global_position.lerp(cam_pos, minf(delta * 3.0, 1.0))
		_cam.look_at(target + Vector3(0, 0.4, 2.6), Vector3.UP)
	_sync_minimap()
