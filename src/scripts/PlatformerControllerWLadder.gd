extends KinematicBody2D
class_name PlatformerControllerWLadder

export(NodePath) var PLAYER_SPRITE
onready var _sprite : Sprite = get_node(PLAYER_SPRITE) if PLAYER_SPRITE else $Sprite
export(NodePath) var ANIMATION_PLAYER
onready var _animation_player : AnimationPlayer = get_node(ANIMATION_PLAYER) if ANIMATION_PLAYER else $AnimationPlayer
export(NodePath) var CAMERA
onready var _camera : Camera2D = get_node(CAMERA) if CAMERA else $Camera2D
export(bool) var LIMIT_CAMERA : bool = true
export(NodePath) var TILEMAP_PATH

export(String) var ACTION_UP : String = "up"
export(String) var ACTION_DOWN : String = "down"
export(String) var ACTION_LEFT : String = "left"
export(String) var ACTION_RIGHT : String = "right"
export(String) var ACTION_JUMP : String = "jump"
export(String) var ACTION_SPRINT : String = "sprint"

export(bool) var JOYSTICK_MOVEMENT : bool = false

export(float, 0, 1000, 0.1) var ACCELERATION : float = 500
export(float, 0, 1000, 0.1) var MAX_SPEED : float = 100
export(float, 0, 1000, 0.1) var FRICTION : float = 500
export(float, 0, 1000, 0.1) var AIR_RESISTENCE : float = 200
export(float, 0, 1000, 0.1) var JUMP_FORCE : float = 200
export(float, 0, 1000, 0.1) var JUMP_CANCEL_FORCE : float = 800
export(float, 0, 1000, 0.1) var GRAVITY : float = 500
export(float, 0, 1, 0.01) var COYOTE_TIMER : float = 0.08
export(float, 0, 1, 0.01) var JUMP_BUFFER_TIMER : float = 0.1
export(bool) var ENABLE_SPRINT : bool = false
export(float, 0, 10, 0.1) var SPRINT_MULTIPLIER : float = 1.5

enum {IDLE, WALK, JUMP, FALL}
var state : int = IDLE

onready var can_sprint : bool = ENABLE_SPRINT
var sprinting : bool = false
var can_jump : bool = false
var should_jump : bool = false
var jumping : bool = false
var can_ladder : bool = false
var laddering : bool = false

func _ready() -> void:
	if LIMIT_CAMERA && _camera:
		var tilemap = get_node(TILEMAP_PATH)
		var tilemap_rect = tilemap.get_used_rect()
		_camera.limit_left = tilemap_rect.position.x * tilemap.cell_size.x
		_camera.limit_top = tilemap_rect.position.y * tilemap.cell_size.y
		_camera.limit_right = _camera.limit_left + tilemap_rect.size.x * tilemap.cell_size.x
		_camera.limit_bottom = _camera.limit_top + tilemap_rect.size.y * tilemap.cell_size.y

var motion : Vector2 = Vector2.ZERO
func _physics_process(delta : float) -> void:
	physics_tick(delta)

func physics_tick(delta : float) -> void:
	var inputs : Dictionary = handle_inputs()
	handle_jump(inputs.jump_strength, inputs.jump_pressed, inputs.jump_released)
	handle_sprint(inputs.sprint_strength)
	handle_motion(delta, inputs.input_direction)
	manage_animations()
	manage_state()
	
	if !jumping && motion.y < 0 && !can_ladder:
		cancel_jump(delta)
	if !can_ladder:
		laddering = false
	if !laddering:
		motion.y += GRAVITY * delta
	if !laddering && !is_on_floor() && can_jump:
		coyote_time()
	motion = move_and_slide(motion, Vector2.UP)

func manage_state() -> void:
	if motion.y == 0:
		if motion.x == 0:
			state = IDLE
		else:
			state = WALK
	elif motion.y < 0:
		state = JUMP
	else:
		state = FALL

func manage_animations() -> void:
	if motion.x > 0:
		_sprite.flip_h = false
	elif motion.x < 0:
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

# Gets the strength and status of the mapped actions and passes them to the handle_motion and handle_jump methods
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
func handle_motion(delta : float, input_direction : Vector2 = Vector2.ZERO) -> void:
	if input_direction.x != 0:
		apply_motion(delta, input_direction, SPRINT_MULTIPLIER if sprinting  else 1.0)
	else:
		apply_friction(delta)
	if input_direction.y != 0 && can_ladder:
		laddering = true
		can_jump = true
		motion.y += input_direction.y * ACCELERATION * delta
		motion.y = clamp(motion.y, -MAX_SPEED * abs(input_direction.y), MAX_SPEED * abs(input_direction.y))
	elif laddering:
		motion.y = 0

func apply_motion(delta : float, move_direction : Vector2, sprint_strength : float) -> void:
	if motion.x != 0 and sign(move_direction.x) != sign(motion.x):
		apply_friction(delta)
	motion.x += move_direction.x * ACCELERATION * delta * (sprint_strength if is_on_floor() else 1.0)
	motion.x = clamp(motion.x, -MAX_SPEED * abs(move_direction.x) * sprint_strength, MAX_SPEED * abs(move_direction.x) * sprint_strength)

func apply_friction(delta : float) -> void:
	var fric = FRICTION * delta * sign(motion.x) * -1 if is_on_floor() else AIR_RESISTENCE * delta * sign(motion.x) * -1
	if abs(motion.x) <= abs(fric):
		motion.x = 0
	else:
		motion.x += fric

func handle_sprint(sprint_strength : float) -> void:
	if sprint_strength != 0 and can_sprint:
		sprinting = true
	else:
		sprinting = false

# ------------------ Jumping Logic ---------------------------------
func handle_jump(jump_strength : float = 0.0, jump_pressed : bool = false, _jump_released : bool = false) -> void:
	if (jump_pressed or should_jump) && can_jump:
		apply_jump()
	elif jump_pressed:
		buffer_jump()
	elif jump_strength == 0 and motion.y < 0:
		jumping = false
	if is_on_floor() and motion.y >= 0:
		can_jump = true

enum JUMP_DIRECTIONS {UP = -1, DOWN}
func apply_jump(jump_force : float = JUMP_FORCE, jump_direction : int = JUMP_DIRECTIONS.UP) -> void:
	can_jump = false
	should_jump = false
	laddering = false
	jumping = true
	motion.y += jump_force * jump_direction

func cancel_jump(delta : float, jump_direction : int = JUMP_DIRECTIONS.UP) -> void:
	motion.y -= JUMP_CANCEL_FORCE * jump_direction * delta

func buffer_jump() -> void:
	should_jump = true
	yield(get_tree().create_timer(JUMP_BUFFER_TIMER),"timeout")
	should_jump = false

func coyote_time() -> void:
	yield(get_tree().create_timer(COYOTE_TIMER),"timeout")
	can_jump = false
