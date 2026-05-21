extends CharacterBody2D


const RUN_SPEED = 350.0
const GROUND_FRICTION = 50.0
const DRIFT_SPEED_MAX = RUN_SPEED + 25.0
const DRIFT_ACC = RUN_SPEED / 5.0
const JUMP_VELOCITY = -600.0
var facingRight = true
@onready var sprite = $Sprite

func _default_phys_proc(delta):
	# Get the input direction and handle the movement/deceleration.
	var direction = Input.get_axis("Left", "Right")
	
	if is_on_floor():
		if direction > 0 : facingRight = true
		elif direction < 0 : facingRight = false
		else: pass
		sprite.flip_h = not facingRight
		
		if direction:
			sprite.play("run")
			velocity.x = direction * RUN_SPEED
		else:
			sprite.play("idle")
			velocity.x = move_toward(velocity.x, 0, GROUND_FRICTION)
		
		if Input.is_action_just_pressed("Jump"):
			sprite.play("jump")
			velocity.y = JUMP_VELOCITY
	else:
		velocity += get_gravity() * delta
		velocity.x = move_toward(
			velocity.x,
			direction * DRIFT_SPEED_MAX,
			DRIFT_ACC)
		if velocity.y > 0:
			sprite.play("fall")


	move_and_slide()


func _physics_process(delta):
	match sprite.animation:
		_:
			_default_phys_proc(delta)
