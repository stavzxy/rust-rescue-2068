extends Node2D
## Level 2 Generator - Plain, Rock-Solid Arena Map

@export var map_width: int = 64
@export var map_height: int = 48
@export var tile_size: int = 32
@export var apple_count: int = 14

const PLAYER_SCENE: PackedScene = preload("res://assets/Player/player.tscn")
const PICKUP_SCRIPT: Script = preload("res://assets/World/pickup_item.gd")
const HUD_SCRIPT: Script = preload("res://assets/World/hud.gd")
const BOSS_SCRIPT: Script = preload("res://assets/Boss/boss.gd")

const WORLD_LAYER: int = 1

var map_size_px: Vector2 = Vector2.ZERO


func _ready() -> void:
	SoundManager.play_bgm("ominous")
	map_size_px = Vector2(map_width * tile_size, map_height * tile_size)
	RenderingServer.set_default_clear_color(Color(0.1, 0.08, 0.07))
	_generate.call_deferred()


func _generate() -> void:
	var container: Node = get_parent() if get_parent() != null and get_parent() != get_tree().root else self
	
	# Disable unconfigured TileMapLayers to eliminate black/grey voids
	var old_tilemap = container.get_node_or_null("TileMapLayer")
	if old_tilemap != null:
		old_tilemap.visible = false
		
	_build_arena_walls(container)
	_build_arena_floor(container)
	_spawn_pillars(container)
	_spawn_hud(container)
	_ensure_player(container)
	_setup_camera_limits()
	_spawn_health_apples(container)
	_spawn_boss(container)


func _build_arena_walls(container: Node) -> void:
	var walls := StaticBody2D.new()
	walls.name = "MapWalls"
	walls.collision_layer = WORLD_LAYER
	walls.collision_mask = 0
	container.add_child(walls)
	
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


func _build_arena_floor(container: Node) -> void:
	var center := map_size_px / 2.0
	
	# 1. Dark Slate Base Ground Floor
	var base_floor := ColorRect.new()
	base_floor.name = "ArenaBaseFloor"
	base_floor.position = Vector2.ZERO
	base_floor.size = map_size_px
	base_floor.color = Color(0.14, 0.12, 0.11)
	base_floor.z_index = -100
	container.add_child(base_floor)

	# 2. Outer Hazard Warning Border
	var border := ColorRect.new()
	border.name = "ArenaBorder"
	border.position = Vector2(24, 24)
	border.size = map_size_px - Vector2(48, 48)
	border.color = Color(0.22, 0.16, 0.12)
	border.z_index = -90
	container.add_child(border)

	# 3. Inner Clean Battle Floor
	var inner_floor := ColorRect.new()
	inner_floor.name = "ArenaInnerFloor"
	inner_floor.position = Vector2(48, 48)
	inner_floor.size = map_size_px - Vector2(96, 96)
	inner_floor.color = Color(0.16, 0.14, 0.13)
	inner_floor.z_index = -80
	container.add_child(inner_floor)

	# 4. Central Boss Ring Plate
	var ring_size := Vector2(700, 700)
	var center_plate := ColorRect.new()
	center_plate.name = "CenterRingPlate"
	center_plate.position = center - (ring_size / 2.0)
	center_plate.size = ring_size
	center_plate.color = Color(0.24, 0.14, 0.13)
	center_plate.z_index = -70
	container.add_child(center_plate)


func _spawn_pillars(container: Node) -> void:
	var center := map_size_px / 2.0
	var positions = [
		Vector2(center.x - 380, center.y - 220),
		Vector2(center.x + 380, center.y - 220),
		Vector2(center.x - 380, center.y + 220),
		Vector2(center.x + 380, center.y + 220),
		Vector2(center.x, center.y - 320),
		Vector2(center.x, center.y + 320),
	]
	
	for pos in positions:
		var pillar := StaticBody2D.new()
		pillar.name = "ArenaPillar"
		pillar.collision_layer = WORLD_LAYER
		pillar.collision_mask = 0
		
		var sprite := Sprite2D.new()
		var img := Image.create(48, 64, false, Image.FORMAT_RGBA8)
		for x in range(48):
			for y in range(64):
				var dist = min(min(x, 47-x), min(y, 63-y))
				var shade = 0.25 + (float(dist) / 12.0) * 0.45
				img.set_pixel(x, y, Color(shade, shade * 0.85, shade * 0.7, 1.0))
		sprite.texture = ImageTexture.create_from_image(img)
		pillar.add_child(sprite)
		
		var col := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = Vector2(44, 60)
		col.shape = box
		pillar.add_child(col)
		
		container.add_child(pillar)
		pillar.global_position = pos


func _spawn_hud(container: Node) -> void:
	if get_tree().get_first_node_in_group("HUD") != null:
		return
	var hud := CanvasLayer.new()
	hud.set_script(HUD_SCRIPT)
	container.add_child(hud)


func _ensure_player(container: Node) -> void:
	var center := map_size_px / 2.0
	var spawn_pos := Vector2(center.x, center.y + 380.0)
	
	var player = get_tree().get_first_node_in_group("Player") as Node2D
	if player != null:
		player.global_position = spawn_pos
		return
		
	var new_player = PLAYER_SCENE.instantiate() as Node2D
	container.add_child(new_player)
	new_player.global_position = spawn_pos


func _setup_camera_limits() -> void:
	var player = get_tree().get_first_node_in_group("Player") as Node2D
	if player == null:
		return
	var cam = player.get_node_or_null("Camera2D") as Camera2D
	if cam != null:
		cam.limit_left = 0
		cam.limit_top = 0
		cam.limit_right = int(map_size_px.x)
		cam.limit_bottom = int(map_size_px.y)


func _spawn_health_apples(container: Node) -> void:
	var center := map_size_px / 2.0
	for i in apple_count:
		var item := Area2D.new()
		item.set_script(PICKUP_SCRIPT)
		item.set("item_type", "apple")
		container.add_child(item)
		
		var pos := Vector2.ZERO
		for attempt in 20:
			pos = Vector2(
				randf_range(140, map_size_px.x - 140),
				randf_range(140, map_size_px.y - 140)
			)
			if pos.distance_to(center) > 280.0:
				break
		item.global_position = pos


func _spawn_boss(container: Node) -> void:
	var center := map_size_px / 2.0
	var boss_node := CharacterBody2D.new()
	boss_node.name = "Boss"
	boss_node.set_script(BOSS_SCRIPT)
	
	container.add_child(boss_node)
	boss_node.global_position = center
	print("=== LEVEL 2: ARENA READY & BOSS SPAWNED ===")
