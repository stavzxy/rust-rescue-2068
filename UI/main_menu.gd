extends Control
## Main Menu Script - Connects UI buttons to Intro Cutscene and Exit game

@onready var start_button: Button = $VBoxContainer/StartButton if has_node("VBoxContainer/StartButton") else null
@onready var quit_button: Button = $VBoxContainer/QuitButton if has_node("VBoxContainer/QuitButton") else null


func _ready() -> void:
	if start_button != null:
		start_button.pressed.connect(_on_start_pressed)
	if quit_button != null:
		quit_button.pressed.connect(_on_quit_pressed)


func _on_start_pressed() -> void:
	SoundManager.play_sfx("ui_click")
	var intro_path := "res://UI/intro_cutscene.tscn"
	if ResourceLoader.exists(intro_path):
		get_tree().change_scene_to_file(intro_path)
	else:
		get_tree().change_scene_to_file("res://assets/World/level_1.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()
