extends Area2D

const ENEMY_LAYER: int = 2

@export var damage: int = 35
@export var slash_duration: float = 0.15

var _hit_targets: Array[Node] = []

static var _shared_texture: ImageTexture = null


static func _get_texture() -> ImageTexture:
	if _shared_texture == null:
		var img := Image.create(32, 16, false, Image.FORMAT_RGBA8)
		img.fill(Color(1.0, 1.0, 1.0, 0.8))
		_shared_texture = ImageTexture.create_from_image(img)
	return _shared_texture


func _ready() -> void:
	collision_layer = 0
	collision_mask = ENEMY_LAYER

	var sprite := Sprite2D.new()
	sprite.texture = _get_texture()
	add_child(sprite)

	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(36.0, 20.0)
	shape.shape = box
	add_child(shape)

	body_entered.connect(_on_hit)
	area_entered.connect(_on_hit)

	var life := Timer.new()
	life.one_shot = true
	life.wait_time = slash_duration
	life.autostart = true
	life.timeout.connect(queue_free)
	add_child(life)

	# Enemies already inside the box when it spawns don't always trigger the
	# signal on the very first frame, so check overlaps once as well.
	await get_tree().physics_frame
	if is_inside_tree():
		for body in get_overlapping_bodies():
			_on_hit(body)
		for area in get_overlapping_areas():
			_on_hit(area)


func _on_hit(target: Node) -> void:
	# Each enemy can only be hit once per slash.
	if target in _hit_targets:
		return
	if not target.has_method("take_damage"):
		return
	_hit_targets.append(target)
	target.take_damage(damage)
	SoundManager.play_sword(["sword_hit", "sword_stab"].pick_random())
