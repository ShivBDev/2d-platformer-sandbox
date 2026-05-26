extends CharacterBody2D

#region consts
# SUBREGION Exported Variables, default values set here, can be updated in editor
@export_group("Character Controller Movement Values")
@export_subgroup("Grounded Values")
@export var RUN_SPEED				: float = 150.0
@export var RUN_ACC					: float = 900.0 # x6 Run Speed, hit max speed in 1/6 sec
@export var RUN_STICK_THRESHOLD		: float = 0.2
@export var IDLE_SPEED_THRESHOLD		: float = 5.0
@export var GROUND_FRICTION			: float = 750.0 # x5 Run Speed, hit 0 in 0.2 sec
@export_subgroup("Aerial Values")
@export var JUMP_VELOCITY			: float = -150.0
@export var JUMP_ACC					: float = -750.0
@export var MAX_JUMP_TIME			: float = 0.2 # in seconds
@export var DRIFT_SPEED				: float = 140.0
@export var DRIFT_ACC				: float = 280.0
@export_range(0.0, 0.5, 0.05, "suffix:Seconds") var COYOTE_TIME : float = 0.1
@export_subgroup("Misc Debug Settings")
@export_range(1.0, 3.0, 0.1) var JUMP_SQUAT_GRAVITY_DAMP : float = 1.5
# SUBREGION Calculated Variables, based on exported variable values
var REDUCED_FRICTION		: float = GROUND_FRICTION / 2.0
var REDUCED_GRAVITY		: Vector2 = get_gravity() / JUMP_SQUAT_GRAVITY_DAMP
#endregion consts

#region state_management
var _stickDir 	: float = 0.0
var _engineDelta 	: float = 0.0
var _facingRight 	: bool = true
var _coyoteTimer 	: float = 0.0
var _jumpTimer 	: float = 0.0
var _jump_squat_last_frame_index : int = 0
var _jump_held : bool = true
@onready var sprite	: AnimatedSprite2D = $Sprite
#endregion state_management

#region control_flow
func _ready() -> void:
	_jump_squat_last_frame_index = sprite.sprite_frames.get_frame_count("jump_squat") - 1

func _physics_process(delta: float) -> void:
	_stickDir = Input.get_axis("Left", "Right")
	_engineDelta = delta

	var stateFn = Callable(self, "_%s_state" % [sprite.animation])
	if stateFn.is_valid(): stateFn.call()
	else: push_error("Character FSM Missing Func for: %s" % [sprite.animation])

	move_and_slide()

## Handle common tasks done before switching to a specific state.
func _switch_state(state: String) -> void:
	match state:
		"run": _apply_run_speed()
		"idle": _apply_ground_friction()
		"fall": _apply_gravity()
		"jump_squat":
			_apply_ground_friction(true) #apply reduced friction for jump squat
			_jump_held = true
		"jump":
			velocity.y = JUMP_VELOCITY
			_jumpTimer = 0.0
		"jump", "fall": _apply_drift_speed()
		_: pass # Some states don't require anything extra
	sprite.play(state)
#endregion control_flow

#region helpers
# TODO: Seems like a simple function, but will later need to differentiate double jump and jump
func _handle_jump_press() -> void:
	if Input.is_action_just_pressed("Jump"):
		_switch_state("jump_squat")

func _handle_coyote_time() -> void:
	if is_on_floor():
		_coyoteTimer = 0.0
		return
	if _coyoteTimer >= COYOTE_TIME:
		return _switch_state("fall")
	_coyoteTimer += _engineDelta

## Gravity
func _apply_gravity(reduced : bool = false) -> void:
	var gravity : Vector2 = REDUCED_GRAVITY if reduced else get_gravity()
	velocity += gravity * _engineDelta
## Slowly reduce player movement
func _apply_ground_friction(reduced : bool = false) -> void:
	var friction : float = REDUCED_FRICTION if reduced else GROUND_FRICTION
	velocity.x = move_toward( velocity.x, 0, friction * _engineDelta)
## Applies lateral run speed (on ground)
func _apply_run_speed() -> void:
	velocity.x = move_toward(velocity.x, RUN_SPEED * _stickDir, RUN_ACC * _engineDelta)
## Applies lateral drift speed (in air)
func _apply_drift_speed() -> void:
	velocity.x = move_toward(velocity.x, DRIFT_SPEED * _stickDir, DRIFT_ACC * _engineDelta)
## One way toggle from true to false for _jump_held
func _handle_jump_hold_check():
	_jump_held = Input.is_action_pressed("Jump") if _jump_held else false
## Track facing direction for sprites
func _set_facing_dir() -> void:
	_facingRight = _facingRight if _stickDir == 0 else _stickDir > 0
	# TODO: Have independent sprites for left and right facing?
	sprite.flip_h = not _facingRight
#endregion helpers

#region states
func _idle_state() -> void:
	# by checking jump before floor check, we add 1 hidden frame of coyote time
	_handle_jump_press()
	_handle_coyote_time()
	if abs(_stickDir) > RUN_STICK_THRESHOLD: return _switch_state("run")
	_set_facing_dir()
	_apply_ground_friction()

func _run_state() -> void:
	# by checking jump before floor check, we add 1 hidden frame of coyote time
	_handle_jump_press()
	_handle_coyote_time()
	if absf(_stickDir) < RUN_STICK_THRESHOLD: return _switch_state("idle")
	_set_facing_dir()
	_apply_run_speed()

func _jump_squat_state() -> void:
	if sprite.frame == _jump_squat_last_frame_index and not sprite.is_playing():
		return _switch_state("jump")
	# Apply reduced friction and gravity to keep momentum and height for jump
	_apply_ground_friction(true)
	_apply_gravity(true)
	_handle_jump_hold_check()

func _jump_state() -> void:
	if is_on_floor(): return _switch_state("idle")
	if velocity.y > 0: return _switch_state("fall")
	_handle_jump_hold_check()
	if _jump_held and _jumpTimer <= MAX_JUMP_TIME:
		_jumpTimer += _engineDelta
		velocity.y += JUMP_ACC * _engineDelta
	_set_facing_dir()
	_apply_drift_speed()
	_apply_gravity()

func _fall_state() -> void:
	if is_on_floor(): return _switch_state("idle")
	_set_facing_dir()
	_apply_drift_speed()
	_apply_gravity()
#endregion
