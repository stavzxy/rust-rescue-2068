extends CharacterBody2D
## Wife NPC - Physical body + Interaction Area

var interact_prompt: Label = null
var sprite: Sprite2D = null
var interact_area: Area2D = null
var player_in_range: bool = false
var activated: bool = false


func _ready() -> void:
	# Set player layer and mask to ensure solid physics collision
	collision_layer = 1
	collision_mask = 1
	
	_setup_sprite()
	_setup_physics_body()
	_setup_interact_area()
	_setup_prompt()


func _setup_sprite() -> void:
	sprite = Sprite2D.new()
	sprite.scale = Vector2(1.0, 1.0)
	
	var path := "res://assets/Cutscenes/wife.png"
	if ResourceLoader.exists(path):
		var tex = load(path) as Texture2D
		if tex != null:
			sprite.texture = tex
			
	add_child(sprite)


func _setup_physics_body() -> void:
	# Solid physical box so player cannot walk through her
	var phys_col := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(32.0, 32.0)
	phys_col.shape = box
	add_child(phys_col)


func _setup_interact_area() -> void:
	interact_area = Area2D.new()
	interact_area.collision_layer = 0
	interact_area.collision_mask = 1 | 2 | 4 | 8 | 16 # Detects player across all layers
	
	var area_col := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 120.0 # Generous interaction range
	area_col.shape = circle
	interact_area.add_child(area_col)
	
	interact_area.body_entered.connect(_on_body_entered)
	interact_area.body_exited.connect(_on_body_exited)
	add_child(interact_area)


func _setup_prompt() -> void:
	interact_prompt = Label.new()
	interact_prompt.text = "[ PRESS F / CLICK TO TALK ]"
	interact_prompt.position = Vector2(-110, -60)
	interact_prompt.add_theme_color_override("font_color", Color(1.0, 0.6, 0.1, 1.0))
	interact_prompt.add_theme_font_size_override("font_size", 16)
	interact_prompt.hide()
	add_child(interact_prompt)


func _on_body_entered(body: Node) -> void:
	print("=== ENTERED WIFE PROXIMITY: ", body.name, " ===")
	player_in_range = true
	if interact_prompt != null:
		interact_prompt.show()


func _on_body_exited(body: Node) -> void:
	player_in_range = false
	if interact_prompt != null:
		interact_prompt.hide()


func _unhandled_input(event: InputEvent) -> void:
	if activated or not player_in_range:
		return
		
	if event.is_pressed() and not event.is_echo():
		if (event is InputEventKey and event.keycode == KEY_F) or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
			get_viewport().set_input_as_handled()
			_trigger_ending_choice()


func _trigger_ending_choice() -> void:
	activated = true
	if interact_prompt != null:
		interact_prompt.hide()
		
	print("=== WIFE INTERACTED -> OPENING ENDING CHOICE UI ===")
	
	var choice_scene = load("res://UI/ending_choice.tscn") as PackedScene
	if choice_scene != null:
		var choice_ui = choice_scene.instantiate()
		get_tree().root.add_child(choice_ui)
	else:
		push_error("ERROR: res://UI/ending_choice.tscn could not be loaded!")
