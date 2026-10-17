extends RefCounted
## FASE 5 — Validador ESTRITO das leis de conservação do Modelo Padrão.
## Verifica, entre estado inicial e final:
##   • carga elétrica (unidades de e/3, soma inteira exata)
##   • número bariônico (conservação exata)
##   • número leptônico POR FAMÍLIA (e, μ, τ)
##   • spin (paridade de estatística: Σ2J módulo 2)
##   • carga de cor (estado físico tem de ser singleto/branco)
##   • sabor (estranheza/caráter/bottomness/topness) — só violável por interação FRACA
##   • energia (Σ massa final ≤ Σ massa inicial) quando em repouso
##
## `weak = true` libera mudanças de sabor (decaimentos beta, W±), mas NÃO
## libera carga, bárion, lépton, cor ou spin.

const ParticleData = preload("res://scripts/particle_data.gd")
const Hadron = preload("res://scripts/hadron.gd")

const OMEGA0_MEV := 1672.45


static func _sum_int(ids: Array, key: String) -> int:
	var s := 0
	for id in ids:
		s += int(ParticleData.get_particle(String(id)).get(key, 0))
	return s


static func _sum_mass(ids: Array) -> float:
	var s := 0.0
	for id in ids:
		s += ParticleData.mass_mev(String(id))
	return s


## Valida uma transformação. Retorna {ok, violations: Array[String], details: Dictionary}.
static func validate(initial: Array, final: Array, weak := false, check_energy := true) -> Dictionary:
	var violations: Array = []
	var details: Dictionary = {}

	# --- carga elétrica ---
	var q_in := _sum_int(initial, "charge_e3")
	var q_out := _sum_int(final, "charge_e3")
	details["charge_e3"] = {"in": q_in, "out": q_out}
	if q_in != q_out:
		violations.append("carga elétrica: %s → %s (e)" % [fmt_e3(q_in), fmt_e3(q_out)])

	# --- número bariônico ---
	var b_in := _sum_int(initial, "baryon_e3")
	var b_out := _sum_int(final, "baryon_e3")
	details["baryon_e3"] = {"in": b_in, "out": b_out}
	if b_in != b_out:
		violations.append("número bariônico: %s → %s" % [fmt_e3(b_in), fmt_e3(b_out)])

	# --- número leptônico por família ---
	for fam in ["le", "lmu", "ltau"]:
		var l_in := _sum_int(initial, fam)
		var l_out := _sum_int(final, fam)
		details[fam] = {"in": l_in, "out": l_out}
		if l_in != l_out:
			violations.append("número leptônico (%s): %d → %d" % [fam_label(fam), l_in, l_out])

	# --- spin: paridade de estatística (Σ2J mod 2) ---
	var s_in := _sum_int(initial, "spin2") % 2
	var s_out := _sum_int(final, "spin2") % 2
	details["spin_parity"] = {"in": s_in, "out": s_out}
	if s_in != s_out:
		violations.append("paridade de spin (bóson/férmion): ímpar ≠ par")

	# --- sabor (conservado em forte/EM; violado só por fraca) ---
	if not weak:
		for fl in ["strangeness", "charm", "bottomness", "topness"]:
			var f_in := _sum_int(initial, fl)
			var f_out := _sum_int(final, fl)
			if f_in != f_out:
				violations.append("sabor (%s): %d → %d (só interação fraca muda sabor)" % [flavor_label(fl), f_in, f_out])

	# --- cor (estado físico = branco) ---
	var col_in := _color_state_ok(initial)
	var col_out := _color_state_ok(final)
	details["color"] = {"in": col_in, "out": col_out}
	if not col_in:
		violations.append("carga de cor (estado inicial não é singleto)")
	if not col_out:
		violations.append("carga de cor (estado final não é singleto)")

	# --- energia (Σ massa) ---
	if check_energy:
		var m_in := _sum_mass(initial)
		var m_out := _sum_mass(final)
		details["mass_mev"] = {"in": m_in, "out": m_out}
		if m_out > m_in + 1e-6:
			violations.append("energia: massa final (%.1f MeV) > inicial (%.1f MeV)" % [m_out, m_in])

	return {"ok": violations.is_empty(), "violations": violations, "details": details}


## Entradas com quarks/glúons livres (cor "livre") não são estados físicos:
## tratados como singleto somente se as cores atribuídas formarem branco.
static func _color_state_ok(ids: Array) -> bool:
	var labels: Array = []
	for id in ids:
		var p := ParticleData.get_particle(String(id))
		var col := String(p.get("color", "none"))
		if col == "octet":
			labels.append("octet")  # glúon carrega cor: exige parceiros
		elif col != "none":
			labels.append(col)
		elif String(p.get("group", "")) == "hadron":
			pass  # hádron já é branco
	if labels.is_empty():
		return true
	# qualquer glúon isolado carrega cor → precisa de outro rótulo
	if labels.has("octet"):
		var non_octet := 0
		for l in labels:
			if l != "octet":
				non_octet += 1
		if non_octet == 0:
			return false
	var clean: Array = []
	for l in labels:
		if l != "octet":
			clean.append(l)
	return Hadron.color_neutral(clean)


# ------------------------------------------------------------------ formatação

static func fmt_e3(e3: int) -> String:
	var sign_s := ""
	if e3 < 0:
		sign_s = "-"
		e3 = -e3
	var whole := e3 / 3
	var rem := e3 % 3
	if rem == 0:
		return "%s%d" % [sign_s, whole]
	if whole == 0:
		return "%s%d/3" % [sign_s, rem]
	return "%s%d %d/3" % [sign_s, whole, rem]


static func fam_label(fam: String) -> String:
	match fam:
		"le":
			return "eletrônico"
		"lmu":
			return "muônico"
		"ltau":
			return "tauônico"
	return fam


static func flavor_label(fl: String) -> String:
	match fl:
		"strangeness":
			return "estranheza"
		"charm":
			return "charme"
		"bottomness":
			return "bottomness"
		"topness":
			return "topness"
	return fl


## Explica o resultado numa linha curta.
static func verdict_line(result: Dictionary) -> String:
	if bool(result.get("ok", false)):
		return "PERMITIDA — todas as leis de conservação respeitadas"
	var v: Array = result.get("violations", [])
	if v.is_empty():
		return "PERMITIDA"
	return "PROIBIDA — " + "; ".join(v)
