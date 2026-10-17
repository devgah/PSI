extends RefCounted
## FASE 3 — Decaimento radioativo estocástico (α, β⁻, β⁺, captura eletrônica,
## fissão espontânea, γ/IT, emissão de nêutrons/prótons) e cadeias.
## Meia-vida e modos vêm dos dados (NUBASE2020); Q-valores calculados das massas.
##
## N(t) = N0 · e^(−λt),  t½ = ln2 / λ.

const NuclideData = preload("res://scripts/nuclide_data.gd")
const Nuclear = preload("res://scripts/nuclear.gd")

const LN2 := 0.6931471805599453
const M_E_KEV := 510.99895
const HE4_ME_KEV := 2424.91587

# rótulos legíveis (PT-BR) por chave de modo (NUBASE)
const MODE_LABELS := {
	"A": "α (alfa)",
	"B-": "β⁻ (beta menos)",
	"B+": "β⁺ (beta mais)",
	"EC": "captura eletrônica",
	"EC+B+": "captura eletrônica / β⁺",
	"2B-": "duplo β⁻",
	"IT": "transição isomérica (γ)",
	"SF": "fissão espontânea",
	"N": "emissão de nêutron",
	"P": "emissão de próton",
	"B-N": "β⁻ + nêutron",
	"B-2N": "β⁻ + 2 nêutrons",
	"B+P": "β⁺ + próton",
	"CD": "decaimento por cluster",
	"STABLE": "estável",
	"P-UNST": "instável (emissão de partícula)",
}


static func mode_label(key: String) -> String:
	return String(MODE_LABELS.get(key, key))


# --------------------------------------------------------------- meia-vida

static func lambda_of(hl_s: float) -> float:
	if not is_finite(hl_s) or hl_s <= 0.0:
		return 0.0
	return LN2 / hl_s


## Amostra um tempo de decaimento exponencial (reprodutível via rng semeado).
static func sample_time(hl_s: float, rng: RandomNumberGenerator) -> float:
	var lam := lambda_of(hl_s)
	if lam <= 0.0:
		return INF
	var u := 1.0 - rng.randf()  # (0,1]
	return -log(u) / lam


# ------------------------------------------------------------------ Q-valores

## Excesso de massa em keV: dado externo quando disponível, senão Weizsäcker.
static func effective_me_kev(z: int, a: int) -> float:
	if z == 2 and a == 4:
		return HE4_ME_KEV
	if NuclideData.has_nuclide(z, a):
		var v := NuclideData.mass_excess_kev(z, a)
		if not is_nan(v):
			return v
	return Nuclear.mass_excess_weizsacker_kev(a, z)


## Q do decaimento α: (Z,A) → (Z−2,A−4) + He-4  (MeV).
static func q_alpha_mev(z: int, a: int) -> float:
	return (effective_me_kev(z, a) - effective_me_kev(z - 2, a - 4) - HE4_ME_KEV) / 1000.0


## Q do β⁻: (Z,A) → (Z+1,A) + e⁻ + ν̄  (usando massas atômicas) (MeV).
static func q_beta_minus_mev(z: int, a: int) -> float:
	return (effective_me_kev(z, a) - effective_me_kev(z + 1, a)) / 1000.0


## Q da captura eletrônica: (Z,A) + e⁻ → (Z−1,A) + ν  (MeV).
static func q_ec_mev(z: int, a: int) -> float:
	return (effective_me_kev(z, a) - effective_me_kev(z - 1, a)) / 1000.0


## Q do β⁺: (Z,A) → (Z−1,A) + e⁺ + ν  (precisa Q_EC > 1,022 MeV) (MeV).
static func q_beta_plus_mev(z: int, a: int) -> float:
	return q_ec_mev(z, a) - 2.0 * M_E_KEV / 1000.0


# --------------------------------------------------------------------- modos

## Modo(s) de decaimento do nuclídeo com respectivas intensidades (%). Usa os
## dados NUBASE quando existem; senão decide por Q-valores.
static func modes(z: int, a: int) -> Array:
	var raw := NuclideData.modes(z, a)
	if not raw.is_empty():
		return raw
	var out := []
	if z > 2 and a > 4 and q_alpha_mev(z, a) > 0.0:
		out.append({"m": "A", "pct": 100.0})
	elif q_beta_minus_mev(z, a) > 0.0:
		out.append({"m": "B-", "pct": 100.0})
	elif q_beta_plus_mev(z, a) > 0.0:
		out.append({"m": "B+", "pct": 100.0})
	elif q_ec_mev(z, a) > 0.0:
		out.append({"m": "EC", "pct": 100.0})
	return out


## Modo dominante (maior intensidade) ou "" se estável.
static func dominant_mode(z: int, a: int) -> String:
	if NuclideData.is_stable(z, a):
		return ""
	var ms := modes(z, a)
	var best := ""
	var best_pct := -1.0
	for m in ms:
		var pct = m.get("pct", null)
		var v := float(pct) if pct != null else 0.0
		if v > best_pct:
			best_pct = v
			best = String(m.get("m", ""))
	return best


# --------------------------------------------------------------- aplicar

## Aplica um decaimento ao nuclídeo (Z,A), retornando os produtos.
## Retorno: {ok, z, a, mode, emitted:[String], q_mev, note}
static func apply_decay(z: int, a: int, mode: String) -> Dictionary:
	var r := {"ok": false, "z": z, "a": a, "mode": mode,
		"emitted": [], "q_mev": 0.0, "note": ""}
	match mode:
		"A":
			if z < 2 or a < 4:
				r["note"] = "sem massa para emitir α"
				return r
			r["z"] = z - 2
			r["a"] = a - 4
			r["emitted"] = ["He-4 (α)"]
			r["q_mev"] = q_alpha_mev(z, a)
		"B-":
			r["z"] = z + 1
			r["emitted"] = ["e⁻", "ν̄ₑ"]
			r["q_mev"] = q_beta_minus_mev(z, a)
		"B+":
			r["z"] = z - 1
			r["emitted"] = ["e⁺", "νₑ"]
			r["q_mev"] = q_beta_plus_mev(z, a)
		"EC":
			r["z"] = z - 1
			r["emitted"] = ["νₑ"]
			r["q_mev"] = q_ec_mev(z, a)
		"EC+B+":
			if q_beta_plus_mev(z, a) > 0.0:
				return apply_decay(z, a, "B+")
			return apply_decay(z, a, "EC")
		"2B-":
			r["z"] = z + 2
			r["emitted"] = ["2 e⁻", "2 ν̄ₑ"]
			r["q_mev"] = (effective_me_kev(z, a) - effective_me_kev(z + 2, a)) / 1000.0
		"N", "B-N", "B-2N":
			var nn := 1
			if mode == "B-2N":
				nn = 2
			if mode == "B-N":
				r["z"] = z + 1  # β⁻ seguido de emissão de nêutron
			r["a"] = a - nn
			r["emitted"] = ["%d nêutron(s)" % nn]
			r["q_mev"] = (effective_me_kev(z, a) - effective_me_kev(r["z"], r["a"])) / 1000.0
		"P", "B+P":
			r["z"] = z - 1
			r["a"] = a - 1
			r["emitted"] = ["próton"]
			r["q_mev"] = (effective_me_kev(z, a) - effective_me_kev(r["z"], r["a"])) / 1000.0
		"IT":
			r["emitted"] = ["γ"]
			r["q_mev"] = 0.0
			r["note"] = "transição isomérica: Z e A inalterados"
		"SF":
			return _apply_fission(z, a)
		_:
			r["note"] = "modo não modelado: %s" % mode
			return r
	r["ok"] = true
	return r


## Fissão espontânea ilustrativa: divide em um fragmento pesado e um leve,
## emitindo alguns nêutrons. (Partição estatística simplificada.)
static func _apply_fission(z: int, a: int) -> Dictionary:
	var r := {"ok": true, "z": z, "a": a, "mode": "SF",
		"emitted": [], "q_mev": (effective_me_kev(z, a) - effective_me_kev(int(z * 0.58), int(a * 0.58))
			- effective_me_kev(z - int(z * 0.58), a - int(a * 0.58))) / 1000.0,
		"note": "fissão: partição ilustrativa em 2 fragmentos"}
	var zh := int(round(float(z) * 0.58))
	var ah := int(round(float(a) * 0.58))
	var zl := z - zh
	var al := a - ah
	# remove alguns nêutrons
	var nn := clampi(int(round(float(a) * 0.012)), 1, 5)
	al -= nn
	zh = clampi(zh, 0, 118)
	zl = clampi(zl, 0, 118)
	r["emitted"] = ["fragmento Z≈%d A≈%d" % [zh, ah],
		"fragmento Z≈%d A≈%d" % [zl, al], "%d nêutron(s)" % nn]
	# o modelo mantém o fragmento pesado como estado resultante
	r["z"] = zh
	r["a"] = ah
	return r


## Cadeia de decaimentos até estabilizar (ou até max_steps). Cada passo é
## determinístico no modo (dominante) — a aleatoriedade está nos tempos.
static func chain(z: int, a: int, max_steps: int = 30) -> Array:
	var steps := []
	var cz := z
	var ca := a
	for i in range(max_steps):
		if NuclideData.is_stable(cz, ca):
			break
		var m := dominant_mode(cz, ca)
		if m == "":
			break
		var res := apply_decay(cz, ca, m)
		if not res["ok"]:
			break
		var hl := NuclideData.half_life_s(cz, ca)
		steps.append({
			"z": cz, "a": ca, "mode": m,
			"q_mev": res["q_mev"], "emitted": res["emitted"],
			"hl_s": hl, "hl_text": NuclideData.nuclide(cz, ca).get("hl_text", ""),
		})
		cz = int(res["z"])
		ca = int(res["a"])
		if ca < 1 or cz < 0:
			break
	return steps


# --------------------------------------------------------- Monte Carlo N(t)

## Simula n0 núcleos independentes e compara com a curva analítica N0·e^(−λt).
## Retorno: {t, n_sim, n_analytic, lambda, hl_s, n0}
static func monte_carlo(n0: int, hl_s: float, t_max: float, steps: int,
		rng: RandomNumberGenerator) -> Dictionary:
	var lam := lambda_of(hl_s)
	var times := PackedFloat64Array()
	for i in range(n0):
		if lam <= 0.0:
			times.append(INF)
		else:
			var u := 1.0 - rng.randf()
			times.append(-log(u) / lam)
	times.sort()
	var t_arr := PackedFloat64Array()
	var n_sim := PackedFloat64Array()
	var n_an := PackedFloat64Array()
	var ptr := 0
	for s in range(steps + 1):
		var t := t_max * float(s) / float(steps)
		while ptr < n0 and times[ptr] <= t:
			ptr += 1
		t_arr.append(t)
		n_sim.append(float(n0 - ptr))
		n_an.append(float(n0) * exp(-lam * t))
	return {"t": t_arr, "n_sim": n_sim, "n_analytic": n_an,
		"lambda": lam, "hl_s": hl_s, "n0": n0}
