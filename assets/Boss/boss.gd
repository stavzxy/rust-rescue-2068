extends CharacterBody2D
## Level 2 Boss - 800 HP Tank with Enrage Phase & Telegraphed Jump Slams

signal boss_defeated

@export var max_health: int = 800
@export var move_speed: float = 120.0
@export var jump_cooldown: float = 3.2
@export var slam_damage: int = 28
@export var slam_radius: float = 90.0

const BOSS_DIR: String = "res://assets/Boss/"

var health: int = 800
var state: String = "CHASE" # CHASE, WINDUP, IN_AIR, RECOVERY
var is_enraged: bool = false
var target_pos: Vector2 = Vector2.ZERO
var jump_timer: float = 0.0
var jump_progress: float = 0.0
var jump_start_pos: Vector2 = Vector2.ZERO
var jump_duration: float = 0.85

var player_ref: Node2D = null
var sprite: AnimatedSprite2D = null
var target_marker: Node2D = null
var hp_bar_bg: ColorRect = null
var hp_bar_fill: ColorRect = null


func _ready() -> void:
	add_to_group("Enemies")
	add_to_group("Boss")
	
	health = max_health
	collision_layer = 2
	collision_mask = 1
	
	_setup_collision()
	_setup_sprite_from_sheet()
	_setup_health_bar()
	_setup_target_marker()


func _setup_collision() -> void:
	if get_node_or_null("CollisionShape2D") != null:
		return
	var col := CollisionShape2D.new()
	col.name = "CollisionShape2D"
	var cap := CapsuleShape2D.new()
	cap.radius = 32.0
	cap.height = 64.0
	col.shape = cap
	add_child(col)


func _setup_sprite_from_sheet() -> void:
	sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null:
		sprite = AnimatedSprite2D.new()
		sprite.name = "AnimatedSprite2D"
		add_child(sprite)
	
	sprite.scale = Vector2(2.2, 2.2)
	
	var frames := SpriteFrames.new()
	frames.add_animation("default")
	frames.set_animation_loop("default", true)
	frames.set_animation_speed("default", 5.0)

	var loaded_sheet: Texture2D = null
	var possible_paths = [
		"res://assets/Boss/BOSS.png",
		"res://assets/Boss/boss.png",
		"res://assets/Boss/Boss.png"
	]
	
	for path in possible_paths:
		if ResourceLoader.exists(path):
			loaded_sheet = load(path) as Texture2D
			if loaded_sheet != null:
				break

	if loaded_sheet == null:
		var dir := DirAccess.open(BOSS_DIR)
		if dir != null:
			for file_name in dir.get_files():
				var clean := file_name.trim_suffix(".import").trim_suffix(".remap")
				if clean.get_extension().to_lower() in ["png", "webp"]:
					loaded_sheet = load(BOSS_DIR + clean) as Texture2D
					if loaded_sheet != null:
						break

	if loaded_sheet != null:
		var w = loaded_sheet.get_width()
		var h = loaded_sheet.get_height()
		if w >= h * 1.4:
			var frame_w = w / 2.0
			var frame1 := AtlasTexture.new()
			frame1.atlas = loaded_sheet
			frame1.region = Rect2(0, 0, frame_w, h)
			var frame2 := AtlasTexture.new()
			frame2.atlas = loaded_sheet
			frame2.region = Rect2(frame_w, 0, frame_w, h)
			frames.add_frame("default", frame1)
			frames.add_frame("default", frame2)
		else:
			frames.add_frame("default", loaded_sheet)
	else:
		_generate_procedural_drone_frames(frames)

	sprite.sprite_frames = frames
	sprite.play("default")


func _generate_procedural_drone_frames(frames: SpriteFrames) -> void:
	for i in range(2):
		var img := Image.create(64, 40, false, Image.FORMAT_RGBA8)
		for x in range(64):
			for y in range(40):
				var dx = x - 32.0
				var dy = y - 20.0
				if (dx*dx) / 600.0 + (dy*dy) / 100.0 <= 1.0:
					img.set_pixel(x, y, Color(0.42, 0.2, 0.48, 1.0))
				if (dx*dx) / 100.0 + ((dy+6.0)*(dy+6.0)) / 25.0 <= 1.0 and dy < -2.0:
					img.set_pixel(x, y, Color(0.7, 0.15, 0.15, 1.0))
				if (dx*dx) / 120.0 + ((dy-8.0)*(dy-8.0)) / 80.0 <= 1.0 and dy > 2.0:
					img.set_pixel(x, y, Color(0.12, 0.1, 0.18, 1.0))
				if abs(dx) > 22.0 and abs(dy) < 14.0:
					if i == 1 and randf() > 0.4:
						img.set_pixel(x, y, Color(0.9, 0.9, 0.95, 1.0))
					else:
						img.set_pixel(x, y, Color(0.08, 0.08, 0.1, 1.0))
		frames.add_frame("default", ImageTexture.create_from_image(img))


func _setup_health_bar() -> void:
	hp_bar_bg = ColorRect.new()
	hp_bar_bg.size = Vector2(100, 12)
	hp_bar_bg.position = Vector2(-50, -60)
	hp_bar_bg.color = Color(0.15, 0.15, 0.15, 0.9)
	add_child(hp_bar_bg)
	
	hp_bar_fill = ColorRect.new()
	hp_bar_fill.size = Vector2(96, 8)
	hp_bar_fill.position = Vector2(-48, -58)
	hp_bar_fill.color = Color(0.9, 0.15, 0.15, 1.0)
	add_child(hp_bar_fill)


func _update_health_bar() -> void:
	if hp_bar_fill != null:
		var pct = maxf(float(health) / float(max_health), 0.0)
		hp_bar_fill.size.x = 96.0 * pct


func _setup_target_marker() -> void:
	target_marker = Node2D.new()
	target_marker.name = "SlamTargetMarker"
	target_marker.visible = false
	target_marker.top_level = true
	
	target_marker.draw.connect(func():
		var line_color = Color(1.0, 0.1, 0.1, 0.85) if is_enraged else Color(1.0, 0.3, 0.1, 0.7)
		target_marker.draw_arc(Vector2.ZERO, slam_radius, 0, TAU, 32, line_color, 5.0)
		target_marker.draw_circle(Vector2.ZERO, 10.0, Color(1.0, 0.1, 0.1, 0.6))
	)
	
	add_child(target_marker)


func _physics_process(delta: float) -> void:
	if player_ref == null or not is_instance_valid(player_ref):
		player_ref = get_tree().get_first_node_in_group("Player") as Node2D
		return
	
	jump_timer += delta
	
	match state:
		"CHASE":
			var dir = (player_ref.global_position - global_position).normalized()
			velocity = dir * move_speed
			move_and_slide()
			
			if jump_timer >= jump_cooldown:
				_start_jump_windup()
				
		"WINDUP":
			velocity = Vector2.ZERO
			move_and_slide()
			
		"IN_AIR":
			jump_progress += delta / jump_duration
			if jump_progress >= 1.0:
				_execute_slam()
			else:
				global_position = jump_start_pos.lerp(target_pos, jump_progress)
				var height = sin(jump_progress * PI) * 120.0
				sprite.position.y = -height
				
		"RECOVERY":
			velocity = Vector2.ZERO
			move_and_slide()


func _start_jump_windup() -> void:
	state = "WINDUP"
	jump_timer = 0.0
	target_pos = player_ref.global_position
	jump_start_pos = global_position
	
	target_marker.global_position = target_pos
	target_marker.visible = true
	target_marker.queue_redraw()
	
	var windup_time = 0.25 if is_enraged else 0.35
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(2.5, 0.3, 0.3, 1.0), windup_time)
	tween.tween_callback(func():
		state = "IN_AIR"
		jump_progress = 0.0
	)


func _execute_slam() -> void:
	state = "RECOVERY"
	sprite.position.y = 0
	sprite.modulate = Color(2.0, 0.4, 0.4, 1.0) if is_enraged else Color(1.0, 1.0, 1.0, 1.0)
	target_marker.visible = false
	
	if is_instance_valid(player_ref):
		var dist = global_position.distance_to(player_ref.global_position)
		if dist <= slam_radius:
			if player_ref.has_method("take_damage"):
				player_ref.take_damage(slam_damage)
	
	var recovery_delay = 0.35 if is_enraged else 0.55
	get_tree().create_timer(recovery_delay).timeout.connect(func():
		state = "CHASE"
	)


func take_damage(amount: int) -> void:
	health -= amount
	_update_health_bar()
	
	if health <= max_health * 0.5 and not is_enraged:
		_enter_enrage_phase()
	
	if sprite != null:
		var tween = create_tween()
		sprite.modulate = Color(2.0, 2.0, 2.0, 1.0)
		var reset_color = Color(2.0, 0.4, 0.4, 1.0) if is_enraged else Color(1.0, 1.0, 1.0, 1.0)
		tween.tween_property(sprite, "modulate", reset_color, 0.08)
	
	if health <= 0:
		_die()


func _enter_enrage_phase() -> void:
	is_enraged = true
	move_speed = 165.0
	jump_cooldown = 2.1
	slam_damage = 35
	slam_radius = 110.0
	
	if hp_bar_fill != null:
		hp_bar_fill.color = Color(1.0, 0.1, 0.0, 1.0)
		
	if sprite != null:
		sprite.modulate = Color(2.0, 0.4, 0.4, 1.0)
	print("=== BOSS ENRAGED! SPEED & SLAM FREQUENCY INCREASED ===")


func _die() -> void:
	print("=== BOSS DEFEATED! QUEUING WIFE NPC SPAWN AT MAP CENTER ===")
	
	if target_marker != null and is_instance_valid(target_marker):
		target_marker.queue_free()
	
	boss_defeated.emit()
	
	# Safely defer spawn to avoid physics state locking crash
	call_deferred("_spawn_wife_at_center")
	
	# Safely defer boss removal
	queue_free()


func _spawn_wife_at_center() -> void:
	var wife_script = load("res://assets/World/wife_npc.gd") as Script
	if wife_script != null:
		var wife_npc = CharacterBody2D.new()
		wife_npc.set_script(wife_script)
		
		# Add to level node
		var parent_node = get_parent()
		if parent_node != null:
			parent_node.add_child(wife_npc)
			
			# Center spawn logic: uses map viewport center or explicit world coordinates
			var viewport_rect = get_viewport_rect()
			wife_npc.global_position = viewport_rect.size / 2.0
			print("=== WIFE SPAWNED AT MAP CENTER: ", wife_npc.global_position, " ===")
