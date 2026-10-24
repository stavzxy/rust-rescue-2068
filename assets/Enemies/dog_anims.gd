extends CharacterBody2D

signal hit_player

const WORLD_LAYER: int = 1
const ENEMY_LAYER: int = 2
const PLAYER_LAYER: int = 4

const DROP_CHANCE: float = 0.35
const DROP_TYPES: Array[String] = ["pipe", "gunpowder", "apple"]
const PICKUP_SCRIPT: Script = preload("res://assets/World/pickup_item.gd")

@export var speed: float = 100.0
@export var max_health: int = 30
@export var attack_damage: int = 10
@export var attack_cooldown: float = 1.0
@export var aggro_range: float = 450.0  # starts chasing early if you get this close

var player: Node2D = null
var alive: bool = true
var entered: bool = false  # set by EntranceTimer: after that the dog always hunts you
var health: int = 30
var direction: Vector2 = Vector2.ZERO

var roam_timer: float = 0.0
var current_roam_dir: Vector2 = Vector2.ZERO
var _attack_cd: float = 0.0

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	alive = true
	entered = false
	health = max_health
	add_to_group("Enemies")

	# Layer 2 = enemies (so bullets / slashes can see us).
	collision_layer = ENEMY_LAYER
	collision_mask = WORLD_LAYER | ENEMY_LAYER | PLAYER_LAYER

	_find_player()
	_pick_random_roam_dir()


func _physics_process(delta: float) -> void:
	if not alive:
		return

	_attack_cd = maxf(_attack_cd - delta, 0.0)
	_find_player()

	var chasing := false
	if player != null and not _player_is_dead():
		chasing = entered or global_position.distance_to(player.global_position) <= aggro_range

	if chasing:
		direction = (player.global_position - global_position).normalized()
	else:
		roam_timer -= delta
		if roam_timer <= 0.0:
			_pick_random_roam_dir()
		direction = current_roam_dir

	velocity = direction * speed
	move_and_slide()

	# Bumped into a wall/prop while wandering: turn around.
	if not chasing and get_slide_collision_count() > 0:
		_pick_random_roam_dir()

	_handle_contact_attack()
	_update_animation()


func _find_player() -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("Player") as Node2D


func _player_is_dead() -> bool:
	return player != null and "is_dead" in player and player.is_dead


func _handle_contact_attack() -> void:
	if _attack_cd > 0.0:
		return
	for i in get_slide_collision_count():
		var collider := get_slide_collision(i).get_collider() as Node
		if collider != null and collider.is_in_group("Player") and collider.has_method("take_damage"):
			collider.take_damage(attack_damage)
			_attack_cd = attack_cooldown
			hit_player.emit()
			SoundManager.play_sfx("dog_attack")
			return


func _update_animation() -> void:
	if anim_sprite == null:
		return
	if anim_sprite.animation != &"run" or not anim_sprite.is_playing():
		anim_sprite.play("run")
	if absf(velocity.x) > 0.01:
		anim_sprite.flip_h = velocity.x < 0.0


func _pick_random_roam_dir() -> void:
	var angle := randf() * TAU
	current_roam_dir = Vector2(cos(angle), sin(angle)).normalized()
	roam_timer = randf_range(2.0, 4.0)


func take_damage(amount: int) -> void:
	if not alive:
		return
	health -= amount
	print("Dog took ", amount, " damage! HP left: ", maxi(health, 0))
	_flash()
	if health > 0:
		SoundManager.play_sfx("enemy_hurt")
	if health <= 0:
		_die()


func _flash() -> void:
	if anim_sprite == null:
		return
	anim_sprite.modulate = Color(1.0, 0.3, 0.3)
	create_tween().tween_property(anim_sprite, "modulate", Color.WHITE, 0.15)


func _die() -> void:
	alive = false
	SoundManager.play_sfx("enemy_death")
	# Collision changes are not allowed mid-physics-callback, so defer them.
	$CollisionShape2D.set_deferred("disabled", true)
	if randf() < DROP_CHANCE:
		_drop_crafting_loot()
	queue_free()


func _drop_crafting_loot() -> void:
	var parent := get_parent()
	if parent == null:
		return

	var drop := Area2D.new()
	drop.set_script(PICKUP_SCRIPT)
	drop.set("item_type", DROP_TYPES.pick_random())  # must be set before it enters the tree
	drop.position = parent.to_local(global_position) if parent is Node2D else global_position
	# Adding physics objects during a physics callback (bullet hit) must be deferred.
	parent.add_child.call_deferred(drop)


func _on_entrance_timer_timeout() -> void:
	entered = true
	SoundManager.play_bark()
