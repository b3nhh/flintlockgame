extends CharacterBody3D

#Player vars
@onready var head = $Neck/Head
@onready var std_collision_shape: CollisionShape3D = $std_collision_shape
@onready var crc_collision_shape: CollisionShape3D = $crc_collision_shape
@onready var ray_cast_3d: RayCast3D = $RayCast3D
@onready var neck: Node3D = $Neck
@onready var camera_3d: Camera3D = $Neck/Head/Eyes/Camera3D
@onready var eyes: Node3D = $Neck/Head/Eyes
@onready var gun_anim: AnimationPlayer = $Neck/Head/Eyes/Camera3D/Rifle/AnimationPlayer
@onready var gun_barrel: Node3D = $Neck/Head/Eyes/Camera3D/Rifle/RayCast3D
@onready var player_body: CharacterBody3D = $"."



#speed vars
#if speed isent declared as float then the whole games lowkey breaks idk why
var speed: float
const WALKING_SPEED = 5.0
const SPRINTING_SPEED = 8.0
const CROUCHING_SPEED = 1.0

#Movement vars
const JUMP_VELOCITY = 4.5
var lerp_speed = 10.0
#player control in air
var air_lerp_speed = 3.0
var crouching_depth = -0.5
var freelook_tilt = 8
var input_dir = Vector2.ZERO

#input vars
var mouse_sens = 0.25
const CAMERA_LIMMIT = 89
const FREELOOK_LIM = 120
var direction = Vector3.ZERO

#states
var walking = false
var sprinting = false
var crouching = false
var freelooking = false
var sliding = false
var launched = false

#sliding vars
var slide_timer = 0.0
var slide_timer_max = 1.0
var slide_vector = Vector2.ZERO
var slide_speed = 10.0

#headbobing vars
const HEAD_SPRINTING_SPEED = 22.0
const HEAD_WALKING_SPEED = 14.0
const HEAD_CROUCHING_SPEED = 10.0
const SPRINTING_INTENSITY = 0.3
const WALKING_INTENSITY = 0.2
const CROUCHING_INTENSITY = 0.1
var curr_head_intensity = 0.0
var head_vector = Vector2.ZERO
var t_bob = 0.0

#gun vars
@onready var canShoot = true
var bullet = load("res://Scenes/Bullet.tscn")
var instance
var launch_strength = 20.0

#physics vars
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)



func _crouching(delta):
	speed = lerp(speed, CROUCHING_SPEED, delta*lerp_speed)
	#smooth crouch
	head.position.y = lerp(head.position.y, crouching_depth, delta * lerp_speed)
	#snappy crouch
	#head.position.y = 1.8 + crouching_depth
	std_collision_shape.disabled = true
	crc_collision_shape.disabled = false
	
	#slide begining logic
	if sprinting && input_dir != Vector2.ZERO:
		sliding = true
		freelooking = true
		slide_timer = slide_timer_max
		slide_vector = input_dir
		print("slide start")
	walking = false
	sprinting = false
	crouching = true
	
func _uncrouching(delta):
	std_collision_shape.disabled = false
	crc_collision_shape.disabled = true
	#smooth uncrouch
	head.position.y = lerp(head.position.y, 0.0, delta * lerp_speed)
	#snappy uncrouch
	#head.position.y = 1.8
	
func _sprinting(delta):
	speed = lerp(speed, SPRINTING_SPEED, delta * lerp_speed)
	walking = false
	sprinting = true
	crouching = false
	
func _walking(delta):
	speed = lerp(speed, WALKING_SPEED, delta*lerp_speed)
	walking = true
	sprinting = false
	crouching = false

func _sliding(delta):
	if sliding:
		slide_timer -= delta
		if slide_timer <= 0:
			sliding = false
			freelooking = false
			print("slide end")

func _handle_freelook(delta):
	if Input.is_action_pressed("freelook") || sliding:
		freelooking = true
		
		#slightly tilts camera when sliding 
		if sliding:
			camera_3d.rotation.z = lerp(-deg_to_rad(2.0), camera_3d.rotation.z, delta * lerp_speed)
		else:
			camera_3d.rotation.z = -deg_to_rad(neck.rotation.y*freelook_tilt)
	else:
		freelooking = false
		neck.rotation.y = lerp(neck.rotation.y, 0.0, delta * lerp_speed)
		camera_3d.rotation.z = lerp(camera_3d.rotation.z, 0.0, delta * lerp_speed)

func _bobing(delta):
	if sprinting:
		curr_head_intensity = SPRINTING_INTENSITY
		t_bob += SPRINTING_INTENSITY * delta
	elif walking:
		curr_head_intensity = WALKING_INTENSITY
		t_bob += WALKING_INTENSITY * delta
	elif crouching:
		curr_head_intensity = CROUCHING_INTENSITY
		t_bob += CROUCHING_INTENSITY * delta
	
	if is_on_floor() && !sliding && input_dir != Vector2.ZERO:
		head_vector.y = sin(t_bob)
		head_vector.x = sin(t_bob/2) + 0.5
		
		eyes.position.y = lerp(eyes.position.y, head_vector.y * (curr_head_intensity/2.0), delta * lerp_speed)
		eyes.position.x = lerp(eyes.position.x, head_vector.x * curr_head_intensity, delta * lerp_speed)
	else: 
		eyes.position.y = lerp(eyes.position.y, 0.0, delta * lerp_speed)
		eyes.position.x = lerp(eyes.position.x, 0.0, delta * lerp_speed)

func _input(event):
	if event is InputEventMouseMotion:
		if freelooking:
			neck.rotate_y(deg_to_rad(-event.relative.x * mouse_sens))
			neck.rotation.y = clamp(neck.rotation.y, deg_to_rad(-FREELOOK_LIM), deg_to_rad(FREELOOK_LIM))
		else:
			rotate_y(deg_to_rad(-event.relative.x * mouse_sens))
		head.rotate_x(deg_to_rad(-event.relative.y * mouse_sens))
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-CAMERA_LIMMIT), deg_to_rad(CAMERA_LIMMIT))
	


func _physics_process(delta: float) -> void:
	#getting movement 
	input_dir = Input.get_vector("left", "right", "up", "down")
	
	if Input.is_action_pressed("crouch") || sliding:
		_crouching(delta)
	elif !ray_cast_3d.is_colliding():
		_uncrouching(delta)
		if Input.is_action_pressed("sprint"):
			_sprinting(delta)
		else:
			_walking(delta)
	
	_handle_freelook(delta)
	_sliding(delta)
	
	if Input.is_action_pressed("shoot"):
		if !gun_anim.is_playing() and canShoot:
			gun_anim.play("Shoot")
			instance = bullet.instantiate()
			instance.position = gun_barrel.global_position
			instance.transform.basis = gun_barrel.global_transform.basis
			#brooks solution 
			var playerLaunchDirZ = player_body.global_transform.basis.z 
			
			velocity += playerLaunchDirZ * launch_strength
			get_parent().add_child(instance)
			canShoot = false
			
			await get_tree().create_timer(1.0).timeout
			canShoot = true
	
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		sliding = false
		
	# Get the input direction and handle the movement/deceleration.
	#Smooth movement
	if is_on_floor():
		direction = lerp(direction, (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized(), delta*lerp_speed)
	else:
		if input_dir != Vector2.ZERO:
			direction = lerp(direction, (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized(), delta*air_lerp_speed)
	#Snappy instant movement 
	#direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if sliding:
		direction = (transform.basis * Vector3(slide_vector.x, 0, slide_vector.y)).normalized()
		speed = (slide_timer + 0.1) * slide_speed
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
		
	

	move_and_slide()
