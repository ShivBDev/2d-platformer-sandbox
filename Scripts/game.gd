extends Node

const gameWorld : String = "uid://cn6gs7ljy7631"
@onready var World : Node2D
var _game_loaded : bool

@onready var GUI : Control = $GUI
@onready var Splash : Control = $GUI/SplashScreen

const SPLASH_SCREEN_DUR = 5.0
var _splash_screen_timer : float = 0.0

func _ready() -> void:
	_game_loaded = false
	_splash_screen_timer = 0.0
	ResourceLoader.load_threaded_request(gameWorld)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	# Keep the splash screen up while stuff loads
	if _splash_screen_timer < SPLASH_SCREEN_DUR:
		_splash_screen_timer += _delta
		return
	if not _game_loaded and \
	ResourceLoader.load_threaded_get_status(gameWorld) == \
	ResourceLoader.ThreadLoadStatus.THREAD_LOAD_LOADED:
		var worldResource = ResourceLoader.load_threaded_get(gameWorld)
		var world2D = worldResource.instantiate()
		World = world2D
		add_child(world2D)
		_game_loaded = true
		GUI.remove_child(Splash)

	pass
