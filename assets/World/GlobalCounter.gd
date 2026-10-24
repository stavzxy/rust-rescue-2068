extends Node
## Autoload singleton (Project Settings > Globals > Autoload, name: GlobalCounter)

signal inventory_updated

const PIPE_QUOTA: int = 3
const GUNPOWDER_QUOTA: int = 5

var pipes: int = 0
var gunpowder: int = 0
var apples: int = 0

var gun_unlocked: bool = false


func add_item(item_type: String, amount: int = 1) -> void:
	match item_type.strip_edges().to_lower():
		"pipe":
			pipes += amount
		"gunpowder":
			gunpowder += amount
		"apple":
			apples += amount
		_:
			push_warning("GlobalCounter: unknown item type '%s'" % item_type)
			return

	_check_crafting_quota()
	_notify()


func _check_crafting_quota() -> void:
	if gun_unlocked:
		return
	if pipes >= PIPE_QUOTA and gunpowder >= GUNPOWDER_QUOTA:
		gun_unlocked = true
		pipes -= PIPE_QUOTA
		gunpowder -= GUNPOWDER_QUOTA
		print("--- PISTOL UNLOCKED! Press '2' to switch stances! ---")


func consume_apple() -> bool:
	if apples > 0:
		apples -= 1
		_notify()
		return true
	return false


## Call this when restarting the run (autoloads survive scene reloads).
func reset() -> void:
	pipes = 0
	gunpowder = 0
	apples = 0
	gun_unlocked = false
	_notify()


func _notify() -> void:
	call_deferred("emit_signal", "inventory_updated")
