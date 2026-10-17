extends SceneTree
## Suite de testes de física — Fase 1 (headless).
## Executar: godot --headless --path . --script res://tests/run_tests.gd

const AtomConstants = preload("res://scripts/atom_constants.gd")
const OrbitalMath = preload("res://scripts/orbital_math.gd")
const OrbitalSampler = preload("res://scripts/orbital_sampler.gd")
const ElectronConfig = preload("res://scripts/electron_config.gd")
const PhotonCannon = preload("res://scripts/photon_cannon.gd")

var failed := 0
var passed := 0


func _init() -> void:
	print("=== QA FÍSICO — Simulador Atômico / Fase 1 ===")
	_test_energies()
	_test_rydberg()
	_test_normalization()
	_test_monte_carlo()
	_test_config()
	_test_selection_rules()
	_test_photon_cannon()
	_test_cascade()
	_test_units()
	print("--------------------------------------------------")
	print("RESULTADO: %d OK, %d FALHAS" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _check(cond: bool, name: String, detail: String = "") -> void:
	if cond:
		passed += 1
		print("  OK    %s" % name)
	else:
		failed += 1
		print("  FALHA %s %s" % [name, detail])


# ------------------------------------------------------------- energias

func _test_energies() -> void:
	print("[1] Energias de niveis (E_n = -13,606 Z^2/n^2)")
	var e1 := OrbitalMath.energy_ev(1, 1)
	_check(absf(e1 + 13.606) < 0.001, "E1(H) = -13,606 eV", "obtido %.6f" % e1)
	_check(absf(OrbitalMath.energy_ev(1, 2) + 3.401) < 0.001, "E2(H) = -3,401 eV",
		"obtido %.6f" % OrbitalMath.energy_ev(1, 2))
	_check(absf(OrbitalMath.energy_ev(2, 1) + 54.423) < 0.002,
		"E1(He+ Z=2) = -54,423 eV", "obtido %.6f" % OrbitalMath.energy_ev(2, 1))
	var de := OrbitalMath.transition_energy_ev(1, 1, 2)
	_check(absf(de - 10.204) < 0.001, "deltaE(1->2) = 10,204 eV", "obtido %.6f" % de)
	_check(OrbitalMath.mean_radius_au(1, 0) == 1.5, "<r>_1s = 1,5 a0")
	_check(OrbitalMath.mean_radius_au(3, 2) == 10.5, "<r>_3d = 10,5 a0")


# --------------------------------------------------------------- rydberg

func _test_rydberg() -> void:
	print("[2] Serie de Rydberg e consistencia hc/lambda")
	var lam_lyman := OrbitalMath.wavelength_nm(1, 1, 2)
	_check(absf(lam_lyman - 121.5) < 0.15, "Lymann-alpha ~ 121,5 nm",
		"obtido %.3f nm" % lam_lyman)
	var lam_halpha := OrbitalMath.wavelength_nm(1, 3, 2)
	_check(lam_halpha > 655.5 and lam_halpha < 657.0, "H-alpha ~ 656 nm",
		"obtido %.3f nm" % lam_halpha)
	var lam_hbeta := OrbitalMath.wavelength_nm(1, 4, 2)
	_check(lam_hbeta > 485.5 and lam_hbeta < 487.0, "H-beta ~ 486 nm",
		"obtido %.3f nm" % lam_hbeta)
	# autoconsistencia: E = hc/lambda calculada pela serie de Rydberg
	var ok := true
	var worst := 0.0
	for n1 in range(1, 5):
		for n2 in range(n1 + 1, 6):
			var l := OrbitalMath.wavelength_nm(1, n1, n2)
			var e_from_lambda := AtomConstants.photon_energy_ev(l)
			var e_direct := OrbitalMath.transition_energy_ev(1, n1, n2)
			var rel := absf(e_from_lambda - e_direct) / e_direct
			worst = maxf(worst, rel)
			if rel > 1.0e-6:
				ok = false
	_check(ok, "hc/lambda == deltaE para todas as linhas 1<=n<5",
		"pior erro relativo %.8f" % worst)
	# hc*Ry em eV deve reproduzir a constante de Rydberg
	var hc_r := AtomConstants.HC_EV_NM * AtomConstants.RYDBERG_CONSTANT_M / 1.0e9
	_check(absf(hc_r - AtomConstants.RYDBERG_EV) < 1.0e-5,
		"hc*R_inf = Ry (eV)", "%.9f vs %.9f" % [hc_r, AtomConstants.RYDBERG_EV])


# ---------------------------------------------------------- normalizacao

func _test_normalization() -> void:
	print("[3] Normalizacao de R_nl e Y_lm")
	var cases := [[1, 0], [2, 1], [3, 2], [4, 3]]
	for c in cases:
		var n := int(c[0])
		var l := int(c[1])
		var r_max := 4.0 * float(n * n) + 12.0
		var steps := 20000
		var dr := r_max / float(steps)
		var acc := 0.0
		for i in range(steps + 1):
			var r := float(i) * dr
			var w := 1.0
			if i == 0 or i == steps:
				w = 0.5
			acc += OrbitalMath.radial_probability(n, l, r) * w * dr
		_check(absf(acc - 1.0) < 0.002, "integral r^2 R^2 dr ~ 1 (%s)" %
			OrbitalMath.orbital_label(n, l), "obtido %.5f" % acc)
	# integral de |Y|^2 sobre a esfera
	for c in [[0, 0], [1, 0], [1, -1], [2, 2], [3, -3]]:
		var l := int(c[0])
		var m := int(c[1])
		var acc := 0.0
		var n_ct := 401
		var n_phi := 720
		for i in range(n_ct - 1):
			var ct0 := -1.0 + 2.0 * float(i) / float(n_ct - 1)
			var ct1 := -1.0 + 2.0 * float(i + 1) / float(n_ct - 1)
			for j in range(n_phi):
				var p0 := TAU * float(j) / float(n_phi)
				var y := OrbitalMath.real_sh(l, m, (ct0 + ct1) * 0.5, p0 + TAU / float(n_phi) * 0.5)
				acc += y * y * (ct1 - ct0) * (TAU / float(n_phi))
		_check(absf(acc - 1.0) < 0.003, "integral |Y_lm|^2 dOmega ~ 1 (l=%d,m=%d)" % [l, m],
			"obtido %.5f" % acc)


# ----------------------------------------------------------- monte carlo

func _test_monte_carlo() -> void:
	print("[4] Amostragem Monte Carlo (regra de Born)")
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	var checks := [[1, 0, 0, 1.5], [2, 0, 0, 6.0], [2, 1, 0, 5.0], [3, 2, 0, 10.5]]
	for c in checks:
		var n := int(c[0])
		var l := int(c[1])
		var m := int(c[2])
		var expected := float(c[3])
		var d := OrbitalSampler.sample_orbital(n, l, m, 20000, rng)
		var pos: PackedVector3Array = d["pos"]
		var neg: PackedVector3Array = d["neg"]
		var total := pos.size() + neg.size()
		if total == 0:
			_check(false, "<r> de %s" % OrbitalMath.orbital_label(n, l), "0 pontos")
			continue
		var sum := 0.0
		for p in pos:
			sum += p.length()
		for p in neg:
			sum += p.length()
		var mean := sum / float(total)
		var err := absf(mean - expected) / expected
		_check(err < 0.05, "<r> de %s ~ %.1f a0" % [OrbitalMath.orbital_label(n, l), expected],
			"obtido %.3f (%.2f%% de erro, %d pontos)" % [mean, err * 100.0, total])
	# 1s so tem fase positiva; 2p m=0 tem os dois lobos com fase oposta
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 7
	var d1s := OrbitalSampler.sample_orbital(1, 0, 0, 500, rng2)
	var d2p := OrbitalSampler.sample_orbital(2, 1, 0, 500, rng2)
	_check((d1s["pos"] as PackedVector3Array).size() > 0
		and (d1s["neg"] as PackedVector3Array).is_empty(),
		"1s: todos os pontos em fase + (sem nodos)")
	_check((d2p["pos"] as PackedVector3Array).size() > 0
		and (d2p["neg"] as PackedVector3Array).size() > 0,
		"2p_z: lobos de fase + e -")


# ------------------------------------------------------------ configuracao

func _test_config() -> void:
	print("[5] Aufbau + Pauli + Hund + excecoes (tabela)")
	_check(ElectronConfig.config_string(1, 1) == "1s¹", "H: 1s¹",
		ElectronConfig.config_string(1, 1))
	_check(ElectronConfig.config_string(6, 6) == "1s² 2s² 2p²", "C: 1s² 2s² 2p²",
		ElectronConfig.config_string(6, 6))
	_check(ElectronConfig.config_string(26, 26) == "1s² 2s² 2p⁶ 3s² 3p⁶ 3d⁶ 4s²",
		"Fe: [Ar] 3d⁶ 4s²", ElectronConfig.config_string(26, 26))
	_check(ElectronConfig.config_string(24, 24) == "1s² 2s² 2p⁶ 3s² 3p⁶ 3d⁵ 4s¹",
		"Cr: exceção 3d⁵ 4s¹", ElectronConfig.config_string(24, 24))
	_check(ElectronConfig.config_string(29, 29) == "1s² 2s² 2p⁶ 3s² 3p⁶ 3d¹⁰ 4s¹",
		"Cu: exceção 3d¹⁰ 4s¹", ElectronConfig.config_string(29, 29))
	var pd := ElectronConfig.config_string(46, 46)
	_check(pd.find("4d¹⁰") >= 0 and pd.find("5s") < 0,
		"Pd: exceção 4d¹⁰ (sem 5s)", pd)

	# Pauli: capacidade 2(2l+1) por subcamada, ate 2 por orbital (n,l,m)
	_check(ElectronConfig.capacity("1s") == 2, "capacidade 1s = 2")
	_check(ElectronConfig.capacity("2p") == 6, "capacidade 2p = 6")
	_check(ElectronConfig.capacity("3d") == 10, "capacidade 3d = 10")
	_check(ElectronConfig.capacity("4f") == 14, "capacidade 4f = 14")

	var conservation_ok := true
	var detail := ""
	for zz in range(1, 55):
		for ee in range(0, zz + 1):
			var occ := ElectronConfig.occupancy_list(zz, ee)
			var sum := 0
			var per_label := {}
			for entry in occ:
				var cnt := int(entry["count"])
				if cnt > 2 or cnt < 1:
					conservation_ok = false
					detail = "count invalido Z=%d e=%d" % [zz, ee]
				sum += cnt
				per_label[entry["label"]] = int(per_label.get(entry["label"], 0)) + cnt
			if sum != ee:
				conservation_ok = false
				detail = "Z=%d pediu %d, somou %d" % [zz, ee, sum]
			for label in per_label:
				if int(per_label[label]) > ElectronConfig.capacity(String(label)):
					conservation_ok = false
					detail = "Pauli violado em %s (Z=%d)" % [label, zz]
	_check(conservation_ok, "conservação de nº de elétrons + Pauli (Z=1..54)", detail)

	# Hund: em C (2p²) os dois elétrons ficam em m diferentes, sem parear
	var c_occ := ElectronConfig.occupancy_list(6, 6)
	var p_count := 0
	var p_paired := false
	for entry in c_occ:
		if String(entry["label"]) == "2p":
			p_count += 1
			if int(entry["count"]) == 2:
				p_paired = true
	_check(p_count == 2 and not p_paired, "Hund: 2p² ocupa dois m distintos",
		"entradas 2p = %d, pareado = %s" % [p_count, p_paired])


# -------------------------------------------------------- regras de selecao

func _test_selection_rules() -> void:
	print("[6] Regras de seleção dipolares (delta_l = +-1, delta_m in {0,+-1})")
	_check(OrbitalMath.is_allowed_transition(1, 0, 0, 2, 1, 0), "1s -> 2p permitido")
	_check(not OrbitalMath.is_allowed_transition(1, 0, 0, 2, 0, 0), "1s -> 2s proibido (delta_l=0)")
	_check(OrbitalMath.is_allowed_transition(2, 1, 0, 3, 2, 0), "2p -> 3d permitido")
	_check(not OrbitalMath.is_allowed_transition(1, 0, 0, 3, 0, 0), "1s -> 3s proibido (delta_l=0)")
	_check(not OrbitalMath.is_allowed_transition(2, 1, 0, 3, 1, 0), "3p -> 3p proibido (delta_l=0)")
	_check(not OrbitalMath.is_allowed_transition(3, 2, 1, 4, 3, -1), "delta_m=-2 proibido")
	_check(OrbitalMath.is_allowed_transition(3, 2, 1, 4, 3, 0), "delta_m=0 permitido")
	_check(not OrbitalMath.is_allowed_transition(2, 0, 0, 2, 1, 0), "mesmo n proibido (sem absorção)")


# ---------------------------------------------------------- canhao de fotons

func _test_photon_cannon() -> void:
	print("[7] Canhão de fótons: absorção, ionização, sem interação")
	var e_12 := OrbitalMath.transition_energy_ev(1, 1, 2)
	var r := PhotonCannon.interact(e_12, 1, 1, 0, 0)
	_check(String(r.get("type", "")) == "excitation", "fóton ressonante excita 1s->2p",
		str(r))
	if String(r.get("type", "")) == "excitation":
		_check(int(r["n"]) == 2 and int(r["l"]) == 1, "estado final n=2, l=1", str(r))

	var no := PhotonCannon.interact(10.0, 1, 1, 0, 0)
	_check(String(no.get("type", "")) == "no_interaction",
		"10,0 eV fora de ressonância -> sem interação", str(no))

	var ion := PhotonCannon.interact(14.0, 1, 1, 0, 0)
	_check(String(ion.get("type", "")) == "ionization",
		"14,0 eV >= 13,606 eV -> efeito fotoelétrico", str(ion))
	if String(ion.get("type", "")) == "ionization":
		_check(absf(float(ion["kinetic_ev"]) - (14.0 - 13.6057)) < 0.001,
			"E_cin do fotoelétron = E - E_ion", "%.5f" % float(ion["kinetic_ev"]))

	# He+ (Z=2): níveis 4x maiores
	var he_12 := OrbitalMath.transition_energy_ev(2, 1, 2)
	_check(absf(he_12 - 40.817) < 0.005, "He+ 1s->2p = 40,817 eV", "%.4f" % he_12)
	var he_ion := PhotonCannon.interact(54.5, 2, 1, 0, 0)
	_check(String(he_ion.get("type", "")) == "ionization",
		"He+ ionizado por 54,5 eV", str(he_ion))

	# transição s->s nunca é absorvida mesmo com energia certa
	var s_to_s := PhotonCannon.try_excite(OrbitalMath.transition_energy_ev(1, 2, 3), 1, 2, 0, 0)
	var ok_ss := true
	if not s_to_s.is_empty():
		ok_ss = int(s_to_s["l"]) == 1  # só pode ir para p
	_check(ok_ss, "s -> s nunca aparece como alvo (só s -> p)")


# --------------------------------------------------------------- cascata

func _test_cascade() -> void:
	print("[8] Cascata de decaimento com conservação de regras")
	var steps := PhotonCannon.cascade(1, {"n": 3, "l": 1, "m": 0}, {"n": 1, "l": 0, "m": 0})
	_check(not steps.is_empty(), "3p -> 1s emite ao menos 1 fóton", str(steps))
	var prev_n := 99
	var chain_ok := true
	var energy_ok := true
	for s in steps:
		if int(s["n_from"]) >= prev_n:
			chain_ok = false
		prev_n = int(s["n_to"])
		if float(s["energy_ev"]) <= 0.0:
			chain_ok = false
		var e_lam := AtomConstants.photon_energy_ev(float(s["lambda_nm"]))
		if absf(e_lam - float(s["energy_ev"])) / float(s["energy_ev"]) > 1.0e-6:
			energy_ok = false
		if not OrbitalMath.is_allowed_transition(int(s["n_from"]), int(s["l_from"]),
				int(s["m_from"]), int(s["n_to"]), int(s["l_to"]), int(s["m_to"])):
			chain_ok = false
	_check(chain_ok, "cascata: n estritamente decrescente + delta_l/delta_m válidos")
	_check(energy_ok, "cascata: hc/lambda = deltaE em cada passo")
	_check(prev_n == 1, "cascata termina no estado fundamental", "terminou em n=%d" % prev_n)

	var fsteps := PhotonCannon.cascade(1, {"n": 4, "l": 3, "m": 0}, {"n": 1, "l": 0, "m": 0})
	_check(fsteps.size() >= 2, "4f -> 1s decai em múltiplos fótons",
		"%d passos" % fsteps.size())
	if fsteps.size() > 0:
		var last: Dictionary = fsteps[fsteps.size() - 1]
		_check(int(last["n_to"]) == 1 and int(last["l_to"]) == 0,
			"último fóton leva ao 1s", str(last))

	var empty := PhotonCannon.cascade(1, {"n": 1, "l": 0, "m": 0}, {"n": 1, "l": 0, "m": 0})
	_check(empty.is_empty(), "estado fundamental não decai")


# ------------------------------------------------------------------ unidades

func _test_units() -> void:
	print("[9] Constantes e conversões de unidades")
	_check(absf(AtomConstants.bohr_to_angstrom(1.0) - 0.529177) < 1.0e-6,
		"1 a0 = 0,529177 Å")
	_check(absf(AtomConstants.photon_energy_ev(656.47) - 1.8887) < 0.001,
		"fóton de 656,47 nm ~ 1,889 eV", "%.5f" % AtomConstants.photon_energy_ev(656.47))
	var roundtrip := AtomConstants.photon_wavelength_nm(AtomConstants.photon_energy_ev(486.1))
	_check(absf(roundtrip - 486.1) < 1.0e-6, "ida e volta eV <-> nm")
	_check(absf(AtomConstants.HARTREE_EV - 2.0 * AtomConstants.RYDBERG_EV) < 1.0e-9,
		"1 Hartree = 2 Ry")
	_check(AtomConstants.scale_note("atom").find("10^-10") > 0, "nota de escala atômica")
