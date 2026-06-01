extends CharacterBody2D
class_name Player

#DEBUG_TOOL god mode impl
const __godMode = "_god_mode"
const __godModeSpeed = 500.0
@onready var __playerCollider: CollisionShape2D = $PlayerCollider
func __handle_god_mode() -> void:
	if not Input.is_action_just_pressed("GodModeToggle"): return
	if sprite.animation == __godMode:
		print("Exiting God Mode")
		__playerCollider.disabled = false
		hurtbox.disabled = false
		return _switch_state("idle")
	print("Entering God Mode")
	__playerCollider.disabled = true
	hurtbox.disabled = true
	return _switch_state(__godMode)
func __god_mode_state() -> void:
	_set_facing_dir()
	var verticalInput : float = Input.get_axis("Down", "Up")
	var inputVec : Vector2 = Vector2(_stickDir, -verticalInput).normalized()
	velocity = inputVec * __godModeSpeed
#DEBUG_TOOL end god mode impl

#region consts
# SUBREGION Exported Variables, default values set here, can be updated in editor
@export_group("Character Controller Movement Values")
@export_subgroup("Grounded Values")
@export var RUN_SPEED				: float = 200.0
@export var RUN_ACC					: float = 500.0
@export var RUN_STICK_THRESHOLD		: float = 0.2
@export var IDLE_SPEED_THRESHOLD		: float = 5.0
@export var GROUND_FRICTION			: float = 1000.0
@export_subgroup("Aerial Values")
@export var JUMP_VELOCITY			: float = -150.0
@export var JUMP_ACC					: float = -1500.0
@export var MAX_JUMP_TIME			: float = 0.2 # in seconds
@export var DRIFT_SPEED				: float = 190.0
@export var DRIFT_ACC				: float = 160.0
@export_range(0.0, 0.5, 0.05, "suffix:Seconds") var COYOTE_TIME : float = 0.1
@export_subgroup("Interaction Values")
@export var KNOCKBACK_STRENGTH		: float = 300
@export var BOUNCE_STRENGTH			: float = -350
@export_subgroup("Misc Physics Settings")
@export var MAX_FALL_SPEED						: float = 1000.0
@export var MAX_WALL_HOLD_FALL_SPEED 			: float = 100.0
@export var MAX_WALL_HOLD_INIT_UPWARD_SPEED 		: float = -100.0
@export var WALL_HOLD_DRIFT_SPEED				: float = 5.0
@export var WALL_HOLD_LATERAL_SPEED_THRESHOLD 	: float = 50.0
@export var WALL_HOLD_LOCKOUT_TIME				: float = 0.2
@export_range(0.0, 2.0, 0.05) var WALL_JUMP_LATERAL_SPEED_SCALE		: float = 1.0
@export_range(0.0, 1.0, 0.05) var WALL_HOLD_GRAVITY_SCALE				: float = 0.25
@export_range(0.0, 1.0, 0.05) var JUMP_SQUAT_GRAVITY_SCALE			: float = 0.5
@export_range(0.0, 1.0, 0.05) var JUMP_SQUAT_GROUND_FRICTION_SCALE	: float = 0.5
@export_range(1.0, 5.0, 0.1) var LANDING_GROUND_FRICTION_SCALE		: float = 1.5
@export_range(0.0, 0.5, 0.05, "suffix:Seconds") var KNOCKDOWN_LOCKOUT : float = 0.2
#endregion consts

#region state_management
# SUBREGION Engine Data
var _stickDir 		: float = 0.0
var _engineDelta 	: float = 0.0
# SUBREGION Player Info
var _facingRight 	: bool = true
var _jump_held 		: bool = true
var _disable_turn 	: bool = false
var _wall_to_right 	: bool = true
var _prev_frame_vel : Vector2 = Vector2.ZERO
# SUBREGION timers
var _coyoteTimer 	: float = 0.0
var _jumpTimer 		: float = 0.0
var _wall_hold_lockout_timer : float = 0.0
var _knock_down_lockout_timer : float = 0.0
# SUBREGION Anim Info
var _jump_last_frame_index : int = 0
var _jump_squat_last_frame_index : int = 0
var _landing_anim_last_frame_index : int = 0
var _down_air_anim_last_frame_index : int = 0
@onready var sprite	: AnimatedSprite2D = $Sprite
@onready var hitbox: CollisionShape2D = $EnvColliders/Hitbox/HitboxShape
@onready var hurtbox: CollisionShape2D = $EnvColliders/Hurtbox/HurtboxShape
@onready var upward_raycast: RayCast2D = $EnvColliders/UpwardRaycast
#endregion state_management

#region control_flow
func _ready() -> void:
	_jump_last_frame_index = \
		sprite.sprite_frames.get_frame_count("jump") - 1
	_jump_squat_last_frame_index = \
		sprite.sprite_frames.get_frame_count("jump_squat") - 1
	_landing_anim_last_frame_index = \
		sprite.sprite_frames.get_frame_count("landing") - 1
	_down_air_anim_last_frame_index = \
		sprite.sprite_frames.get_frame_count("down_air") - 1

func _physics_process(delta: float) -> void:
	_stickDir = Input.get_axis("Left", "Right")
	_engineDelta = delta

	__handle_god_mode() #DEBUG_TOOL enable god mode check

	var stateFn = Callable(self, "_%s_state" % [sprite.animation])
	if stateFn.is_valid(): stateFn.call()
	else: push_error("Character FSM Missing Func for: %s" % [sprite.animation])

	_prev_frame_vel = velocity
	move_and_slide()

## Handle common tasks done before switching to a specific state.
func _switch_state(state: String) -> void:
	match state:
		"run": _apply_run_speed()
		"idle": _apply_ground_friction()
		"fall":
			_coyoteTimer = 0.0
			if _disable_turn : _disable_turn = false
		"jump_squat":
			_apply_ground_friction(JUMP_SQUAT_GROUND_FRICTION_SCALE)
			_jump_held = true
		"jump":
			velocity.y = JUMP_VELOCITY
			_jumpTimer = 0.0
		"jump", "fall": _apply_drift_speed()
		"landing":
			_apply_ground_friction(LANDING_GROUND_FRICTION_SCALE)
		"wall_hold":
			if velocity.y < 0 : velocity.y = maxf(velocity.y, MAX_WALL_HOLD_INIT_UPWARD_SPEED)
			elif velocity.y > 0 : velocity.y = minf(velocity.y, MAX_WALL_HOLD_FALL_SPEED)
		"down_air":
			if _disable_turn : _disable_turn = false
			hitbox.disabled = false
			hurtbox.disabled = true
		_: pass # Some states don't require anything extra
	sprite.play(state)
#endregion control_flow

#region helpers
func _handle_attack_press() -> bool:
	if not Input.is_action_just_pressed("Attack"): return false
	_switch_state("down_air")
	return true

func _handle_jump_press() -> bool:
	if not Input.is_action_just_pressed("Jump"): return false
	_wall_hold_lockout_timer = 0.0
	if is_on_floor() and velocity.y >= 0:
		_switch_state("jump_squat")
		return true
	_jump_held = true # allow variable jump height for coyote/wall jumps
	if is_on_wall():
		var dir : float = -1.0 if _wall_to_right else 1.0
		velocity.x = absf(JUMP_VELOCITY) * WALL_JUMP_LATERAL_SPEED_SCALE * dir
		_disable_turn = false
		_set_facing_dir(false)
		_disable_turn = true
	_switch_state("jump")
	return true

func _handle_wall_hold_check() -> bool:
	if _wall_hold_lockout_timer < WALL_HOLD_LOCKOUT_TIME :
		_wall_hold_lockout_timer += _engineDelta
		return false
	if is_on_wall():
		var wallN : Vector2 = get_wall_normal()
		if absf(wallN.x) < 0.8 : return false
		_wall_to_right = true if wallN.x < 0 else false
		if _wall_to_right:
			if Input.is_action_pressed("Right") or \
			_prev_frame_vel.x > WALL_HOLD_LATERAL_SPEED_THRESHOLD:
				_switch_state("wall_hold")
				return true
		else:
			if Input.is_action_pressed("Left") or \
			_prev_frame_vel.x < -WALL_HOLD_LATERAL_SPEED_THRESHOLD:
				_switch_state("wall_hold")
				return true
	return false


## Gravity
func _apply_gravity(
gravityScale : float = 1.0,
maxFallSpeed : float = MAX_FALL_SPEED) -> void:
	var gravity : Vector2 = get_gravity() * gravityScale * _engineDelta
	velocity += gravity
	velocity.y = minf(maxFallSpeed, velocity.y)
## Slowly reduce player movement
func _apply_ground_friction(frictionScale : float = 1.0) -> void:
	var friction : float = GROUND_FRICTION * frictionScale * _engineDelta
	velocity.x = move_toward(velocity.x, 0, friction)
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
func _set_facing_dir(stickBased:bool = true) -> void:
	if _disable_turn: return
	if stickBased:
		_facingRight = _facingRight if _stickDir == 0 else _stickDir > 0
	else:
		_facingRight = velocity.x > 0
	# TODO: Have independent sprites for left and right facing?
	sprite.flip_h = not _facingRight
#endregion helpers

#region states
func _idle_state() -> void:
	# by checking jump before floor check, we add 1 hidden frame of coyote time
	if _handle_jump_press() : return
	if not is_on_floor(): return _switch_state("fall")
	if absf(_stickDir) > RUN_STICK_THRESHOLD: return _switch_state("run")
	_set_facing_dir()
	_apply_ground_friction()

func _run_state() -> void:
	# by checking jump before floor check, we add 1 hidden frame of coyote time
	if _handle_jump_press(): return
	if not is_on_floor(): return _switch_state("fall")
	if absf(_stickDir) < RUN_STICK_THRESHOLD: return _switch_state("idle")
	_set_facing_dir()
	_apply_run_speed()

func _jump_squat_state() -> void:
	if sprite.frame == _jump_squat_last_frame_index and not sprite.is_playing():
		return _switch_state("jump")
	# Apply reduced friction and gravity to keep momentum and height for jump
	_apply_ground_friction(JUMP_SQUAT_GROUND_FRICTION_SCALE)
	_apply_gravity(JUMP_SQUAT_GRAVITY_SCALE)
	_handle_jump_hold_check()

func _jump_state() -> void:
	if is_on_floor() and velocity.y >= 0: return _switch_state("landing")
	if _handle_wall_hold_check(): return
	if velocity.y > 0: return _switch_state("fall")
	_handle_jump_hold_check()
	if _jump_held and _jumpTimer <= MAX_JUMP_TIME:
		_jumpTimer += _engineDelta
		velocity.y += JUMP_ACC * _engineDelta
	if _handle_attack_press(): return
	_set_facing_dir()
	_apply_drift_speed()
	_apply_gravity()

func _fall_state() -> void:
	if is_on_floor() and velocity.y >= 0: return _switch_state("landing")
	if _handle_wall_hold_check(): return
	if _handle_attack_press(): return
	_set_facing_dir()
	_apply_drift_speed()
	#coyote time!
	if _coyoteTimer < COYOTE_TIME:
		_coyoteTimer += _engineDelta
		if _handle_jump_press(): return
	else:
		_apply_gravity()

func _wall_hold_state() -> void:
	if is_on_floor(): return _switch_state("idle")
	if not is_on_wall(): return _switch_state("fall")
	if _handle_jump_press(): return
	_set_facing_dir()
	_apply_drift_speed()
	_apply_gravity(WALL_HOLD_GRAVITY_SCALE, MAX_WALL_HOLD_FALL_SPEED)
	#apply subtle drift into wall
	var dir : float = 1.0 if _wall_to_right else -1.0
	velocity.x += WALL_HOLD_DRIFT_SPEED * _engineDelta * dir

func _landing_state() -> void:
	if sprite.frame == _landing_anim_last_frame_index and not sprite.is_playing():
		return _switch_state("idle")
	_apply_ground_friction(LANDING_GROUND_FRICTION_SCALE)

func _down_air_state() -> void:
	if is_on_floor() and velocity.y >= 0:
		hitbox.disabled = true
		hurtbox.disabled = false
		return _switch_state("landing")
	var frame : int = sprite.frame
	if frame == _down_air_anim_last_frame_index and not sprite.is_playing():
		hitbox.disabled = true
		hurtbox.disabled = false
		_switch_state("fall" if velocity.y >=0 else "jump")
		sprite.frame = 0 if velocity.y >=0 else _jump_last_frame_index
	_apply_drift_speed()
	_apply_gravity()

func _knocked_down_state() -> void:
	if _knock_down_lockout_timer < KNOCKDOWN_LOCKOUT:
		_knock_down_lockout_timer += _engineDelta
	elif is_on_floor(): return _switch_state("landing")
	_apply_gravity()
	pass
#endregion

# Signals
func _on_hurtbox_body_entered(_body: Node2D) -> void:
	var xdir : float
	if velocity.x != 0: xdir = -1.0 if velocity.x > 0 else 1.0
	else : xdir = -1.0 if _facingRight else 1.0
	var ydir : float = -1.0
	if upward_raycast.is_colliding() : ydir = 1.0
	var knockbackDir : Vector2 = Vector2(xdir, ydir).normalized()
	velocity = knockbackDir * KNOCKBACK_STRENGTH
	_knock_down_lockout_timer = 0.0
	_switch_state("knocked_down")
	pass # Replace with function body.

func _on_hitbox_body_entered(_body: Node2D) -> void:
	_jump_held = false
	velocity.y = BOUNCE_STRENGTH
	print("You hit Spike!")
	pass # Replace with function body.
