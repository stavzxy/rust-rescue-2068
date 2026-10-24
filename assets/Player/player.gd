extends CharacterBody2D

signal died
signal health_changed(current: int, maximum: int)

static var instance: CharacterBody2D = null

# Physics layers: 1 = world/props, 2 = enemies, 4 = player
const WORLD_LAYER: int = 1
const ENEMY_LAYER: int = 2
const PLAYER_LAYER: int = 4

const MAX_MAG_SIZE: int = 20
const RELOAD_TIME: float = 1.5
const FIRE_COOLDOWN: float = 0.15
const SLASH_TIME: float = 0.35
const APPLE_HEAL: int = 25
# The art faces UP, but look_at() points the +X axis (right) at the mouse.
# Rotating the sprite 90 degrees makes the picture face the same way the bullets fly.
const SPRITE_FACING_OFFSET_DEG: float = 90.0
const INVULN_TIME: float = 0.6

const BULLET_SCRIPT: Script = preload("res://assets/Weapons/bullet.gd")
const SLASH_SCRIPT: Script = preload("res://assets/Weapons/slash_area.gd")

const UNARMED_TEX: Texture2D = preload("res://assets/Player/joe_spritesheet.png")
const BLADE_TEX: Texture2D = preload("res://assets/Player/Joeblade.png")
const GUN_TEX: Texture2D = preload("res://assets/Player/JoeGun.png")

@export var speed: float = 180.0
@export var max_health: int = 100

var health: int = 100
var is_dead: bool = false
var current_stance: String = "unarmed"  # "unarmed" or "pistol"
var is_reloading: bool = false
var is_slashing: bool = false
var ammo_in_mag: int = MAX_MAG_SIZE

var anim_sprite: AnimatedSprite2D = null
var _next_shot_msec: int = 0
var _invuln_until_msec: int = 0


func _enter_tree() -> void:
	# HARD SINGLETON: a second Joe is deleted before it ever acts.
	if instance != null and instance != self and is_instance_valid(instance):
		queue_free()
		return
	instance = self


func _ready() -> void:
	if instance != self:
		return

	add_to_group("Player")
	collision_layer = PLAYER_LAYER
	collision_mask = WORLD_LAYER | ENEMY_LAYER
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

	health = max_health
	_setup_animated_sprite()
	_apply_stance("unarmed")


func _exit_tree() -> void:
	if instance == self:
		instance = null
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# ---------------------------------------------------------------- sprites
func _setup_animated_sprite() -> void:
	anim_sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if anim_sprite == null:
		anim_sprite = AnimatedSprite2D.new()
		anim_sprite.name = "AnimatedSprite2D"
		add_child(anim_sprite)

	# Each sheet is a horizontal strip of square frames (64x64), so the frame
	# count is simply width / height.
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")

	_add_sheet_animation(frames, "unarmed", UNARMED_TEX, 8.0, true)
	_add_sheet_animation(frames, "armed", GUN_TEX, 8.0, true)
	var slash_frames := _add_sheet_animation(frames, "slash", BLADE_TEX, 16.0, false)
	# Play the whole slash animation inside SLASH_TIME.
	frames.set_animation_speed("slash", slash_frames / SLASH_TIME)

	anim_sprite.sprite_frames = frames
	anim_sprite.rotation_degrees = SPRITE_FACING_OFFSET_DEG


func _add_sheet_animation(frames: SpriteFrames, anim_name: String, sheet: Texture2D, fps: float, looping: bool) -> int:
	var frame_size: int = sheet.get_height()
	var count: int = int(sheet.get_width() / frame_size)
	frames.add_animation(anim_name)
	frames.set_animation_loop(anim_name, looping)
	frames.set_animation_speed(anim_name, fps)
	for i in count:
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(i * frame_size, 0, frame_size, frame_size)
		frames.add_frame(anim_name, atlas)
	return count


func _stance_anim() -> String:
	return "armed" if current_stance == "pistol" else "unarmed"


# ------------------------------------------------------------------ input
func _unhandled_input(event: InputEvent) -> void:
	if instance != self:
		return

	if is_dead:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
			_restart()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				_apply_stance("unarmed")
			KEY_2:
				if GlobalCounter.gun_unlocked:
					_apply_stance("pistol")
				else:
					print("Pistol locked! Gather %d Pipes and %d Gunpowder first." % [GlobalCounter.PIPE_QUOTA, GlobalCounter.GUNPOWDER_QUOTA])
			KEY_V:
				_perform_melee_slash()
			KEY_R:
				if current_stance == "pistol":
					_start_reload()
			KEY_E:
				_eat_apple()


func _apply_stance(new_stance: String) -> void:
	current_stance = new_stance
	if is_instance_valid(anim_sprite) and not is_slashing:
		anim_sprite.play(_stance_anim())
		anim_sprite.pause()
		anim_sprite.frame = 0
	GlobalCounter.inventory_updated.emit()


# --------------------------------------------------------------- movement
func _key_axis(negative: Key, positive: Key) -> float:
	return float(Input.is_key_pressed(positive)) - float(Input.is_key_pressed(negative))


func _physics_process(_delta: float) -> void:
	if instance != self or is_dead:
		return

	var input_vector := Vector2.ZERO
	input_vector.x = Input.get_axis("ui_left", "ui_right")
	if input_vector.x == 0.0:
		input_vector.x = _key_axis(KEY_A, KEY_D)
	input_vector.y = Input.get_axis("ui_up", "ui_down")
	if input_vector.y == 0.0:
		input_vector.y = _key_axis(KEY_W, KEY_S)

	var moving := input_vector != Vector2.ZERO
	if moving:
		input_vector = input_vector.normalized()

	if is_instance_valid(anim_sprite) and not is_slashing:
		var anim := _stance_anim()
		if moving:
			if anim_sprite.animation != anim or not anim_sprite.is_playing():
				anim_sprite.play(anim)
		else:
			if anim_sprite.animation != anim:
				anim_sprite.animation = anim
			anim_sprite.pause()
			anim_sprite.frame = 0

	velocity = input_vector * speed
	if moving:
		SoundManager.start_footsteps()
	else:
		SoundManager.stop_footsteps()
	move_and_slide()

	look_at(get_global_mouse_position())

	# Hold the mouse button to keep firing (rate-limited by FIRE_COOLDOWN).
	if current_stance == "pistol" and (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)):
		_try_shoot()

	queue_redraw()


func _draw() -> void:
	if is_dead:
		return
	var local_m := get_local_mouse_position()
	draw_line(local_m + Vector2(-10, 0), local_m + Vector2(10, 0), Color.RED, 2.0)
	draw_line(local_m + Vector2(0, -10), local_m + Vector2(0, 10), Color.RED, 2.0)


# ----------------------------------------------------------------- combat
func _perform_melee_slash() -> void:
	if is_slashing or is_dead:
		return
	is_slashing = true
	SoundManager.play_sword("sword_swing", 10.0)

	if is_instance_valid(anim_sprite):
		anim_sprite.play("slash")

	var slash := Area2D.new()
	slash.set_script(SLASH_SCRIPT)
	get_tree().current_scene.add_child(slash)
	var forward_dir := Vector2.RIGHT.rotated(rotation)
	slash.global_position = global_position + forward_dir * 32.0
	slash.rotation = rotation

	await get_tree().create_timer(SLASH_TIME).timeout
	is_slashing = false
	if not is_dead:
		_apply_stance(current_stance)


func _try_shoot() -> void:
	if is_reloading or is_slashing or is_dead:
		return

	var now := Time.get_ticks_msec()
	if now < _next_shot_msec:
		return

	if ammo_in_mag <= 0:
		_start_reload()
		return

	_next_shot_msec = now + int(FIRE_COOLDOWN * 1000.0)
	ammo_in_mag -= 1
	_spawn_bullet()
	GlobalCounter.inventory_updated.emit()

	if ammo_in_mag <= 0:
		_start_reload()


func _spawn_bullet() -> void:
	SoundManager.play_sfx("pistol")
	var aim_dir := (get_global_mouse_position() - global_position).normalized()
	if aim_dir == Vector2.ZERO:
		aim_dir = Vector2.RIGHT.rotated(rotation)

	var bullet := Area2D.new()
	bullet.set_script(BULLET_SCRIPT)
	bullet.set("direction", aim_dir)
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = global_position + aim_dir * 16.0
	bullet.rotation = aim_dir.angle()


func _start_reload() -> void:
	if is_reloading or ammo_in_mag >= MAX_MAG_SIZE:
		return
	is_reloading = true
	print("Reloading... (%.1fs)" % RELOAD_TIME)
	GlobalCounter.inventory_updated.emit()

	await get_tree().create_timer(RELOAD_TIME).timeout
	ammo_in_mag = MAX_MAG_SIZE
	is_reloading = false
	print("Reload complete!")
	GlobalCounter.inventory_updated.emit()


# ----------------------------------------------------------------- health
func take_damage(amount: int) -> void:
	if is_dead:
		return
	var now := Time.get_ticks_msec()
	if now < _invuln_until_msec:
		return  # brief invulnerability so a dog can't melt you in one frame
	_invuln_until_msec = now + int(INVULN_TIME * 1000.0)

	health = maxi(health - amount, 0)
	health_changed.emit(health, max_health)
	GlobalCounter.inventory_updated.emit()
	_flash()
	SoundManager.play_sfx("player_hurt")

	if health <= 0:
		_die()


func heal(amount: int) -> void:
	if is_dead:
		return
	health = mini(health + amount, max_health)
	health_changed.emit(health, max_health)
	GlobalCounter.inventory_updated.emit()


func _eat_apple() -> void:
	if health >= max_health:
		return
	if GlobalCounter.consume_apple():
		heal(APPLE_HEAL)
		SoundManager.play_sfx("eat")


func _flash() -> void:
	if not is_instance_valid(anim_sprite):
		return
	anim_sprite.modulate = Color(1.0, 0.3, 0.3)
	create_tween().tween_property(anim_sprite, "modulate", Color.WHITE, 0.25)


func _die() -> void:
	is_dead = true
	SoundManager.stop_footsteps()
	SoundManager.play_sfx("player_death")
	velocity = Vector2.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(anim_sprite):
		anim_sprite.pause()
		anim_sprite.modulate = Color(0.4, 0.4, 0.4)
	queue_redraw()
	died.emit()
	GlobalCounter.inventory_updated.emit()
	print("Joe is down. Press R to restart.")


func _restart() -> void:
	GlobalCounter.reset()
	get_tree().reload_current_scene()
