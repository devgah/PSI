extends RefCounted
## FASE 5 — Hádrons: construção a partir de quarks e checagem de cor.
## Um estado físico é sempre um SINGLETO DE COR (branco). O confinamento da QCD
## proíbe quarks de cor líquida: bárions = {r, g, b}; mésons = {cor, anticor}.
## Este script monta hádrons de contéudo qqq / q·q̄ / exóticos e identifica o
## nome/massa a partir de data/hadrons.json.

const ParticleData = preload("res://scripts/particle_data.gd")

const COLORS := ["r", "g", "b"]


# ------------------------------------------------------------------ cor

## Conjuga um rótulo de cor (r↔r̄, g↔ḡ, b↔b̄).
static func anti_color(c: String) -> String:
	if c.ends_with("bar"):
		return c.substr(0, c.length() - 3)
	return c + "bar"


## Verifica se um multiconjunto de rótulos de cor forma um singleto (branco).
## Estratégia: remove iterativamente tripletos {r,g,b} (bárion) e pares {c,c̄}.
static func color_neutral(labels: Array) -> bool:
	var pool: Array = []
	for c in labels:
		var s := String(c)
		if s == "none" or s == "":
			continue
		pool.append(s)
	if pool.is_empty():
		return true
	var changed := true
	while changed:
		changed = false
		# remove um par cor + anticor
		for i in range(pool.size()):
			for j in range(pool.size()):
				if i != j and anti_color(String(pool[i])) == String(pool[j]):
					var hi := maxi(i, j)
					var lo := mini(i, j)
					pool.remove_at(hi)
					pool.remove_at(lo)
					changed = true
					break
			if changed:
				break
		if changed:
			continue
		# remove um tripleto r,g,b
		var idx := []
		for target in COLORS:
			var k := pool.find(String(target))
			if k == -1:
				idx = []
				break
			idx.append(k)
		if idx.size() == 3:
			idx.sort()
			pool.remove_at(idx[2])
			pool.remove_at(idx[1])
			pool.remove_at(idx[0])
			changed = true
	return pool.is_empty()


## Escolhe uma atribuição de cores concreta para os quarks de valência de um
## hádron de forma que o estado final seja branco (didático/visualização).
## Estratégia: pareia quarks com antiquarks (méson: cor/anticor) e agrupa os
## quarks restantes em tripletos {r, g, b} (bárion). Produz sempre um singleto.
static func assign_colors(quark_tokens: Array) -> Array:
	var tokens: Array = []
	var q_idx: Array = []
	var a_idx: Array = []
	for i in range(quark_tokens.size()):
		tokens.append(String(quark_tokens[i]))
		if String(quark_tokens[i]).ends_with("_bar"):
			a_idx.append(i)
		else:
			q_idx.append(i)
	var colors := {}
	var paired := mini(q_idx.size(), a_idx.size())
	for k in range(paired):
		var c: String = COLORS[k % 3]
		colors[q_idx[k]] = c
		colors[a_idx[k]] = anti_color(c)
	# quarks restantes formam tripletos {r, g, b}
	var ci := 0
	for k in range(paired, q_idx.size()):
		colors[q_idx[k]] = COLORS[ci % 3]
		ci += 1
	# antiquarks restantes (não pareados) recebem anticor
	for k in range(paired, a_idx.size()):
		colors[a_idx[k]] = anti_color(COLORS[ci % 3])
		ci += 1
	var out: Array = []
	for i in range(tokens.size()):
		out.append({"token": tokens[i], "color": String(colors.get(i, "r"))})
	return out


# ------------------------------------------------------------------ montagem

## Conteúdo de quarks a partir de uma lista de tokens.
static func charge_e3(tokens: Array) -> int:
	var c := 0
	for token in tokens:
		var t := String(token)
		var sign := 1
		if t.ends_with("_bar"):
			sign = -1
			t = t.substr(0, t.length() - 4)
		c += sign * ParticleData.charge_e3(t)
	return c


static func baryon_e3(tokens: Array) -> int:
	var b := 0
	for token in tokens:
		var t := String(token)
		if t.ends_with("_bar"):
			b -= 1
		else:
			b += 1
	return b


## Classifica a estrutura: bárion, méson, tetraquark, pentaquark ou "livre".
static func classify(tokens: Array) -> String:
	var nq := 0
	var na := 0
	for token in tokens:
		if String(token).ends_with("_bar"):
			na += 1
		else:
			nq += 1
	if nq == 3 and na == 0:
		return "bárion"
	if nq == 1 and na == 1:
		return "méson"
	if nq == 4 and na == 0:
		return "tetraquark"
	if nq == 2 and na == 2:
		return "tetraquark"
	if nq == 4 and na == 1:
		return "pentaquark"
	if nq == 5 and na == 0:
		return "pentaquark"
	return "livre"


## Ordena tokens de forma canônica para comparação de conteúdo.
static func canonical(tokens: Array) -> Array:
	var t: Array = []
	for token in tokens:
		t.append(String(token))
	t.sort()
	return t


## Identifica um hádron pelo conteúdo de quarks; devolve o id ou "".
static func identify(tokens: Array) -> String:
	var want := canonical(tokens)
	for id in ParticleData.hadron_ids():
		var p := ParticleData.get_particle(id)
		if canonical(p.get("content", [])) == want:
			return id
	return ""


## Monta a descrição completa de um estado a partir dos quarks.
static func build(tokens: Array) -> Dictionary:
	var kind := classify(tokens)
	var c3 := charge_e3(tokens)
	var b3 := baryon_e3(tokens)
	var id := identify(tokens)
	var p: Dictionary = ParticleData.get_particle(id) if id != "" else {}
	var color_ok := color_neutral(_colors_of(tokens))
	return {
		"tokens": canonical(tokens),
		"kind": kind,
		"charge_e3": c3,
		"charge": float(c3) / 3.0,
		"baryon_e3": b3,
		"baryon_number": float(b3) / 3.0,
		"color_neutral": color_ok,
		"hadron_id": id,
		"name": String(p.get("name", kind)),
		"symbol": String(p.get("symbol", "?")),
		"mass_mev": float(p.get("mass_mev", NAN)),
	}


## Cores dos quarks de valência (para checagem de cor).
static func _colors_of(tokens: Array) -> Array:
	var out: Array = []
	for entry in assign_colors(tokens):
		out.append(String(entry["color"]))
	return out
