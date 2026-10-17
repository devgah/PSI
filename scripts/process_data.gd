extends RefCounted
## FASE 5 — Catálogo de processos (data/processes.json) para o validador de
## leis de conservação. Cada processo lista partículas iniciais/finais, se é
## fraco e se contém bósons virtuais.

const Conservation = preload("res://scripts/conservation.gd")

const PROCESSES_PATH := "res://data/processes.json"

static var _data: Dictionary = {}


static func _load() -> Dictionary:
	if not _data.is_empty():
		return _data
	var f := FileAccess.open(PROCESSES_PATH, FileAccess.READ)
	if f == null:
		push_error("processes.json não encontrado")
		_data = {"meta": {}, "processes": {}}
		return _data
	_data = JSON.parse_string(f.get_as_text())
	if _data == null:
		push_error("JSON inválido em processes.json")
		_data = {"meta": {}, "processes": {}}
	return _data


static func _processes() -> Dictionary:
	return _load().get("processes", {})


static func ids() -> Array:
	return _processes().keys()


static func count() -> int:
	return ids().size()


static func has(id: String) -> bool:
	return _processes().has(id)


static func process(id: String) -> Dictionary:
	return _processes().get(id, {})


static func name(id: String) -> String:
	return String(process(id).get("name", id))


static func equation(id: String) -> String:
	return String(process(id).get("equation", ""))


static func initial(id: String) -> Array:
	return process(id).get("initial", [])


static func final(id: String) -> Array:
	return process(id).get("final", [])


static func is_weak(id: String) -> bool:
	return bool(process(id).get("weak", false))


static func is_virtual(id: String) -> bool:
	return bool(process(id).get("virtual", false))


static func expected(id: String) -> String:
	return String(process(id).get("expected", ""))

static func note(id: String) -> String:
	return String(process(id).get("note", ""))


## Roda o validador para o processo e devolve o resultado + se bate com o esperado.
static func validate(id: String) -> Dictionary:
	var p := process(id)
	var weak := bool(p.get("weak", false))
	var check_energy := not bool(p.get("virtual", false))
	var result := Conservation.validate(p.get("initial", []), p.get("final", []), weak, check_energy)
	result["expected"] = expected(id)
	var allowed := bool(result.get("ok", false))
	result["matches_expected"] = (allowed == (expected(id) == "permitida"))
	return result
