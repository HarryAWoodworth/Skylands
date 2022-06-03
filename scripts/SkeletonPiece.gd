extends RigidBody2D

# 0 -> 5
const MAX_FRAMES := 5
const grav := 9.0
const wait := 15.0
const bnc := 0.5
const frctn := 1.0

func init(frame: int, position_: Vector2, velocity_ : Vector2) -> void:
	if frame > MAX_FRAMES:
		print("ERROR: MAX FRAMES IS ", MAX_FRAMES, ", ATTEMPTING TO SET FRAME TO: ", frame)
		frame = MAX_FRAMES
	if frame < 0:
		print("ERROR: MIN FRAMES IS 0, ATTEMPTING TO SET FRAME TO: ", frame)
		frame = 0
	$Sprite.frame = frame
	position = position_
	linear_velocity = velocity_
	gravity_scale = grav
	weight = wait
	bounce = bnc
	friction = frctn
	$Sprite.visible = true
	
