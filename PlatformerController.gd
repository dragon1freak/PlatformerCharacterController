extends PlatformerControllerClass
class_name PlatformerController

export(NodePath) var PLAYER_SPRITE
onready var _sprite : Sprite = get_node(PLAYER_SPRITE) if PLAYER_SPRITE else $Sprite
export(NodePath) var ANIMATION_PLAYER
onready var _animation_player : AnimationPlayer = get_node(ANIMATION_PLAYER) if ANIMATION_PLAYER else $AnimationPlayer

export(String) var ACTION_UP : String = "up"
export(String) var ACTION_DOWN : String = "down"
export(String) var ACTION_LEFT : String = "left"
export(String) var ACTION_RIGHT : String = "right"
export(String) var ACTION_JUMP : String = "jump"
export(String) var ACTION_INTERACT : String = "interact"
export(String) var ACTION_ALT_MOVE : String = "alt_move"

export(bool) var JOYSTICK_MOVEMENT : bool = false

export(float, 0, 1000, 0.1) var ACCELERATION : float = 300
export(float, 0, 1000, 0.1) var MAX_SPEED : float = 50
export(float, 0, 1000, 0.1) var FRICTION : float = 200
export(float, 0, 1000, 0.1) var AIR_RESISTENCE : float
export(float, 0, 1000, 0.1) var JUMP_FORCE : float
export(float, 0, 1000, 0.1) var JUMP_CANCEL_FORCE : float
export(float, 0, 1000, 0.1) var GRAVITY : float
export(float, 0, 1, 0.01) var COYOTE_TIMER : float
export(float, 0, 1, 0.01) var JUMP_BUFFER_TIMER : float

enum {IDLE, WALK, JUMP, FALLING}
var state : int = IDLE
var can_jump : bool = true
var should_jump : bool = false
var jumping : bool = false


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

var motion : Vector2 = Vector2.ZERO
func _physics_process(delta : float) -> void:
	handle_inputs(delta)
	
	if !is_on_floor() && can_jump:
		coyote_time()
	if !jumping && motion.y < 0:
		cancel_jump(delta)
	motion.y += GRAVITY * delta
	motion = move_and_slide(motion, Vector2.UP)

func coyote_time() -> void:
	yield(get_tree().create_timer(COYOTE_TIMER),"timeout")
	can_jump = false

func buffer_jump() -> void:
	should_jump = true
	yield(get_tree().create_timer(JUMP_BUFFER_TIMER),"timeout")
	should_jump = false

func get_input_direction() -> Vector2:
	var x_dir = Input.get_action_strength(ACTION_RIGHT) - Input.get_action_strength(ACTION_LEFT)
	var y_dir = Input.get_action_strength(ACTION_DOWN) - Input.get_action_strength(ACTION_UP)

	return Vector2(x_dir if JOYSTICK_MOVEMENT else sign(x_dir), y_dir if JOYSTICK_MOVEMENT else sign(y_dir))

func handle_inputs(delta : float) -> void:
	var input_direction : Vector2 = get_input_direction()
	var jump_strength : float = Input.get_action_strength(ACTION_JUMP)
	var jump_pushed : bool = Input.is_action_just_pressed(ACTION_JUMP)
	var jump_released : bool = Input.is_action_just_released(ACTION_JUMP)
#	var interact_strength : float = Input.get_action_strength(ACTION_INTERACT)
#	var alt_move_strength : float = Input.get_action_strength(ACTION_ALT_MOVE)
	handle_jump(jump_strength, jump_pushed, jump_released)
	handle_motion(delta, input_direction)

func handle_motion(delta : float, input_direction : Vector2 = Vector2.ZERO) -> void:
	if input_direction.x != 0:
		apply_motion(input_direction, delta)
	else:
		apply_friction(delta)

func apply_motion(move_direction : Vector2, delta : float) -> void:
	if motion.x != 0 and sign(move_direction.x) != sign(motion.x):
		apply_friction(delta)
	motion.x += move_direction.x * ACCELERATION * delta
	motion.x = clamp(motion.x, -MAX_SPEED * abs(move_direction.x), MAX_SPEED * abs(move_direction.x))

func apply_friction(delta : float) -> void:
	var fric = FRICTION * delta * sign(motion.x) * -1 if is_on_floor() else AIR_RESISTENCE * delta * sign(motion.x) * -1
	motion.x += fric
	if abs(motion.x) < fric:
		motion.x = 0

func handle_jump(jump_strength : float = 0.0, jump_pressed : bool = false, jump_released : bool = false) -> void:
	if (jump_pressed or should_jump) && can_jump:
		apply_jump()
	elif jump_pressed:
		buffer_jump()
	elif jump_released:
		if motion.y < 0:
			jumping = false
	if is_on_floor():
		can_jump = true
		if should_jump:
			apply_jump()
			should_jump = false

enum JUMP_DIRECTIONS {UP = -1, DOWN}
func apply_jump(jump_force : float = JUMP_FORCE, jump_direction : int = JUMP_DIRECTIONS.UP) -> void:
	can_jump = false
	jumping = true
	motion.y += jump_force * jump_direction

func cancel_jump(delta: float, jump_direction : int = JUMP_DIRECTIONS.UP) -> void:
	motion.y -= JUMP_CANCEL_FORCE * jump_direction * delta
