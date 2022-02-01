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

export(float, 0, 1000, 0.1) var ACCELERATION : float
export(float, 0, 1000, 0.1) var MAX_SPEED : float
export(float, 0, 1000, 0.1) var FRICTION : float
export(float, 0, 1000, 0.1) var AIR_RESISTENCE : float
export(float, 0, 1000, 0.1) var JUMP_FORCE : float
export(float, 0, 1000, 0.1) var GRAVITY : float

enum {IDLE, WALK, JUMP, FALLING}
var state : int = IDLE


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func _physics_process(delta : float) -> void:
	var input_direction : Vector2 = get_input_direction()
	apply_motion(input_direction, delta)

func get_input_direction() -> Vector2:
	var x_dir = Input.get_action_strength(ACTION_RIGHT) - Input.get_action_strength(ACTION_LEFT)
	var y_dir = Input.get_action_strength(ACTION_DOWN) - Input.get_action_strength(ACTION_UP)

	return Vector2(x_dir if JOYSTICK_MOVEMENT else sign(x_dir), y_dir if JOYSTICK_MOVEMENT else sign(y_dir))

var motion : Vector2 = Vector2.ZERO
func apply_motion(move_direction : Vector2, delta : float) -> void:
	if move_direction.x != 0:
		if motion.x != 0 and sign(move_direction.x) != sign(motion.x):
			apply_friction(delta)
		motion.x += move_direction.x * ACCELERATION * delta
		motion.x = clamp(motion.x, -MAX_SPEED * abs(move_direction.x), MAX_SPEED * abs(move_direction.x))
	if move_direction.x == 0 and motion.x != 0:
		apply_friction(delta)
	
	motion.y += GRAVITY * delta
	motion = move_and_slide(motion, Vector2.UP)

func apply_friction(delta : float) -> void:
#	motion.x = lerp(motion.x, 0, FRICTION * delta)
	motion.x += FRICTION * delta * 1 if sign(motion.x) == -1 else -1
	if abs(motion.x) < 1:
		motion.x = 0
	print(motion.x)
