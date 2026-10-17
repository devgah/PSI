extends Camera3D
## Câmera orbital: arrastar = girar, roda = zoom contínuo.

var distance := 18.0
var yaw := 0.9
var pitch := 0.32
var target := Vector3.ZERO
var _dragging := false

const MIN_DIST := 2.5
const MAX_DIST := 140.0


func _ready() -> void:
	fov = 60.0
	current = true
	_apply()


func _process(_delta: float) -> void:
	_apply()


func _apply() -> void:
	var offset := Vector3(cos(pitch) * cos(yaw), sin(pitch), cos(pitch) * sin(yaw)) * distance
	global_position = target + offset
	look_at_from_position(global_position, target, Vector3.UP)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			distance = clampf(distance * 0.9, MIN_DIST, MAX_DIST)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			distance = clampf(distance * 1.1111, MIN_DIST, MAX_DIST)
	elif event is InputEventMouseMotion and _dragging:
		yaw -= event.relative.x * 0.005
		pitch = clampf(pitch + event.relative.y * 0.005, -1.5, 1.5)
