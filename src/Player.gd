extends PlatformerController


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

var old_state

# Called when the node enters the scene tree for the first time.
func _ready():
	old_state = self.state

func _process(delta):
	if old_state != self.state:
		print(self.state)
		old_state = self.state


