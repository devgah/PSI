extends RefCounted
## Dados externos dos elementos (data/elements.json) — engenharia orientada a dados.
## Inclui a primeira energia de ionização medida (NIST ASD v5.12).

const DATA_PATH := "res://data/elements.json"

static var _cache: Dictionary = {}


static func _load() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	if f == null:
		push_error("elements.json não encontrado: %s" % DATA_PATH)
		return {"meta": {}, "elements": {}}
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed == null:
		push_error("JSON inválido em elements.json")
		return {"meta": {}, "elements": {}}
	_cache = parsed
	return _cache


static func meta() -> Dictionary:
	return _load().get("meta", {})


static func count() -> int:
	return (_load().get("elements", {}) as Dictionary).size()


static func element(z: int) -> Dictionary:
	return (_load().get("elements", {}) as Dictionary).get(str(z), {})


static func symbol(z: int) -> String:
	return String(element(z).get("sym", "?"))


static func name(z: int) -> String:
	return String(element(z).get("name", "?"))


static func group(z: int) -> int:
	return int(element(z).get("group", 0))


static func period(z: int) -> int:
	return int(element(z).get("period", 0))


static func block(z: int) -> String:
	return String(element(z).get("block", "?"))


static func category(z: int) -> String:
	return String(element(z).get("category", "?"))


## Primeira energia de ionização (eV), valor medido NIST.
static func ie1_ev(z: int) -> float:
	var v = element(z).get("ie1_ev", null)
	return float(v) if v != null else 0.0


static func ie1_unc_ev(z: int) -> float:
	var v = element(z).get("ie1_unc_ev", null)
	return float(v) if v != null else 0.0


static func all_z() -> Array:
	var out := []
	for k in (_load().get("elements", {}) as Dictionary):
		out.append(int(k))
	out.sort()
	return out


## Número atômico a partir do símbolo químico (ex.: "O" -> 8). 0 se ausente.
static func z_of_symbol(sym: String) -> int:
	for zz in all_z():
		if symbol(zz) == sym:
			return zz
	return 0
