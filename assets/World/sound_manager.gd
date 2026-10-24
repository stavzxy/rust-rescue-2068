extends Node
## Global Sound Manager - Aligned with res://assets/audio/ flat structure

var bgm_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
const SFX_POOL_SIZE = 8

# Flat paths directly in res://assets/audio/
var bgm_tracks = {
	"boss": "res://assets/audio/bgm_for_boss_fight.ogg",
	"ominous": "res://assets/audio/bgm_ominous.ogg",
	"upbeat": "res://assets/audio/bgm_upbeat.ogg"
}

var sfx_tracks = {
	"boss_roar": "res://assets/audio/boss_roar.wav",
	"bullet_hit": "res://assets/audio/bullet_hit.wav",
	"craft": "res://assets/audio/craft_completion.wav",
	"dog_attack": "res://assets/audio/dog_attacking.wav",
	"dog_bark": "res://assets/audio/dog_barking.wav",
	"eat": "res://assets/audio/eating.wav",
	"enemy_death": "res://assets/audio/enemy_death.wav",
	"enemy_hurt": "res://assets/audio/enemy_hurt.wav",
	"footsteps": "res://assets/audio/footsteps_on_metal_scrap.wav",
	"pickup": "res://assets/audio/pickup_universal.wav",
	"pistol": "res://assets/audio/pistol_shot.wav",
	"player_hurt": "res://assets/audio/player_hurt.wav",
	"player_death": "res://assets/audio/players_death.wav",
	"sword_stab": "res://assets/audio/sword_stab.wav",
	"sword_swing": "res://assets/audio/sword_swing.wav",
		"ui_click": "res://assets/audio/ui_click.wav",
	"machine_gun": "res://assets/audio/machine_gun_shot_burst.wav",
	"sword_hit": "res://assets/audio/sword_hit.wav",
	"pickup_weapon": "res://assets/audio/pickup_weapons.wav",
	"purify": "res://assets/audio/purify.wav",
	"smith": "res://assets/audio/smithing_hammer.wav",
	"drone": "res://assets/audio/drone.wav",
	"dog_growl": "res://assets/audio/dog_growling.wav"
	
}

var loaded_sfx = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Setup BGM AudioStreamPlayer
	bgm_player = AudioStreamPlayer.new()
	bgm_player.bus = "Master"
	bgm_player.volume_db = -5.0
	add_child(bgm_player)
	
	# Setup SFX AudioStreamPlayer Pool
	for i in range(SFX_POOL_SIZE):
		var p = AudioStreamPlayer.new()
		p.bus = "Master"
		p.volume_db = 5.0
		add_child(p)
		sfx_players.append(p)
		
	# Preload all SFX from res://assets/audio/
	for key in sfx_tracks:
		var path: String = sfx_tracks[key]
		# Fallback checks if files get moved to sfx/ subfolder later
		var alt_path: String = path.replace("assets/audio/", "assets/audio/sfx/")
		
		var final_path: String = ""
		if ResourceLoader.exists(path):
			final_path = path
		elif ResourceLoader.exists(alt_path):
			final_path = alt_path
			
		if final_path != "":
			var res = load(final_path)
			if res is AudioStream:
				loaded_sfx[key] = res
				print("=== SFX LOADED SUCCESSFULLY: ", key, " -> ", final_path, " ===")


func play_bgm(track_name: String) -> void:
	if not bgm_tracks.has(track_name):
		return
		
	var path: String = bgm_tracks[track_name]
	var alt_path: String = path.replace("assets/audio/", "assets/audio/bgm/")
	
	var final_path: String = ""
	if ResourceLoader.exists(path):
		final_path = path
	elif ResourceLoader.exists(alt_path):
		final_path = alt_path
		
	if final_path != "":
		var stream = load(final_path) as AudioStream
		if stream != null and bgm_player.stream != stream:
			bgm_player.stream = stream
			bgm_player.play()
			print("=== PLAYING BGM: ", track_name, " ===")


func stop_bgm() -> void:
	if bgm_player != null:
		bgm_player.stop()


func play_sfx(sfx_name: String) -> void:
	if not loaded_sfx.has(sfx_name):
		return
		
	var stream: AudioStream = loaded_sfx[sfx_name]
	for player in sfx_players:
		if not player.playing:
			player.stream = stream
			player.play()
			return
			
			
var footstep_player: AudioStreamPlayer = null


func start_footsteps() -> void:
	if not loaded_sfx.has("footsteps"):
		return
	if footstep_player == null:
		footstep_player = AudioStreamPlayer.new()
		footstep_player.bus = "Master"
		footstep_player.stream = loaded_sfx["footsteps"]
		add_child(footstep_player)
	if not footstep_player.playing:
		footstep_player.play()


func stop_footsteps() -> void:
	if footstep_player != null:
		footstep_player.stop()


func play_bark() -> void:
	if not loaded_sfx.has("dog_bark"):
		return
	var p := AudioStreamPlayer.new()
	p.bus = "Master"
	p.stream = loaded_sfx["dog_bark"]
	p.volume_db = -8.0
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()

func play_sword(sfx_name: String, vol_db: float = 8.0) -> void:
	if not loaded_sfx.has(sfx_name):
		return
	var p := AudioStreamPlayer.new()
	p.bus = "Master"
	p.stream = loaded_sfx[sfx_name]
	p.volume_db = vol_db
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
