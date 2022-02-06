extends KinematicBody2D
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
export(bool) var CAN_SPRINT : bool = false
export(float, 0, 10, 0.1) var SPRINT_MULTIPLIER : float = 1.5

enum {IDLE, WALK, JUMP, FALL}
var state : int = IDLE
var can_jump : bool = false
var should_jump : bool = false
var jumping : bool = false
var can_ladder : bool = false

var motion : Vector2 = Vector2.ZERO
func _physics_process(delta : float) -> void:
	physics_tick(delta)
	timer(delta)

func physics_tick(delta : float) -> void:
	var inputs : Dictionary = handle_inputs(delta)
	handle_jump(inputs.jump_strength, inputs.jump_pushed, inputs.jump_released)
	handle_motion(delta, inputs.input_direction, inputs.sprint_strength)
	manage_animations()
	manage_state()
	
	if !is_on_floor() && can_jump:
		coyote_time()
	if !jumping && motion.y < 0 && !can_ladder:
		cancel_jump(delta)
	if !can_ladder:
		motion.y += GRAVITY * delta
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
	elif motion.x != 0:
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
func handle_inputs(delta : float) -> Dictionary:
	var input_direction : Vector2 = get_input_direction()
	var jump_strength : float = Input.get_action_strength(ACTION_JUMP)
	var jump_pushed : bool = Input.is_action_just_pressed(ACTION_JUMP)
	var jump_released : bool = Input.is_action_just_released(ACTION_JUMP)
	var sprint_strength : float = Input.get_action_strength(ACTION_SPRINT)
	
	return {input_direction = input_direction, jump_strength = jump_strength,
			jump_pushed = jump_pushed, jump_released = jump_released, sprint_strength = sprint_strength}

# Gets the X/Y axis movement direction using the input mappings assigned to the ACTION UP/DOWN/LEFT/RIGHT variables
func get_input_direction() -> Vector2:
	var x_dir = Input.get_action_strength(ACTION_RIGHT) - Input.get_action_strength(ACTION_LEFT)
	var y_dir = Input.get_action_strength(ACTION_DOWN) - Input.get_action_strength(ACTION_UP)

	return Vector2(x_dir if JOYSTICK_MOVEMENT else sign(x_dir), y_dir if JOYSTICK_MOVEMENT else sign(y_dir))

# ------------------ Movement Logic ---------------------------------
func handle_motion(delta : float, input_direction : Vector2 = Vector2.ZERO, sprint_strength : float = 0.0) -> void:
	if input_direction.x != 0:
		apply_motion(delta, input_direction, SPRINT_MULTIPLIER if sprint_strength > 0 else 1.0)
	else:
		apply_friction(delta)
	if input_direction.y != 0 && can_ladder:
		motion.y += input_direction.y * ACCELERATION * delta
		motion.y = clamp(motion.y, -MAX_SPEED * abs(input_direction.y), MAX_SPEED * abs(input_direction.y))
	elif can_ladder:
		motion.y = 0

func apply_motion(delta : float, move_direction : Vector2, sprint_strength : float) -> void:
	if motion.x != 0 and sign(move_direction.x) != sign(motion.x):
		apply_friction(delta)
	motion.x += move_direction.x * ACCELERATION * delta * (sprint_strength if is_on_floor() else 1)
	motion.x = clamp(motion.x, -MAX_SPEED * abs(move_direction.x) * sprint_strength, MAX_SPEED * abs(move_direction.x) * sprint_strength)

func apply_friction(delta : float) -> void:
	var fric = FRICTION * delta * sign(motion.x) * -1 if is_on_floor() else AIR_RESISTENCE * delta * sign(motion.x) * -1
	if abs(motion.x) <= abs(fric):
		motion.x = 0
	else:
		motion.x += fric

# ------------------ Jumping Logic ---------------------------------
func handle_jump(jump_strength : float = 0.0, jump_pressed : bool = false, jump_released : bool = false) -> void:
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
	jumping = true
	motion.y += jump_force * jump_direction
	$JumpSound.play()

func cancel_jump(delta : float, jump_direction : int = JUMP_DIRECTIONS.UP) -> void:
	motion.y -= JUMP_CANCEL_FORCE * jump_direction * delta

func buffer_jump() -> void:
	should_jump = true
	yield(get_tree().create_timer(JUMP_BUFFER_TIMER),"timeout")
	should_jump = false

func coyote_time() -> void:
	yield(get_tree().create_timer(COYOTE_TIMER),"timeout")
	can_jump = false



# ------ Extra -----
var score = 0
func score():
	score += floor(rand_range(5, 10))
	self.get_node("CanvasLayer/Control/Label").text = str(score)

var time = 100
var sum = 0.0
func timer(delta):
	sum += delta
	if sum >= 1.0:
		sum = 0.0
		time -= 1
		self.get_node("CanvasLayer/Control/Label2").text = str(time)
