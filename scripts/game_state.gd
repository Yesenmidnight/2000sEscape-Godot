extends Node
## GameState —— 迁移自 ESC_Core.GameState，按报亭循环重组：
## 天数 / 回忆货币 / 玩家背包 / 存档 / 场景流转方向

const SAVE_PATH := "user://save.json"

var day := 1
var memory_coins := 0
var travel := "to_work" # street 场景的方向参数: to_work / to_home
var player_inventory: GridInventory

func _ready() -> void:
	player_inventory = GridInventory.new(6, 5) # 6列x5行，与原版默认一致

func new_game() -> void:
	day = 1
	memory_coins = 0
	player_inventory.restore({"cols": 6, "rows": 5, "items": []})
	ContainerManager.reset_all()

func go_to_sleep() -> void:
	day += 1
	save_game()

func add_coins(v: int) -> void:
	memory_coins += v

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game() -> void:
	var data := {
		"day": day,
		"coins": memory_coins,
		"backpack": player_inventory.serialize(),
		"containers": ContainerManager.serialize_all(),
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		print("[GameState] 已存档: ", SAVE_PATH)

func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	if data == null:
		return false
	day = int(data.get("day", 1))
	memory_coins = int(data.get("coins", 0))
	player_inventory.restore(data.get("backpack", {}))
	ContainerManager.restore_all(data.get("containers", {}))
	return true
