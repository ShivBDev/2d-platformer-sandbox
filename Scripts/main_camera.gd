extends Camera2D
@onready var _player : Player = %Player

func _process(_delta: float) -> void:
	var y : float = absf(_player.position.y)
	var expCamY : float = (floorf(y / GameData.LEVEL_HEIGHT) * GameData.LEVEL_HEIGHT) * -1.0
	if expCamY != position.y: position.y = expCamY
	pass
