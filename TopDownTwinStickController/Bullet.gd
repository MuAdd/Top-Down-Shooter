extends MeshInstance

export(float) var PROJECTILE_SPEED = 1;
var direction 

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	var motion =  direction * PROJECTILE_SPEED
	translate(motion)


func _on_Timer_timeout():
	queue_free()
