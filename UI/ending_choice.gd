extends CanvasLayer
## Routes moral choice to CS2.ogv or CS2_wife.ogv
## Supports Mouse hover/clicks + Keyboard (Arrow Keys/WASD + Enter/Space)

@onready var eat_wife_btn: Button = $ChoicePanel/VBoxContainer/EatWifeButton
@onready var eaten_by_wife_btn: Button = $ChoicePanel/VBoxContainer/EatenByWifeButton

var original_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	
	# 1. Unhide and unlock mouse cursor so player can see and move it freely
	original_mouse_mode = Input.get_mouse_mode()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# 2. Connect button press signals
	if eat_wife_btn != null:
		eat_wife_btn.pressed.connect(_on_eat_wife)
	if eaten_by_wife_btn != null:
		eaten_by_wife_btn.pressed.connect(_on_eaten_by_wife)
		
	# 3. Automatically focus the first button for immediate Keyboard / Controller navigation
	if eat_wife_btn != null:
		eat_wife_btn.grab_focus()


func _on_eat_wife() -> void:
	_launch_ending_cutscene("res://assets/Cutscenes/CS2.ogv")


func _on_eaten_by_wife() -> void:
	_launch_ending_cutscene("res://assets/Cutscenes/CS2_wife.ogv")


func _launch_ending_cutscene(video_path: String) -> void:
	get_tree().paused = false
	ProjectSettings.set_setting("global/ending_video_path", video_path)
	
	var ending_scene_path := "res://UI/ending_cutscene.tscn"
	if ResourceLoader.exists(ending_scene_path):
		get_tree().change_scene_to_file(ending_scene_path)
	else:
		get_tree().change_scene_to_file("res://UI/main_menu.tscn")
	queue_free()
