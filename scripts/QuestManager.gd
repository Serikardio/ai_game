extends Node

## Глобальный менеджер квестов.
## Предметы нужно ПРИНЕСТИ тотемам, а не просто собрать.

signal quest_updated

var objectives = {
	"gold_block": {"name": "Слиток золота", "current": 0, "required": 3, "done": false},
	"stone_block": {"name": "Блок камня", "current": 0, "required": 3, "done": false},
	"wood": {"name": "Бревно", "current": 0, "required": 20, "done": false},
	"campfire": {"name": "Костёр у тотемов", "current": 0, "required": 1, "done": false},
}

var quest_active: bool = false
var quest_complete: bool = false

func start_quest():
	quest_active = true
	quest_updated.emit()

## Игрок сдаёт предметы тотему. Возвращает что принял.
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
			obj.done = obj.current >= obj.required
			delivered.append(obj.name + " x" + str(give))

	_check_all_complete()
	quest_updated.emit()
	return delivered

func complete_campfire():
	if not quest_active:
		return
	objectives.campfire.current = 1
	objectives.campfire.done = true
	_check_all_complete()
	quest_updated.emit()

func _check_all_complete():
	for obj in objectives.values():
		if not obj.done:
			quest_complete = false
			return
	quest_complete = true

func get_remaining_text() -> String:
	var parts = []
	for obj in objectives.values():
		if not obj.done:
			parts.append(obj.name + " " + str(obj.current) + "/" + str(obj.required))
	if parts.size() == 0:
		return "Всё собрано!"
	return "Нужно ещё: " + ", ".join(parts)
