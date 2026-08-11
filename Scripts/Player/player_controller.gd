extends CharacterBody3D

@onready var head = $Head
@onready var camera = $Head/Camera3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

@export var mouse_sensitivity := 0.003
var pitch := 0.0

@export_group("Movement Speeds")
@export var walk_speed := 8.0
@export var sprint_speed := 13.0
@export var crouch_speed := 3.5
@export var crouch_sprint_speed := 5.5

@export_group("Movement Feel")
@export var acceleration := 45.0     # ground speed ramp-up, in m/s^2
@export var friction := 55.0         # ground speed ramp-down when no input, in m/s^2
@export var air_control_multiplier := 0.85  # CoD-style: keep most of your control in the air

@export_group("Jump")
@export var jump_velocity := 6.5
@export var gravity_multiplier := 2.2       # snappier, less floaty than real-world gravity
@export var fall_gravity_multiplier := 1.4  # extra pull on the way down, on top of gravity_multiplier

@export_group("Crouch")
@export var stand_height := 2.0
@export var crouch_height := 1.2
@export var crouch_transition_speed := 6.0

@export_group("Slide")
@export var slide_min_speed := 6.0    # minimum horizontal speed required to trigger a slide
@export var slide_speed_boost := 1.0   # multiplies your speed into the slide for a bit of a burst
@export var slide_friction := 18.0     # m/s^2 — gentler than normal friction, a Prey (2017)-style tactical slide
@export var slide_buffer_time := 0.2   # seconds a mid-air crouch press is remembered for, so landing still slides

var is_crouching := false
var is_sprinting := false
var is_sliding := false
var slide_buffer_remaining := 0.0
var crouch_amount := 0.0
var stand_head_y: float


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	stand_head_y = head.position.y


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		pitch = clamp(pitch - event.relative.y * mouse_sensitivity, -PI / 2, PI / 2)
		head.rotation.x = pitch


func _physics_process(delta: float) -> void:
	# Add the gravity, falling faster than rising so the jump doesn't float at the apex.
	if not is_on_floor():
		var gravity_scale := gravity_multiplier * (fall_gravity_multiplier if velocity.y < 0.0 else 1.0)
		velocity += get_gravity() * gravity_scale * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	if Input.is_action_just_pressed("crouch"):
		if is_crouching:
			is_crouching = false
			is_sliding = false
		elif is_on_floor():
			if not _try_start_slide():
				is_crouching = true
		else:
			slide_buffer_remaining = slide_buffer_time  # remember the press; resolve it once we land

	if slide_buffer_remaining > 0.0:
		slide_buffer_remaining -= delta
		if is_on_floor():
			if not _try_start_slide():
				is_crouching = true
			slide_buffer_remaining = 0.0

	if is_sliding and not is_on_floor():
		is_sliding = false
	_update_crouch(delta)

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("left", "right", "forward", "backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	is_sprinting = Input.is_action_pressed("sprint") and direction != Vector3.ZERO

	if is_sliding:
		var horizontal := Vector3(velocity.x, 0, velocity.z)
		var horizontal_speed := horizontal.length()
		var new_speed := move_toward(horizontal_speed, 0.0, slide_friction * delta)
		if horizontal_speed > 0.001:
			horizontal = horizontal.normalized() * new_speed
		velocity.x = horizontal.x
		velocity.z = horizontal.z
		if new_speed <= crouch_speed:
			is_sliding = false
	else:
		var speed := walk_speed
		if is_crouching:
			speed = crouch_sprint_speed if is_sprinting else crouch_speed
		elif is_sprinting:
			speed = sprint_speed

		var accel_rate := acceleration if is_on_floor() else acceleration * air_control_multiplier
		var friction_rate := friction if is_on_floor() else friction * air_control_multiplier

		if direction:
			velocity.x = move_toward(velocity.x, direction.x * speed, accel_rate * delta)
			velocity.z = move_toward(velocity.z, direction.z * speed, accel_rate * delta)
		else:
			velocity.x = move_toward(velocity.x, 0, friction_rate * delta)
			velocity.z = move_toward(velocity.z, 0, friction_rate * delta)

	move_and_slide()


## Kicks off a slide if moving fast enough while sprinting; returns false
## (letting the caller fall back to a normal crouch) otherwise.
func _try_start_slide() -> bool:
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if not is_sprinting or not is_on_floor() or horizontal_speed < slide_min_speed:
		return false

	is_crouching = true
	is_sliding = true
	var boosted := Vector3(velocity.x, 0, velocity.z).normalized() * horizontal_speed * slide_speed_boost
	velocity.x = boosted.x
	velocity.z = boosted.z
	return true


func _update_crouch(delta: float) -> void:
	var target := 1.0 if is_crouching else 0.0
	crouch_amount = move_toward(crouch_amount, target, crouch_transition_speed * delta)

	var capsule := collision_shape.shape as CapsuleShape3D
	capsule.height = lerp(stand_height, crouch_height, crouch_amount)
	collision_shape.position.y = lerp(0.0, (crouch_height - stand_height) / 2.0, crouch_amount)
	head.position.y = lerp(stand_head_y, stand_head_y - (stand_height - crouch_height), crouch_amount)
