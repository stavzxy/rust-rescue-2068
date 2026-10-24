extends StaticBody2D

const WORLD_LAYER: int = 1

@export var prop_texture_path: String = ""
@export_range(0.1, 1.0) var collision_scale: float = 0.8


func _ready() -> void:
	collision_layer = WORLD_LAYER
	collision_mask = 0

	if prop_texture_path == "" or not ResourceLoader.exists(prop_texture_path):
		return

	var tex := load(prop_texture_path) as Texture2D
	if tex == null:
		return

	var sprite := Sprite2D.new()
	sprite.texture = tex
	add_child(sprite)

	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = tex.get_size() * collision_scale
	shape.shape = box
	add_child(shape)
