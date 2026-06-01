extends VisibleOnScreenEnabler2D
var lvl_idx = 0

func _ready() -> void:
	position.y = lvl_idx * GameData.LEVEL_HEIGHT * -1
