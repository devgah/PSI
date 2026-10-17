extends RefCounted
## Canhão de fótons: absorção (transição dipolar), ionização (efeito fotoelétrico)
## e emissão (cascata + série de Rydberg). Validador de regras de seleção.

const OrbitalMath = preload("res://scripts/orbital_math.gd")
const AtomConstants = preload("res://scripts/atom_constants.gd")

const ENERGY_TOLERANCE_EV := 0.05
const MAX_N := 8


## Energia de ionização a partir do nível n (eV). z = carga efetiva (Z ou Z_eff).
static func ionization_energy_ev(z: float, n: int) -> float:
	if n <= 0:
		return 0.0
	return AtomConstants.RYDBERG_EV * z * z / float(n * n)


## Resultado da interação de um fóton de energia `energy_ev` com o elétron
## no orbital (n, l, m) de um átomo com carga efetiva z.
## Retorna {type: "ionization"|"excitation"|"no_interaction", ...}
static func interact(energy_ev: float, z: float, n: int, l: int, m: int) -> Dictionary:
	if energy_ev <= 0.0:
		return {"type": "no_interaction", "reason": "energia nula"}
	var e_ion := ionization_energy_ev(z, n)
	if energy_ev >= e_ion:
		return {
			"type": "ionization",
			"kinetic_ev": energy_ev - e_ion,
			"threshold_ev": e_ion,
		}
	var ex := try_excite(energy_ev, z, n, l, m)
	if not ex.is_empty():
		ex["type"] = "excitation"
		return ex
	return {
		"type": "no_interaction",
		"reason": "sem transição com delta_l = +-1 próxima de %.3f eV" % energy_ev,
	}


## Procura (n2,l2,m2) acessível por absorção com E_fóton ~ delta_E (tolerancia).
static func try_excite(energy_ev: float, z: float, n: int, l: int, m: int,
		tol: float = ENERGY_TOLERANCE_EV) -> Dictionary:
	var best := {}
	var best_diff := tol
	for n2 in range(1, MAX_N + 1):
		if n2 == n:
			continue
		var de := OrbitalMath.transition_energy_ev(z, n, n2)
		if de <= 0.0:
			continue
		var diff: float = absf(de - energy_ev)
		if diff > best_diff:
			continue
		for l2 in [l - 1, l + 1]:
			if l2 < 0 or l2 >= n2:
				continue
			for m2 in range(m - 1, m + 2):
				if absi(m2) > l2:
					continue
				if not OrbitalMath.is_allowed_transition(n, l, m, n2, l2, m2):
					continue
				best_diff = diff
				best = {"n": n2, "l": l2, "m": m2, "delta_e": de,
					"diff": diff, "lambda_nm": OrbitalMath.wavelength_nm(z, n, n2)}
	return best


## Cascata de decaimento do estado `cur` até `target` (mesmo elétron).
## Caminho mais longo em energia decrescente (mais fótons emitidos),
## respeitando sempre delta_l = +-1 e delta_m in {0, +-1}.
## Cada passo: {n_from, l_from, m_from, n_to, l_to, m_to, energy_ev, lambda_nm}
static func cascade(z: float, cur: Dictionary, target: Dictionary) -> Array:
	if cur.is_empty() or target.is_empty():
		return []
	if int(cur["n"]) == int(target["n"]) and int(cur["l"]) == int(target["l"]) \
			and int(cur["m"]) == int(target["m"]):
		return []
	var path := _longest_path(cur, target)
	var steps := []
	for i in range(path.size() - 1):
		var a: Dictionary = path[i]
		var b: Dictionary = path[i + 1]
		steps.append({
			"n_from": a["n"], "l_from": a["l"], "m_from": a["m"],
			"n_to": b["n"], "l_to": b["l"], "m_to": b["m"],
			"energy_ev": OrbitalMath.transition_energy_ev(z, int(a["n"]), int(b["n"])),
			"lambda_nm": OrbitalMath.wavelength_nm(z, int(a["n"]), int(b["n"])),
		})
	return steps


## Caminho mais longo (recursão em DAG: n sempre decrescente; memo por referência).
static func _longest_path(state: Dictionary, target: Dictionary,
		memo: Dictionary = {}) -> Array:
	var k := "%d_%d_%d" % [int(state["n"]), int(state["l"]), int(state["m"])]
	if memo.has(k):
		return memo[k]
	if int(state["n"]) == int(target["n"]) and int(state["l"]) == int(target["l"]) \
			and int(state["m"]) == int(target["m"]):
		memo[k] = [state.duplicate()]
		return memo[k]
	var best_path: Array = []
	var n1 := int(state["n"])
	for n2 in range(int(target["n"]), n1):
		for l2 in range(0, n2):
			for m2 in range(-l2, l2 + 1):
				if not OrbitalMath.is_allowed_transition(n1, int(state["l"]),
						int(state["m"]), n2, l2, m2):
					continue
				var nxt := {"n": n2, "l": l2, "m": m2}
				var sub: Array = _longest_path(nxt, target, memo)
				if sub.size() > 0 and sub.size() + 1 > best_path.size():
					best_path = [state.duplicate()] + sub
	memo[k] = best_path
	return best_path


## Linhas espectrais de Rydberg para transições até n_ground (espectro do nível n_max).
static func spectrum_lines(z: float, n_max: int, n_ground: int = 1) -> Array:
	var lines := []
	for n1 in range(n_ground, n_max):
		for n2 in range(n1 + 1, n_max + 1):
			lines.append({
				"n_from": n2, "n_to": n1,
				"lambda_nm": OrbitalMath.wavelength_nm(z, n2, n1),
				"energy_ev": OrbitalMath.transition_energy_ev(z, n1, n2),
			})
	return lines
