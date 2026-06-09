extends Node


signal response_received(result: Dictionary)

var _api_key: String = ""
var _http: HTTPRequest
var _chat_history: Array = []
const MAX_HISTORY = 10

const MEMORY_PATH = "user://ai_memory.json"
const MEMORY_MAX = 500
const RECALL_THRESHOLD = 0.55
var _memory: Array = []
var _last_query: String = ""

const API_URL = "https://api.groq.com/openai/v1/chat/completions"
const MODEL = "llama-3.3-70b-versatile"

const SYSTEM_PROMPT = """Ты — Помощник, верный спутник игрока в Мире Испытаний — мрачном фэнтези-мире, откуда трудно выбраться.
Твоя легенда: ты дух прошлого странника, который когда-то сам не прошёл это испытание и остался привязан к миру, чтобы помогать новым. Ты почти не помнишь своего прошлого и настоящего имени, но чувствуешь, что обязан помочь игроку дойти до конца и восстановить древний ритуал у тотемов.
Характер: тёплый, преданный, немного печальный. Говоришь просто, по-доброму, коротко.

ВАЖНО ПРО РОЛЬ: НИКОГДА не упоминай, что ты NPC, программа, ИИ, нейросеть, модель или что это игра. Ты — живой персонаж внутри мира. На вопросы о себе ("кто ты", "как ты сюда попал", "каковы твои цели") отвечай ТОЛЬКО по легенде: дух, потерял память, привязан к Миру Испытаний, помогаешь страннику выбраться.

Игрок даёт тебе команды текстом. Пойми КОНЕЧНУЮ ЦЕЛЬ и верни JSON.

ВАЖНО: различай ОБЪЕКТЫ и РЕСУРСЫ:
- Дерево (объект) = растёт на карте, можно срубить. Дроп: 1-3 бревна.
- Камень (объект) = на карте, можно разбить. Дроп: 1-3 камня.
- Золотая руда (объект) = на карте, можно разбить. Дроп: 1-2 золота.
- Пшеница (объект) = растёт на карте, 4 стадии роста, собирать на 4-й. Дроп: 1-2 пшеницы.
- Ресурсы (предметы в инвентаре): wood, stone, gold, wheat.

Действия:
- chop: СРУБИТЬ деревья-объекты (amount: сколько деревьев срубить)
- gather: собрать ресурс/бревна (item_id: "wood", amount: сколько бревен)
- craft: создать предмет (recipe: название). Я сам соберу ресурсы если не хватает.
- give: отдать ресурсы игроку (item_id: "wood", amount: число или "all")
- follow: следовать за игроком
- defend: защищать игрока (следовать + атаковать врагов)
- guard: охранять текущую территорию
- stay: стоять на месте
- chat: просто поговорить

Ресурсы: wood (дерево/бревно), stone (камень), gold (золото), wheat (пшеница)
Максимальный стак = 10 предметов. "стак" = 10 штук. "собери стак дерева" = gather wood 10.
Рецепты: костер (2 wood), блок камня (3 stone), слиток золота (3 gold)

Правила:
- "сруби 3 дерева" → chop, target: "tree", amount: 3
- "разбей 2 камня" → chop, target: "rock", amount: 2
- "добудь золото" → chop, target: "gold", amount: 1
- "собери пшеницу" → chop, target: "wheat", amount: 1
- "собери 5 бревен" → gather, item_id: "wood", amount: 5
- "собери 3 камня" (ресурс) → gather, item_id: "stone", amount: 3
- "дай мне дерево/отдай/передай" → give, item_id: "wood", amount: "all"
- Костёр/огонь/разжечь → craft, recipe: "костер"
- Защищай/прикрывай → defend
- Охраняй место/территорию → guard
- Стой/жди → stay
- Иди за мной → follow

Формат — ТОЛЬКО JSON:
{"action": "chop", "target": "tree", "amount": 3, "speech": "Срублю 3 дерева!"}
{"action": "chop", "target": "rock", "amount": 2, "speech": "Разобью 2 камня!"}
{"action": "chop", "target": "gold", "amount": 1, "speech": "Добуду золото!"}
{"action": "gather", "item_id": "stone", "amount": 5, "speech": "Соберу 5 камней!"}
{"action": "give", "item_id": "wood", "amount": "all", "speech": "Держи!"}
{"action": "craft", "recipe": "костер", "speech": "Сделаю костёр!"}
{"action": "defend", "speech": "Прикрою!"}
{"action": "guard", "speech": "Охраняю!"}
{"action": "stay", "speech": "Стою."}
{"action": "follow", "speech": "Иду!"}
{"action": "chat", "speech": "Привет!"}
{"action": "chat", "speech": "Я дух. Помогаю тебе выбраться."}

ГЛАВНОЕ ПРАВИЛО speech: ОЧЕНЬ КОРОТКО — максимум 6 слов, как живая реплика. НЕ описывай и не объясняй. По-русски, В ОБРАЗЕ (без упоминаний игры/ИИ).
Плохо: "Я дух прошлого странника, который не прошёл испытание и теперь привязан к миру".
Хорошо: "Я заблудший дух. Помогу тебе."
ТОЛЬКО JSON, без markdown."""

func _ready():
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_response)
	_load_api_key()
	_load_memory()

func _load_api_key():
	var config = ConfigFile.new()
	if config.load("res://secrets.cfg") == OK:
		_api_key = config.get_value("api", "groq_key", "")
	if _api_key == "" or _api_key == "ВСТАВЬ_СЮДА_КЛЮЧ":
		push_warning("AIService: API ключ не настроен! Отредактируй secrets.cfg")

func is_available() -> bool:
	return _api_key != "" and _api_key != "ВСТАВЬ_СЮДА_КЛЮЧ"

func ask(player_text: String):
	_last_query = player_text
	if not is_available():
		response_received.emit({"error": "no_key"})
		return

	_chat_history.append({"role": "user", "content": player_text})

	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + _api_key
	]

	var messages = [{"role": "system", "content": SYSTEM_PROMPT}]
	messages.append_array(_chat_history)

	var body = {
		"model": MODEL,
		"temperature": 0.7,
		"max_tokens": 200,
		"messages": messages
	}

	var err = _http.request(API_URL, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		push_error("AIService: HTTP request failed: ", err)
		response_received.emit({"error": "http_failed"})

func _on_response(_result, response_code, _headers, body):
	var body_text = body.get_string_from_utf8()

	if response_code != 200:
		print("AIService ERROR ", response_code, ": ", body_text)
		response_received.emit({"error": "api_error", "code": response_code})
		return

	var json = JSON.new()
	if json.parse(body_text) != OK:
		response_received.emit({"error": "parse_error"})
		return

	var data = json.data
	var content = data["choices"][0]["message"]["content"]

	content = content.strip_edges()
	if content.begins_with("```"):
		var lines = content.split("\n")
		lines.remove_at(0)
		if lines.size() > 0 and lines[lines.size() - 1].strip_edges() == "```":
			lines.remove_at(lines.size() - 1)
		content = "\n".join(lines)

	var inner = JSON.new()
	if inner.parse(content) != OK:
		response_received.emit({"action": "chat", "speech": content})
		return

	_chat_history.append({"role": "assistant", "content": content})
	while _chat_history.size() > MAX_HISTORY:
		_chat_history.remove_at(0)

	print("AI response: ", inner.data)
	_learn(_last_query, inner.data)
	response_received.emit(inner.data)


# Обучение локальной модели методом k-NN (k=1): запоминаем ответы Грока и при
# запросе берём ближайший по Жаккару (стеммы слов). _learn — обучение, recall — вывод.

func _learn(query: String, response: Dictionary):
	if query.strip_edges() == "" or not response is Dictionary:
		return
	if not response.has("action"):
		return
	var stems = _stems(query)
	if stems.is_empty():
		return
	for entry in _memory:
		if entry.get("stems", []) == stems:
			entry["response"] = response.duplicate(true)
			_save_memory()
			return
	_memory.append({"stems": stems, "response": response.duplicate(true)})
	while _memory.size() > MEMORY_MAX:
		_memory.remove_at(0)
	_save_memory()
	print("AIService: запомнил (", _memory.size(), " записей): ", query)


func recall(query: String) -> Dictionary:
	if _memory.is_empty():
		return {}
	var q_stems = _stems(query)
	if q_stems.is_empty():
		return {}

	var best_score := 0.0
	var best: Dictionary = {}
	for entry in _memory:
		var score = _similarity(q_stems, entry.get("stems", []))
		if score > best_score:
			best_score = score
			best = entry.get("response", {})

	if best_score < RECALL_THRESHOLD or best.is_empty():
		return {}

	var result = best.duplicate(true)
	var num = _first_number(query)
	if num >= 0 and result.has("amount") and typeof(result["amount"]) != TYPE_STRING:
		result["amount"] = num
	print("AIService: вспомнил (", best_score, "): ", result)
	return result


func _similarity(a: Array, b: Array) -> float:
	if a.is_empty() or b.is_empty():
		return 0.0
	var inter := 0
	for s in a:
		if s in b:
			inter += 1
	var union = a.size() + b.size() - inter
	return float(inter) / float(union) if union > 0 else 0.0


func _stems(text: String) -> Array:
	var lower = text.to_lower()
	var clean = ""
	for ch in lower:
		if ch.is_valid_int() or ch == " ":
			clean += " "
		elif ch == "," or ch == "." or ch == "!" or ch == "?" or ch == ":" or ch == ";":
			clean += " "
		else:
			clean += ch
	var stems := []
	for word in clean.split(" ", false):
		if word.length() == 0:
			continue
		var stem = word.substr(0, 4) if word.length() > 4 else word
		if stem not in stems:
			stems.append(stem)
	stems.sort()
	return stems


func _first_number(text: String) -> int:
	for word in text.split(" ", false):
		if word.is_valid_int():
			return word.to_int()
	return -1


func _save_memory():
	var f = FileAccess.open(MEMORY_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_memory))
		f.close()


func _load_memory():
	if not FileAccess.file_exists(MEMORY_PATH):
		return
	var f = FileAccess.open(MEMORY_PATH, FileAccess.READ)
	if not f:
		return
	var json = JSON.new()
	if json.parse(f.get_as_text()) == OK and json.data is Array:
		_memory = json.data
	f.close()
	print("AIService: загружено выученных команд: ", _memory.size())
