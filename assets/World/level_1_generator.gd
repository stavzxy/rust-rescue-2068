extends Node2D
## Level 1 Generator - Handles map layout, enemy spawner, and portal transition

@export var map_width: int = 64
@export var map_height: int = 48
@export var tile_size: int = 32
@export var junk_prop_count: int = 60
@export var spawner_inset: float = 100.0
@export var clamp_camera_to_map: bool = true
@export var pickup_counts: Dictionary = {"pipe": 8, "gunpowder": 10, "apple": 6}
@export var target_dog_kills: int = 5

const DOG_SCENE: PackedScene = preload("res://assets/Enemies/DogAnims.tscn")
const SPAWNER_SCENE: PackedScene = preload("res://assets/Enemies/enemy_spawner.tscn")
const PICKUP_SCRIPT: Script = preload("res://assets/World/pickup_item.gd")
const JUNK_SCRIPT: Script = preload("res://assets/World/junk_prop.gd")
const HUD_SCRIPT: Script = preload("res://assets/World/hud.gd")
const PROPS_DIR: String = "res://assets/World/Props/"

const WORLD_LAYER: int = 1

var map_size_px: Vector2 = Vector2.ZERO
var exit_zone: Area2D = null
var exit_pos: Vector2 = Vector2.ZERO
var portal_active: bool = false
var spawner_ref: Node2D = null
var is_changing_scene: bool = false

# Robust Instance Tracking
var tracked_dog_ids: Dictionary = {}
var total_unique_kills: int = 0


func _ready() -> void:
	SoundManager.play_bgm("upbeat")
	GlobalCounter.reset()
	tracked_dog_ids.clear()
	total_unique_kills = 0
	
	map_size_px = Vector2(map_width * tile_size, map_height * tile_size)
	var center := map_size_px / 2.0
	exit_pos = Vector2(center.x, center.y - 180.0)
	RenderingServer.set_default_clear_color(Color(0.08, 0.08, 0.1))
	_generate.call_deferred()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_P:
			if portal_active:
				print("=== KEY 'P' PRESSED (PORTAL ACTIVE) -> LAUNCHING LEVEL 2 ===")
				_trigger_scene_change()
			else:
				print("=== KEY 'P' BLOCKED: %d/%d unique dogs killed. Portal inactive! ===" % [
					total_unique_kills, target_dog_kills
				])


func _physics_process(_delta: float) -> void:
	_scan_and_track_enemies()
	
	if not portal_active or is_changing_scene or exit_zone == null:
		return
		
	var player := _find_player_node()
	if player != null and is_instance_valid(player):
		var dist = player.global_position.distance_to(exit_zone.global_position)
		if dist <= 120.0:
			print("=== PLAYER STEPPED ON PORTAL (Distance: %.1f) ===" % dist)
			_trigger_scene_change()


func _scan_and_track_enemies() -> void:
	var active_enemies = get_tree().get_nodes_in_group("Enemies")
	for enemy in active_enemies:
		if enemy is Node2D and is_instance_valid(enemy):
			var dog_id = enemy.get_instance_id()
			if not tracked_dog_ids.has(dog_id):
				tracked_dog_ids[dog_id] = true
				enemy.tree_exited.connect(func(): _on_dog_unique_death(dog_id))


func _on_dog_unique_death(dog_id: int) -> void:
	if not tracked_dog_ids.has(dog_id):
		return # Already processed
		
	tracked_dog_ids.erase(dog_id)
	total_unique_kills += 1
	print("=== UNIQUE DOG KILL: %d / %d ===" % [total_unique_kills, target_dog_kills])
	
	if total_unique_kills >= target_dog_kills:
		_activate_portal()


func _trigger_scene_change() -> void:
	if is_changing_scene:
		return
	is_changing_scene = true
	set_physics_process(false)
	set_process(false)
	call_deferred("_change_scene")


func _find_player_node() -> Node2D:
	var player := get_tree().get_first_node_in_group("Player") as Node2D
	if player != null:
		return player
	
	if get_parent() != null:
		player = get_parent().get_node_or_null("Player") as Node2D
		if player != null:
			return player
		
	for node in get_tree().get_nodes_in_group("Player"):
		if node is Node2D:
			return node as Node2D
			
	return null


func _generate() -> void:
	_build_walls()
	_paint_ground()
	_spawn_hud()
	_ensure_single_player()
	_setup_camera()
	_spawn_crafting_materials()
	_spawn_exit_portal()
	_spawn_junk_props()
	_setup_enemy_spawners()


func _build_walls() -> void:
	var walls := StaticBody2D.new()
	walls.name = "MapWalls"
	walls.collision_layer = WORLD_LAYER
	walls.collision_mask = 0
	add_child(walls)
	
	var t := 64.0
	var w := map_size_px.x
	var h := map_size_px.y
	var defs: Array = [
		[Vector2(w / 2.0, -t / 2.0), Vector2(w + t * 2.0, t)],
		[Vector2(w / 2.0, h + t / 2.0), Vector2(w + t * 2.0, t)],
		[Vector2(-t / 2.0, h / 2.0), Vector2(t, h + t * 2.0)],
		[Vector2(w + t / 2.0, h / 2.0), Vector2(t, h + t * 2.0)],
	]
	for d in defs:
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = d[1]
		shape.shape = rect
		shape.position = d[0]
		walls.add_child(shape)


func _paint_ground() -> void:
	var layer: TileMapLayer = null
	if get_parent() != null:
		layer = get_parent().get_node_or_null("TileMapLayer") as TileMapLayer
	if layer == null:
		layer = get_node_or_null("TileMapLayer") as TileMapLayer
		
	if layer == null or layer.tile_set == null:
		return
	var source := layer.tile_set.get_source(0) as TileSetAtlasSource
	if source == null:
		return

	var valid_tiles: Array[Vector2i] = []
	var grid := source.get_atlas_grid_size()
	for col in range(min(grid.x, 16)):
		for row in range(min(grid.y, 16)):
			var coords := Vector2i(col, row)
			if source.has_tile(coords):
				valid_tiles.append(coords)

	if valid_tiles.is_empty():
		valid_tiles.append(Vector2i(0, 0))

	for x in map_width:
		for y in map_height:
			var tile_coords: Vector2i = valid_tiles[(x + y) % valid_tiles.size()]
			layer.set_cell(Vector2i(x, y), 0, tile_coords)


func _spawn_hud() -> void:
	if get_tree().get_first_node_in_group("HUD") != null:
		return
	var hud := CanvasLayer.new()
	hud.set_script(HUD_SCRIPT)
	if get_parent() != null:
		get_parent().add_child(hud)
	else:
		add_child(hud)


func _ensure_single_player() -> void:
	var center := map_size_px / 2.0
	var existing := _find_player_node()
	
	if existing != null:
		existing.global_position = center
		return
	
	var player_scene: PackedScene = null
	if ResourceLoader.exists("res://assets/Player/player.tscn"):
		player_scene = load("res://assets/Player/player.tscn") as PackedScene
	elif ResourceLoader.exists("res://player.tscn"):
		player_scene = load("res://player.tscn") as PackedScene
		
	if player_scene != null:
		var new_player := player_scene.instantiate() as Node2D
		if get_parent() != null:
			get_parent().add_child(new_player)
		else:
			add_child(new_player)
		new_player.global_position = center


func _setup_camera() -> void:
	var player := _find_player_node()
	if player == null:
		return
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return
	
	if clamp_camera_to_map:
		cam.limit_left = 0
		cam.limit_top = 0
		cam.limit_right = int(map_size_px.x)
		cam.limit_bottom = int(map_size_px.y)


func _random_point(margin: float = 64.0, avoid_center_radius: float = 0.0) -> Vector2:
	var center := map_size_px / 2.0
	var p := center
	for i in 20:
		p = Vector2(
			randf_range(margin, map_size_px.x - margin),
			randf_range(margin, map_size_px.y - margin))
		if p.distance_to(center) >= avoid_center_radius:
			break
	return p


func _spawn_crafting_materials() -> void:
	for item_type in pickup_counts:
		for i in int(pickup_counts[item_type]):
			var item := Area2D.new()
			item.set_script(PICKUP_SCRIPT)
			item.set("item_type", String(item_type))
			add_child(item)
			item.global_position = _random_point(64.0)


func _spawn_junk_props() -> void:
	var textures: Array[String] = []
	var dir := DirAccess.open(PROPS_DIR)
	if dir == null:
		return
	for file_name in dir.get_files():
		var clean := file_name.trim_suffix(".import").trim_suffix(".remap")
		if clean.get_extension().to_lower() in ["png", "webp", "jpg", "jpeg"]:
			var path := PROPS_DIR + clean
			if not textures.has(path):
				textures.append(path)
	
	if textures.is_empty():
		return
	
	var center := map_size_px / 2.0
	for i in junk_prop_count:
		var pos := Vector2.ZERO
		for attempt in 30:
			pos = _random_point(96.0, 120.0)
			if pos.distance_to(exit_pos) > 140.0 and pos.distance_to(center) > 140.0:
				break
		
		var prop := StaticBody2D.new()
		prop.set_script(JUNK_SCRIPT)
		prop.set("prop_texture_path", textures.pick_random())
		add_child(prop)
		prop.global_position = pos


func _spawn_exit_portal() -> void:
	exit_zone = Area2D.new()
	exit_zone.name = "ExitPortal"
	exit_zone.collision_layer = 0
	exit_zone.collision_mask = 0xFFFFFFFF
	exit_zone.monitoring = true
	exit_zone.z_index = 20
	
	var portal_sprite = AnimatedSprite2D.new()
	portal_sprite.name = "PortalSprite"
	portal_sprite.scale = Vector2(3.0, 3.0)
	exit_zone.add_child(portal_sprite)
	
	var frames = SpriteFrames.new()
	frames.add_animation("portal")
	frames.set_animation_loop("portal", true)
	frames.set_animation_speed("portal", 8.0)
	
	for i in range(4):
		var img = Image.create(48, 48, false, Image.FORMAT_RGBA8)
		var color_shift = float(i) / 4.0
		
		for x in range(48):
			for y in range(48):
				var dx = x - 24.0
				var dy = y - 24.0
				var dist = sqrt(dx*dx + dy*dy)
				
				var ring_brightness = sin(color_shift * TAU) * 0.4 + 0.6
				if dist > 10.0 and dist < 22.0:
					ring_brightness *= (1.0 - abs(dist - 16.0) / 8.0)
				else:
					ring_brightness = 0.0
				
				var core_brightness = 0.0
				if dist <= 10.0:
					core_brightness = (1.0 - dist / 10.0) * 1.0
				
				var r = ring_brightness * 0.4 + core_brightness * 0.9
				var g = ring_brightness * 0.8 + core_brightness * 0.95
				var b = ring_brightness * 1.0 + core_brightness * 1.0
				var a = maxf(ring_brightness, core_brightness)
				
				img.set_pixel(x, y, Color(r, g, b, a))
		
		var tex = ImageTexture.create_from_image(img)
		frames.add_frame("portal", tex)
	
	portal_sprite.sprite_frames = frames
	portal_sprite.play("portal")
	portal_sprite.modulate = Color(0.6, 0.8, 1.0, 0.2)
	
	var collision = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 80.0
	collision.shape = circle
	exit_zone.add_child(collision)
	
	exit_zone.body_entered.connect(_on_portal_body_entered)
	
	add_child(exit_zone)
	exit_zone.global_position = exit_pos


func _on_portal_body_entered(body: Node) -> void:
	if not portal_active or is_changing_scene:
		return
	if body.is_in_group("Player") or body.name.to_lower().contains("player"):
		print("=== AREA2D BODY ENTERED ===")
		_trigger_scene_change()


func _setup_enemy_spawners() -> void:
	if get_parent() != null:
		spawner_ref = get_parent().get_node_or_null("EnemySpawner") as Node2D
	if spawner_ref == null:
		spawner_ref = get_node_or_null("EnemySpawner") as Node2D
	if spawner_ref == null:
		spawner_ref = SPAWNER_SCENE.instantiate() as Node2D
		if get_parent() != null:
			get_parent().add_child(spawner_ref)
		else:
			add_child(spawner_ref)
	
	spawner_ref.global_position = Vector2.ZERO
	
	var s := spawner_inset
	var positions: Array[Vector2] = [
		Vector2(s, s),
		Vector2(map_size_px.x - s, s),
		Vector2(s, map_size_px.y - s),
		Vector2(map_size_px.x - s, map_size_px.y - s),
		Vector2(map_size_px.x / 2.0, map_size_px.y - s),
	]
	
	var i := 0
	for child in spawner_ref.get_children():
		if child is Marker2D:
			(child as Marker2D).global_position = positions[i % positions.size()]
			i += 1

	if spawner_ref.has_signal("wave_completed"):
		spawner_ref.wave_completed.connect(func():
			if total_unique_kills >= target_dog_kills:
				_activate_portal()
		)


func _activate_portal() -> void:
	if not is_inside_tree():
		return
	if portal_active or exit_zone == null:
		return
		
	if total_unique_kills < target_dog_kills:
		return
	
	portal_active = true
	print("=== ALL 5 UNIQUE DOGS DEFEATED! PORTAL ACTIVATED ===")
	
	if spawner_ref and spawner_ref.has_method("stop"):
		spawner_ref.stop()
	
	var hud := get_tree().get_first_node_in_group("HUD")
	if hud != null and hud.has_method("show_level_cleared"):
		hud.show_level_cleared()
	
	var portal_sprite = exit_zone.get_node_or_null("PortalSprite") as AnimatedSprite2D
	if portal_sprite:
		portal_sprite.show()
		var tween = create_tween()
		tween.tween_property(portal_sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.5)


func _change_scene() -> void:
	var path := "res://scenes/level_2.tscn"
	print("=== ATTEMPTING SCENE CHANGE TO: ", path, " ===")
	
	if not ResourceLoader.exists(path):
		push_error("CRITICAL: res://scenes/level_2.tscn does not exist!")
		is_changing_scene = false
		return

	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		print("=== ERROR: GODOT REJECTED LEVEL 2 LOAD. ERROR CODE: ", err, " ===")
		is_changing_scene = false
