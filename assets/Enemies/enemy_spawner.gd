extends Node2D

signal wave_completed

@export var max_dogs: int = 5
@export var spawn_interval: float = 2.5
@export var start_delay: float = 2.0
@export var spawn_jitter: float = 16.0

const DOG_SCENE_PATH: String = "res://assets/Enemies/DogAnims.tscn"

var dog_scene: PackedScene = null
var spawn_points: Array[Marker2D] = []
var dogs_spawned: int = 0
var dogs_killed: int = 0
var _spawn_index: int = 0
var _running: bool = false
var stopped: bool = false


func _ready() -> void:
	dogs_spawned = 0
	dogs_killed = 0
	dog_scene = load(DOG_SCENE_PATH) as PackedScene
	if dog_scene == null:
		return

	for child in get_children():
		if child is Marker2D:
			spawn_points.append(child)

	var timer := get_node_or_null("EntranceTimer") as Timer
	if timer == null:
		timer = Timer.new()
		timer.name = "EntranceTimer"
		add_child(timer)

	timer.one_shot = true
	timer.wait_time = start_delay
	timer.timeout.connect(_on_entrance_timer_timeout)
	timer.start()


func stop() -> void:
	stopped = true
	_running = false


func _on_entrance_timer_timeout() -> void:
	if _running or stopped:
		return
	_running = true
	_spawn_loop()


func _spawn_loop() -> void:
	while is_inside_tree() and dogs_spawned < max_dogs and not stopped:
		_spawn_single_dog()
		if dogs_spawned < max_dogs and not stopped:
			await get_tree().create_timer(spawn_interval).timeout


func _spawn_single_dog() -> void:
	if stopped or dog_scene == null or spawn_points.is_empty():
		return

	var dog := dog_scene.instantiate() as Node2D
	var marker := spawn_points[_spawn_index % spawn_points.size()]
	_spawn_index += 1
	dogs_spawned += 1

	get_parent().add_child(dog)
	dog.global_position = marker.global_position + Vector2(
		randf_range(-spawn_jitter, spawn_jitter),
		randf_range(-spawn_jitter, spawn_jitter)
	)
	
	# Connect tree_exited to strictly count dog kills
	dog.tree_exited.connect(_on_dog_killed)
	print("Dog %d/%d spawned." % [dogs_spawned, max_dogs])


func _on_dog_killed() -> void:
	dogs_killed += 1
	print("Dogs killed: %d / %d" % [dogs_killed, max_dogs])
	if dogs_killed >= max_dogs:
		print("=== WAVE FULLY CLEARED ===")
		wave_completed.emit()
