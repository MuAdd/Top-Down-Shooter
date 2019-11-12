extends Spatial

const BULLET = preload("res://TopDownTwinStickController/Bullet.tscn")

export(NodePath) var PlayerPath  = "" #You must specify this in the inspector!
export(NodePath) var CameraPath  = ""
export(NodePath) var MeshInstancePath  = ""
export(float) var MovementSpeed = 15
export(float) var Acceleration = 3
export(float) var Deacceleration = 5
export(float) var MaxJump = 19
export(float) var RotationSpeed = 3
export(float) var MaxZoom = 0.5
export(float) var MinZoom = 1.5
export(float) var ZoomSpeed = 2

var Player
var Camera
var MeshInstance
var BulletPosition
var RayCast 
var InnerGimbal
var Direction = Vector3()
var LastDirection = Vector3()
var CameraRotation
var gravity = -10
var Accelerate = Acceleration
var Movement = Vector3()
var ZoomFactor = 1
var ActualZoom = 1
var Speed = Vector3()
var CurrentVerticalSpeed = Vector3()
var JumpAcceleration = 3
var IsAirborne = false
var Joystick_Deadzone = 0.2
var Mouse_Deadzone = 20

enum ROTATION_INPUT{MOUSE, JOYSTICK, MOVE_DIR}


func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)
	Player = get_node(PlayerPath)
	Camera = get_node(CameraPath)
	MeshInstance = get_node(MeshInstancePath)
	BulletPosition = MeshInstance.get_child(0)
	RayCast = get_node("/root/TestScene/RayCast")
	InnerGimbal =  $InnerGimbal

func _unhandled_input(event):
	
	#Rotation Mesh with Joystick
	if event is InputEventJoypadMotion :
		var horizontal = Input.get_action_strength("look_right") - Input.get_action_strength("look_left")
		var vertical = Input.get_action_strength("look_up") - Input.get_action_strength("look_back")
		if abs(horizontal) > Joystick_Deadzone or abs(vertical) > Joystick_Deadzone:
			rotateMesh(Vector2(horizontal,vertical), ROTATION_INPUT.JOYSTICK)
		else:
			#Rotate Mesh from last Moved Direction (Left joystick)
			rotateMesh(Speed,ROTATION_INPUT.MOVE_DIR)

	#Rotate Mesh with Mouse Motion
	elif event is InputEventMouseMotion:
		if magnitude(event.get_speed()) > Mouse_Deadzone: # or event is InputEventMouseButton:
			rotateMesh(event, ROTATION_INPUT.MOUSE)
			
		else:
			#Rotate Mesh from last Moved Direction (WASD Key presses)
			rotateMesh(Speed, ROTATION_INPUT.MOVE_DIR)

	#Rotate Mesh with Mouse Button Left
	elif event is InputEventMouseButton and event.get_button_index() == BUTTON_LEFT:
		rotateMesh(event, ROTATION_INPUT.MOUSE)

	#Zoom
	if event is InputEventMouseButton:
		match event.button_index:
			BUTTON_WHEEL_UP:
				ZoomFactor -= 0.05
			BUTTON_WHEEL_DOWN:
				ZoomFactor += 0.05
		ZoomFactor = clamp(ZoomFactor, MaxZoom, MinZoom)

	#Quit Game
	if event is InputEventKey and event.pressed:
		match event.scancode:
			KEY_ESCAPE:
				get_tree().quit()

func rotateMesh(event_data, input_method):
	match input_method:
		ROTATION_INPUT.MOUSE:
			#event_data is mouse position in viewport
			var rayLength = 100
			var from = Camera.project_ray_origin(event_data.position)
			var to = from + Camera.project_ray_normal(event_data.position)*rayLength
			RayCast.translation = from
			RayCast.cast_to = to
			RayCast.force_raycast_update()
			var collision_point = RayCast.get_collision_point()
			MeshInstance.look_at(collision_point,Vector3.UP)
			var rotationDegree = MeshInstance.get_rotation_degrees().y
			MeshInstance.set_rotation_degrees(Vector3(90,rotationDegree + 180,0))
		ROTATION_INPUT.JOYSTICK:
			#event_data is right joystick axis strength
			var rot = atan2(event_data.y,event_data.x)*180/PI
			rot += InnerGimbal.get_rotation_degrees().y 
			rot += 90
			MeshInstance.set_rotation_degrees(Vector3(90,rot,0))
		ROTATION_INPUT.MOVE_DIR:
			#event_data is directional vector to rotate player
			#Check if Player is moving and new movement is different than last direction
			if magnitude(event_data) > 0 and LastDirection.dot(event_data.normalized()) != 0:
				#Rotate in Direction of Movement
				var angle = atan2(event_data.x, event_data.z)
				var char_rot = MeshInstance.get_rotation()
				var rot_y = angle - char_rot.y  
				MeshInstance.rotate_y(rot_y)

#Helper math function
func magnitude(vector):
	if typeof(vector) == typeof(Vector2()):
		return sqrt(vector.x*vector.x + vector.y*vector.y)
	elif typeof(vector) == typeof(Vector3()):
		return sqrt(vector.x*vector.x + vector.z*vector.z)

func _process(delta):
	#Shoot
	if (Input.is_action_pressed("shoot")):
		var bullet = BULLET.instance()
		get_node("/root/").add_child(bullet)
		bullet.set_translation(BulletPosition.get_global_transform().origin)
		bullet.direction = BulletPosition.get_global_transform().basis.z
		
	#Jump
	if (Input.is_action_pressed("jump")) and not IsAirborne:
		CurrentVerticalSpeed = Vector3(0,MaxJump,0)
		IsAirborne = true

func _physics_process(delta):
	#Rotation[Camera]
	CameraRotation = RotationSpeed * delta
	if (Input.is_action_pressed("rotate_left")):
		InnerGimbal.rotate(Vector3.UP, CameraRotation)
	elif (Input.is_action_pressed("rotate_right")):
		InnerGimbal.rotate(Vector3.UP, -CameraRotation)
	
	#Movement
	var CameraTransform = Camera.get_global_transform()
	if(Input.is_action_pressed("move_up")):
		Direction += -CameraTransform.basis[2]
	if(Input.is_action_pressed("move_back")):
		Direction += CameraTransform.basis[2]
	if(Input.is_action_pressed("move_left")):
		Direction += -CameraTransform.basis[0]
	if(Input.is_action_pressed("move_right")):
		Direction += CameraTransform.basis[0]
	Direction.y = 0
	LastDirection = Direction.normalized()
	var MaxSpeed = MovementSpeed * Direction.normalized()
	Accelerate = Deacceleration
	if(Direction.dot(Speed) > 0):
		Accelerate = Acceleration
	Direction = Vector3.ZERO
	Speed = Speed.linear_interpolate(MaxSpeed, delta * Accelerate)
	Movement = Player.transform.basis * (Speed)
	Movement = Speed
	CurrentVerticalSpeed.y += gravity * delta * JumpAcceleration
	Movement += CurrentVerticalSpeed
	Player.move_and_slide(Movement,Vector3.UP)
	if Player.is_on_floor() :
		CurrentVerticalSpeed.y = 0
		IsAirborne = false
	
	#Zoom
	ActualZoom = lerp(ActualZoom, ZoomFactor, delta * ZoomSpeed)
	InnerGimbal.set_scale(Vector3(ActualZoom,ActualZoom,ActualZoom))
