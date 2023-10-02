extends CharacterBody2D
class_name PlatformerController

# The path to the character's Sprite node, defaults to 'get_node("Sprite")'
@export_node_path("Sprite2D") var PLAYER_SPRITE
@onready var _sprite : Sprite2D = get_node(PLAYER_SPRITE) if PLAYER_SPRITE else $Sprite2D

# The path to the character's AnimationPlayer node, defaults to 'get_node("AnimationPlayer")'
@export_node_path("AnimationPlayer") var ANIMATION_PLAYER
@onready var _animation_player : AnimationPlayer = get_node(ANIMATION_PLAYER) if ANIMATION_PLAYER else $AnimationPlayer

# Input Map actions related to each movement direction, jumping, and sprinting.  Set each to their related
# action's name in your Input Mapping or create actions with the default names.
@export var ACTION_UP : String = "up"
@export var ACTION_DOWN : String = "down"
@export var ACTION_LEFT : String = "left"
@export var ACTION_RIGHT : String = "right"
@export var ACTION_JUMP : String = "jump"
@export var ACTION_SPRINT : String = "sprint"

# Enables/Disables hard movement when using a joystick.  When enabled, slightly moving the joystick
# will only move the character at a percentage of the maximum acceleration and speed instead of the maximum.
@export var JOYSTICK_MOVEMENT : bool = false

# The following float values are in px/sec when used in movement calculations with 'delta'
# How fast the character gets to the MAX_SPEED value
@export_range(0, 1000, 0.1) var ACCELERATION : float = 500
# The overall cap on the character's speed
@export_range(0, 1000, 0.1) var MAX_SPEED : float = 100
# The speed of the character while sliding on a wall
@export_range(0, 1000, 0.1) var WALL_SLIDE_SPEED : float = 50
# How fast the character's speed goes back to zero when not moving
@export_range(0, 1000, 0.1) var FRICTION : float = 500
# How fast the character's speed goes back to zero when not moving in the air
@export_range(0, 1000, 0.1) var AIR_RESISTENCE : float = 200
# The speed of the jump when leaving the ground
@export_range(0, 1000, 0.1) var JUMP_FORCE : float = 200
# How fast the character's vertical speed goes back to zero when cancelling a jump
@export_range(0, 1000, 0.1) var JUMP_CANCEL_FORCE : float = 800
# The speed of gravity applied to the character
@export_range(0, 1000, 0.1) var GRAVITY : float = 500

# How long in seconds after walking off a platform the character can still jump, set this to zero to disable it
@export_range(0, 1, 0.01) var COYOTE_TIMER : float = 0.08
# How long in seconds before landing should the game still accept the Jump command, set this to zero to disable it
@export_range(0, 1, 0.01) var JUMP_BUFFER_TIMER : float = 0.1

# Enable/Disable sprinting
@export var ENABLE_SPRINT : bool = false
# Enable/Disable Wall Jumping
@export var ENABLE_WALL_JUMPING : bool = true
# Sprint multiplier, multiplies the MAX_SPEED by this value when sprinting
@export_range(0, 10, 0.1) var SPRINT_MULTIPLIER : float = 1.5

# The four possible character states and the character's current state
enum {IDLE, WALK, JUMP, FALL, WALL_SLIDE}
var state : int = IDLE

# The player can sprint when can_sprint is true
@onready var can_sprint : bool = ENABLE_SPRINT
# The player can wall jump when can_wall_jump is true
@onready var can_wall_jump : bool = ENABLE_WALL_JUMPING
# The player is sprinting when sprinting is true
var sprinting : bool = false
# The player can jump when can_jump is true
var can_jump : bool = false
# The player should jump when landing if should_jump is true, this is used for the jump_buffering
var should_jump : bool = false
# The player will execute a wall jump if can_wall_jump is true and the last call of move_and_slide was only colliding with a wall.
var wall_jump: bool = false
# The player is jumping when jumping is true
var jumping : bool = false

func _physics_process(delta : float) -> void:
	physics_tick(delta)

# Overrideable physics process used by the controller that calls whatever functions should be called
# and any logic that needs to be done on the _physics_process tick
func physics_tick(delta : float) -> void:
	var inputs : Dictionary = handle_inputs()
	handle_jump(delta, inputs.input_direction, inputs.jump_strength, inputs.jump_pressed, inputs.jump_released)
	handle_sprint(inputs.sprint_strength)
	handle_velocity(delta, inputs.input_direction)
	manage_animations()
	manage_state()

	velocity.y += GRAVITY * delta
	if !is_on_floor() && can_jump:
		coyote_time()
	move_and_slide()

# Manages the character's current state based on the current velocity vector
func manage_state() -> void:
	if velocity.y == 0:
		if velocity.x == 0:
			state = IDLE
		else:
			state = WALK
	elif velocity.y < 0:
			state = JUMP
	else:
		if can_wall_jump && is_on_wall_only():
			state = WALL_SLIDE
		else:
			state = FALL

# Manages the character's animations based on the current state and sprite direction based on
# the current horizontal velocity
func manage_animations() -> void:
	if velocity.x > 0:
		_sprite.flip_h = false
	elif velocity.x < 0:
		_sprite.flip_h = true
	match state:
		IDLE:
			_animation_player.play("Idle")
		WALK:
			_animation_player.play("Walk")
		JUMP:
			_animation_player.play("Jump")
		FALL:
			_animation_player.play("Fall")
		WALL_SLIDE:
			_animation_player.play("Fall") # TODO: possibly animation for wall slide, imo it looks fine as the falling one

# Gets the strength and status of the mapped actions
func handle_inputs() -> Dictionary:
	return {
		input_direction = get_input_direction(),
		jump_strength = Input.get_action_strength(ACTION_JUMP),
		jump_pressed = Input.is_action_just_pressed(ACTION_JUMP),
		jump_released = Input.is_action_just_released(ACTION_JUMP),
		sprint_strength = Input.get_action_strength(ACTION_SPRINT) if ENABLE_SPRINT else 0.0}

# Gets the X/Y axis movement direction using the input mappings assigned to the ACTION UP/DOWN/LEFT/RIGHT variables
func get_input_direction() -> Vector2:
	var x_dir = Input.get_action_strength(ACTION_RIGHT) - Input.get_action_strength(ACTION_LEFT)
	var y_dir = Input.get_action_strength(ACTION_DOWN) - Input.get_action_strength(ACTION_UP)

	return Vector2(x_dir if JOYSTICK_MOVEMENT else sign(x_dir), y_dir if JOYSTICK_MOVEMENT else sign(y_dir))

# ------------------ Movement Logic ---------------------------------
# Takes delta and the current input direction and either applies the movement or applies friction
func handle_velocity(delta : float, input_direction : Vector2 = Vector2.ZERO) -> void:
	if input_direction.x != 0:
		apply_velocity(delta, input_direction)
	else:
		apply_friction(delta)

# Applies velocity in the current input direction using the ACCELERATION, MAX_SPEED, and SPRINT_MULTIPLIER
func apply_velocity(delta : float, move_direction : Vector2) -> void:
	if velocity.x != 0 and sign(move_direction.x) != sign(velocity.x):
		apply_friction(delta)

	if can_wall_jump && state == WALL_SLIDE && !jumping:
		velocity.y = WALL_SLIDE_SPEED

	var sprint_strength = SPRINT_MULTIPLIER if sprinting else 1.0
	velocity.x += move_direction.x * ACCELERATION * delta * (sprint_strength if is_on_floor() else 1.0)
	velocity.x = clamp(velocity.x, -MAX_SPEED * abs(move_direction.x) * sprint_strength, MAX_SPEED * abs(move_direction.x) * sprint_strength)

# Applies friction to the horizontal axis when not moving using the FRICTION and AIR_RESISTENCE values
func apply_friction(delta : float) -> void:
	var fric = FRICTION * delta * sign(velocity.x) * -1 if is_on_floor() else AIR_RESISTENCE * delta * sign(velocity.x) * -1
	if abs(velocity.x) <= abs(fric):
		velocity.x = 0
	else:
		velocity.x += fric

# Sets the sprinting variable according to the strength of the sprint input action
func handle_sprint(sprint_strength : float) -> void:
	if sprint_strength != 0 and can_sprint:
		sprinting = true
	else:
		sprinting = false

# ------------------ Jumping Logic ---------------------------------
# Takes delta and the jump action status and strength and handles the jumping logic
func handle_jump(delta : float, move_direction : Vector2, jump_strength : float = 0.0, jump_pressed : bool = false, _jump_released : bool = false) -> void:
	if (jump_pressed or should_jump) && can_jump:
		apply_jump(move_direction)
	elif jump_pressed:
		buffer_jump()
	elif jump_strength == 0 and velocity.y < 0:
		cancel_jump(delta)
	elif can_wall_jump && !is_on_floor() && is_on_wall_only():
		can_jump = true
		wall_jump = true
		jumping = false
	if is_on_floor() and velocity.y >= 0:
		can_jump = true
		wall_jump = false
		jumping = false

# The values for the jump direction, default is UP or -1
enum JUMP_DIRECTIONS {UP = -1, DOWN = 1}
# Applies a jump force to the character in the specified direction, defaults to JUMP_FORCE and JUMP_DIRECTIONS.UP
# but can be passed a new force and direction
func apply_jump(move_direction : Vector2, jump_force : float = JUMP_FORCE, jump_direction : int = JUMP_DIRECTIONS.UP) -> void:
	can_jump = false
	should_jump = false
	jumping = true
	if (wall_jump):
		# Jump away from the direction the character is currently facing
		velocity.x += jump_force * -move_direction.x
		wall_jump = false
		velocity.y = 0
	velocity.y += jump_force * jump_direction

# If jump is released before reaching the top of the jump the jump is cancelled using the JUMP_CANCEL_FORCE and default
func cancel_jump(delta : float) -> void:
	jumping = false
	velocity.y -= JUMP_CANCEL_FORCE * sign(velocity.y) * delta

# If jump is pressed before hitting the ground, it's buffered using the JUMP_BUFFER_TIMER value and the jump is applied
# if the character lands before the timer ends
func buffer_jump() -> void:
	should_jump = true
	await get_tree().create_timer(JUMP_BUFFER_TIMER).timeout
	should_jump = false

# If the character steps off of a platform, they are given an amount of time in the air to still jump using the COYOTE_TIMER value
func coyote_time() -> void:
	await get_tree().create_timer(COYOTE_TIMER).timeout
	can_jump = false
