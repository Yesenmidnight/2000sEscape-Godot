extends CanvasLayer
## OverlayUI —— 背包 / 容器浮层管理（对应 RM 版 Scene_Backpack / Scene_Container 的打开关闭）
## B 开关背包 · ESC 关闭浮层 · 容器界面由场景调用 open_container()

const BackpackScene := preload("res://scenes/ui/backpack_ui.tscn")
const ContainerScene := preload("res://scenes/ui/container_ui.tscn")

var _backpack: Control = null
var _container: Control = null

func _ready() -> void:
	layer = 140 # 必须高于场景 UI 层(110)：同层时场景的全屏容器会挡住浮层的鼠标输入

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_B:
				if _container == null:
					if _backpack:
						close_backpack()
					else:
						open_backpack()
				get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				if _container:
					close_container()
				elif _backpack:
					close_backpack()
				get_viewport().set_input_as_handled()

func open_backpack() -> void:
	if _backpack:
		return
	_backpack = BackpackScene.instantiate()
	add_child(_backpack)

func close_backpack() -> void:
	if _backpack:
		_backpack.queue_free()
		_backpack = null

func open_container(id: int) -> void:
	close_all()
	_container = ContainerScene.instantiate()
	_container.container_id = id
	add_child(_container)

func close_container() -> void:
	if _container:
		_container.queue_free()
		_container = null

func close_all() -> void:
	close_backpack()
	close_container()
