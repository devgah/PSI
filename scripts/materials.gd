extends RefCounted
## FASE 4 — Dados externos de reações químicas (data/reactions.json) e de
## materiais + interações fracas (data/materials.json).

const REACTIONS_PATH := "res://data/reactions.json"
const MATERIALS_PATH := "res://data/materials.json"

static var _reactions: Dictionary = {}
static var _materials: Dictionary = {}


static func _load_reactions() -> Dictionary:
	if not _reactions.is_empty():
		return _reactions
	var f := FileAccess.open(REACTIONS_PATH, FileAccess.READ)
	if f == null:
		push_error("reactions.json não encontrado")
		_reactions = {"meta": {}, "reactions": {}}
		return _reactions
	_reactions = JSON.parse_string(f.get_as_text())
	if _reactions == null:
		push_error("JSON inválido em reactions.json")
		_reactions = {"meta": {}, "reactions": {}}
	return _reactions


static func _load_materials() -> Dictionary:
	if not _materials.is_empty():
		return _materials
	var f := FileAccess.open(MATERIALS_PATH, FileAccess.READ)
	if f == null:
		push_error("materials.json não encontrado")
		_materials = {"meta": {}, "materials": {}, "weak_interactions": {}}
		return _materials
	_materials = JSON.parse_string(f.get_as_text())
	if _materials == null:
		push_error("JSON inválido em materials.json")
		_materials = {"meta": {}, "materials": {}, "weak_interactions": {}}
	return _materials


# -------------------------------------------------------------------- reações

static func reactions_meta() -> Dictionary:
	return _load_reactions().get("meta", {})


static func reaction_ids() -> Array:
	return (_load_reactions().get("reactions", {}) as Dictionary).keys()


static func reaction_count() -> int:
	return reaction_ids().size()


static func has_reaction(id: String) -> bool:
	return (_load_reactions().get("reactions", {}) as Dictionary).has(id)


static func reaction(id: String) -> Dictionary:
	return (_load_reactions().get("reactions", {}) as Dictionary).get(id, {})


static func reaction_dh_kj(id: String) -> float:
	return float(reaction(id).get("dh_kj", 0.0))


static func reaction_ds_j_k(id: String) -> float:
	return float(reaction(id).get("ds_j_k", 0.0))


static func reaction_ea_kj(id: String) -> float:
	return float(reaction(id).get("ea_kj", 0.0))


static func reaction_ea_catalyzed_kj(id: String) -> float:
	var v = reaction(id).get("ea_catalyzed_kj", null)
	return float(v) if v != null else NAN


static func reaction_catalyst(id: String) -> String:
	return String(reaction(id).get("catalyst", ""))


static func reaction_equation(id: String) -> String:
	return String(reaction(id).get("equation", ""))


static func reaction_name(id: String) -> String:
	return String(reaction(id).get("name", ""))


static func reaction_note(id: String) -> String:
	return String(reaction(id).get("note", ""))


# ------------------------------------------------------------------ materiais

static func materials_meta() -> Dictionary:
	return _load_materials().get("meta", {})


static func material_ids() -> Array:
	return (_load_materials().get("materials", {}) as Dictionary).keys()


static func material_count() -> int:
	return material_ids().size()


static func has_material(id: String) -> bool:
	return (_load_materials().get("materials", {}) as Dictionary).has(id)


static func material(id: String) -> Dictionary:
	return (_load_materials().get("materials", {}) as Dictionary).get(id, {})


static func material_name(id: String) -> String:
	return String(material(id).get("name", "?"))


static func material_formula(id: String) -> String:
	return String(material(id).get("formula", "?"))


static func material_structure(id: String) -> String:
	return String(material(id).get("structure", ""))


static func material_bonding(id: String) -> String:
	return String(material(id).get("bonding", ""))


static func material_band_gap_ev(id: String) -> float:
	var v = material(id).get("band_gap_ev", null)
	return float(v) if v != null else NAN


static func material_conduction(id: String) -> String:
	return String(material(id).get("conduction", ""))


static func material_note(id: String) -> String:
	return String(material(id).get("note", ""))


# --------------------------------------------------------- interações fracas

static func weak_interaction_ids() -> Array:
	return (_load_materials().get("weak_interactions", {}) as Dictionary).keys()


static func weak_interaction(id: String) -> Dictionary:
	return (_load_materials().get("weak_interactions", {}) as Dictionary).get(id, {})


static func weak_interaction_name(id: String) -> String:
	return String(weak_interaction(id).get("name", "?"))


static func weak_interaction_energy_range(id: String) -> Array:
	return weak_interaction(id).get("energy_kj_range", [])
