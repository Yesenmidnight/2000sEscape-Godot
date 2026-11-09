extends Control
## 街道小地图：两条路线 + 节点 + 玩家标记（数据由 street.gd 每帧同步）

var lane_name := ""
var step := 0
var token_world := Vector3.ZERO

const WORLD_X0 := -7.2
const WORLD_X1 := 8.4
const MAP_X0 := 14.0
const MAP_X1 := 216.0
const LANE_MY := {"大街": 46.0, "小巷": 86.0}

func _map_x(wx: float) -> float:
	return MAP_X0 + (wx - WORLD_X0) / (WORLD_X1 - WORLD_X0) * (MAP_X1 - MAP_X0)

func _draw() -> void:
	# 半透明底板
	draw_rect(Rect2(Vector2(4, 8), Vector2(226, 116)), Color(0.04, 0.05, 0.09, 0.72))
	draw_rect(Rect2(Vector2(4, 8), Vector2(226, 116)), Color(0.4, 0.45, 0.6, 0.5), false, 1.0)
	# 两条路线
	for lane in LANE_MY:
		var pts := PackedVector2Array()
		for i in range(6):
			pts.append(Vector2(_map_x(-6.0 + i * 2.4), LANE_MY[lane]))
		var active: bool = lane == lane_name
		draw_polyline(pts, Color(0.45, 0.5, 0.7, 0.95) if active else Color(0.22, 0.25, 0.36, 0.7), 2.0)
		# 节点
		for i in range(6):
			var arrived: bool = lane == lane_name and i <= step
			var p := Vector2(_map_x(-6.0 + i * 2.4), LANE_MY[lane])
			draw_circle(p, 4.0, Color(0.2, 0.9, 0.55) if arrived else Color(0.3, 0.32, 0.45))
	# 玩家标记
	var tp := Vector2(_map_x(token_world.x), LANE_MY.get(lane_name, 66.0))
	draw_circle(tp, 6.0, Color("00ff88"))
	draw_arc(tp, 8.0, 0.0, TAU, 24, Color(0, 1, 0.6, 0.6), 2.0)
	# 标签
	draw_string(ThemeDB.fallback_font, Vector2(12, 26), "路线图", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.7, 0.75, 0.9))
