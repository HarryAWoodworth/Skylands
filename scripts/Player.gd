extends KinematicBody2D

signal playerHealthUpdate(newHealth)
signal playerDied

export var speed: int = 1200
export var jump_speed: int = -1800
export var roll_speed: int = 2400
export var gravity: int = 4000
export var friction: int = 80
export (float, 0, 1.0) var acceleration = 0.25

const DEBUG: bool = false

const SPEED_THRESHOLD := 1000
const HEIGHT_THRESHOLD := 5
const COLLISION_DAMP := 1
const MAX_BOUNCE_LENGTH := 1000
const push_factor := 1.0
const MAX_PUSH_STRENGTH := 1000
# Higher value, more velocity is dampened
const VELOCITY_BOUNCE_X_DAMPEN := 1.5
const VELOCITY_BOUNCE_Y_DAMPEN := 2
# Threshhold for no more bouncing, smaller number = more bounce
const VELOCITY_Y_BOUNCE_THRESHOLD := -120

onready var collisionShape = $CollisionShape2D

enum { IDLE, RUNNING, JUMPING, FALLING, ATTACKING, LANDING, ROLLING, IBLOCKING, BLOCKING, HURTING, FLYING, THROWING, DYING }

var health: int
var max_health: int
var state: int = -1
var dead := false
var knockback := 0
var knockbackPower := Vector2(100,-100)
var weapon_knockback_power := 100

var velocity = Vector2.ZERO
var fallingFast = false
var in_attack_area = []

var initial_death_fly := false

func init(health_: int, max_health_: int, newPos: Vector2) -> void:
	health = health_
	max_health = max_health_
	position = newPos

func _ready():
	setState(IDLE, true)
	$SmokeL.emitting = false
	$SmokeR.emitting = false

func _physics_process(delta):
	
	# Get input
	get_input()

	# If not dead, apply velocity from input with gravity
	if !dead:
		velocity.y += gravity * delta
		velocity = move_and_slide(velocity, Vector2.UP, false, 4, 0.785398, true)
		# Apply impulse to rigidbodies
		for index in get_slide_count():
			var collision = get_slide_collision(index)
			if collision.collider is RigidBody2D:
				var vel_len = clamp(velocity.length(), 1, MAX_PUSH_STRENGTH)
				print("Vel_len: ", vel_len)
				collision.collider.apply_central_impulse(-collision.normal * vel_len)
		
	# If dead, bounce
	else:
		var collision = move_and_collide(velocity * delta)
		velocity.y += gravity * delta
		if collision:
			velocity = velocity.bounce(collision.normal).clamped(MAX_BOUNCE_LENGTH)
			
			# Dampen velocity
			velocity.x /= VELOCITY_BOUNCE_X_DAMPEN
			velocity.y /= VELOCITY_BOUNCE_Y_DAMPEN
			# If under threshold, stop bouncing
			if velocity.y > VELOCITY_Y_BOUNCE_THRESHOLD:
				velocity.y = 0
	
	# Friction for death fly
	if dead and velocity.y == 0:
		if velocity.x > 0:
			velocity.x -= friction
		if velocity.x < 0:
			velocity.x += friction
	
	# Check to stop death fly y velocity
	if initial_death_fly and velocity.y >= 0:
		initial_death_fly = false
	
	# If moving down and not in falling state, go into falling state
	if velocity.y > 0 and state != FALLING:
		setState(FALLING)
		return
	
	# Check for falling fast
	#if velocity.y != 0: print(velocity.y)
	if !fallingFast and velocity.y > SPEED_THRESHOLD:
		if DEBUG: print("Falling Fast!")
		fallingFast = true
	
	# Landing after jumping and falling
	if [JUMPING, FALLING].has(state) and velocity.y == 0:
		if fallingFast:
			setState(LANDING)
		else:
			setState(IDLE)
		return
	
	# Landing fast
	if [JUMPING, FALLING, ATTACKING, IBLOCKING].has(state) and velocity.y == 0 and fallingFast:
		setState(LANDING)
		return
	
	# Idling
	if (state != IDLE and state != LANDING) and velocity == Vector2.ZERO:
		setState(IDLE)
		return

func get_input():
	
	if _knockback() or dead or (state == HURTING and velocity.y != 0): return
	
	var dir = 0
	velocity.x = 0
	
	# If roll just pressed or state is still rolling add dir to velocity
	if Input.is_action_just_pressed("roll") or state == ROLLING:
		# Set state to rolling
		if state != ROLLING: setState(ROLLING)
		# Add dir in direction player is currently facing 
		if $Sprite.flip_h: dir -= 1
		else: dir += 1
		velocity.x = lerp(velocity.x, dir * roll_speed, acceleration)
		return
	
	# Attacking
	if Input.is_action_pressed("attack"):
		setState(ATTACKING)
		return
	
	# Blocking
	if Input.is_action_pressed("block"):
		setState(IBLOCKING)
		return
	
	# Jumping
	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			if setState(JUMPING):
				velocity.y = jump_speed
				return
	
	# Running
	if Input.is_action_pressed("walk_right"):
		setState(RUNNING)
		dir += 1
		if $Sprite.flip_h: _flip()
	if Input.is_action_pressed("walk_left"):
		setState(RUNNING)
		dir -= 1
		if !$Sprite.flip_h: _flip()
	if dir != 0 and _can_add_momentum():
		velocity.x = lerp(velocity.x, dir * speed, acceleration)
		return
	
	# Lerp to 0 if no movement (friction)
	velocity.x = lerp(velocity.x, 0, acceleration)

func take_damage(amount: int) -> void:
	if health <= 0: return
	health -= amount
	if DEBUG: print("Player took ", amount, " damage. Health now ", health)
	emit_signal("playerHealthUpdate", health)
	if health <= 0:
		_die()

func gain_health(amount: int) -> void:
	health += amount
	if health > max_health:
		health += max_health
	if DEBUG: print("Player gained ", amount, " health. Health now ", health)
	emit_signal("playerHealthUpdate", health)

func setKnockback(value: int, power: Vector2) -> void:
	setState(HURTING)
	knockback = value
	knockbackPower = power

func setState(to: int, hard: bool = false):
	
	var current_state = state
	
	if hard or state == -1 or to == DYING:
		_set_state_to(to, true, true)
		return true
	
	match (current_state):
		IDLE:
			match (to):
				RUNNING:   _set_state_to(to)
				JUMPING:   _set_state_to(to)
				FALLING:   _set_state_to(to)
				ATTACKING: _set_state_to(to)
				ROLLING:   _set_state_to(to)
				IBLOCKING: _set_state_to(to)
				HURTING:   _set_state_to(to)
				_:         return false
	
		RUNNING:
			match (to):
				IDLE:      _set_state_to(to)
				JUMPING:   _set_state_to(to)
				FALLING:   _set_state_to(to)
				ATTACKING: _set_state_to(to)
				ROLLING:   _set_state_to(to)
				IBLOCKING: _set_state_to(to)
				HURTING:   _set_state_to(to)
				_:         return false
		
		JUMPING:
			match (to):
				IDLE:      _set_state_to(to)
				FALLING:   _fall_short()
				ATTACKING: _set_state_to(to)
				LANDING:   _land()
				IBLOCKING: _set_state_to(to)
				HURTING:   _set_state_to(to)
				_:         return false
		
		FALLING:
			match (to):
				IDLE:      _set_state_to(to)
				ATTACKING: _set_state_to(to)
				LANDING:   _land()
				IBLOCKING: _set_state_to(to)
				HURTING:   _set_state_to(to)
				_:         return false
			
		ATTACKING:
			match (to):
				LANDING:   _land()
				ROLLING:   _set_state_to(to)
				IBLOCKING: _set_state_to(to)
				HURTING:   _set_state_to(to)
				_:         return false
			
		LANDING:
			match (to):
				HURTING:   _set_state_to(to)
				_: return false
			
		ROLLING:
			match (to):
				FALLING:   _set_state_to(to)
				HURTING:   _set_state_to(to)
				_:         return false
		
		IBLOCKING:
			match (to):
				RUNNING:   _set_state_to(to)
				JUMPING:   _set_state_to(to)
				ATTACKING: _set_state_to(to)
				LANDING:   _land()
				ROLLING:   _set_state_to(to)
				HURTING:   _set_state_to(to)
				_:         return false
	
		BLOCKING:
			match (to):
				HURTING:   _set_state_to(to)
				_:         return false
		
		HURTING:
			match (to):
				IDLE:      
					if knockback <= 0:
						_set_state_to(to)
				RUNNING:
					if knockback <= 0:
						_set_state_to(to)
				_:         return false
		
		FLYING:
			match (to):
				FALLING:   _set_state_to(to)
				HURTING:   _set_state_to(to)
				_:         return false
		
		THROWING:
			match (to):
				LANDING:   _land()
				ROLLING:   _set_state_to(to)
				IBLOCKING: _set_state_to(to)
				HURTING:   _set_state_to(to)
				_:         return false
		
		DYING:
			match(to):
				_:         return false
	
	return true

func _knockback():
	if !dead:
		# Return if no knockback
		if knockback <= 0: return
		# Decrement knockback
		knockback-=1
		# Add Velocity
		velocity = knockbackPower
		return true	
	else:
		return false

func _die() -> void:
	dead = true
	initial_death_fly = true
	#set_collision_layer_bit(0, false)
	emit_signal("playerDied")
	setState(DYING)

func _set_state_to(newState: int, anim: bool = true, hard: bool = false) -> void:
	if anim:
		match(newState):
			IDLE:      $AnimationPlayer.play("idle")
			RUNNING:   $AnimationPlayer.play("run")
			JUMPING:   $AnimationPlayer.play("jump")
			FALLING:   $AnimationPlayer.play("fall")
			ATTACKING: $AnimationPlayer.play("attack")
			LANDING:   $AnimationPlayer.play("land")
			ROLLING:   $AnimationPlayer.play("roll")
			IBLOCKING: $AnimationPlayer.play("block_idle")
			HURTING:   $AnimationPlayer.play("hurt")
			FLYING:    $AnimationPlayer.play("fly")
			THROWING:  $AnimationPlayer.play("throw")
			DYING:  $AnimationPlayer.play("die")
	state = newState
	if DEBUG:
		print("Set state to ", state, " Hard?: ", hard)

func _land() -> void:
	_set_state_to(LANDING)
	$Camera2D.add_trauma(0.4)
	fallingFast = false

func _fall_short() -> void:
	$AnimationPlayer.play("fall_short")
	_set_state_to(FALLING, false)

func _can_add_momentum() -> bool:
	match(state):
		IDLE:      return false
		RUNNING:   return true
		JUMPING:   return true
		FALLING:   return true
		ATTACKING: return velocity.y != 0
		LANDING:   return false
		ROLLING:   return false
		IBLOCKING: return false
		DYING:     return true
	return true

func _flip() -> void:
	# Stop flip during landing anim
	if state == LANDING: return
	$Sprite.flip_h = !$Sprite.flip_h
	$DamageArea/CollisionShape2D.position.x *= -1

func _on_AnimationPlayer_animation_finished(anim_name):
	match (anim_name):
		"attack":
			setState(IDLE, true)
		"land":
			fallingFast = false
			setState(IDLE, true)
		"roll":
			setState(IDLE, true)
		"block":
			setState(IDLE, true)
		"throw":
			setState(IDLE, true)

func _on_DamageArea_body_entered(enemy):
	enemy.take_damage(1)
	var dirx = 1
	var diry = -1
	print("Enemy: ", enemy.position, " Player: ", position)
	if enemy.position.x < position.x:
		dirx = -1
	if enemy.position.y > position.y + HEIGHT_THRESHOLD:
		diry = 1
	enemy.setKnockback(10, Vector2(dirx * weapon_knockback_power, diry * weapon_knockback_power))




