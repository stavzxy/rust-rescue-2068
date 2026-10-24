extends CanvasLayer

var hud_label: Label
var message_label: Label
var is_level_cleared: bool = false


func _ready() -> void:
	add_to_group("HUD")
	layer = 10

	var panel := PanelContainer.new()
	panel.offset_left = 16.0
	panel.offset_top = 16.0
	panel.offset_right = 320.0
	panel.offset_bottom = 160.0
	add_child(panel)

	hud_label = Label.new()
	hud_label.add_theme_color_override("font_color", Color.WHITE)
	hud_label.add_theme_font_size_override("font_size", 18)
	panel.add_child(hud_label)

	message_label = Label.new()
	message_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 42)
	message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	message_label.visible = false
	add_child(message_label)

	GlobalCounter.inventory_updated.connect(_update_hud)
	_update_hud()


func show_level_cleared() -> void:
	is_level_cleared = true
	_update_hud()


func _update_hud() -> void:
	if not is_instance_valid(hud_label):
		return

	var player := get_tree().get_first_node_in_group("Player")
	var text := ""

	if player != null and "health" in player:
		text += "HP: %d / %d\n" % [player.health, player.max_health]
	else:
		text += "HP: 100 / 100\n"

	text += "Apples: %d  (E: eat)\n" % GlobalCounter.apples

	if GlobalCounter.gun_unlocked:
		if player != null and "current_stance" in player:
			var stance_name: String = str(player.current_stance).to_upper()
			text += "Stance: %s\n" % stance_name
			if stance_name == "PISTOL":
				if player.is_reloading:
					text += "Ammo: RELOADING...\n"
				else:
					text += "Ammo: %d / %d (R: reload)\n" % [player.ammo_in_mag, player.MAX_MAG_SIZE]
			else:
				text += "Keys: 1: Unarmed | 2: Pistol | V: Slash\n"
	else:
		text += "Pipes: %d / %d\n" % [GlobalCounter.pipes, GlobalCounter.PIPE_QUOTA]
		text += "Gunpowder: %d / %d\n" % [GlobalCounter.gunpowder, GlobalCounter.GUNPOWDER_QUOTA]
		text += "Controls: V: Slash | 1: Unarmed\n"

	hud_label.text = text

	var dead: bool = player != null and "is_dead" in player and player.is_dead

	if dead:
		message_label.text = "YOU DIED\nPress R to restart"
		message_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
		message_label.visible = true
	elif is_level_cleared:
		message_label.text = "LEVEL 1 CLEARED!\nEnter the Glowing Portal (North of Center) or Press 'P'"
		message_label.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))
		message_label.visible = true
	else:
		message_label.visible = false
