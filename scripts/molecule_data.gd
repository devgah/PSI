extends RefCounted
## FASE 4 — Dados externos de moléculas (data/molecules.json).
## Comprimentos/ângulos/energias de ligação e dipolos (referências experimentais).

const DATA_PATH := "res://data/molecules.json"

const ElementData = preload("res://scripts/element_data.gd")

static var _cache: Dictionary = {}

## Ordem de exibição no seletor da interface.
const DISPLAY_ORDER := [
	"H2", "He2", "Li2", "Be2", "B2", "C2", "N2", "O2", "F2", "Ne2",
	"CO", "HF", "HCl", "H2O", "NH3", "CH4", "CO2", "NaCl",
]


static func _load() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	if f == null:
		push_error("molecules.json não encontrado: %s" % DATA_PATH)
		_cache = {"meta": {}, "molecules": {}}
		return _cache
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed == null:
		push_error("JSON inválido em molecules.json")
		_cache = {"meta": {}, "molecules": {}}
		return _cache
	_cache = parsed
	return _cache


static func meta() -> Dictionary:
	return _load().get("meta", {})


static func count() -> int:
	return (_load().get("molecules", {}) as Dictionary).size()


static func ids() -> Array:
	var out := []
	for id in DISPLAY_ORDER:
		if has(id):
			out.append(id)
	var all_ids := (_load().get("molecules", {}) as Dictionary).keys()
	for id in all_ids:
		if not out.has(id):
			out.append(id)
	return out


static func has(id: String) -> bool:
	return (_load().get("molecules", {}) as Dictionary).has(id)


static func molecule(id: String) -> Dictionary:
	return (_load().get("molecules", {}) as Dictionary).get(id, {})


static func all() -> Dictionary:
	return _load().get("molecules", {})


# ------------------------------------------------------------------ acessores

static func name(id: String) -> String:
	return String(molecule(id).get("name", "?"))


static func formula(id: String) -> String:
	return String(molecule(id).get("formula", "?"))


static func atoms(id: String) -> Array:
	return molecule(id).get("atoms", [])


static func bonds(id: String) -> Array:
	return molecule(id).get("bonds", [])


static func geometry(id: String) -> String:
	return String(molecule(id).get("geometry", ""))


static func bond_length_pm(id: String) -> float:
	var v = molecule(id).get("bond_length_pm", null)
	return float(v) if v != null else NAN


static func bond_angle_deg(id: String) -> float:
	var v = molecule(id).get("bond_angle_deg", null)
	return float(v) if v != null else NAN


static func bond_order(id: String) -> int:
	return int(molecule(id).get("bond_order", 0))


static func bond_energy_ev(id: String) -> float:
	var v = molecule(id).get("bond_energy_ev", null)
	return float(v) if v != null else NAN


static func dipole_debye(id: String) -> float:
	var v = molecule(id).get("dipole_debye", null)
	return float(v) if v != null else NAN


static func hybridization(id: String) -> String:
	return String(molecule(id).get("hybridization", ""))


static func lone_pairs(id: String) -> int:
	return int(molecule(id).get("lone_pairs", 0))


static func note(id: String) -> String:
	return String(molecule(id).get("note", ""))


static func phase(id: String) -> String:
	return String(molecule(id).get("phase", ""))


# ------------------------------------------------------------------ simbólico

static func element_z(id: String) -> int:
	var s := String(molecule(id).get("atoms", [""])[0])
	return ElementData.z_of_symbol(s)
