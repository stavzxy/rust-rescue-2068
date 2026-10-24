extends Area2D
## Destructible & Transition Exit Portal - Level 1

@export var portal_health: int = 30

var health: int = 30
var alive: bool = true
var portal_sprite: AnimatedSprite2D = null
var is_transitioning: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0xFFFFFFFF
	
	health = portal_health
	_setup_collision()
	_setup_sprite()
	
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	visible = false
	alive = false


func _setup_collision() -> void:
	if get_node_or_null("CollisionShape2D") != null:
		return
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 45.0
	shape.shape = circle
	add_child(shape)


func _setup_sprite() -> void:
	portal_sprite = AnimatedSprite2D.new()
	add_child(portal_sprite)
	
	var frames = SpriteFrames.new()
	frames.add_animation("portal")
	frames.set_animation_loop("portal", true)
	frames.set_animation_speed("portal", 6.0)
	
	for i in range(4):
		var img = Image.create(48, 48, false, Image.FORMAT_RGBA8)
		var color_shift = float(i) / 4.0
		
		for x in range(48):
			for y in range(48):
				var dx = x - 24.0
				var dy = y - 24.0
				var dist = sqrt(dx*dx + dy*dy)
				
				var ring_brightness = sin(color_shift * TAU) * 0.3 + 0.3
				if dist > 15.0 and dist < 22.0:
					ring_brightness *= (1.0 - abs(dist - 18.5) / 6.5)
				
				var core_brightness = 0.0
				if dist < 10.0:
					core_brightness = (1.0 - dist / 10.0) * 0.9
				
				var r = ring_brightness * 0.7 + core_brightness * 1.0
				var g = ring_brightness * 0.5 + core_brightness * 0.3
				var b = ring_brightness * 1.0 + core_brightness * 0.8
				var a = maxf(ring_brightness, core_brightness)
				
				img.set_pixel(x, y, Color(r, g, b, a))
		
		var tex = ImageTexture.create_from_image(img)
		frames.add_frame("portal", tex)
	
	portal_sprite.sprite_frames = frames
	portal_sprite.play("portal")
	portal_sprite.modulate = Color(0.7, 0.6, 1.0, 0.0)


func _activate() -> void:
	alive = true
	visible = true
	health = portal_health
	print("=== EXIT PORTAL ACTIVATED ===")
	
	var tween = create_tween()
	tween.tween_property(portal_sprite, "modulate", Color(0.7, 0.6, 1.0, 1.0), 0.8)


func take_damage(amount: int) -> void:
	if not alive or is_transitioning:
		return
	
	health -= amount
	print("Portal hit! Health: ", health, " / ", portal_health)
	_flash()
	
	if health <= 0:
		_destroy()


func _flash() -> void:
	var tween = create_tween()
	portal_sprite.modulate = Color(1.0, 0.8, 1.0, 1.0)
	tween.tween_property(portal_sprite, "modulate", Color(0.7, 0.6, 1.0, 1.0), 0.1)


func _on_body_entered(body: Node) -> void:
	if not alive or is_transitioning:
		return
	if body.is_in_group("Player") or body.name.to_lower().contains("player"):
		print("=== PLAYER STEPPED INTO PORTAL -> LOADING LEVEL 2 ===")
		_transition_to_level_2()


func _on_area_entered(area: Area2D) -> void:
	if area.has_method("get_damage"):
		take_damage(area.get_damage())


func _destroy() -> void:
	if is_transitioning:
		return
	alive = false
	print("=== PORTAL DESTROYED -> TRANSITIONING TO LEVEL 2 ===")
	
	var tween = create_tween()
	tween.tween_property(portal_sprite, "modulate", Color(1.0, 1.0, 0.5, 0.0), 0.3)
	tween.tween_callback(func(): _transition_to_level_2())


func _transition_to_level_2() -> void:
	if is_transitioning:
		return
	is_transitioning = true
	print("=== ENTERING BOSS ARENA (LEVEL 2) ===")
	
	var target_path := "res://scenes/level_2.tscn"
	if ResourceLoader.exists(target_path):
		get_tree().change_scene_to_file(target_path)
	else:
		push_error("Error: Could not find Level 2 scene file at " + target_path)
		is_transitioning = false
