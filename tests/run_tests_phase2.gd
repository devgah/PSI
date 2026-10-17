extends SceneTree
## Suite de testes — FASE 2 (tabela periódica, Slater, NIST).
## Executar: godot --headless --path . --script res://tests/run_tests_phase2.gd

const AtomConstants = preload("res://scripts/atom_constants.gd")
const OrbitalMath = preload("res://scripts/orbital_math.gd")
const PhotonCannon = preload("res://scripts/photon_cannon.gd")
const ElectronConfig = preload("res://scripts/electron_config.gd")
const Slater = preload("res://scripts/slater.gd")
const ElementData = preload("res://scripts/element_data.gd")
const AtomicProperties = preload("res://scripts/atomic_properties.gd")

var failed := 0
var passed := 0


func _init() -> void:
	print("=== QA — Simulador Atômico / Fase 2 (tabela periódica + Slater) ===")
	_test_element_data()
	_test_slater_rules()
	_test_atomic_properties()
	_test_zeff_engine()
	_test_phase1_no_regression()
	print("--------------------------------------------------")
	print("RESULTADO FASE 2: %d OK, %d FALHAS" % [passed, failed])
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

func _test_element_data() -> void:
	print("[10] Dados externos (data/elements.json — IE1 do NIST ASD)")
	_check(ElementData.count() == 54, "54 elementos (Z=1..54)",
		"obtido %d" % ElementData.count())
	_check(ElementData.symbol(1) == "H" and ElementData.symbol(54) == "Xe",
		"símbolos H..Xe")
	_check(ElementData.name(26) == "Ferro", "nome PT-BR do Fe", ElementData.name(26))
	_check(ElementData.group(11) == 1 and ElementData.period(11) == 3,
		"Na: grupo 1, período 3")
	_check(ElementData.group(18) == 18 and ElementData.period(18) == 3,
		"Ar: grupo 18, período 3")
	_check(ElementData.block(26) == "d" and ElementData.block(6) == "p"
		and ElementData.block(1) == "s", "blocos s/p/d corretos")

	# valores medidos (NIST) — tolerância apertada
	var cases := {
		1: 13.598434599702, 2: 24.587389011, 3: 5.391714996,
		6: 11.2602880, 11: 5.13907696, 26: 7.9024681, 54: 12.1298437}
	var ok := true
	var detail := ""
	for z in cases:
		var got := ElementData.ie1_ev(int(z))
		if not _near(got, float(cases[z]), 1.0e-6):
			ok = false
			detail = "Z=%d: %.6f != %.6f" % [z, got, float(cases[z])]
	_check(ok, "IE1(NIST) confere com a base para amostra", detail)

	var all_valid := true
	for z in ElementData.all_z():
		var ie := ElementData.ie1_ev(int(z))
		var g := ElementData.group(int(z))
		var p := ElementData.period(int(z))
		if ie <= 0.0 or g < 1 or g > 18 or p < 1 or p > 5:
			all_valid = false
	_check(all_valid, "todos os 54 elementos têm IE1>0 e grupo/período válidos")

	# gases nobres têm IE1 alta em relação aos vizinhos de período
	var noble_ok := ElementData.ie1_ev(10) > ElementData.ie1_ev(9) \
		and ElementData.ie1_ev(10) > ElementData.ie1_ev(11) \
		and ElementData.ie1_ev(18) > ElementData.ie1_ev(17) \
		and ElementData.ie1_ev(36) > ElementData.ie1_ev(35) \
		and ElementData.ie1_ev(54) > ElementData.ie1_ev(53)
	_check(noble_ok, "gases nobres com IE1 > vizinhos (Ne, Ar, Kr, Xe)")
	_check(String(ElementData.meta().get("url", "")).find("nist.gov") > 0,
		"metadados apontam a fonte NIST")


# ------------------------------------------------------------- regras Slater

func _test_slater_rules() -> void:
	print("[11] Regras de Slater — Z_eff (valores de livro-texto)")
	var expected := {
		2: 1.70, 3: 1.30, 4: 1.95, 5: 2.60, 6: 3.25, 7: 3.90,
		8: 4.55, 9: 5.20, 10: 5.85, 11: 2.20}
	var ok := true
	var detail := ""
	for z in expected:
		var got := Slater.z_eff_outer(int(z))
		if not _near(got, float(expected[z]), 0.005):
			ok = false
			detail = "Z=%d: %.3f != %.2f" % [z, got, float(expected[z])]
	_check(ok, "Z_eff da valência (He, Li, Be, B, C, N, O, F, Ne, Na)", detail)

	# metais de transição: 3d vs 4s
	_check(_near(_z_eff_orbital(26, 3, 2), 6.25, 0.01), "Fe 3d: Z_eff = 6,25",
		"%.3f" % _z_eff_orbital(26, 3, 2))
	_check(_near(_z_eff_orbital(26, 4, 0), 3.75, 0.01), "Fe 4s: Z_eff = 3,75",
		"%.3f" % _z_eff_orbital(26, 4, 0))

	_check(_near(Slater.z_eff_outer(1), 1.0, 1.0e-9), "H: Z_eff = 1 (sem blindagem)")
	var mono := true
	var prev := 0.0
	for z in range(3, 11):
		var v := Slater.z_eff_outer(z)
		if v < prev:
			mono = false
		prev = v
	_check(mono, "Z_eff cresce ao longo do período 2 (Li..Ne)")

	var less := true
	for z in range(2, 55):
		if Slater.z_eff_outer(z) >= float(z):
			less = false
	_check(less, "Z_eff < Z para todo elemento multieletrônico (blindagem)")

	_check(Slater.outer_n(26, 26) == 4, "camada de valência do Fe = n=4")
	_check(Slater.outer_n(1, 1) == 1, "camada do H = n=1")


func _z_eff_orbital(z: int, n: int, l: int) -> float:
	var occ := ElectronConfig.occupancy_list(z, z)
	# escolhe a órbita de base correspondente (n,l) e computa o Z_eff daquela órbita
	var base := {}
	for e in occ:
		if int(e["n"]) == n and int(e["l"]) == l:
			base = e
			break
	if base.is_empty():
		# não ocupado no fundamental: usa o elétron mais externo como base
		base = occ[occ.size() - 1]
	return Slater.z_eff_for(z, z, base, n, l)


# ----------------------------------------------------------- propriedades

func _test_atomic_properties() -> void:
	print("[12] Propriedades atômicas (raio de Slater, IE estimada vs NIST)")
	_check(_near(AtomicProperties.slater_radius_au(1), 1.0, 1.0e-6),
		"raio do H = 1 a0", "%.4f" % AtomicProperties.slater_radius_au(1))
	_check(_near(AtomicProperties.slater_radius_au(11), 9.0 / 2.2, 1.0e-6),
		"raio do Na = n^2/Z_eff = 4,09 a0")
	_check(_near(AtomicProperties.slater_radius_angstrom(1), AtomConstants.BOHR_ANG, 1.0e-9),
		"raio do H em Å = 0,529 Å")
	_check(_near(AtomicProperties.slater_ie1_ev(1), AtomConstants.RYDBERG_EV, 1.0e-6),
		"IE1(Slater) do H = 13,606 eV")
	# Slater estima energia de ionização de forma GROSSEIRA: erros grandes em
	# metais de transição/gases nobres são esperados e documentados. Aqui só
	# verificamos que o erro é finito e que o modelo funciona bem nos alcalinos.
	var finite_ok := true
	for z in ElementData.all_z():
		var e := AtomicProperties.slater_ie1_error(int(z))
		if e < 0.0 or not is_finite(e):
			finite_ok = false
	_check(finite_ok, "erro |Slater - NIST|/NIST finito para os 54 elementos")
	var alkali_ok := true
	var alkali_detail := ""
	for z in [3, 11, 19, 37]:
		var e := AtomicProperties.slater_ie1_error(int(z))
		if e > 0.80:
			alkali_ok = false
			alkali_detail = "Z=%d erro %.0f%%" % [z, e * 100.0]
	_check(alkali_ok, "Slater acerta alcalinos (Li, Na, K, Rb) dentro de 80%",
		alkali_detail)
	# tendência qualitativa: alcalino < gás nobre do mesmo período (Slater)
	_check(AtomicProperties.slater_ie1_ev(3) < AtomicProperties.slater_ie1_ev(10)
		and AtomicProperties.slater_ie1_ev(11) < AtomicProperties.slater_ie1_ev(18)
		and AtomicProperties.slater_ie1_ev(19) < AtomicProperties.slater_ie1_ev(36)
		and AtomicProperties.slater_ie1_ev(37) < AtomicProperties.slater_ie1_ev(54),
		"tendência: IE(alcalino) < IE(gás nobre) no mesmo período")
	_check(is_finite(AtomicProperties.slater_ie1_error(46)),
		"Pd (config excepcional 4d¹⁰) não quebra o cálculo")
	_check(AtomicProperties.nist_ie1_ev(2) > 20.0 and AtomicProperties.nist_ie1_ev(2) < 26.0,
		"IE1(NIST) do He ~ 24,6 eV", "%.3f" % AtomicProperties.nist_ie1_ev(2))


# ------------------------------------------------- integração no motor

func _test_zeff_engine() -> void:
	print("[13] Motor aceita Z_eff (float): energias, transições, fótons")
	# Li: Z_eff(val.)=1.30, n=2 -> energia do nível fortemente reduzida
	var ze := Slater.z_eff_outer(3)
	var e2 := OrbitalMath.energy_ev(ze, 2)
	_check(_near(e2, -AtomConstants.RYDBERG_EV * 1.30 * 1.30 / 4.0, 1.0e-6),
		"E_2 do Li = -Ry*Z_eff^2/4", "%.4f eV" % e2)
	var de := OrbitalMath.transition_energy_ev(ze, 2, 3)
	var expected := AtomConstants.RYDBERG_EV * 1.30 * 1.30 * (1.0 / 4.0 - 1.0 / 9.0)
	_check(_near(de, expected, 1.0e-6), "ΔE(2->3) do Li coerente com Z_eff",
		"%.4f eV" % de)
	var lam := OrbitalMath.wavelength_nm(ze, 2, 3)
	_check(_near(AtomConstants.photon_energy_ev(lam), de, 1.0e-6),
		"hc/λ = ΔE com Z_eff (Li)")

	# ionização com Z_eff do He (1.70) e elétron em n=1
	var ion := PhotonCannon.interact(40.0, Slater.z_eff_outer(2), 1, 0, 0)
	_check(String(ion.get("type", "")) == "ionization",
		"fóton de 40 eV ioniza He(Z_eff=1,70, n=1)", str(ion))
	var below := PhotonCannon.interact(30.0, Slater.z_eff_outer(2), 1, 0, 0)
	_check(String(below.get("type", "")) != "ionization",
		"30 eV não ioniza He(Z_eff) — abaixo de 39,3 eV")

	# H (Z_eff=1) mantém a série de Balmer
	var halo := OrbitalMath.wavelength_nm(Slater.z_eff_outer(1), 3, 2)
	_check(halo > 655.5 and halo < 657.0, "H-alpha inalterado com Z_eff=1",
		"%.3f nm" % halo)


# ----------------------------------------------- não regressão da Fase 1

func _test_phase1_no_regression() -> void:
	print("[14] Não regressão da Fase 1 (z inteiro ainda funciona)")
	_check(_near(OrbitalMath.energy_ev(1, 1), -13.60569, 0.001), "E1(H) ok")
	_check(_near(OrbitalMath.energy_ev(2, 1), -54.4228, 0.002), "E1(He+, Z=2) ok")
	_check(_near(OrbitalMath.transition_energy_ev(1, 1, 2), 10.204, 0.001),
		"ΔE(1->2) do H ok")
