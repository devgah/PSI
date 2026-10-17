extends RefCounted
## Preenchimento eletrônico: Aufbau + Pauli + Hund + exceções reais (tabela).
## Dados externos em data/ground_config.json (engenharia orientada a dados).

const DATA_PATH := "res://data/ground_config.json"

static var _cache: Dictionary = {}
static var _super_digits := {0: "⁰", 1: "¹", 2: "²", 3: "³", 4: "⁴",
	5: "⁵", 6: "⁶", 7: "⁷", 8: "⁸", 9: "⁹"}


static func _load() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	if f == null:
		push_error("ground_config.json não encontrado: %s" % DATA_PATH)
		return {"aufbau_order": [], "exceptions": {}}
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed == null:
		push_error("JSON inválido em ground_config.json")
		return {"aufbau_order": [], "exceptions": {}}
	_cache = parsed
	return _cache


## n a partir do rótulo ("3d" -> 3)
static func _n_of(label: String) -> int:
	return int(label.substr(0, label.length() - 1))


## l a partir do rótulo ("3d" -> 2)
static func _l_of(label: String) -> int:
	var letter := label.substr(label.length() - 1)
	match letter:
		"s":
			return 0
		"p":
			return 1
		"d":
			return 2
		"f":
			return 3
	return 0


## Capacidade da subcamada: 2(2l+1) — princípio de Pauli.
static func capacity(label: String) -> int:
	return 2 * (2 * _l_of(label) + 1)


## Contagem de elétrons por subcamada para Z, com exceções da tabela.
static func fill_counts(z: int) -> Dictionary:
	var data := _load()
	var order: Array = data.get("aufbau_order", [])
	var counts := {}
	var remaining := z
	for label in order:
		if remaining <= 0:
			break
		var cap := capacity(label)
		var take: int = mini(cap, remaining)
		counts[label] = take
		remaining -= take
	# exceções reais (Cr, Cu, Nb, Mo, ...): total preservado, só redistribui
	var exc: Dictionary = data.get("exceptions", {}).get(str(z), {})
	if not exc.is_empty():
		var before := 0
		var after := 0
		for label in exc:
			if counts.has(label):
				before += int(counts[label])
			elif int(exc[label]) > 0:
				counts[label] = 0
			after += int(exc[label])
		for label in exc:
			counts[label] = int(exc[label])
		if before != after:
			push_warning("Exceção de configuração com total divergente para Z=%d" % z)
	return counts


## Lista de orbitais ocupados (expandida em m, ordem de Hund) com até n_electrons.
## Cada entrada: {label, n, l, m, count} — count = 1 ou 2 (Pauli).
static func occupancy_list(z: int, n_electrons: int) -> Array:
	var counts := fill_counts(z)
	var data := _load()
	var order: Array = data.get("aufbau_order", [])
	var out := []
	var left := maxi(n_electrons, 0)
	for label in order:
		if left <= 0:
			break
		var have: int = int(counts.get(label, 0))
		if have <= 0:
			continue
		var take: int = mini(have, left)
		left -= take
		var l := _l_of(label)
		var n := _n_of(label)
		var n_m := 2 * l + 1
		# ordem Hund: ocupa cada m com spin paralelo antes de emparelhar
		var m_order := _hund_m_order(l)
		var buckets := {}
		for i in range(take):
			var mi: int = i if i < n_m else i - n_m
			var mm: int = m_order[mi]
			buckets[mm] = int(buckets.get(mm, 0)) + 1
		for mm in buckets:
			out.append({"label": label, "n": n, "l": l, "m": int(mm),
				"count": int(buckets[mm])})
	return out


static func _hund_m_order(l: int) -> Array:
	var base := [0, 1, -1, 2, -2, 3, -3]
	var out := []
	for mm in base:
		if absi(mm) <= l:
			out.append(mm)
	return out


## Último orbital ocupado (maior energia do átomo hidrogenoide).
static func highest_orbital(z: int, n_electrons: int) -> Dictionary:
	var occ := occupancy_list(z, n_electrons)
	if occ.is_empty():
		return {}
	return occ[occ.size() - 1]


## String de configuração em ordem de camada: "1s² 2s² 2p⁶ 3s² 3p⁶ 3d⁶ 4s²"
static func config_string(z: int, n_electrons: int) -> String:
	var counts := fill_counts(z)
	var left := maxi(n_electrons, 0)
	var used := {}
	for label in counts:
		used[label] = 0
	var data := _load()
	var order: Array = data.get("aufbau_order", [])
	for label in order:
		if left <= 0:
			break
		var have: int = int(counts.get(label, 0))
		if have <= 0:
			continue
		var take: int = mini(have, left)
		left -= take
		used[label] = take
	# ordena por camada (n) e depois por l
	var labels := []
	for label in used:
		if int(used[label]) > 0:
			labels.append(label)
	labels.sort_custom(func(a, b):
		var na := _n_of(a)
		var nb := _n_of(b)
		if na != nb:
			return na < nb
		return _l_of(a) < _l_of(b))
	var parts := []
	for label in labels:
		parts.append(label + _superscript(int(used[label])))
	if parts.is_empty():
		return "(sem elétrons)"
	return " ".join(parts)


static func _superscript(v: int) -> String:
	var s := str(v)
	var out := ""
	for ch in s:
		out += str(_super_digits.get(int(ch), ch))
	return out
