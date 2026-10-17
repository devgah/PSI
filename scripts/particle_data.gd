extends RefCounted
## FASE 5 — Modelo Padrão: catálogo de partículas elementares e hádrons.
## Carrega data/particles.json (6 quarks + anti, 12 léptons, bósons) e
## data/hadrons.json (bárions, mésons, exóticos). As antipartículas de hádrons
## são derivadas automaticamente (conteúdo de quarks conjugado).
##
## Convenções numéricas (inteiros exatos, evitam erro de ponto flutuante):
##   charge_e3  = carga elétrica em unidades de e/3
##   baryon_e3  = número bariônico em unidades de 1/3
##   spin2      = 2J
##   le/lmu/ltau = número leptônico por família
##   strangeness/charm/bottomness/topness = números quânticos de sabor

const PARTICLES_PATH := "res://data/particles.json"
const HADRONS_PATH := "res://data/hadrons.json"

static var _particles: Dictionary = {}
static var _hadrons: Dictionary = {}
static var _table: Dictionary = {}
static var _quarks: Dictionary = {}
static var _loaded := false


# ------------------------------------------------------------------ carregamento

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_particles = _load_json(PARTICLES_PATH, ["quarks", "leptons", "bosons"])
	_hadrons = _load_json(HADRONS_PATH, ["hadrons"])
	_quarks = _particles.get("quarks", {})
	_build_table()


static func _load_json(path: String, keys: Array) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	var empty := {"meta": {}}
	for k in keys:
		empty[k] = {}
	if f == null:
		push_error("Arquivo não encontrado: " + path)
		return empty
	var data = JSON.parse_string(f.get_as_text())
	if data == null:
		push_error("JSON inválido em " + path)
		return empty
	return data


static func _build_table() -> void:
	_table = {}
	# partículas elementares já vêm com todas as antipartículas explícitas
	for group in ["quarks", "leptons", "bosons"]:
		for id in (_particles.get(group, {}) as Dictionary):
			var d: Dictionary = (_particles[group][id] as Dictionary).duplicate(true)
			d["id"] = id
			d["group"] = group
			_fill_defaults(d)
			_table[id] = d
	# hádrons + antipartículas derivadas
	for id in (_hadrons.get("hadrons", {}) as Dictionary):
		var src: Dictionary = _hadrons["hadrons"][id]
		var d := _build_hadron(id, src)
		_table[id] = d
		_table["anti_" + id] = _conjugate_hadron(d)


static func _fill_defaults(d: Dictionary) -> void:
	d["name"] = String(d.get("name", d.get("id", "?")))
	d["charge_e3"] = int(d.get("charge_e3", 0))
	d["baryon_e3"] = int(d.get("baryon_e3", 0))
	d["spin2"] = int(d.get("spin2", 0))
	d["le"] = int(d.get("le", 0))
	d["lmu"] = int(d.get("lmu", 0))
	d["ltau"] = int(d.get("ltau", 0))
	d["strangeness"] = int(d.get("strangeness", 0))
	d["charm"] = int(d.get("charm", 0))
	d["bottomness"] = int(d.get("bottomness", 0))
	d["topness"] = int(d.get("topness", 0))
	d["mass_mev"] = float(d.get("mass_mev", 0.0))
	d["color"] = String(d.get("color", "none"))


static func _build_hadron(id: String, src: Dictionary) -> Dictionary:
	var content: Array = src.get("content", [])
	var charge := 0
	var baryon := 0
	var s := 0
	var c := 0
	var bb := 0
	var tt := 0
	for token in content:
		var sign := 1
		var base := String(token)
		if base.ends_with("_bar"):
			sign = -1
			base = base.substr(0, base.length() - 4)
		var q: Dictionary = _quarks.get(base, {})
		charge += sign * int(q.get("charge_e3", 0))
		baryon += sign * int(q.get("baryon_e3", 1))
		s += sign * int(q.get("strangeness", 0))
		c += sign * int(q.get("charm", 0))
		bb += sign * int(q.get("bottomness", 0))
		tt += sign * int(q.get("topness", 0))
	return {
		"id": id,
		"name": String(src.get("name", id)),
		"symbol": String(src.get("symbol", id)),
		"group": "hadron",
		"sector": String(src.get("sector", "")),
		"jpi": String(src.get("jpi", "")),
		"content": content.duplicate(),
		"charge_e3": charge,
		"baryon_e3": baryon,
		"spin2": int(src.get("spin2", 0)),
		"mass_mev": float(src.get("mass_mev", 0.0)),
		"lifetime_s": src.get("lifetime_s", null),
		"le": 0, "lmu": 0, "ltau": 0,
		"strangeness": s, "charm": c, "bottomness": bb, "topness": tt,
		"color": "none",
	}


static func _conjugate_hadron(d: Dictionary) -> Dictionary:
	var content: Array = []
	for token in d["content"]:
		var t := String(token)
		if t.ends_with("_bar"):
			content.append(t.substr(0, t.length() - 4))
		else:
			content.append(t + "_bar")
	var out := d.duplicate(true)
	out["id"] = "anti_" + String(d["id"])
	out["name"] = "anti-" + String(d["name"])
	out["symbol"] = "anti-" + String(d.get("symbol", ""))
	out["content"] = content
	out["charge_e3"] = -int(d["charge_e3"])
	out["baryon_e3"] = -int(d["baryon_e3"])
	out["strangeness"] = -int(d["strangeness"])
	out["charm"] = -int(d["charm"])
	out["bottomness"] = -int(d["bottomness"])
	out["topness"] = -int(d["topness"])
	return out


# ----------------------------------------------------------------- acesso

static func has(id: String) -> bool:
	_ensure_loaded()
	return _table.has(id)


static func get_particle(id: String) -> Dictionary:
	_ensure_loaded()
	return _table.get(id, {})


static func ids() -> Array:
	_ensure_loaded()
	return _table.keys()


static func charge_e3(id: String) -> int:
	return int(get_particle(id).get("charge_e3", 0))


static func charge(id: String) -> float:
	return float(charge_e3(id)) / 3.0


static func baryon_e3(id: String) -> int:
	return int(get_particle(id).get("baryon_e3", 0))


static func baryon_number(id: String) -> float:
	return float(baryon_e3(id)) / 3.0


static func spin2(id: String) -> int:
	return int(get_particle(id).get("spin2", 0))


static func spin(id: String) -> float:
	return float(spin2(id)) / 2.0


static func mass_mev(id: String) -> float:
	return float(get_particle(id).get("mass_mev", 0.0))


static func name(id: String) -> String:
	return String(get_particle(id).get("name", id))


static func symbol(id: String) -> String:
	var p := get_particle(id)
	var s := String(p.get("symbol", ""))
	if s != "":
		return s
	return _derive_symbol(id)


const _ELEM_SYMBOLS := {
	"e-": "e⁻", "e+": "e⁺", "mu-": "μ⁻", "mu+": "μ⁺",
	"tau-": "τ⁻", "tau+": "τ⁺", "nu_e": "ν_e", "nu_e_bar": "ν̄_e",
	"nu_mu": "ν_μ", "nu_mu_bar": "ν̄_μ", "nu_tau": "ν_τ", "nu_tau_bar": "ν̄_τ",
	"gamma": "γ", "g": "g", "W+": "W⁺", "W-": "W⁻", "Z0": "Z⁰", "H": "H",
}


static func _derive_symbol(id: String) -> String:
	if _ELEM_SYMBOLS.has(id):
		return _ELEM_SYMBOLS[id]
	if id.begins_with("anti_"):
		return "anti-" + _derive_symbol(id.substr(5))
	if id.ends_with("_bar"):
		return id.substr(0, id.length() - 4) + "̄"
	return id


static func group(id: String) -> String:
	return String(get_particle(id).get("group", ""))


static func is_fermion(id: String) -> bool:
	return spin2(id) % 2 == 1


static func is_quark(id: String) -> bool:
	return group(id) == "quark"


static func is_lepton(id: String) -> bool:
	return group(id) == "lepton"


static func is_hadron(id: String) -> bool:
	return group(id) == "hadron"


static func is_antiparticle(id: String) -> bool:
	return id.begins_with("anti_") or id.ends_with("_bar")


static func flavor(id: String) -> Dictionary:
	var p := get_particle(id)
	return {
		"strangeness": int(p.get("strangeness", 0)),
		"charm": int(p.get("charm", 0)),
		"bottomness": int(p.get("bottomness", 0)),
		"topness": int(p.get("topness", 0)),
	}


static func lepton_numbers(id: String) -> Dictionary:
	var p := get_particle(id)
	return {
		"le": int(p.get("le", 0)),
		"lmu": int(p.get("lmu", 0)),
		"ltau": int(p.get("ltau", 0)),
	}


static func quarks_meta() -> Dictionary:
	_ensure_loaded()
	return _particles.get("meta", {})


static func elementary_ids_by_group(g: String) -> Array:
	_ensure_loaded()
	return (_particles.get(g, {}) as Dictionary).keys()


static func hadron_ids() -> Array:
	_ensure_loaded()
	return (_hadrons.get("hadrons", {}) as Dictionary).keys()
