extends RefCounted
## Dados nucleares externos (data/nuclides.json) — NUBASE2020 / AME2020.
## Contém excesso de massa (keV), meia-vida (s) e modos de decaimento dos
## nuclídeos no estado fundamental. Engenharia orientada a dados.

const DATA_PATH := "res://data/nuclides.json"

static var _cache: Dictionary = {}
static var _index: Dictionary = {}


static func _load() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	if f == null:
		push_error("nuclides.json não encontrado: %s" % DATA_PATH)
		_cache = {"meta": {}, "nuclides": []}
		return _cache
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed == null:
		push_error("JSON inválido em nuclides.json")
		_cache = {"meta": {}, "nuclides": []}
		return _cache
	_cache = parsed
	_index.clear()
	for e in _cache.get("nuclides", []):
		_index[_key(int(e["z"]), int(e["a"]))] = e
	return _cache


static func _key(z: int, a: int) -> String:
	return "%d:%d" % [z, a]


static func meta() -> Dictionary:
	return _load().get("meta", {})


static func count() -> int:
	return (_load().get("nuclides", []) as Array).size()


static func has_nuclide(z: int, a: int) -> bool:
	_load()
	return _index.has(_key(z, a))


static func nuclide(z: int, a: int) -> Dictionary:
	_load()
	return _index.get(_key(z, a), {})


## Excesso de massa atômico em keV, ou NAN se desconhecido.
static func mass_excess_kev(z: int, a: int) -> float:
	var e := nuclide(z, a)
	if e.is_empty():
		return NAN
	var v = e.get("me_kev", null)
	return float(v) if v != null else NAN


static func half_life_s(z: int, a: int) -> float:
	var e := nuclide(z, a)
	if e.is_empty():
		return NAN
	if bool(e.get("stable", false)):
		return INF
	var v = e.get("hl_s", null)
	return float(v) if v != null else NAN


static func is_stable(z: int, a: int) -> bool:
	var e := nuclide(z, a)
	return bool(e.get("stable", false)) if not e.is_empty() else false


static func modes(z: int, a: int) -> Array:
	return nuclide(z, a).get("modes", [])


## Símbolo do elemento no nuclídeo (ex.: "Fe"); usa o símbolo bruto da NUBASE.
static func symbol(z: int, a: int) -> String:
	var e := nuclide(z, a)
	return String(e.get("sym", "")) if not e.is_empty() else ""


static func abundance(z: int, a: int) -> float:
	var e := nuclide(z, a)
	var v = e.get("abund", null)
	return float(v) if v != null else 0.0


## Nuclídeo "representativo" do elemento Z: estável de maior abundância
## isotópica; senão o de maior meia-vida; senão o primeiro encontrado.
static func ground_isotope(z: int) -> Dictionary:
	_load()
	var best := {}
	var best_score := -1.0
	for e in _cache.get("nuclides", []):
		if int(e["z"]) != z:
			continue
		var score := -1.0
		if bool(e.get("stable", false)):
			score = 1.0e6 + abundance(z, int(e["a"]))
		else:
			var hl = e.get("hl_s", null)
			if hl != null and is_finite(float(hl)):
				score = float(hl)
		if score > best_score:
			best_score = score
			best = e
	return best


## Lista de A (números de massa) conhecidos para o elemento Z, ordenados.
static func a_list(z: int) -> Array:
	_load()
	var out := []
	for e in _cache.get("nuclides", []):
		if int(e["z"]) == z:
			out.append(int(e["a"]))
	out.sort()
	return out
