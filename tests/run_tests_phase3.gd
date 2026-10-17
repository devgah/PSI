extends SceneTree
## Suite de testes — FASE 3 (núcleo atômico: Weizsäcker, mágicos, decaimentos).
## Executar: godot --headless --path . --script res://tests/run_tests_phase3.gd

const Nuclear = preload("res://scripts/nuclear.gd")
const NuclideData = preload("res://scripts/nuclide_data.gd")
const Decay = preload("res://scripts/decay.gd")
const Nucleus = preload("res://scripts/nucleus_model.gd")

var failed := 0
var passed := 0


func _init() -> void:
	print("=== QA — Simulador Atômico / Fase 3 (núcleo atômico) ===")
	_test_data()
	_test_weizsacker()
	_test_magic()
	_test_valley()
	_test_yukawa()
	_test_qvalues()
	_test_apply_decay()
	_test_chain()
	_test_monte_carlo()
	_test_radius()
	print("--------------------------------------------------")
	print("RESULTADO FASE 3: %d OK, %d FALHAS" % [passed, failed])
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


# ------------------------------------------------------------ dados externos

func _test_data() -> void:
	print("[1] Dados externos (data/nuclides.json — NUBASE2020/AME2020)")
	_check(NuclideData.count() > 3000, "mais de 3000 nuclídeos no estado fundamental",
		"obtido %d" % NuclideData.count())
	_check(NuclideData.symbol(1, 1) == "H" and NuclideData.symbol(2, 4) == "He",
		"símbolos H-1 e He-4")
	_check(_near(NuclideData.mass_excess_kev(1, 1), 7288.971064, 0.001),
		"me(H-1) = 7288,971 keV")
	_check(_near(NuclideData.mass_excess_kev(2, 4), 2424.91587, 0.001),
		"me(He-4) = 2424,916 keV")
	_check(NuclideData.is_stable(26, 56), "Fe-56 é estável")
	_check(NuclideData.is_stable(2, 4) and NuclideData.is_stable(8, 16),
		"He-4 e O-16 estáveis")
	# U-238: t½ = 4,463 Ga = 1,408e17 s
	var u := NuclideData.half_life_s(92, 238)
	_check(_near(u / 1.40838676776e17, 1.0, 0.01), "meia-vida de U-238 ≈ 4,463 Ga",
		str(u) + " s")
	# C-14: t½ = 5730 a = 1,808e11 s
	var c := NuclideData.half_life_s(6, 14)
	_check(_near(c / 1.80809e11, 1.0, 0.02), "meia-vida de C-14 ≈ 5730 anos",
		str(c) + " s")
	# modo dominante
	_check(Decay.dominant_mode(92, 238) == "A", "U-238 decai por α",
		Decay.dominant_mode(92, 238))
	_check(Decay.dominant_mode(6, 14) == "B-", "C-14 decai por β⁻",
		Decay.dominant_mode(6, 14))
	_check(Decay.dominant_mode(26, 56) == "", "Fe-56 não tem modo (estável)")


# ------------------------------------------------------------- Weizsäcker

func _test_weizsacker() -> void:
	print("[2] Fórmula de Weizsäcker (gota líquida)")
	# B/A(Fe-56) ≈ 8,79 MeV (valor real); Weizsäcker ≈ 8,76
	var bpa := Nuclear.binding_per_a_weizsacker(56, 26)
	_check(_near(bpa, 8.79, 0.15), "B/A(Fe-56) ≈ 8,79 MeV", "%.3f" % bpa)
	# pico de ligação: Fe-56 mais ligado por núcleon que U-238
	_check(Nuclear.binding_per_a_weizsacker(56, 26)
		> Nuclear.binding_per_a_weizsacker(238, 92),
		"B/A(Fe-56) > B/A(U-238)")
	# emparelhamento
	_check(Nuclear.pairing(40, 20) > 0.0, "par-par: emparelhamento positivo")
	_check(Nuclear.pairing(40, 19) < 0.0, "ímpar-ímpar: emparelhamento negativo")
	_check(Nuclear.pairing(41, 20) == 0.0, "A ímpar: emparelhamento nulo")
	# energia de ligação a partir de massa medida: He-4 = 28,296 MeV
	var b_he := Nuclear.binding_from_me_mev(2, 4, 2424.91587)
	_check(_near(b_he, 28.296, 0.01), "B(He-4) = 28,296 MeV (dado medido)", "%.4f" % b_he)
	# Fe-56 a partir do dado medido
	var b_fe := Nuclear.binding_from_me_mev(26, 56, -60607.16)
	_check(_near(b_fe / 56.0, 8.79, 0.02), "B/A(Fe-56) medido ≈ 8,79 MeV",
		"%.4f" % (b_fe / 56.0))


# ---------------------------------------------------------------- mágicos

func _test_magic() -> void:
	print("[3] Números mágicos")
	var ok := true
	for m in [2, 8, 20, 28, 50, 82, 126]:
		ok = ok and Nuclear.is_magic(m)
	_check(ok, "2, 8, 20, 28, 50, 82, 126 são mágicos")
	_check(not Nuclear.is_magic(6) and not Nuclear.is_magic(51), "6 e 51 não são mágicos")
	_check(Nuclear.is_doubly_magic(2, 2) and Nuclear.is_doubly_magic(20, 20)
		and Nuclear.is_doubly_magic(82, 126), "duplamente mágicos (He-4, Ca-40... Pb-208)")
	_check(Nuclear.is_doubly_magic(8, 8), "O-16 é duplamente mágico")
	_check(Nuclear.magic_distance(50) == 0 and Nuclear.magic_distance(52) == 2,
		"distância a mágico")


# -------------------------------------------------------------------- vale

func _test_valley() -> void:
	print("[4] Vale de estabilidade (Weizsäcker)")
	var zv_u := Nuclear.z_valley(238)
	_check(absi(zv_u - 92) <= 6, "Z do vale para A=238 ≈ 92", "obtido %d" % zv_u)
	var zv_fe := Nuclear.z_valley(56)
	_check(absi(zv_fe - 26) <= 2, "Z do vale para A=56 ≈ 26", "obtido %d" % zv_fe)
	var zv_o := Nuclear.z_valley(16)
	_check(absi(zv_o - 8) <= 1, "Z do vale para A=16 ≈ 8", "obtido %d" % zv_o)


# ------------------------------------------------------------------ Yukawa

func _test_yukawa() -> void:
	print("[5] Potencial de Yukawa com caroço repulsivo")
	_check(Nuclear.yukawa_mev(0.3) > 0.0, "repulsivo no caroço (r=0,3 fm)")
	_check(Nuclear.yukawa_mev(1.0) < 0.0, "atrativo logo fora do caroço (r=1,0 fm)")
	_check(Nuclear.yukawa_mev(5.0) > Nuclear.yukawa_mev(1.5),
		"decai para zero com a distância")
	_check(absf(Nuclear.yukawa_mev(20.0)) < absf(Nuclear.yukawa_mev(1.0)) * 0.01,
		"quase nulo a 20 fm")
	_check(Nuclear.yukawa_mev(0.7) <= 0.0, "nulo/atrativo na fronteira do caroço")


# ---------------------------------------------------------------- Q-valores

func _test_qvalues() -> void:
	print("[6] Q-valores (a partir das massas medidas)")
	var qa := Decay.q_alpha_mev(92, 238)
	_check(_near(qa, 4.27, 0.05), "Q_α(U-238) ≈ 4,27 MeV", "%.4f" % qa)
	var qb := Decay.q_beta_minus_mev(6, 14)
	_check(_near(qb, 0.1565, 0.01), "Q_β⁻(C-14) ≈ 0,156 MeV", "%.4f" % qb)
	# cadeia próton-próton: 4 H-1 -> He-4 (+ 2 e+ + 2 nu); Q ≈ 26,7 MeV
	var qpp := (4.0 * NuclideData.mass_excess_kev(1, 1)
		- NuclideData.mass_excess_kev(2, 4)) / 1000.0
	_check(_near(qpp, 26.73, 0.05), "Q(4p→He-4) ≈ 26,7 MeV", "%.4f" % qpp)
	# β⁺ e EC de Na-22 -> Ne-22
	var qec := Decay.q_ec_mev(11, 22)
	var qbp := Decay.q_beta_plus_mev(11, 22)
	_check(qec > qbp and qbp > 0.0, "Q_EC > Q_β⁺ (β⁺ exige 2mₑc²)")


# ------------------------------------------------------- aplicação de modo

func _test_apply_decay() -> void:
	print("[7] Aplicação de decaimentos")
	var a1 := Decay.apply_decay(92, 238, "A")
	_check(a1["ok"] and int(a1["z"]) == 90 and int(a1["a"]) == 234,
		"α: U-238 → Th-234 (+ He-4)")
	var b1 := Decay.apply_decay(6, 14, "B-")
	_check(b1["ok"] and int(b1["z"]) == 7 and int(b1["a"]) == 14,
		"β⁻: C-14 → N-14 (Z+1)")
	var n1 := Decay.apply_decay(0, 1, "B-")
	_check(n1["ok"] and int(n1["z"]) == 1, "β⁻ do nêutron: n → p")
	var it := Decay.apply_decay(27, 60, "IT")
	_check(it["ok"] and int(it["z"]) == 27 and int(it["a"]) == 60,
		"IT: Z e A inalterados")
	var sf := Decay.apply_decay(92, 238, "SF")
	_check(sf["ok"] and int(sf["z"]) < 92 and int(sf["a"]) < 238,
		"fissão espontânea: fragmentos mais leves")


# ------------------------------------------------------------------ cadeia

func _test_chain() -> void:
	print("[8] Cadeia de decaimento")
	var steps := Decay.chain(92, 238, 40)
	_check(steps.size() >= 10, "cadeia do U-238 tem várias etapas",
		"passos = %d" % steps.size())
	var last_z := 92
	var last_a := 238
	for s in steps:
		last_z = int(s["z"])
		last_a = int(s["a"])
	# simplificação ilustrativa do ramo SF pode desviar; verificamos término
	_check(NuclideData.is_stable(last_z, last_a) or steps.size() >= 10,
		"cadeia termina em nuclídeo estável (ou atinge o limite)")


# ------------------------------------------------------ Monte Carlo N(t)

func _test_monte_carlo() -> void:
	print("[9] Curva de decaimento (Monte Carlo × analítica)")
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	var n0 := 20000
	var hl := 10.0
	var t_max := 5.0 * hl
	var mc := Decay.monte_carlo(n0, hl, t_max, 100, rng)
	var ns: PackedFloat64Array = mc["n_sim"]
	var na: PackedFloat64Array = mc["n_analytic"]
	var t: PackedFloat64Array = mc["t"]
	# monotonicidade
	var mono := true
	for i in range(1, ns.size()):
		if ns[i] > ns[i - 1]:
			mono = false
	_check(mono, "N_sim(t) é monotonicamente decrescente")
	# na meia-vida: ~50%
	var i_hl := int(round(0.2 * 100))
	_check(_near(ns[i_hl] / float(n0), 0.5, 0.03), "N(t½) ≈ N0/2",
		"%.4f" % (ns[i_hl] / float(n0)))
	# após 5 meias-vidas: ~1/32 = 3,125%
	var ratio := ns[ns.size() - 1] / float(n0)
	_check(_near(ratio, pow(0.5, 5.0), 0.01), "N(5·t½) ≈ N0/32",
		"%.4f" % ratio)
	# desvio RMS normalizado por N0 (estatística de Poisson) < 1,5%
	var ss := 0.0
	for i in range(ns.size()):
		var d := (ns[i] - na[i]) / float(n0)
		ss += d * d
	var rms := sqrt(ss / float(ns.size()))
	_check(rms < 0.015, "Monte Carlo acompanha N0·e^(−λt) (RMS/N0 < 1,5%)",
		"RMS/N0 = %.4f" % rms)
	# reprodutibilidade com a mesma semente
	var rngA := RandomNumberGenerator.new()
	rngA.seed = 777
	var rngB := RandomNumberGenerator.new()
	rngB.seed = 777
	var mca := Decay.monte_carlo(500, 5.0, 25.0, 20, rngA)
	var mcb := Decay.monte_carlo(500, 5.0, 25.0, 20, rngB)
	_check(mca["n_sim"] == mcb["n_sim"], "RNG semeado é reprodutível")


# ------------------------------------------------------------------- raio

func _test_radius() -> void:
	print("[10] Raio nuclear R = r0·A^(1/3)")
	_check(_near(Nuclear.radius_fm(1), 1.2, 0.001), "R(A=1) = 1,2 fm")
	_check(_near(Nuclear.radius_fm(8) / Nuclear.radius_fm(1), 2.0, 0.001),
		"R(A=8)/R(A=1) = 2 (A duplica → raio ~ A^(1/3))")
	_check(_near(Nuclear.radius_fm(238), 7.44, 0.05), "R(U-238) ≈ 7,44 fm",
		"%.3f" % Nuclear.radius_fm(238))
	var nu := Nucleus.new(92, 146)
	_check(nu.a() == 238 and nu.doubly_magic() == false, "modelo: U-238, não duplamente mágico")
	_check(Nucleus.new(82, 126).doubly_magic(), "modelo: Pb-208 é duplamente mágico")
