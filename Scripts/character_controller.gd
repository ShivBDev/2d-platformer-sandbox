extends CharacterBody2D

#region consts
const RUN_SPEED = 350.0
const RUN_ACC = 2100.0
const RUN_STICK_THRESHOLD = 0.2
const IDLE_SPEED_THRESHOLD = 5.0
const GROUND_FRICTION = 1750.0
const REDUCED_FRICTION_FACTOR = 2.0

const DRIFT_SPEED = RUN_SPEED
const DRIFT_ACC = RUN_ACC / 10.0
const JUMP_VELOCITY = -250.0
const JUMP_ACC = -2500.0
const MAX_JUMP_TIME = 0.2 # in seconds
const COYOTE_TIME = 0.2 # in seconds
#endregion consts

#region state_management
var stickDir : float = 0.0
var engineDelta : float = 0.0
var facingRight : bool = true
var coyoteTimer : float = 0.0
@onready var sprite = $Sprite
#endregion state_management

#region control_flow
func _ready():
	_jump_squat_last_frame_index = sprite.sprite_frames.get_frame_count("jump_squat") - 1

func _physics_process(delta):
	stickDir = Input.get_axis("Left", "Right")
	engineDelta = delta
	
	var stateFn = Callable(self, "_%s_state" % [sprite.animation])
	if stateFn.is_valid(): stateFn.call()
	else: push_error("Character FSM Missing Func for: %s" % [sprite.animation])
	
	move_and_slide()

# Handle common tasks done before switching to a specific state.
func _switch_state(state: String):
	match state:
		"run": _apply_run_speed()
		"idle": _apply_ground_friction()
		"fall": _apply_gravity()
		"jump_squat": _apply_ground_friction(true) #apply reduced friction for jump squat
		"jump": velocity.y = JUMP_VELOCITY
		"jump", "fall": _apply_drift_speed()
		_: pass # Some states don't require anything extra
	sprite.play(state)
#endregion control_flow

#region helpers
# TODO: Seems like a simple function, but will later need to differentiate double jump and jump
func _handle_jump_press():
	if Input.is_action_just_pressed("Jump"):
		_switch_state("jump_squat")

func _handle_coyote_time():
	if is_on_floor():
		coyoteTimer = 0.0
		return
	if coyoteTimer >= COYOTE_TIME:
		return _switch_state("fall")
	coyoteTimer += engineDelta

func _apply_gravity():
	velocity += get_gravity() * engineDelta
func _apply_ground_friction(reducedFriction : bool = false):
	var friction = GROUND_FRICTION/REDUCED_FRICTION_FACTOR if reducedFriction else GROUND_FRICTION
	velocity.x = move_toward( velocity.x, 0, friction * engineDelta)
func _apply_run_speed():
	velocity.x = move_toward(velocity.x, RUN_SPEED * stickDir, RUN_ACC * engineDelta)
func _apply_drift_speed():
	velocity.x = move_toward(velocity.x, DRIFT_SPEED * stickDir, DRIFT_ACC * engineDelta)
func _set_facing_dir():
	if stickDir > 0 : facingRight = true
	elif stickDir < 0 : facingRight = false
	else: pass
	sprite.flip_h = not facingRight
#endregion helpers

#region states
func _idle_state():
	# by checking jump before floor check, we add 1 hidden frame of coyote time
	_handle_jump_press()
	_handle_coyote_time()
	if abs(stickDir) > RUN_STICK_THRESHOLD: return _switch_state("run")
	_set_facing_dir()
	_apply_ground_friction()

func _run_state():
	# by checking jump before floor check, we add 1 hidden frame of coyote time
	_handle_jump_press() 
	_handle_coyote_time()
	if abs(stickDir) < RUN_STICK_THRESHOLD: return _switch_state("idle")
	_set_facing_dir()
	_apply_run_speed()

var _jump_squat_last_frame_index = 0
func _jump_squat_state():
	if sprite.frame == _jump_squat_last_frame_index and not sprite.is_playing():
		return _switch_state("jump")
	# Don't apply gravity, coyote time is handled by jump squat duration
	# Apply reduced friction to keep momentum for jump
	_apply_ground_friction(true)

func _jump_state():
	if is_on_floor(): return _switch_state("idle")
	if velocity.y > 0: return _switch_state("fall")
	_set_facing_dir()
	_apply_drift_speed()
	_apply_gravity()

func _fall_state():
	if is_on_floor(): return _switch_state("idle")
	_set_facing_dir()
	_apply_drift_speed()
	_apply_gravity()
#endregion
