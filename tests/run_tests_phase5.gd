extends SceneTree
## Suite de testes — FASE 5 (Zoom partônico: Modelo Padrão, conservação, QCD).
## Executar: godot --headless --path . --script res://tests/run_tests_phase5.gd

const ParticleData = preload("res://scripts/particle_data.gd")
const Hadron = preload("res://scripts/hadron.gd")
const Conservation = preload("res://scripts/conservation.gd")
const StringBreaking = preload("res://scripts/string_breaking.gd")
const NucleonModel = preload("res://scripts/nucleon_model.gd")

var failed := 0
var passed := 0


func _init() -> void:
	print("=== QA — Simulador Atômico / Fase 5 (QCD e Modelo Padrão) ===")
	_test_particle_data()
	_test_multiplets()
	_test_hadron_build()
	_test_color()
	_test_conservation_allowed()
	_test_conservation_forbidden()
	_test_string_breaking()
	_test_nucleon_model()
	print("--------------------------------------------------")
	print("RESULTADO FASE 5: %d OK, %d FALHAS" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _check(cond: bool, name: String, detail: String = "") -> void:
	if cond:
		passed += 1
		print("  OK    %s" % name)
	else:
		failed += 1
		print("  FALHA %s %s" % [name, detail])


func _near(a: float, b: float, tol: float) -> bool:
	return absf(a - b) <= tol


# ------------------------------------------------------- catálogo de partículas

func _test_particle_data() -> void:
	print("[1] Catálogo do Modelo Padrão (particles.json)")
	_check(ParticleData.elementary_ids_by_group("quarks").size() == 12,
		"12 quarks (6 sabores + 6 antiquarks)",
		"obtido %d" % ParticleData.elementary_ids_by_group("quarks").size())
	_check(ParticleData.elementary_ids_by_group("leptons").size() == 12,
		"12 léptons (3 famílias + anti)")
	_check(ParticleData.elementary_ids_by_group("bosons").size() == 6,
		"6 bósons (γ, g, W±, Z⁰, H)")
	_check(ParticleData.charge_e3("u") == 2, "carga de u = +2/3")
	_check(ParticleData.charge_e3("d") == -1, "carga de d = −1/3")
	_check(ParticleData.charge_e3("e-") == -3, "carga do elétron = −1")
	_check(ParticleData.charge_e3("e+") == 3, "carga do pósitron = +1")
	_check(ParticleData.charge_e3("nu_e") == 0, "neutrino neutro")
	_check(ParticleData.baryon_e3("u") == 1, "número bariônico de u = 1/3")
	_check(ParticleData.baryon_e3("u_bar") == -1, "anti-quark tem B = −1/3")
	_check(ParticleData.spin2("t") == 1, "quark é férmion (spin 1/2)")
	_check(ParticleData.spin2("gamma") == 2, "fóton é bóson (spin 1)")
	_check(ParticleData.spin2("H") == 0, "Higgs tem spin 0")
	_check(ParticleData.lepton_numbers("e-")["le"] == 1, "elétron: Le = +1")
	_check(ParticleData.lepton_numbers("e+")["le"] == -1, "pósitron: Le = −1")
	_check(ParticleData.lepton_numbers("mu-")["lmu"] == 1, "múon: Lμ = +1")
	_check(_near(ParticleData.mass_mev("e-"), 0.51099895, 1e-6),
		"massa do elétron = 0,511 MeV")
	_check(_near(ParticleData.mass_mev("W+"), 80377.0, 1.0), "massa de W ≈ 80,4 GeV")


# ---------------------------------------------------------------- hádrons

func _test_multiplets() -> void:
	print("[2] Espectro de hádrons (hadrons.json)")
	_check(ParticleData.hadron_ids().size() >= 24, "≥ 24 hádrons no catálogo",
		"obtido %d" % ParticleData.hadron_ids().size())
	_check(ParticleData.has("anti_proton"), "antipartículas de hádrons geradas")
	_check(ParticleData.charge_e3("proton") == 3, "próton: +1 (3/3)")
	_check(ParticleData.charge_e3("anti_proton") == -3, "anti-próton: −1")
	_check(ParticleData.baryon_e3("neutron") == 3, "nêutron: B = 1")
	_check(_near(ParticleData.mass_mev("proton"), 938.272, 0.01),
		"massa do próton = 938,272 MeV")
	_check(_near(ParticleData.mass_mev("neutron"), 939.565, 0.01),
		"massa do nêutron = 939,565 MeV")
	_check(ParticleData.baryon_e3("pion+") == 0, "méson tem B = 0")
	_check(ParticleData.charge_e3("pion+") == 3, "π+ tem carga +1")
	_check(ParticleData.charge_e3("kaon+") == 3, "K+ tem carga +1")
	_check(ParticleData.spin2("omega-") == 3, "Ω⁻ tem spin 3/2")
	_check(ParticleData.spin2("Jpsi") == 2, "J/ψ é vetorial (spin 1)")
	_check(int(ParticleData.get_particle("omega-").get("strangeness", 0)) == -3,
		"Ω⁻ tem estranheza −3")
	_check(ParticleData.get_particle("kaon-")["strangeness"] == -1,
		"K⁻ tem estranheza −1")


func _test_hadron_build() -> void:
	print("[3] Montagem e identificação de hádrons")
	var p := Hadron.build(["u", "u", "d"])
	_check(p["hadron_id"] == "proton", "uud → próton", String(p["hadron_id"]))
	_check(p["charge_e3"] == 3 and p["baryon_e3"] == 3,
		"uud: carga +1, B = 1")
	var n := Hadron.build(["u", "d", "d"])
	_check(n["hadron_id"] == "neutron", "udd → nêutron")
	_check(n["charge_e3"] == 0, "udd: carga 0")
	var pip := Hadron.build(["u", "d_bar"])
	_check(pip["hadron_id"] == "pion+" and pip["kind"] == "méson",
		"u·d̄ → π+ (méson)")
	_check(pip["charge_e3"] == 3 and pip["baryon_e3"] == 0,
		"π+: carga +1, B = 0")
	var om := Hadron.build(["s", "s", "s"])
	_check(om["hadron_id"] == "omega-" and om["charge_e3"] == -3,
		"sss → Ω⁻ (carga −1)")
	var psi := Hadron.build(["c", "c_bar"])
	_check(psi["hadron_id"] == "Jpsi" and psi["charge_e3"] == 0,
		"c·c̄ → J/ψ (neutro)")
	_check(Hadron.classify(["u", "u", "u"]) == "bárion", "uuu é bárion")
	_check(Hadron.classify(["u", "d_bar"]) == "méson", "u·d̄ é méson")
	_check(Hadron.classify(["c", "c_bar", "u", "u_bar"]) == "tetraquark",
		"c·c̄·u·ū é tetraquark")
	_check(Hadron.classify(["u", "u", "d", "c", "c_bar"]) == "pentaquark",
		"uud·c·c̄ é pentaquark")
	# conteúdo desconhecido → não identifica, mas calcula carga
	var unknown := Hadron.build(["u", "d", "c"])
	_check(unknown["hadron_id"] == "" and unknown["charge_e3"] == 3,
		"conteúdo udc: identifica carga sem nome tabelado")


# ---------------------------------------------------------- carga de cor

func _test_color() -> void:
	print("[4] Confinamento: neutralidade de cor (singleto/branco)")
	_check(Hadron.color_neutral(["r", "g", "b"]), "bárion {r,g,b} é branco")
	_check(not Hadron.color_neutral(["r", "g"]), "{r,g} não é branco")
	_check(not Hadron.color_neutral(["r"]), "{r} (quark livre) não é branco")
	_check(Hadron.color_neutral(["r", "rbar"]), "méson {r,r̄} é branco")
	_check(Hadron.color_neutral(["r", "rbar", "g", "gbar"]),
		"tetraquark pareado é branco")
	_check(Hadron.color_neutral(["r", "rbar", "g", "b", "r"]),
		"pentaquark (q·q̄ + rrbg) é branco")
	_check(not Hadron.color_neutral(["r", "g", "b", "rbar"]),
		"{r,g,b,r̄} não é branco")
	_check(Hadron.color_neutral([]), "estado vazio é branco")
	_check(Hadron.anti_color("r") == "rbar", "anti-cor de r = r̄")
	_check(Hadron.anti_color("rbar") == "r", "anti-cor de r̄ = r")
	# atribuição concreta para cada hádron é branca
	for id in ["proton", "neutron", "pion+", "kaon0", "X3872", "Pc4312"]:
		var content: Array = ParticleData.get_particle(id).get("content", [])
		var cols: Array = []
		for e in Hadron.assign_colors(content):
			cols.append(String(e["color"]))
		_check(Hadron.color_neutral(cols),
			"atribuição de cor de %s é branca" % id, str(cols))


# ------------------------------------------------- validar: permitidas

func _test_conservation_allowed() -> void:
	print("[5] Validador: processos PERMITIDOS")
	# decaimento beta do nêutron (fraca): n → p + e⁻ + ν̄ₑ
	var beta := Conservation.validate(["neutron"], ["proton", "e-", "nu_e_bar"], true)
	_check(beta["ok"], "n → p + e⁻ + ν̄ₑ é permitida",
		Conservation.verdict_line(beta))
	# decaimento do múon (fraca): μ⁻ → e⁻ + ν̄ₑ + ν_μ
	var mu := Conservation.validate(["mu-"], ["e-", "nu_e_bar", "nu_mu"], true)
	_check(mu["ok"], "μ⁻ → e⁻ + ν̄ₑ + ν_μ é permitida",
		Conservation.verdict_line(mu))
	# decaimento do píon carregado (fraca): π⁺ → μ⁺ + ν_μ
	var pion := Conservation.validate(["pion+"], ["mu+", "nu_mu"], true)
	_check(pion["ok"], "π⁺ → μ⁺ + ν_μ é permitida",
		Conservation.verdict_line(pion))
	# decaimento do π0 (eletromagnético): π0 → 2γ
	var pi0 := Conservation.validate(["pion0"], ["gamma", "gamma"], false)
	_check(pi0["ok"], "π0 → γγ é permitida (EM)",
		Conservation.verdict_line(pi0))
	# aniquilação: e⁻ + e⁺ → 2γ
	var ann := Conservation.validate(["e-", "e+"], ["gamma", "gamma"], false)
	_check(ann["ok"], "e⁻ + e⁺ → γγ é permitida",
		Conservation.verdict_line(ann))
	# processo forte: p + p̄ → π⁺ + π⁻ + π0
	var strong := Conservation.validate(["proton", "anti_proton"],
		["pion+", "pion-", "pion0"], false)
	_check(strong["ok"], "pp̄ → π⁺π⁻π0 é permitida (forte)",
		Conservation.verdict_line(strong))
	# sub-processo fraco com mudança de sabor: d → u + W⁻ (W é VIRTUAL,
	# fora da camada de massa; portanto a checagem de energia não se aplica)
	var qbeta := Conservation.validate(["d"], ["u", "W-"], true, false)
	_check(qbeta["ok"], "d → u + W⁻ é permitida (fraca)",
		Conservation.verdict_line(qbeta))
	# decaimento com mudança de estranheza, só via fraca:
	# Λ0 → p + π⁻
	var lam := Conservation.validate(["lambda0"], ["proton", "pion-"], true)
	_check(lam["ok"], "Λ0 → p + π⁻ é permitida com interação fraca",
		Conservation.verdict_line(lam))
	# Ω⁻ → Λ0 + K⁻ (ΔS = 1, fraca)
	var omega := Conservation.validate(["omega-"], ["lambda0", "kaon-"], true)
	_check(omega["ok"], "Ω⁻ → Λ0 + K⁻ é permitida (fraca)",
		Conservation.verdict_line(omega))


# ------------------------------------------------ validar: proibidas

func _test_conservation_forbidden() -> void:
	print("[6] Validador: processos PROIBIDOS")
	# falta o (anti)neutrino → viola número leptônico
	var no_nu := Conservation.validate(["neutron"], ["proton", "e-"], true)
	_check(not no_nu["ok"], "n → p + e⁻ é proibida (falta ν̄ₑ)")
	_check(_violates(no_nu, "leptônico"), "  → acusa violação leptônica")
	# próton → pósitron + fóton: viola bárion, carga e lépton
	var pdecay := Conservation.validate(["proton"], ["e+", "gamma"], false)
	_check(not pdecay["ok"], "p → e⁺ + γ é proibida (decaimento do próton)")
	_check(_violates(pdecay, "bariônico"), "  → acusa violação do número bariônico")
	# elétron → fóton: viola carga e lépton
	var edecay := Conservation.validate(["e-"], ["gamma"], false)
	_check(not edecay["ok"], "e⁻ → γ é proibida (carga/lepton)")
	_check(_violates(edecay, "carga"), "  → acusa violação de carga")
	# mudança de estranheza sem interação fraca: Λ0 → p + π⁻ (forte)
	var strong_flavor := Conservation.validate(["lambda0"], ["proton", "pion-"], false)
	_check(not strong_flavor["ok"],
		"Λ0 → p + π⁻ proibida SEM interação fraca")
	_check(_violates(strong_flavor, "sabor"),
		"  → acusa violação de sabor (estranheza)")
	# energia: π0 → p + p̄ impossível (massa final > inicial)
	var energy := Conservation.validate(["pion0"], ["proton", "anti_proton"], false)
	_check(not energy["ok"], "π0 → pp̄ é proibida por energia")
	_check(_violates(energy, "energia"), "  → acusa violação de energia")
	# violação do número bariônico em reação hadrônica
	var baryon := Conservation.validate(["proton", "proton"],
		["proton", "pion+"], false)
	_check(not baryon["ok"], "pp → pπ⁺ é proibida (bárion/carga)")
	# estatística de spin: férmion → bóson único
	var estat := Conservation.validate(["proton"], ["Z0"], false)
	_check(not estat["ok"], "p → Z0 proibida (bárion/carga/spin)")


func _violates(result: Dictionary, needle: String) -> bool:
	for v in result.get("violations", []):
		if String(v).findn(needle) >= 0:
			return true
	return false


# --------------------------------------------------------- quebra de corda

func _test_string_breaking() -> void:
	print("[7] Confinamento e quebra de corda")
	_check(_near(StringBreaking.pull_energy_mev(0.5), 500.0, 1e-6),
		"energia da corda a 0,5 fm = 500 MeV")
	_check(_near(StringBreaking.breaking_distance_fm(), 0.6, 1e-6),
		"a corda rompe a 0,6 fm (2·m_q = 600 MeV)")
	_check(StringBreaking.confined_at(0.3), "quark confinado a 0,3 fm")
	_check(not StringBreaking.confined_at(0.8), "corda rompida a 0,8 fm")
	# puxar um u do próton: cria par d d̄ → π⁺ (u d̄) + nêutron (udd)
	var br := StringBreaking.split_nucleon("proton", 0, "d")
	_check(br["ok"], "quebra de corda do próton bem-sucedida")
	_check(br["meson"]["hadron_id"] == "pion+",
		"u + d̄ → π⁺", String(br["meson"]["hadron_id"]))
	_check(br["baryon"]["hadron_id"] == "neutron",
		"ud + d → nêutron", String(br["baryon"]["hadron_id"]))
	_check(br["meson"]["color_neutral"] and br["baryon"]["color_neutral"],
		"fragmentos são hádrons BRANCOS (sem cor)")
	# balanço global de carga e bárion entre entrada e saída
	var q_in := Conservation._sum_int(["proton"], "charge_e3")
	var q_out := int(br["meson"]["charge_e3"]) + int(br["baryon"]["charge_e3"])
	_check(q_in == q_out, "carga conservada na quebra de corda")
	var b_in := Conservation._sum_int(["proton"], "baryon_e3")
	var b_out := int(br["meson"]["baryon_e3"]) + int(br["baryon"]["baryon_e3"])
	_check(b_in == b_out, "número bariônico conservado na quebra de corda")
	# aniquilação e⁻ + e⁺ → 1,022 MeV
	_check(_near(StringBreaking.annihilation_energy_mev("e-", "e+"), 1.021998, 1e-4),
		"aniquilação e⁻e⁺ libera ≈ 1,022 MeV (2×511 keV)")


# ------------------------------------------------------------ modelo do núcleon

func _test_nucleon_model() -> void:
	print("[8] Modelo do núcleon (quarks de valência + glúons)")
	var pv := NucleonModel.valence("proton")
	_check(pv.size() == 3, "próton tem 3 quarks de valência")
	_check(String(pv[0]["flavor"]) == "u" and String(pv[1]["flavor"]) == "u"
		and String(pv[2]["flavor"]) == "d", "próton = uud")
	_check(String(pv[0]["color"]) != String(pv[1]["color"])
		and String(pv[1]["color"]) != String(pv[2]["color"]),
		"cores de valência distintas (r, g, b)")
	var nv := NucleonModel.valence("neutron")
	_check(String(nv[2]["flavor"]) == "d", "nêutron = udd")
	var vm := NucleonModel.valence_mass_mev("proton")
	_check(vm > 8.0 and vm < 10.0,
		"massa dos quarks de valência do próton ≈ 9 MeV", "%.2f" % vm)
	var gf := NucleonModel.gluon_fraction("proton")
	_check(gf > 0.98 and gf < 1.0,
		"~99% da massa do próton vem de glúons/mar", "%.4f" % gf)
	_check(NucleonModel.gluon_energy_mev("proton") > 900.0,
		"energia dos glúons > 900 MeV")
	var sea1 := NucleonModel.sea_pairs(12, 0x1234)
	var sea2 := NucleonModel.sea_pairs(12, 0x1234)
	_check(sea1.size() == 12, "mar com 12 pares virtuais")
	_check(String(sea1[0]["flavor"]) == String(sea2[0]["flavor"]),
		"mar de quarks reprodutível (mesma semente)")
	_check(String(sea1[0]["anti"]) == String(sea1[0]["flavor"]) + "_bar",
		"cada par do mar é quark + antiquark")
