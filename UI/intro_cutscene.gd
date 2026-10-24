extends Control
## Intro Cutscene Player - Streams CS1.ogv with input debounce buffer

@onready var video_player: VideoStreamPlayer = $VideoStreamPlayer
var can_skip: bool = false


func _ready() -> void:
	# Debounce buffer to ignore the click used to launch from Main Menu
	get_tree().create_timer(0.35).timeout.connect(func(): can_skip = true)
	
	var video_paths = [
		"res://assets/Cutscenes/CS1.ogv",
		"res://assets/Cutscenes/CS1 .mp4",
		"res://assets/Cutscenes/CS1.mp4"
	]
	
	var stream: VideoStream = null
	for path in video_paths:
		if ResourceLoader.exists(path):
			var loaded = load(path)
			if loaded is VideoStream:
				stream = loaded
				print("=== INTRO VIDEO LOADED: ", path, " ===")
				break
				
	if stream != null and video_player != null:
		video_player.stream = stream
		if not video_player.finished.is_connected(_start_level_1):
			video_player.finished.connect(_start_level_1)
		video_player.play()
	else:
		print("=== NO VALID VIDEO STREAM FOUND. GOING TO LEVEL 1 ===")
		_start_level_1()


func _unhandled_input(event: InputEvent) -> void:
	if not can_skip:
		return
		
	if event.is_pressed() and not event.is_echo():
		if event is InputEventKey or event is InputEventMouseButton:
			print("=== INTRO CUTSCENE SKIPPED ===")
			_start_level_1()


func _start_level_1() -> void:
	var possible_level_paths = [
		"res://level_1.tscn",
		"res://scenes/level_1.tscn",
		"res://assets/World/level_1.tscn",
		"res://World/level_1.tscn"
	]
	
	for path in possible_level_paths:
		if ResourceLoader.exists(path):
			print("=== LOADING LEVEL 1 AT: ", path, " ===")
			get_tree().change_scene_to_file(path)
			return
			
	push_error("ERROR: level_1.tscn missing!")
