extends CharacterBody2D

const SPEED = 80.0
const RUN_SPEED = 160.0
const RUN_DIST_THRESHOLD = 200.0
const FOLLOW_DIST = 120.0
const STOP_DIST   = 80.0
const TREE_FOLLOW_DIST = 600.0
const ATTACK_DIST = 30.0
const DAMAGE = 10

enum State { FOLLOWING, MOVING_TO_TREE, ATTACKING, MOVING_TO_CRAFT, COLLECTING }
enum { DOWN, UP, LEFT, RIGHT, UP_LEFT, UP_RIGHT, DOWN_LEFT, DOWN_RIGHT }

var current_state = State.FOLLOWING
var player: Node2D = null
var target_tree: Node2D = null
var idle_dir = DOWN
var current_facing = DOWN
var is_moving = false
var is_attacking = false

# Navigation
var nav_agent: NavigationAgent2D

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
@onready var chat_label = $ChatLabel

var _chat_timer: SceneTreeTimer = null

func _ready():
	add_to_group("npc")

	# Create NavigationAgent2D
	nav_agent = NavigationAgent2D.new()
	nav_agent.path_desired_distance = 4.0
	nav_agent.target_desired_distance = 4.0
	nav_agent.path_max_distance = 50.0
	nav_agent.avoidance_enabled = false
	add_child(nav_agent)

	collision_layer = 1
	collision_mask = 1

	player = get_tree().get_first_node_in_group("player")
	if not player:
		await get_tree().process_frame
		player = get_tree().get_first_node_in_group("player")

	if player:
		if player.has_signal("tree_hit"):
			player.tree_hit.connect(_on_player_hit_tree)

	anim.play("Idle_down")
	hitbox.area_entered.connect(_on_hitbox_area_entered)
	hitbox_shape.disabled = true

# --- Navigation helper ---

func _navigate_to(target_pos: Vector2, speed: float = SPEED) -> Vector2:
	nav_agent.target_position = target_pos
	if nav_agent.is_navigation_finished():
		return Vector2.ZERO
	var next_pos = nav_agent.get_next_path_position()
	var dir = global_position.direction_to(next_pos)
	# Fallback: if nav returns current position, use direct movement
	if dir.length() < 0.01:
		dir = global_position.direction_to(target_pos)
	return dir * speed

# --- Command System ---

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
	for handler_name in command_groups.keys():
		var synonyms = command_groups[handler_name]
		for synonym in synonyms:
			if lower_text.contains(synonym):
				detected_handler = handler_name
				break
		if detected_handler != "":
			break

	if detected_handler != "":
		call(detected_handler, words)
	else:
		show_chat_message("Не понял... Я могу собрать или сделать!")

func _cmd_gather(args: Array):
	print("NPC is gathering with args: ", args)
	var full_text = " ".join(args).to_lower()

	if full_text.contains("дерево") or full_text.contains("дерева") or full_text.contains("дрова") or full_text.contains("древесин"):
		var current_count = NPCInventory.get_item_count("wood")
		var requested_amount = 0

		if full_text.contains("все"):
			requested_amount = 50
		else:
			for arg in args:
				if arg.is_valid_int():
					requested_amount = arg.to_int()
					break
			if requested_amount == 0:
				requested_amount = 1

		var target_total = requested_amount
		if full_text.contains("еще") or (requested_amount == 1 and not full_text.contains("1")):
			target_total = current_count + requested_amount

		pending_gather_id = "wood"
		pending_gather_amount = target_total
		pending_recipe = ""

		show_chat_message("Окей! Добуду " + str(target_total) + " дерева")
		_check_gather_goal()
		return

	if args.size() >= 2:
		show_chat_message("Не знаю, где искать " + args[1])
	else:
		show_chat_message("Что собрать? Скажи: собери дерево")

func _cmd_craft(args: Array):
	var full_text = " ".join(args)
	var found_recipe = ""
	for recipe_name in RECIPES.keys():
		if full_text.contains(recipe_name):
			found_recipe = recipe_name
			break

	if found_recipe != "":
		show_chat_message("Понял, делаю " + found_recipe + "!")
		pending_recipe = found_recipe
		_check_craft_dependencies()
	else:
		show_chat_message("Что сделать? Я умею: " + ", ".join(RECIPES.keys()))

func _check_gather_goal():
	if pending_gather_id == "":
		return
	var count = NPCInventory.get_item_count(pending_gather_id)
	print("NPC: Проверяю сбор ", pending_gather_id, ": ", count, "/", pending_gather_amount)

	if count >= pending_gather_amount:
		show_chat_message("Готово! Собрал " + str(count))
		pending_gather_id = ""
		pending_gather_amount = 0
		current_state = State.FOLLOWING
		return

	if _find_nearby_item():
		current_state = State.COLLECTING
		collect_timer = 3.0
	else:
		_find_nearest_tree()

func _check_craft_dependencies():
	if pending_recipe == "":
		return
	var requirements = RECIPES[pending_recipe]
	var missing_resources = false

	for res_id in requirements:
		var count = NPCInventory.get_item_count(res_id)
		if count < requirements[res_id]:
			missing_resources = true
			break

	if not missing_resources:
		_find_craft_spot()
		return

	if _find_nearby_item():
		current_state = State.COLLECTING
		collect_timer = 3.0
	else:
		_find_nearest_tree()

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
		target_tree = closest_tree
		current_state = State.MOVING_TO_TREE
	else:
		current_state = State.FOLLOWING

func _find_nearby_item() -> bool:
	var items = get_tree().get_nodes_in_group("collectibles")
	var min_dist = 500.0
	for item in items:
		if global_position.distance_to(item.global_position) < min_dist:
			return true
	return false

func _find_craft_spot():
	var items = get_tree().get_nodes_in_group("campspot")
	if items.size() > 0:
		pending_craft_target = items[0]
		current_state = State.MOVING_TO_CRAFT
	else:
		current_state = State.FOLLOWING

# --- Physics / State Machine ---

func _physics_process(delta):
	if current_state == State.MOVING_TO_TREE or current_state == State.ATTACKING:
		if not is_instance_valid(target_tree) or target_tree.is_cut:
			target_tree = null
			is_attacking = false
			hitbox_shape.disabled = true
			if pending_gather_id != "" or pending_recipe != "":
				current_state = State.COLLECTING
				collect_timer = 2.0
			else:
				current_state = State.FOLLOWING

	match current_state:
		State.FOLLOWING:
			_handle_following(delta)
		State.MOVING_TO_TREE:
			_handle_moving_to_tree(delta)
		State.MOVING_TO_CRAFT:
			_handle_moving_to_craft(delta)
		State.COLLECTING:
			_handle_collecting(delta)
		State.ATTACKING:
			pass

func _handle_following(delta):
	if not player:
		return
	var dist = global_position.distance_to(player.global_position)

	if not is_moving and dist > FOLLOW_DIST:
		is_moving = true
	elif is_moving and dist < STOP_DIST:
		is_moving = false

	if is_moving:
		var is_running = dist > RUN_DIST_THRESHOLD
		var spd = RUN_SPEED if is_running else SPEED
		velocity = _navigate_to(player.global_position, spd)
		if velocity.length() > 0:
			_play_walk_animation(velocity.normalized(), is_running)
	else:
		velocity = Vector2.ZERO
		_play_idle_animation()
	move_and_slide()

func _handle_moving_to_tree(delta):
	if not is_instance_valid(target_tree):
		current_state = State.FOLLOWING
		return
	var dist = global_position.distance_to(target_tree.global_position)

	if dist < ATTACK_DIST:
		velocity = Vector2.ZERO
		current_state = State.ATTACKING
		_attack_loop()
	else:
		velocity = _navigate_to(target_tree.global_position, SPEED)
		if velocity.length() > 0:
			_play_walk_animation(velocity.normalized())
		move_and_slide()

func _handle_moving_to_craft(delta):
	if pending_craft_target == null or not is_instance_valid(pending_craft_target):
		current_state = State.FOLLOWING
		pending_recipe = ""
		pending_craft_target = null
		return
	var dist = global_position.distance_to(pending_craft_target.global_position)

	if dist < 30.0:
		velocity = Vector2.ZERO
		_play_idle_animation()
		var retreat_dir = (global_position - pending_craft_target.global_position).normalized()
		global_position += retreat_dir * 15.0

		var target = pending_craft_target
		pending_recipe = ""
		pending_craft_target = null
		current_state = State.FOLLOWING
		is_moving = false

		if target.has_method("try_build"):
			target.try_build(self)
	else:
		velocity = _navigate_to(pending_craft_target.global_position, SPEED)
		if velocity.length() > 0:
			_play_walk_animation(velocity.normalized())
		move_and_slide()

func _handle_collecting(delta):
	var items = get_tree().get_nodes_in_group("collectibles")
	var closest_item = null
	var min_dist = 400.0

	for item in items:
		var dist = global_position.distance_to(item.global_position)
		if dist < min_dist:
			min_dist = dist
			closest_item = item

	if closest_item:
		if min_dist > 10.0:
			velocity = _navigate_to(closest_item.global_position, SPEED)
			if velocity.length() > 0:
				_play_walk_animation(velocity.normalized())
			move_and_slide()
		else:
			velocity = (closest_item.global_position - global_position).normalized() * (SPEED * 0.5)
			move_and_slide()
	else:
		collect_timer -= delta
		if collect_timer <= 0:
			current_state = State.FOLLOWING
			if pending_recipe != "":
				_check_craft_dependencies()
			elif pending_gather_id != "":
				_check_gather_goal()

func _on_player_hit_tree(tree):
	if current_state == State.FOLLOWING:
		target_tree = tree
		current_state = State.MOVING_TO_TREE

# --- Attack ---

func _attack_loop():
	while is_instance_valid(target_tree) and not target_tree.is_cut and current_state == State.ATTACKING:
		var dir_to_tree = (target_tree.global_position - global_position).normalized()
		var attack_dir = _get_dir_enum(dir_to_tree)

		is_attacking = true
		_update_hitbox(attack_dir)
		_start_attack_animation(attack_dir)

		await get_tree().create_timer(0.4).timeout
		await get_tree().create_timer(0.1).timeout

	is_attacking = false
	hitbox_shape.disabled = true
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

# --- Animation ---

func _play_walk_animation(dir: Vector2, is_running: bool = false):
	if is_attacking:
		return
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
	if is_attacking:
		return
	match idle_dir:
		DOWN:       anim.play("Idle_down")
		UP:         anim.play("Idle_up")
		LEFT:       anim.play("Idle_left")
		RIGHT:      anim.play("Idle_right")
		UP_LEFT:    anim.play("Idle_up_left")
		UP_RIGHT:   anim.play("Idle_up_right")
		DOWN_LEFT:  anim.play("Idle_down_left")
		DOWN_RIGHT: anim.play("Idle_down_right")

func needs_pickup() -> bool:
	return pending_gather_id != "" or pending_recipe != ""


func show_chat_message(text: String, duration: float = 3.0):
	chat_label.add_theme_color_override("font_color", Color.WHITE)
	chat_label.scale = Vector2(0.25, 0.25)
	chat_label.visible = true
	chat_label.text = text
	chat_label.visible_ratio = 0.0
	var tween = create_tween()
	tween.tween_property(chat_label, "visible_ratio", 1.0, text.length() * 0.03)
	await tween.finished
	_chat_timer = get_tree().create_timer(duration)
	_chat_timer.timeout.connect(func(): chat_label.visible = false)


func pick_up(item) -> bool:
	if item:
		NPCInventory.add_item(item)
		print("NPC подобрал: ", item.name)
		if current_state == State.COLLECTING:
			collect_timer = 2.0
		if pending_recipe != "":
			_check_craft_dependencies()
		elif pending_gather_id != "":
			_check_gather_goal()
		return true
	return false
