extends Node2D

# BASE
# [ ] Skeleton Death Shatter

# GENERATION
# [ ] Gen islands
# [ ] Gen skeletons
#    [ ] Test idle head turn
# [ ] Fall effect

# ITEMS
# [ ] Pick up items
# [ ] Throw items
# [ ] Boxes
#   [ ] Gen boxes
#   [ ] Break boxes
#     [ ] Break effect
#   [ ] Spawn items

# AUDIO
# [ ] Music
# [ ] Sound Effects

# Skeleton piece
const skeleton_piece = preload("res://scenes/SkeletonPiece.tscn")

const DEBUG := true
const SKELETON_PIECE_SPEED := 500

func _process(_delta):
	if DEBUG and Input.is_action_just_pressed("debug"):
		$Actors/Skeleton.queue_free()
		$Player.gain_health(1)

func _ready():
	randomize()
	for actor in $Actors.get_children():
		actor.connect("skeleton_died", self, "_on_skeleton_death")
	var heartsNum = $CanvasLayer/Healthbar.get_children().size()
	$Player.init(heartsNum, heartsNum, $PlayerSpawnOrigin.position)
	for actor in $Actors.get_children():
		actor.init($Player)

# When a skeleton dies, shoot out pieces at random directions
func _on_skeleton_death(pos: Vector2) -> void:
	for i in range(0,6):
		var skeleton_piece_instance = skeleton_piece.instance()
		# Use call_deffered to avoid lag spike
		call_deferred("add_child_to_skeleton_pieces", skeleton_piece_instance)
		skeleton_piece_instance.init(i, pos, _random_velocity())

func add_child_to_skeleton_pieces(piece: Node) -> void:
	$SkeletonPieces.add_child(piece)

func _random_velocity() -> Vector2:
	return Vector2(SKELETON_PIECE_SPEED,0).rotated((randf() * PI) + PI)

func _on_Area2D_body_entered(body):
	if body.name == "Player":
		body.position = $PlayerSpawnOrigin.position
	else: 
		body.queue_free()

func _on_Player_playerHealthUpdate(newHealth: int):
	$CanvasLayer/Healthbar.updateHealthBar(newHealth)

func _on_Player_playerDied():
	pass # Replace with function body.
