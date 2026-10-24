extends Area2D

const WORLD_LAYER: int = 1
const ENEMY_LAYER: int = 2

@export var speed: float = 800.0
@export var damage: int = 25
@export var lifetime: float = 2.0

var direction: Vector2 = Vector2.RIGHT

static var _shared_texture: ImageTexture = null
var _spent: bool = false


static func _get_texture() -> ImageTexture:
	# Built once and shared by every bullet instead of once per shot.
	if _shared_texture == null:
		var img := Image.create(12, 4, false, Image.FORMAT_RGBA8)
		img.fill(Color(1.0, 0.85, 0.1))
		_shared_texture = ImageTexture.create_from_image(img)
	return _shared_texture


func _ready() -> void:
	collision_layer = 0
	# Hits enemies (layer 2) and stops on walls / props (layer 1).
	collision_mask = WORLD_LAYER | ENEMY_LAYER
	direction = direction.normalized()

	var sprite := Sprite2D.new()
	sprite.texture = _get_texture()
	add_child(sprite)

	# Long thin box so a fast bullet can't skip over thin targets between frames.
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(16.0, 4.0)
	shape.shape = box
	add_child(shape)

	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	var life := Timer.new()
	life.one_shot = true
	life.wait_time = lifetime
	life.autostart = true
	life.timeout.connect(queue_free)
	add_child(life)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta


func _on_body_entered(body: Node2D) -> void:
	if _spent:
		return
	if body.has_method("take_damage"):
		body.take_damage(damage)
	_despawn()  # enemies AND walls stop the bullet


func _on_area_entered(area: Area2D) -> void:
	if _spent:
		return
	if area.has_method("take_damage"):
		area.take_damage(damage)
		_despawn()


func _despawn() -> void:
	_spent = true
	SoundManager.play_sfx("bullet_hit")
	set_deferred("monitoring", false)
	queue_free()
