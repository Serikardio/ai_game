extends CharacterBody2D

const SPEED = 80.0
const RUN_SPEED = 160.0
const RUN_DIST_THRESHOLD = 200.0
const JUMP_VELOCITY = -400.0
const FOLLOW_DIST = 120.0   # Начинает идти к игроку
const STOP_DIST   = 80.0    # Останавливается у игрока
const TREE_FOLLOW_DIST = 600.0 # Радиус поиска дерева
const ATTACK_DIST = 30.0  # Подходим ближе (было 35)
const DAMAGE = 10

enum State { FOLLOWING, MOVING_TO_TREE, ATTACKING, MOVING_TO_CRAFT, COLLECTING }
enum { DOWN, UP, LEFT, RIGHT, UP_LEFT, UP_RIGHT, DOWN_LEFT, DOWN_RIGHT }

var current_state = State.FOLLOWING
var player: Node2D = null
var target_tree: Node2D = null
var idle_dir = DOWN
var current_facing = DOWN # New variable to track facing direction for idle
var is_moving = false
var is_attacking = false

# Complex Task Data
var pending_recipe = ""
var pending_craft_target = null
var pending_gather_id = ""
var pending_gather_amount = 0
var collect_timer = 0.0
const RECIPES = {
	"костер": {"wood": 2}
}

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var animP: AnimationPlayer = $AnimationPlayer
@onready var hitbox = $"Hit-box"
@onready var hitbox_shape = $"Hit-box/CollisionShape2D"

func _ready():
	add_to_group("npc")
	
	# Настройка коллизий:
	# Layer 1 - NPC (чтобы Area2Ds предметов его видели)
	# Mask 1 - Блокируется окружением (стены, деревья)
	collision_layer = 1
	collision_mask = 1
	
	player = get_tree().get_first_node_in_group("player")
	if not player:
		# Ждем кадра, если игрока еще нет в дереве
		await get_tree().process_frame
		player = get_tree().get_first_node_in_group("player")
		
	if player:
		# Физически игнорируем игрока (чтобы не "липнуть"), но остаемся на том же слое
		add_collision_exception_with(player)
		if player.has_signal("tree_hit"):
			player.tree_hit.connect(_on_player_hit_tree)
	
	anim.play("Idle_down")
	hitbox.area_entered.connect(_on_hitbox_area_entered)
	hitbox_shape.disabled = true


# Command System Data
var command_groups = {
	"_cmd_gather": ["собери", "получи", "возьми", "добудь", "сруби", "принеси", "намайни"],
	"_cmd_craft": ["сделай", "построй", "крафти", "создай", "скрафти", "приготовь"],
}

func receive_command(text: String):
	print("NPC received command: ", text)
	var lower_text = text.to_lower()
	var words = Array(lower_text.strip_edges().split(" ", false))
	if words.size() == 0:
		return
		
	var detected_handler = ""
	
	# Ищем совпадение по группам синонимов
	for handler_name in command_groups.keys():
		var synonyms = command_groups[handler_name]
		for synonym in synonyms:
			if lower_text.contains(synonym):
				detected_handler = handler_name
				break
		if detected_handler != "":
			break
			
	if detected_handler != "":
		# Вызываем соответствующий метод
		call(detected_handler, words)
	else:
		print("NPC: Привет! Я тебя не совсем понял. Я могу что-то собрать или сделать.")

func _cmd_gather(args: Array):
	print("NPC is gathering with args: ", args)
	var full_text = " ".join(args).to_lower()
	
	# Keywords for tree harvesting
	if full_text.contains("дерево") or full_text.contains("дерева") or full_text.contains("дрова") or full_text.contains("древесин"):
		var current_count = NPCInventory.get_item_count("wood")
		var requested_amount = 0
		
		# Check for "все" (all)
		if full_text.contains("все"):
			requested_amount = 50 # High number
		else:
			# Find a number in args
			for arg in args:
				if arg.is_valid_int():
					requested_amount = arg.to_int()
					break
			
			# If no number, assume 1 more
			if requested_amount == 0:
				requested_amount = 1
		
		# Handle "еще" (more) or default to relative if no number provided but "еще" present
		# Actually, let's make it always relative + requested_amount if current_count < target
		# If user says "собери дерево", they likely mean "go get another one"
		# If they say "собери 5", they likely mean "I want 5 in total"
		
		var target_total = requested_amount
		if full_text.contains("еще") or (requested_amount == 1 and not full_text.contains("1")):
			target_total = current_count + requested_amount
		
		# Set gather goal
		pending_gather_id = "wood"
		pending_gather_amount = target_total
		pending_recipe = "" # Clear recipe if manual gathering started
		
		print("NPC: Цель - собрать до ", target_total, " дерева (сейчас ", current_count, ")")
		_check_gather_goal()
		return

	if args.size() >= 2:
		var amount = args[0].to_int()
		var item_type = args[1]
		print("NPC: Иду собирать ", amount, " ", item_type)
		print("NPC: Не знаю, где искать ", item_type)
	elif args.size() == 1:
		print("NPC: Иду собирать ", args[0])
		print("NPC: Не знаю, где искать ", args[0])
	else:
		print("NPC: Уточни, что собрать? Например: 'собери дерево'")

func _find_nearest_tree():
	var trees = get_tree().get_nodes_in_group("trees")
	var closest_tree = null
	var min_dist = INF
	
	for tree in trees:
		if not tree.is_cut:
			var dist = global_position.distance_to(tree.global_position)
			if dist < min_dist:
				min_dist = dist
				closest_tree = tree
				
	if closest_tree:
		print("NPC: Нашел дерево! Иду рубить.")
		target_tree = closest_tree
		current_state = State.MOVING_TO_TREE
	else:
		print("NPC: Рядом нет подходящих деревьев :(")
		current_state = State.FOLLOWING

func _cmd_craft(args: Array):
	print("NPC is crafting check inside: ", args)
	var full_text = " ".join(args)
	
	var found_recipe = ""
	for recipe_name in RECIPES.keys():
		if full_text.contains(recipe_name):
			found_recipe = recipe_name
			break
			
	if found_recipe != "":
		print("NPC: Понял, делаю ", found_recipe)
		pending_recipe = found_recipe
		_check_craft_dependencies()
	else:
		print("NPC: Что именно сделать? Я умею: ", ", ".join(RECIPES.keys()))

func _check_gather_goal():
	if pending_gather_id == "": return
	
	var count = NPCInventory.get_item_count(pending_gather_id)
	print("NPC: Проверяю сбор ", pending_gather_id, ": ", count, "/", pending_gather_amount)
	
	if count >= pending_gather_amount:
		print("NPC: Сбор окончен! У меня уже есть ", count)
		pending_gather_id = ""
		pending_gather_amount = 0
		current_state = State.FOLLOWING
		return
		
	# Still missing items, look for items on ground then trees
	if _find_nearby_item():
		print("NPC: Вижу ресурсы на земле, иду добирать.")
		current_state = State.COLLECTING
		collect_timer = 3.0
	else:
		print("NPC: Ресурсов на земле нет, иду к дереву.")
		_find_nearest_tree()

func _check_craft_dependencies():
	if pending_recipe == "": return
	
	var requirements = RECIPES[pending_recipe]
	var missing_resources = false
	
	for res_id in requirements:
		var count = NPCInventory.get_item_count(res_id)
		print("NPC: Checking ", res_id, " - have ", count, "/", requirements[res_id])
		if count < requirements[res_id]:
			missing_resources = true
			break
			
	if not missing_resources:
		print("NPC: Ресурсы для '", pending_recipe, "' есть. Ищу место для стройки.")
		_find_craft_spot()
		return

	# If missing resources, look for items on the ground first
	print("NPC: Мне не хватает ресурсов для '", pending_recipe, "'. Ищу на земле...")
	if _find_nearby_item():
		print("NPC: Вижу ресурсы на земле! Иду подбирать.")
		current_state = State.COLLECTING
		collect_timer = 3.0 # Increased wait time
	else:
		print("NPC: На земле ничего нет. Попробую срубить.")
		_find_nearest_tree()

func _find_nearby_item() -> bool:
	var items = get_tree().get_nodes_in_group("collectibles")
	var closest_item = null
	var min_dist = 500.0 # Increased search radius for loose items
	
	for item in items:
		var dist = global_position.distance_to(item.global_position)
		if dist < min_dist:
			min_dist = dist
			closest_item = item
	
	return closest_item != null

func _find_craft_spot():
	var items = get_tree().get_nodes_in_group("campspot")
	print("NPC: Found ", items.size(), " potential build spots (group: campspot).")
	if items.size() > 0:
		pending_craft_target = items[0]
		current_state = State.MOVING_TO_CRAFT
		print("NPC: Иду строить ", pending_recipe, " к ", pending_craft_target.name)
	else:
		print("NPC: ОШИБКА: Не нашел места (campspot) для '", pending_recipe, "'. Возвращаюсь к игроку.")
		current_state = State.FOLLOWING

func _physics_process(_delta):
	# Если дерево, которое мы рубили, исчезло — возвращаемся к игроку
	if current_state == State.MOVING_TO_TREE or current_state == State.ATTACKING:
		if not is_instance_valid(target_tree) or target_tree.is_cut:
			target_tree = null
			is_attacking = false
			hitbox_shape.disabled = true
			
			# Переходим к сбору лута ТУЛЬКО если у нас есть активная задача (сбор или крафт)
			if pending_gather_id != "" or pending_recipe != "":
				print("NPC: Цель выполнена, ищу лут для задачи.")
				current_state = State.COLLECTING
				collect_timer = 2.0
			else:
				print("NPC: Помощь закончена, возвращаюсь к игроку.")
				current_state = State.FOLLOWING
	
	# Переключаем логику в зависимости от состояния
	match current_state:
		State.FOLLOWING:
			_handle_following()
		State.MOVING_TO_TREE:
			_handle_moving_to_tree()
		State.MOVING_TO_CRAFT:
			_handle_moving_to_craft()
		State.COLLECTING:
			_handle_collecting(_delta)
		State.ATTACKING:
			pass

func _handle_following():
	if not player: return
	
	var to_player = player.global_position - global_position
	var dist = to_player.length()

	if not is_moving and dist > FOLLOW_DIST:
		is_moving = true
	elif is_moving and dist < STOP_DIST:
		is_moving = false

	if is_moving:
		var dir = to_player.normalized()
		var current_speed = SPEED
		var is_running = false
		
		if dist > RUN_DIST_THRESHOLD:
			current_speed = RUN_SPEED
			is_running = true
			
		velocity = dir * current_speed
		_play_walk_animation(dir, is_running)
	else:
		velocity = Vector2.ZERO
		_play_idle_animation()
	move_and_slide()

func _handle_moving_to_tree():
	if not is_instance_valid(target_tree):
		current_state = State.FOLLOWING
		return
		
	var to_tree = target_tree.global_position - global_position
	var dist = to_tree.length()
	
	if dist < ATTACK_DIST:
		print("NPC: Дошел до дерева, помогаю")
		velocity = Vector2.ZERO
		current_state = State.ATTACKING
		_attack_loop()
	else:
		var dir = to_tree.normalized()
		velocity = dir * SPEED
		_play_walk_animation(dir)
		move_and_slide()

func _handle_moving_to_craft():
	if pending_craft_target == null:
		return
		
	if not is_instance_valid(pending_craft_target):
		print("NPC: Место для стройки потеряно.")
		current_state = State.FOLLOWING
		pending_recipe = ""
		pending_craft_target = null
		return
		
	var to_target = pending_craft_target.global_position - global_position
	var dist = to_target.length()
	
	if dist < 30.0: # Increased from 10.0 for reliability
		print("NPC: Прибыл на место стройки, строю...")
		velocity = Vector2.ZERO
		_play_idle_animation()
		
		# Делаем маааленький шаг назад, чтобы не стоять в центре будущего костра
		var retreat_dir = (global_position - pending_craft_target.global_position).normalized()
		global_position += retreat_dir * 15.0 
		
		# Сбрасываем данные ПЕРЕД вызовом, чтобы не было конфликтов
		var target = pending_craft_target
		pending_recipe = ""
		pending_craft_target = null
		current_state = State.FOLLOWING
		is_moving = false # Принудительно сбрасываем, чтобы начать следование заново
		
		if target.has_method("try_build"):
			target.try_build(self)
	else:
		var dir = to_target.normalized()
		velocity = dir * SPEED
		_play_walk_animation(dir)
		move_and_slide()

func _handle_collecting(delta):
	var items = get_tree().get_nodes_in_group("collectibles")
	var closest_item = null
	var min_dist = 400.0 # Wide search for loot
	
	for item in items:
		var dist = global_position.distance_to(item.global_position)
		if dist < min_dist:
			min_dist = dist
			closest_item = item
			
	if closest_item:
		# Не сбрасываем таймер здесь каждый кадр, иначе он никогда не кончится если мы просто рядом
		var to_item = (closest_item.global_position - global_position)
		if to_item.length() > 10.0:
			var dir = to_item.normalized()
			velocity = dir * SPEED
			_play_walk_animation(dir)
			move_and_slide()
		else:
			# Close enough to pick up (collision should trigger)
			# But we might need a small push or just wait for Area2D
			velocity = to_item.normalized() * (SPEED * 0.5)
			_play_walk_animation(velocity)
			move_and_slide()
	else:
		collect_timer -= delta
		if collect_timer <= 0:
			print("NPC: Больше не вижу лута, проверяю задачу.")
			current_state = State.FOLLOWING
			if pending_recipe != "":
				_check_craft_dependencies()
			elif pending_gather_id != "":
				_check_gather_goal()

func _on_player_hit_tree(tree):
	# Если мы уже рубим что-то, не переключаемся (или можно добавить логику переключения на ближайшее)
	if current_state == State.FOLLOWING:
		print("NPC: Вижу, ты попал по дереву! Иду на помощь.")
		target_tree = tree
		current_state = State.MOVING_TO_TREE



func _attack_loop():
	while is_instance_valid(target_tree) and not target_tree.is_cut and current_state == State.ATTACKING:
		var dir_to_tree = (target_tree.global_position - global_position).normalized()
		var attack_dir = _get_dir_enum(dir_to_tree)
		
		is_attacking = true
		_update_hitbox(attack_dir)
		_start_attack_animation(attack_dir)
		
		# Ждем конца анимации с таймаутом для безопасности
		await get_tree().create_timer(0.4).timeout 
		
		# Короткая пауза
		await get_tree().create_timer(0.1).timeout
		
	is_attacking = false
	hitbox_shape.disabled = true
	# Возвращаемся в FOLLOWING только если мы всё еще в состоянии атаки (не переключились на сбор)
	if current_state == State.ATTACKING:
		current_state = State.FOLLOWING



func _update_hitbox(_dir):
	hitbox_shape.disabled = false

func _get_dir_enum(dir: Vector2):
	if dir.x < -0.4 and dir.y < -0.4: return UP_LEFT
	if dir.x > 0.4 and dir.y < -0.4:  return UP_RIGHT
	if dir.x < -0.4 and dir.y > 0.4:  return DOWN_LEFT
	if dir.x > 0.4 and dir.y > 0.4:   return DOWN_RIGHT
	if abs(dir.x) > abs(dir.y):
		return RIGHT if dir.x > 0 else LEFT
	else:
		return DOWN if dir.y > 0 else UP

func _start_attack_animation(dir):
	match dir:
		DOWN:       animP.play("Attack_down"); idle_dir = DOWN
		UP:         animP.play("Attack_up"); idle_dir = UP
		LEFT:       animP.play("Attack_left"); idle_dir = LEFT
		RIGHT:      animP.play("Attack_right"); idle_dir = RIGHT
		UP_LEFT:    animP.play("Attack_left_up"); idle_dir = UP_LEFT
		UP_RIGHT:   animP.play("Attack_right_up"); idle_dir = UP_RIGHT
		DOWN_LEFT:  animP.play("Attack_left_down"); idle_dir = DOWN_LEFT
		DOWN_RIGHT: animP.play("Attack_right_down"); idle_dir = DOWN_RIGHT

func _on_hitbox_area_entered(area):
	var obj = area.get_parent()
	if obj.has_method("mine"):
		obj.mine(DAMAGE)

func _play_walk_animation(dir: Vector2, is_running: bool = false):
	if is_attacking: return
	idle_dir = _get_dir_enum(dir)
	var prefix = "dash_" if is_running else ""
	
	match idle_dir:
		UP_LEFT:    anim.play(prefix + "up_left")
		UP_RIGHT:   anim.play(prefix + "up_right")
		DOWN_LEFT:  anim.play(prefix + "down_left")
		DOWN_RIGHT: anim.play(prefix + "down_right")
		UP:         anim.play(prefix + "up")
		DOWN:       anim.play(prefix + "down")
		LEFT:       anim.play(prefix + "left")
		RIGHT:      anim.play(prefix + "right")

func _play_idle_animation():
	if is_attacking: return
	match idle_dir:
		DOWN:       anim.play("Idle_down")
		UP:         anim.play("Idle_up")
		LEFT:       anim.play("Idle_left")
		RIGHT:      anim.play("Idle_right")
		UP_LEFT:    anim.play("Idle_up_left")
		UP_RIGHT:   anim.play("Idle_up_right")
		DOWN_LEFT:  anim.play("Idle_down_left")
		DOWN_RIGHT: anim.play("Idle_down_right")

func pick_up(item) -> bool:
	if item:
		NPCInventory.add_item(item)
		print("NPC подобрал: ", item.name)
		
		# Продлеваем таймер сбора если мы в этом состоянии
		if current_state == State.COLLECTING:
			collect_timer = 2.0
		
		# If we were gathering for a recipe, check if we now have enough to build
		if pending_recipe != "":
			_check_craft_dependencies()
		elif pending_gather_id != "":
			_check_gather_goal()
		return true
	return false
