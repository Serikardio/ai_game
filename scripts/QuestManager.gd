extends Node


signal quest_updated
signal objective_completed(obj_id)
signal quest_finished

var _finished_emitted: bool = false

var objectives = {
	"gold_block": {"name": "Слиток золота", "current": 0, "required": 3, "done": false},
	"stone_block": {"name": "Блок камня", "current": 0, "required": 3, "done": false},
	"wood": {"name": "Бревно", "current": 0, "required": 6, "done": false},
	"campfire": {"name": "Костёр у тотемов", "current": 0, "required": 1, "done": false},
}

var quest_active: bool = false
var quest_complete: bool = false

func start_quest():
	quest_active = true
	quest_updated.emit()

func deliver_items() -> Array[String]:
	if not quest_active or quest_complete:
		return []

	var delivered: Array[String] = []

	for obj_id in objectives:
		var obj = objectives[obj_id]
		if obj.done or obj_id == "campfire":
			continue

		var has = Inventory.get_item_count(obj_id)
		if has <= 0:
			continue

		var need = obj.required - obj.current
		var give = mini(has, need)
		if give > 0:
			Inventory.remove_item(obj_id, give)
			obj.current += give
			var was_done = obj.done
			obj.done = obj.current >= obj.required
			delivered.append(obj.name + " x" + str(give))
			if obj.done and not was_done:
				objective_completed.emit(obj_id)

	_check_all_complete()
	quest_updated.emit()
	return delivered

func complete_campfire():
	if not quest_active:
		return
	var was_done = objectives.campfire.done
	objectives.campfire.current = 1
	objectives.campfire.done = true
	if not was_done:
		objective_completed.emit("campfire")
	_check_all_complete()
	quest_updated.emit()

func _check_all_complete():
	for obj in objectives.values():
		if not obj.done:
			quest_complete = false
			return
	quest_complete = true
	if not _finished_emitted:
		_finished_emitted = true
		quest_finished.emit()

func get_remaining_text() -> String:
	var parts = []
	for obj in objectives.values():
		if not obj.done:
			parts.append(obj.name + " " + str(obj.current) + "/" + str(obj.required))
	if parts.size() == 0:
		return "Всё собрано!"
	return "Нужно ещё: " + ", ".join(parts)
