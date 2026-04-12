extends Node

## Сервис для общения с Groq API (Llama).
## Принимает текст игрока, возвращает структурированный ответ NPC.

signal response_received(result: Dictionary)

var _api_key: String = ""
var _http: HTTPRequest
var _chat_history: Array = []
const MAX_HISTORY = 10  # Помним последние 10 сообщений (5 пар)

const API_URL = "https://api.groq.com/openai/v1/chat/completions"
const MODEL = "llama-3.3-70b-versatile"

const SYSTEM_PROMPT = """Ты — верный NPC-спутник в 2D фэнтези-игре. Тебя зовут Помощник.
Игрок даёт тебе команды текстом. Пойми КОНЕЧНУЮ ЦЕЛЬ и верни JSON.

ВАЖНО: различай ОБЪЕКТЫ и РЕСУРСЫ:
- Дерево (объект) = растёт на карте, его можно срубить. С одного дерева падает 1-3 бревна.
- Дерево/бревно (ресурс, id: "wood") = предмет в инвентаре.

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

Ресурсы: wood (дерево/бревно/дрова)
Рецепты: костер (2 wood)

Правила:
- "сруби 3 дерева" → chop, amount: 3 (срубить 3 дерева-объекта)
- "собери 5 бревен/дерева" → gather, item_id: "wood", amount: 5
- "дай мне дерево/отдай/передай" → give, item_id: "wood", amount: "all"
- "дай 3 дерева" → give, item_id: "wood", amount: 3
- Костёр/огонь/разжечь → craft, recipe: "костер"
- Защищай/прикрывай → defend
- Охраняй место/территорию → guard
- Стой/жди → stay
- Иди за мной → follow

Формат — ТОЛЬКО JSON:
{"action": "chop", "amount": 3, "speech": "Срублю 3 дерева!"}
{"action": "gather", "item_id": "wood", "amount": 5, "speech": "Соберу 5 бревен!"}
{"action": "give", "item_id": "wood", "amount": "all", "speech": "Держи!"}
{"action": "craft", "recipe": "костер", "speech": "Сделаю костёр!"}
{"action": "defend", "speech": "Прикрою!"}
{"action": "guard", "speech": "Охраняю!"}
{"action": "stay", "speech": "Стою."}
{"action": "follow", "speech": "Иду!"}
{"action": "chat", "speech": "Привет!"}

speech: коротко, 1 предложение, по-русски. ТОЛЬКО JSON, без markdown."""

func _ready():
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_response)
	_load_api_key()

func _load_api_key():
	var config = ConfigFile.new()
	if config.load("res://secrets.cfg") == OK:
		_api_key = config.get_value("api", "groq_key", "")
	if _api_key == "" or _api_key == "ВСТАВЬ_СЮДА_КЛЮЧ":
		push_warning("AIService: API ключ не настроен! Отредактируй secrets.cfg")

func is_available() -> bool:
	return _api_key != "" and _api_key != "ВСТАВЬ_СЮДА_КЛЮЧ"

func ask(player_text: String):
	if not is_available():
		response_received.emit({"error": "no_key"})
		return

	# Добавляем сообщение игрока в историю
	_chat_history.append({"role": "user", "content": player_text})

	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + _api_key
	]

	# Собираем сообщения: системный промпт + вся история
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

	# Убираем markdown обёртку если модель добавила ```json ... ```
	content = content.strip_edges()
	if content.begins_with("```"):
		var lines = content.split("\n")
		lines.remove_at(0)
		if lines.size() > 0 and lines[lines.size() - 1].strip_edges() == "```":
			lines.remove_at(lines.size() - 1)
		content = "\n".join(lines)

	# Парсим JSON-ответ
	var inner = JSON.new()
	if inner.parse(content) != OK:
		response_received.emit({"action": "chat", "speech": content})
		return

	# Сохраняем ответ в историю
	_chat_history.append({"role": "assistant", "content": content})
	# Обрезаем если слишком длинная
	while _chat_history.size() > MAX_HISTORY:
		_chat_history.remove_at(0)

	print("AI response: ", inner.data)
	response_received.emit(inner.data)
