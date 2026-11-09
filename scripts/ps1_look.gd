class_name PS1Look
## 把实例化的 GLB 场景统一成 PS1 质感：
## 遍历所有 MeshInstance3D，把表面材质替换为 ps1_spatial ShaderMaterial，
## 并迁移原 StandardMaterial3D 的 albedo 颜色与贴图。

const SHADER := preload("res://shaders/ps1_spatial.gdshader")

static func ps1_material(src: Material) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	var col := Color(0.8, 0.8, 0.8)
	if src is StandardMaterial3D:
		col = src.albedo_color
		if src.albedo_texture != null:
			m.set_shader_parameter("use_tex", true)
			m.set_shader_parameter("tex", src.albedo_texture)
	m.set_shader_parameter("base_color", col)
	return m

static func apply(root: Node) -> void:
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := mi.mesh
		if mesh == null:
			continue
		for s in mesh.get_surface_count():
			var src := mesh.surface_get_material(s)
			mi.set_surface_override_material(s, ps1_material(src))

## 实例化 GLB（保留导入的原始 PBR 材质——色彩经过 Blender 校准）。
## PS1 shader 材质路径（apply）暂缓启用： lambert 光照下部分 GLB 网格不渲染、
## base_color 迁移在部分导入材质上失效（4.7 实测），待用隔离场景单独调试。
static func spawn(glb_path: String, yaw_deg := 0.0) -> Node3D:
	var scene: PackedScene = load(glb_path)
	var node: Node3D = scene.instantiate()
	node.rotation_degrees.y = yaw_deg
	return node

## 给场景挂一套简单的摊位灯光（主方向光 + 两个补光点）
static func add_stall_lights(world: Node3D) -> void:
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-52, 28, 0)
	key.light_energy = 1.1
	world.add_child(key)
	var warm := OmniLight3D.new()
	warm.position = Vector3(0.6, 2.2, -1.4)
	warm.light_color = Color(1.0, 0.9, 0.75)
	warm.light_energy = 2.2
	warm.omni_range = 6.0
	world.add_child(warm)
	var cool := OmniLight3D.new()
	cool.position = Vector3(-1.4, 1.9, 0.9)
	cool.light_color = Color(0.75, 0.82, 1.0)
	cool.light_energy = 1.4
	cool.omni_range = 6.0
	world.add_child(cool)

## 夜色背景环境（深蓝夜空 + 轻雾）
static func add_night_env(world: Node3D) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.055, 0.10)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.46, 0.55)
	env.ambient_light_energy = 1.6
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
