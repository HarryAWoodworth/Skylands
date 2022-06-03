extends KinematicBody2D

signal skeleton_died(position)

export var speed: int = 1200
export var jump_speed: int = -1800
export var gravity: int = 4000
export (float, 0, 1.0) var friction = 0.1
export (float, 0, 1.0) var acceleration = 0.25
export var health := 5
export var damage := 1

# Debug flag
const DEBUG := false
# Threshold for jumping due to skeleton height offset
const HEIGHT_THRESHOLD := 5
# Only run towards the player if they are at least this distance
const RUN_THRESHOLD := 25

var velocity := Vector2.ZERO
var followingPlayer := false
var player: Node
var hit_pos: Array
var laser_color := Color(1,0,0)
var playerClose = false
var knockback := 0
var knockbackPower := Vector2.ZERO
var weapon_knockback_power := 200
var death_knockback_power := 800

var state := -1
var playerInAttackRange := false

enum { IDLE, IDLE_SIT, IDLE_TURN, RUNNING, JUMPING, FALLING, ATTACKING, HURTING }

# Set physics to stop so init can happen
func _ready():
	set_physics_process(false)

# init with target node and resume physics process
func init(target: Node):
	player = target
	set_physics_process(true)
	if randi() % 2:
		setState(IDLE)
	else:
		setState(IDLE_SIT)

func _draw():
	if DEBUG:
		for hit in hit_pos:
			draw_circle((hit - position).rotated(-rotation), 5, laser_color)
			draw_line(Vector2(), (hit - position).rotated(-rotation), laser_color)

func _physics_process(delta):
	if DEBUG: update()

#	if playerInAttackRange:
#		if setState(ATTACKING):
#			return

	# Get movement
	_get_movement()
	
	# Apply movement
	velocity.y += gravity * delta
	velocity = move_and_slide(velocity, Vector2.UP)
	
	# Randomly turn head if sitting
	if state == IDLE_SIT and rand_range(0,100) > 95:
		setState(IDLE_TURN)
		return
	
	# Raycast to player
	if !followingPlayer or DEBUG:
		_raycastToPlayer()
	
	# If moving down and not in falling state, go into falling state
	if velocity.y > 0 and state != FALLING:
		setState(FALLING)
	
	# Landing after jumping and falling
	if [JUMPING, FALLING].has(state) and velocity.y == 0:
		setState(IDLE)
		return
	
	# Jump
	if playerClose and player.position.y < position.y-HEIGHT_THRESHOLD and $JumpTimer.time_left == 0:
		if is_on_floor():
			if setState(JUMPING):
				velocity.y = jump_speed
				$JumpTimer.start()
				return

	# Idling
	if state != IDLE and velocity == Vector2.ZERO:
		setState(IDLE)

func _get_movement():
	
	if _knockback() or (state == HURTING and velocity.y != 0): return
	
	var dir = 0
	velocity.x = 0
	
	if player.position.x > position.x and player.position.x - position.x > RUN_THRESHOLD:
		setState(RUNNING)
		dir = 1
		if $Sprite.flip_h: _flip()
	if player.position.x < position.x and position.x - player.position.x > RUN_THRESHOLD:
		setState(RUNNING)
		dir = -1
		if !$Sprite.flip_h: _flip()
	if dir != 0 and _can_add_momentum():
		velocity.x = lerp(velocity.x, dir * speed, acceleration)
		return
	
	velocity.x = lerp(velocity.x, 0, acceleration)

func _knockback():
	# Return if no knockback
	if knockback <= 0: return
	# Decrement knockback
	knockback-=1
	# Add Velocity
	velocity = knockbackPower
	return true

func setKnockback(value: int, power: Vector2) -> void:
	setState(HURTING)
	knockback = value
	knockbackPower = power

func setState(to: int, hard: bool = false):
	
	if hard or state == -1:
		_set_state_to(to, true, true)
		return true
	
	match (state):
		IDLE:
			match (to):
				RUNNING:   _set_state_to(to)
				JUMPING:   _set_state_to(to)
				FALLING:   _set_state_to(to)
				ATTACKING: _set_state_to(to)
				HURTING:   _set_state_to(to)
				_:         return false
	
		IDLE_SIT:
			match (to):
				RUNNING:   _set_state_to(to)
				JUMPING:   _set_state_to(to)
				FALLING:   _set_state_to(to)
				ATTACKING: _set_state_to(to)
				HURTING:   _set_state_to(to)
				_:         return false
		
		IDLE_TURN:
			match (to):
				RUNNING:   _set_state_to(to)
				JUMPING:   _set_state_to(to)
				FALLING:   _set_state_to(to)
				ATTACKING: _set_state_to(to)
				HURTING:   _set_state_to(to)
				_:         return false
		
		RUNNING:
			match (to):
				IDLE:      _set_state_to(to)
				JUMPING:   _set_state_to(to)
				FALLING:   _set_state_to(to)
				ATTACKING: _set_state_to(to)
				HURTING:   _set_state_to(to)
				_:         return false
		
		JUMPING:
			match (to):
				IDLE:      _set_state_to(to)
				FALLING:   _set_state_to(to)
				ATTACKING: _set_state_to(to)
				HURTING:   _set_state_to(to)
				_:         return false
		
		FALLING:
			match (to):
				IDLE:      _set_state_to(to)
				ATTACKING: _set_state_to(to)
				HURTING:   _set_state_to(to)
				_:         return false
		
		ATTACKING:
			match (to):
				HURTING:   _set_state_to(to)
				_:         return false
		
		HURTING:
			match (to):
				IDLE:      _set_state_to(to)
				_:         return false
	
	return true

func take_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		_die()

func _can_add_momentum() -> bool:
	if knockback > 0: return false
	match(state):
		IDLE:      return false
		RUNNING:   return true
		JUMPING:   return true
		FALLING:   return true
		ATTACKING: return velocity.y != 0
		_:         return false

func _die() -> void:
	emit_signal("skeleton_died", position)
	queue_free()

func _set_state_to(newState: int, anim: bool = true, hard: bool = false) -> void:
	if anim:
		match(newState):
			IDLE:      $AnimationPlayer.play("idle")
			IDLE_SIT:  $AnimationPlayer.play("idle_sit")
			IDLE_TURN: $AnimationPlayer.play("idle_sit_turn")
			RUNNING:   $AnimationPlayer.play("run")
			JUMPING:   $AnimationPlayer.play("jump")
			FALLING:   $AnimationPlayer.play("fall")
			ATTACKING: $AnimationPlayer.play("attack")
			HURTING:   $AnimationPlayer.play("hurt")
	state = newState
	if DEBUG:
		print("Skeleton set state to ", state, " Hard?: ", hard)

func _flip() -> void:
	$Sprite.flip_h = !$Sprite.flip_h
	if $Sprite.position.x == -7:
		$Sprite.position.x = 13
		$Attackrange/CollisionShape2D.position.x = 39
	else:
		$Sprite.position.x = -7
		$Attackrange/CollisionShape2D.position.x = -33
	$DamageArea/CollisionShape2D.position.x *= -1

func _raycastToPlayer():
	hit_pos = []
	var space_state = get_world_2d().direct_space_state
	var target_extents = player.collisionShape.shape.extents - Vector2(5, 5)
	var nw = player.position - target_extents
	var se = player.position + target_extents
	var ne = player.position + Vector2(target_extents.x, -target_extents.y)
	var sw = player.position + Vector2(-target_extents.x, target_extents.y)
	for pos in [nw, ne, se, sw]:
		var result = space_state.intersect_ray(position, pos, [self], collision_mask)
		if result:
			hit_pos.append(result.position)
			if result.collider.name == "Player":
				followingPlayer = true
			if !DEBUG:
				break

func _on_Jumprange_body_entered(body):
	if body.name == "Player" and playerClose == false:
		playerClose = true

func _on_Jumprange_body_exited(body):
	if body.name == "Player" and playerClose == true:
		playerClose = false

func _on_AnimationPlayer_animation_finished(anim_name):
	match (anim_name):
		"attack":
			setState(IDLE, true)

func _on_Attackrange_body_shape_entered(_body_rid, body, _body_shape_index, _local_shape_index):
	if body.name == "Player":
		playerInAttackRange = true

func _on_Attackrange_body_shape_exited(_body_rid, body, _body_shape_index, _local_shape_index):
	if body.name == "Player":
		playerInAttackRange = false

func _on_DamageArea_body_entered(body):
	print("Damage body entered")
	body.take_damage(damage)
	var dirx = 1
	var diry = -1
	if body.position.x < position.x:
		dirx = -1
	if body.position.y  > position.y:
		diry = 1
		
	# Apply great force is player is dead
	if !body.dead:
		body.setKnockback(10, Vector2(dirx * weapon_knockback_power, diry * weapon_knockback_power))
	else:
		body.velocity = Vector2(dirx * death_knockback_power, diry * death_knockback_power)
		# body.setKnockback(10, Vector2(dirx * death_knockback_power, diry * death_knockback_power))
	
