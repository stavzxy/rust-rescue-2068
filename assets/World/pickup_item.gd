extends Area2D

const PLAYER_LAYER: int = 4
const FALLBACK_COLORS: Dictionary = {
	"pipe": Color(0.2, 0.5, 1.0),
	"gunpowder": Color(0.6, 0.6, 0.6),
	"apple": Color(0.9, 0.1, 0.1),
}

@export var item_type: String = "pipe"


func _ready() -> void:
	collision_layer = 0
	collision_mask = PLAYER_LAYER  # only the player picks things up

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 16.0
	shape.shape = circle
	add_child(shape)

	var sprite := Sprite2D.new()
	var clean_type := item_type.strip_edges().to_lower()
	var tex_path := "res://assets/Items/" + clean_type + ".png"

	if ResourceLoader.exists(tex_path):
		sprite.texture = load(tex_path) as Texture2D
	else:
		# Visible placeholder instead of an invisible item.
		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(FALLBACK_COLORS.get(clean_type, Color.WHITE))
		sprite.texture = ImageTexture.create_from_image(img)
	add_child(sprite)

	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return
	set_deferred("monitoring", false)  # prevents double pickup
	GlobalCounter.add_item(item_type, 1)
	SoundManager.play_sfx("pickup")
	print("Picked up: ", item_type)
	queue_free()
