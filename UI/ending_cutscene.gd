extends Control
## Plays selected ending video and returns to Main Menu

@onready var video_player: VideoStreamPlayer = $VideoStreamPlayer
var can_skip: bool = false


func _ready() -> void:
	get_tree().create_timer(0.35).timeout.connect(func(): can_skip = true)
	
	var video_path: String = String(ProjectSettings.get_setting("global/ending_video_path", "res://assets/Cutscenes/CS2.ogv"))
	
	if not ResourceLoader.exists(video_path):
		var ogv_path = video_path.replace(".mp4", ".ogv")
		if ResourceLoader.exists(ogv_path):
			video_path = ogv_path
			
	var stream: VideoStream = null
	if ResourceLoader.exists(video_path):
		var loaded = load(video_path)
		if loaded is VideoStream:
			stream = loaded
		
	if stream != null and video_player != null:
		print("=== PLAYING ENDING CUTSCENE: ", video_path, " ===")
		video_player.stream = stream
		if not video_player.finished.is_connected(_return_to_main_menu):
			video_player.finished.connect(_return_to_main_menu)
		video_player.play()
	else:
		_return_to_main_menu()


func _unhandled_input(event: InputEvent) -> void:
	if not can_skip:
		return
		
	if event.is_pressed() and not event.is_echo():
		if event is InputEventKey or event is InputEventMouseButton:
			_return_to_main_menu()


func _return_to_main_menu() -> void:
	var menu_path := "res://UI/main_menu.tscn"
	if ResourceLoader.exists(menu_path):
		get_tree().change_scene_to_file(menu_path)
	else:
		get_tree().quit()
