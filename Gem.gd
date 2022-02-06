extends Area2D


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func getgot():
	$CollisionShape2D.set_deferred("disabled", true)
	$Sprite.visible = false
	$AudioStreamPlayer2D.play()
	print($CollisionShape2D.disabled)
	yield(get_tree().create_timer(10),"timeout")
	enable()

func enable():
	$CollisionShape2D.set_deferred("disabled", false)
	$Sprite.visible = true

func _on_Gem_body_entered(body):
	if body.name == "Player":
		body.score()
		self.getgot()
