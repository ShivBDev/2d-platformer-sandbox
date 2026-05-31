extends Camera2D

const SCREEN_HEIGHT : float = 720.0 # Should Match Viewport height
@onready var player : Player = %Player

func _process(_delta: float) -> void:
	var y : float = absf(player.position.y)
	var expCamY : float = (floorf(y / SCREEN_HEIGHT) * SCREEN_HEIGHT) * -1.0
	if expCamY != position.y: position.y = expCamY
	pass
