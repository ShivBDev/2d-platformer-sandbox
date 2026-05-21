extends CharacterBody2D


const RUN_SPEED = 350.0
const RUN_ACC = 1400.0
const RUN_STICK_THRESHOLD = 0.2
const IDLE_SPEED_THRESHOLD = 5.0
const GROUND_FRICTION = 700.0
const DRIFT_SPEED_MAX = RUN_SPEED + 25.0
const DRIFT_ACC = RUN_SPEED / 5.0
const JUMP_VELOCITY = -600.0

# State Mgmt
var stickDir = 0.0
var engineDelta = 0.0
var facingRight = true
@onready var sprite = $Sprite

func _ready():
	_jump_squat_last_frame_index = sprite.sprite_frames.frame_count("jump_squat") - 1

func _physics_process(delta):
	stickDir = Input.get_axis("Left", "Right")
	engineDelta = delta
	
	match sprite.animation:
		_:
			_default_phys_proc(delta)

func _default_phys_proc(delta):
	pass
	#if is_on_floor():
		#if stickDir > 0 : facingRight = true
		#elif stickDir < 0 : facingRight = false
		#else: pass
		#sprite.flip_h = not facingRight
		#
		#if stickDir:
			#sprite.play("run")
			#velocity.x = stickDir * RUN_SPEED
		#else:
			#sprite.play("idle")
			#velocity.x = move_toward(velocity.x, 0, GROUND_FRICTION)
		#
		#if Input.is_action_just_pressed("Jump"):
			#sprite.play("jump")
			#velocity.y = JUMP_VELOCITY
	#else:
		#velocity += get_gravity() * delta
		#velocity.x = move_toward(
			#velocity.x,
			#stickDir * DRIFT_SPEED_MAX,
			#DRIFT_ACC)
		#if velocity.y > 0:
			#sprite.play("fall")
	#move_and_slide()

func _apply_gravity(): velocity += get_gravity() * engineDelta
func _apply_ground_friction(): velocity.x = move_toward(velocity.x, 0, GROUND_FRICTION * engineDelta)
func _apply_run_speed(): velocity.x = move_toward(velocity.x, RUN_SPEED, RUN_ACC * engineDelta)

func _set_facing_dir():
	if stickDir > 0 : facingRight = true
	elif stickDir < 0 : facingRight = false
	else: pass
	sprite.flip_h = not facingRight

func _handle_jump_press():
	if Input.is_action_just_pressed("Jump"):
		sprite.play("jump_squat")

func _idle_state():
	if is_on_floor():
		_set_facing_dir()
		if abs(stickDir) > RUN_STICK_THRESHOLD:
			_apply_run_speed()
			sprite.play("run")
		else:
			_apply_ground_friction()
		_handle_jump_press()
	else:
		_apply_gravity()
		sprite.play("fall")

func _run_state():
	if is_on_floor():
		_set_facing_dir()
		if abs(stickDir) < RUN_STICK_THRESHOLD:
			_apply_ground_friction()
			sprite.play("idle")
		else:
			_apply_run_speed()
		_handle_jump_press()
	else:
		_apply_gravity()
		sprite.play("fall")

var _jump_squat_last_frame_index = 0
func _jump_squat_state():
	# Don't apply gravity, coyote time is handled by jump squat duration
	_apply_ground_friction()
	if sprite.frame == _jump_squat_last_frame_index:
		# Short hop if jump released during jump squat
		velocity.y = JUMP_VELOCITY if Input.is_action_pressed("Jump") else (JUMP_VELOCITY / 2.0)
		sprite.play("jump")

func _jump_state():
	if not is_on_floor():
		_apply_gravity()
		if velocity.y > 0:
			sprite.play("fall")
	else:
		_apply_ground_friction()
		sprite.play("idle")
