extends CharacterBody3D

var speed
const WALK_SPEED = 8.0
const SPRINT_SPEED = 8.0
const JUMP_VELOCITY = 4.5
const SENSITIVITY = 0.002
const HIT_STAGGER = 8.0

#bob variables
const BOB_FREQ = 2.4
const BOB_AMP = 0.08
var t_bob = 0.0

#fov variables
const BASE_FOV = 75.0
const FOV_CHANGE = 1.5

# signal
signal player_hit

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = 9.8

# Bullets
var bullet = load("res://Scenes/Bullet.tscn")
var instance
@onready var canShoot = true

var impulseStrength = 10

@onready var head_node = $Head
@onready var gun_anim = $Head/Camera3D/Rifle/AnimationPlayer
@onready var gun_barrel = $Head/Camera3D/Rifle/RayCast3D
@onready var gun_anim2 = $Head/Camera3D/Rifle2/AnimationPlayer
@onready var gun_barrel2 = $Head/Camera3D/Rifle2/RayCast3D

# Camera look and mouse variables
@onready var head = $Head/Camera3D # Head node for recoil
var mouse_input : bool = false 			# Check mouse movement
var rotation_input : float				# Rotation in X
var tilt_input : float					# Rotation in Y
	# Rotation Variables
var mouse_rotation : Vector3
var player_rotation : Vector3
var camera_rotation : Vector3
	# Export Variables
@export var MOUSE_SENSITIVITY = 0.5					# Mouse sensitivity
@export var TILT_UPPER_LIMIT = deg_to_rad(90)		# Upper tilt limit
@export var TILT_LOWER_LIMIT = deg_to_rad(-90.0)	# Lower tilt limit
@export var CAMERA_CONTROLLER = Camera3D			# Assigned camera

var target_rotation: Vector3
var smooth_rotation: Vector3
var mouse_sensitivity = 0.01


func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event):
	if event is InputEventMouseMotion:
		target_rotation.x -= event.relative.y * mouse_sensitivity
		target_rotation.x = clamp(target_rotation.x, rad_to_deg(-80), deg_to_rad(50))
		target_rotation.y -= event.relative.x * mouse_sensitivity
	## If both conditions are met, which means that the input event is a mouse movement and the mouse mode is captured.
	#mouse_input = event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	#
	#if mouse_input:
		#rotation_input = -event.relative.x * MOUSE_SENSITIVITY		# Rotation in X
		#tilt_input = -event.relative.y * MOUSE_SENSITIVITY			# Rotation in Y

func _update_camera(delta):
	smooth_rotation = smooth_rotation.lerp(target_rotation, delta * 10)
	rotation = smooth_rotation



func _input(event):
	# Exit Option
	if event.is_action_pressed("exit"):
		get_tree().quit()

func _walk():
	if Input.is_action_just_pressed("sprint") and is_on_floor():
		speed = SPRINT_SPEED
	else:
		speed = WALK_SPEED
		
func _jump():
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

func _physics_process(delta):
	_update_camera(delta)
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta
	# Handle Jump.
	_jump()
	# Handle Sprint.
	_walk()

	# Get the input direction and handle the movement/deceleration.
	var input_dir = Input.get_vector("left", "right", "up", "down")
	var direction = (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if is_on_floor():
		if direction:
			velocity.x = lerp(velocity.x, direction.x * speed, delta * 15.0)
			velocity.z = lerp(velocity.z, direction.z * speed, delta * 15.0) 	
		else:
			velocity.x = lerp(velocity.x, direction.x * speed, delta * 7.0)
			velocity.z = lerp(velocity.z, direction.z * speed, delta * 7.0)
	else:
		velocity.x = lerp(velocity.x, direction.x * speed, delta * 3.0)
		velocity.z = lerp(velocity.z, direction.z * speed, delta * 3.0)
	
	# Head bob
	#t_bob += delta * velocity.length() * float(is_on_floor())
	#head.transform.origin = _headbob(t_bob)
	
	# FOV
	#var velocity_clamped = clamp(velocity.length(), 0.5, SPRINT_SPEED * 2)
	#var target_fov = BASE_FOV + FOV_CHANGE * velocity_clamped
	#head.fov = lerp(head.fov, target_fov, delta * 8.0)
	
	# Shooting
	if Input.is_action_pressed("shoot"):
		if !gun_anim.is_playing() and canShoot:
			gun_anim.play("Shoot")
			instance = bullet.instantiate()
			instance.position = gun_barrel.global_position
			instance.transform.basis = gun_barrel.global_transform.basis
			#brooks solution 
			var playerLaunchDirZ = head.global_transform.basis.z 
			
			velocity += playerLaunchDirZ * impulseStrength
			get_parent().add_child(instance)
			canShoot = false
			
			await get_tree().create_timer(1.0).timeout
			canShoot = true
			
		
		
	
	move_and_slide()

func setCanShoot():
	canShoot = true

func _headbob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	pos.x = cos(time * BOB_FREQ / 2) * BOB_AMP
	return pos


func hit(dir):
	emit_signal("player_hit")
	velocity += dir * HIT_STAGGER
