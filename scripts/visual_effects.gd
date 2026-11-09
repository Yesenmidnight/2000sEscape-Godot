extends CanvasLayer
## VisualEffects —— 迁移自 ESC_VisualEffects.js：CRT/VHS 全屏滤镜
## 分层结构（修复「弯曲导致 UI 点击判定偏移」问题）：
##   layer 100 world_fx  —— 仅对游戏画面做桶形弯曲（UI 不在此层 → 判定天然对齐）
##   layer 110 scene UI  —— 场景自带的 HUD/按钮（ui_layer，不弯曲）
##   layer 140 overlay   —— 背包/容器浮层（OverlayUI），必须高于场景 UI（同层会被场景全屏容器挡住输入）
##   layer 150 drag ghost —— 拖拽幽灵，跟随浮层网格
##   layer 160 grain     —— 扫描线/噪点/暗角/闪烁，覆盖全部画面（不移动像素 → 不影响判定）
## F1 开关滤镜 · F12 手动截图

const LAYER_WORLD_FX := 100
const LAYER_SCENE_UI := 110
const LAYER_OVERLAY := 140
const LAYER_DRAG := 150
const LAYER_GRAIN := 160

const PRESETS := {
	"menu": {"curvature": 0.10, "scanline_opacity": 0.20, "noise_intensity": 0.06, "vignette_intensity": 0.60, "flicker_intensity": 0.010},
	"home": {"curvature": 0.14, "scanline_opacity": 0.15, "noise_intensity": 0.05, "vignette_intensity": 0.55, "flicker_intensity": 0.010},
	"street": {"curvature": 0.14, "scanline_opacity": 0.20, "noise_intensity": 0.08, "vignette_intensity": 0.40, "flicker_intensity": 0.0},
	"newsstand": {"curvature": 0.12, "scanline_opacity": 0.18, "noise_intensity": 0.06, "vignette_intensity": 0.45, "flicker_intensity": 0.005},
}

var enabled := true
var _fx_mat: ShaderMaterial   # 世界弯曲（仅 curvature）
var _grain_mat: ShaderMaterial # 颗粒覆盖层（curvature=0）
var _fx_rect: ColorRect
var _grain_rect: ColorRect

func _ready() -> void:
	layer = LAYER_WORLD_FX
	var sh: Shader = load("res://shaders/crt_vhs.gdshader")

	# 世界弯曲层：只弯画面，无颗粒
	_fx_rect = ColorRect.new()
	_fx_rect.name = "WorldFX"
	_fx_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_mat = ShaderMaterial.new()
	_fx_mat.shader = sh
	_fx_mat.set_shader_parameter("curvature", 0.14)
	_fx_mat.set_shader_parameter("scanline_opacity", 0.0)
	_fx_mat.set_shader_parameter("noise_intensity", 0.0)
	_fx_mat.set_shader_parameter("vignette_intensity", 0.0)
	_fx_mat.set_shader_parameter("flicker_intensity", 0.0)
	_fx_mat.set_shader_parameter("beam_speed", 0.0)
	_fx_rect.material = _fx_mat
	add_child(_fx_rect)

	# 颗粒覆盖层：不弯曲，覆盖包括 UI 在内的全部画面
	_grain_rect = ColorRect.new()
	_grain_rect.name = "GrainOverlay"
	_grain_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_grain_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grain_mat = ShaderMaterial.new()
	_grain_mat.shader = sh
	_grain_mat.set_shader_parameter("curvature", 0.0)
	_grain_rect.material = _grain_mat
	var grain_layer := CanvasLayer.new()
	grain_layer.layer = LAYER_GRAIN
	grain_layer.add_child(_grain_rect)
	add_child(grain_layer)

	apply_preset("menu")
	if OS.get_cmdline_user_args().has("--auto-shot"):
		_auto_shot()

## 场景氛围预设（对应原版 applySceneEffect，参数用 tween 平滑过渡）
func apply_preset(name: String) -> void:
	var p: Dictionary = PRESETS.get(name, PRESETS["street"])
	_tween_param(_fx_mat, "curvature", float(p.curvature))
	_tween_param(_grain_mat, "scanline_opacity", float(p.scanline_opacity))
	_tween_param(_grain_mat, "noise_intensity", float(p.noise_intensity))
	_tween_param(_grain_mat, "vignette_intensity", float(p.vignette_intensity))
	_tween_param(_grain_mat, "flicker_intensity", float(p.flicker_intensity))

func _tween_param(mat: ShaderMaterial, k: String, to: float) -> void:
	var from_v = mat.get_shader_parameter(k)
	if from_v == null:
		from_v = 0.0
	var tw := create_tween()
	tw.tween_method(func(v: float): mat.set_shader_parameter(k, v), float(from_v), to, 0.5)

func toggle() -> void:
	enabled = not enabled
	_fx_rect.visible = enabled
	_grain_rect.visible = enabled

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			toggle()
		elif event.keycode == KEY_F12:
			_save_shot("manual_shot")

func _save_shot(shot_name: String) -> void:
	var img := get_tree().root.get_texture().get_image()
	var path := OS.get_user_data_dir().path_join(shot_name + ".png")
	img.save_png(path)
	print("[截图] ", path)

## --auto-shot 演示序列：场景 → 背包（含多尺寸物品）→ 容器搜刮，随后退出
func _auto_shot() -> void:
	await get_tree().create_timer(1.0).timeout
	_save_shot("shot_1_scene")
	GameState.player_inventory.restore({"cols": 6, "rows": 5, "items": []})
	for id in [76, 59, 31, 91, 49]: # 热水瓶2x2 / 红领巾1x2 / 磁带1x1 / 连环画3x2 / 橘子汽水1x2
		GameState.player_inventory.add_item(id)
	for e in GameState.player_inventory.items: # 旋转橘子汽水(1x2→2x1)验证等比绘制
		if e.id == 49:
			GameState.player_inventory.rotate_item(e)
			break
	OverlayUI.open_backpack()
	await get_tree().create_timer(0.8).timeout
	_save_shot("shot_2_backpack")
	OverlayUI.close_all()
	OverlayUI.open_container(37) # 小巷熊猫垃圾桶 2x3
	await get_tree().create_timer(0.8).timeout
	_save_shot("shot_3_container")
	OverlayUI.close_all()
	# 3D 场景组装验证：报亭 GLB + 家 GLB
	get_tree().change_scene_to_file("res://scenes/newsstand.tscn")
	await get_tree().create_timer(1.2).timeout
	_save_shot("shot_4_newsstand3d")
	get_tree().change_scene_to_file("res://scenes/home.tscn")
	await get_tree().create_timer(1.2).timeout
	_save_shot("shot_5_home3d")
	get_tree().quit()
