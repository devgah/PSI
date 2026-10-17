extends RefCounted
## FASE 4 — Orbitais moleculares (LCAO-MO) para moléculas diatômicas.
## Diagrama esquemático; preenchimento por Aufbau + regra de Hund. A ordem
## relativa σ2p / π2p segue o resultado padrão da mistura s-p:
##   valência total ≤ 10 elétrons  → π2p abaixo de σ2p  (B₂, C₂, N₂, CO)
##   valência total ≥ 11 elétrons  → σ2p abaixo de π2p  (O₂, F₂, Ne₂)
## As energias são ilustrativas (unidades arbitrárias); a ORDEM e o
## preenchimento é que têm significado físico.

const ElementData = preload("res://scripts/element_data.gd")


# ------------------------------------------------------------- elétrons de valência

static func valence_from_z(z: int) -> int:
	if z <= 0:
		return 0
	if z == 2:
		return 2  # He: 1s²
	var g := ElementData.group(z)
	if g >= 1 and g <= 2:
		return g
	if g >= 13 and g <= 18:
		return g - 10
	return 0


static func valence_electrons(sym: String) -> int:
	return valence_from_z(ElementData.z_of_symbol(sym))


# ------------------------------------------------------------- diagrama genérico

## Preenche uma lista de subcamadas {label, deg, energy, type} e devolve o
## dicionário completo do diagrama.
static func _fill(levels: Array, n_total: int) -> Dictionary:
	var remaining := n_total
	for o in levels:
		var cap := 2 * int(o["deg"])
		var e := mini(remaining, cap)
		o["electrons"] = e
		remaining -= e

	var bonding := 0
	var antibonding := 0
	var unpaired := 0
	for o in levels:
		var e := int(o["electrons"])
		if String(o["type"]) == "bonding":
			bonding += e
		elif String(o["type"]) == "antibonding":
			antibonding += e
		unpaired += _unpaired_in(int(o["deg"]), e)

	var homo := ""
	var lumo := ""
	var homo_e := -1.0
	var lumo_e := -1.0
	for o in levels:
		var e := int(o["electrons"])
		if e > 0:
			homo = String(o["label"])
			homo_e = float(o["energy"])
	for o in levels:
		if int(o["electrons"]) < 2 * int(o["deg"]):
			lumo = String(o["label"])
			lumo_e = float(o["energy"])
			break

	var gap := 0.0
	if homo_e >= 0.0 and lumo_e >= 0.0:
		gap = lumo_e - homo_e

	return {
		"levels": levels,
		"n_electrons": n_total,
		"bonding_electrons": bonding,
		"antibonding_electrons": antibonding,
		"bond_order": float(bonding - antibonding) / 2.0,
		"unpaired": unpaired,
		"paramagnetic": unpaired > 0,
		"homo": homo,
		"lumo": lumo,
		"homo_lumo_gap": gap,
	}


## Desemparelhados numa subcamada de degenerescência deg com e elétrons.
static func _unpaired_in(deg: int, e: int) -> int:
	if deg <= 0:
		return 0
	var cap := 2 * deg
	if e >= cap:
		return 0
	if e <= deg:
		return e
	return cap - e


static func _s_levels(n: int) -> Array:
	return [
		{"label": "σ%ds" % n, "deg": 1, "energy": 0.0, "type": "bonding"},
		{"label": "σ*%ds" % n, "deg": 1, "energy": 2.0, "type": "antibonding"},
	]


static func _sp_levels(total: int) -> Array:
	var levels := [
		{"label": "σ2s", "deg": 1, "energy": 0.0, "type": "bonding"},
		{"label": "σ*2s", "deg": 1, "energy": 2.0, "type": "antibonding"},
	]
	if total <= 10:
		levels.append({"label": "π2p", "deg": 2, "energy": 3.0, "type": "bonding"})
		levels.append({"label": "σ2p", "deg": 1, "energy": 4.5, "type": "bonding"})
		levels.append({"label": "π*2p", "deg": 2, "energy": 6.0, "type": "antibonding"})
		levels.append({"label": "σ*2p", "deg": 1, "energy": 8.0, "type": "antibonding"})
	else:
		levels.append({"label": "σ2p", "deg": 1, "energy": 3.0, "type": "bonding"})
		levels.append({"label": "π2p", "deg": 2, "energy": 4.0, "type": "bonding"})
		levels.append({"label": "π*2p", "deg": 2, "energy": 6.0, "type": "antibonding"})
		levels.append({"label": "σ*2p", "deg": 1, "energy": 8.0, "type": "antibonding"})
	return levels


## Diagrama para uma molécula diatômica homonuclear (A₂).
static func homonuclear(sym: String) -> Dictionary:
	var z := ElementData.z_of_symbol(sym)
	var period := ElementData.period(z)
	var va := valence_electrons(sym)
	var total := 2 * va
	var d: Dictionary
	if period <= 1:
		d = _fill(_s_levels(1), total)
	else:
		d = _fill(_sp_levels(total), total)
	d["kind"] = "A2"
	d["symbol"] = sym
	return d


## Ligação simples (σ) para moléculas com H ou pares iônicos (Na–Cl).
static func single_bond(sym_a: String, sym_b: String) -> Dictionary:
	var levels := [
		{"label": "σ", "deg": 1, "energy": 0.0, "type": "bonding"},
		{"label": "σ*", "deg": 1, "energy": 2.0, "type": "antibonding"},
	]
	var d := _fill(levels, 2)
	d["kind"] = "single"
	d["symbol"] = sym_a + sym_b
	return d


## Diagrama por símbolos. Trata homonuclear, hidretos e pares alcalino-halogênio.
static func diatomic(sym_a: String, sym_b: String) -> Dictionary:
	if sym_a == sym_b:
		return homonuclear(sym_a)
	# hidretos: ligação simples σ (exceto He, que não liga)
	if sym_a == "H" or sym_b == "H":
		var other := sym_b if sym_a == "H" else sym_a
		if other == "He":
			var d0 := _fill([
				{"label": "σ", "deg": 1, "energy": 0.0, "type": "bonding"},
				{"label": "σ*", "deg": 1, "energy": 2.0, "type": "antibonding"},
			], 3)
			d0["kind"] = "nobond"
			d0["symbol"] = sym_a + sym_b
			return d0
		return single_bond(sym_a, sym_b)
	# par alcalino + halogênio → caráter iônico (ligação simples efetiva)
	var za := ElementData.z_of_symbol(sym_a)
	var zb := ElementData.z_of_symbol(sym_b)
	var ga := ElementData.group(za)
	var gb := ElementData.group(zb)
	if (ga == 1 and gb == 17) or (ga == 17 and gb == 1):
		return single_bond(sym_a, sym_b)
	# heteronuclear covalente (ex.: CO) — usa o total de elétrons de valência
	var total := valence_electrons(sym_a) + valence_electrons(sym_b)
	var d := _fill(_sp_levels(total), total)
	d["kind"] = "AB"
	d["symbol"] = sym_a + sym_b
	return d


static func bond_order(sym_a: String, sym_b: String) -> float:
	return float(diatomic(sym_a, sym_b)["bond_order"])


static func unpaired(sym_a: String, sym_b: String) -> int:
	return int(diatomic(sym_a, sym_b)["unpaired"])


static func is_paramagnetic(sym_a: String, sym_b: String) -> bool:
	return bool(diatomic(sym_a, sym_b)["paramagnetic"])
