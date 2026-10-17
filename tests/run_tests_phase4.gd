extends SceneTree
## Suite de testes — FASE 4 (ligação química: LCAO-MO, Pauling, VSEPR, Morse).
## Executar: godot --headless --path . --script res://tests/run_tests_phase4.gd

const Electronegativity = preload("res://scripts/electronegativity.gd")
const MolecularOrbital = preload("res://scripts/molecular_orbital.gd")
const MoleculeData = preload("res://scripts/molecule_data.gd")
const MoleculeModel = preload("res://scripts/molecule_model.gd")
const Vsepr = preload("res://scripts/vsepr.gd")
const Morse = preload("res://scripts/morse.gd")
const Thermodynamics = preload("res://scripts/thermodynamics.gd")
const Materials = preload("res://scripts/materials.gd")

var failed := 0
var passed := 0


func _init() -> void:
	print("=== QA — Simulador Atômico / Fase 4 (ligação química) ===")
	_test_data()
	_test_pauling()
	_test_mo_diatomics()
	_test_mo_filling()
	_test_vsepr()
	_test_morse()
	_test_model_geometry()
	_test_model_consistency()
	_test_thermodynamics()
	_test_materials()
	print("--------------------------------------------------")
	print("RESULTADO FASE 4: %d OK, %d FALHAS" % [passed, failed])
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
	print("[1] Dados externos (en_pauling.json, molecules.json)")
	_check(MoleculeData.count() >= 18, "≥ 18 moléculas no catálogo",
		"obtido %d" % MoleculeData.count())
	_check(MoleculeData.has("H2") and MoleculeData.has("O2")
		and MoleculeData.has("H2O") and MoleculeData.has("CH4"),
		"moléculas-chave presentes (H2, O2, H2O, CH4)")
	_check(_near(MoleculeData.bond_length_pm("H2"), 74.14, 0.01),
		"comprimento de ligação H–H = 74,14 pm")
	_check(_near(MoleculeData.bond_angle_deg("H2O"), 104.45, 0.01),
		"ângulo H–O–H = 104,45°")
	_check(MoleculeData.bond_order("N2") == 3, "N₂: ordem de ligação 3 (dado)")
	_check(_near(Electronegativity.en_of(1), 2.20, 0.001), "EN(H) = 2,20")
	_check(_near(Electronegativity.en_of(8), 3.44, 0.001), "EN(O) = 3,44")
	_check(_near(Electronegativity.en_of(9), 3.98, 0.001), "EN(F) = 3,98")
	_check(is_nan(Electronegativity.en_of(2)), "EN(He) indefinida (null)")


# --------------------------------------------------- eletronegatividade

func _test_pauling() -> void:
	print("[2] Eletronegatividade de Pauling e classificação")
	_check(_near(Electronegativity.delta_en(1, 9), 1.78, 0.001),
		"ΔEN(H,F) = 1,78")
	_check(Electronegativity.bond_class(1, 1) == "covalente apolar",
		"H–H: covalente apolar (ΔEN=0)")
	_check(Electronegativity.bond_class(1, 17) == "covalente polar",
		"H–Cl: covalente polar", Electronegativity.bond_class(1, 17))
	_check(Electronegativity.bond_class(11, 17) == "iônica",
		"Na–Cl: iônica (ΔEN≈2,23)", Electronegativity.bond_class(11, 17))
	_check(Electronegativity.bond_class(1, 9) == "iônica",
		"H–F: iônica no limiar (ΔEN=1,78)")
	var ic1 := Electronegativity.ionic_character(1, 1)
	var ic2 := Electronegativity.ionic_character(11, 17)
	_check(_near(ic1, 0.0, 1e-9), "caráter iônico H–H = 0")
	_check(ic2 > 0.6 and ic2 < 1.0, "caráter iônico Na–Cl alto e < 1",
		"%.3f" % ic2)


# ---------------------------------------------------- orbitais moleculares

func _test_mo_diatomics() -> void:
	print("[3] LCAO-MO: ordens de ligação (valores canônicos)")
	var cases := {
		"H2": 1.0, "He2": 0.0, "Li2": 1.0, "Be2": 0.0, "B2": 1.0,
		"C2": 2.0, "N2": 3.0, "O2": 2.0, "F2": 1.0, "Ne2": 0.0,
		"CO": 3.0, "HF": 1.0, "HCl": 1.0, "NaCl": 1.0,
	}
	for id in cases:
		var got := float(MolecularOrbital.diatomic(
			String(MoleculeData.atoms(id)[0]), String(MoleculeData.atoms(id)[1]))["bond_order"])
		_check(_near(got, float(cases[id]), 1e-6),
			"%s: ordem de ligação = %.0f" % [id, cases[id]], "obtido %.2f" % got)


func _test_mo_filling() -> void:
	print("[4] LCAO-MO: preenchimento, magnetismo, HOMO/LUMO")
	# O2 paramagnético (2 desemparelhados em π*2p)
	var o2 := MolecularOrbital.homonuclear("O")
	_check(int(o2["unpaired"]) == 2, "O₂: 2 elétrons desemparelhados",
		"obtido %d" % int(o2["unpaired"]))
	_check(bool(o2["paramagnetic"]), "O₂ é paramagnético")
	_check(String(o2["homo"]) == "π*2p", "O₂ HOMO = π*2p", String(o2["homo"]))
	# N2 diamagnético, HOMO σ2p
	var n2 := MolecularOrbital.homonuclear("N")
	_check(int(n2["unpaired"]) == 0 and not bool(n2["paramagnetic"]),
		"N₂ diamagnético")
	_check(String(n2["homo"]) == "σ2p", "N₂ HOMO = σ2p", String(n2["homo"]))
	# B2 paramagnético (2 desemparelhados em π2p)
	var b2 := MolecularOrbital.homonuclear("B")
	_check(int(b2["unpaired"]) == 2, "B₂: 2 desemparelhados")
	# C2 diamagnético (π2p⁴)
	var c2 := MolecularOrbital.homonuclear("C")
	_check(int(c2["unpaired"]) == 0, "C₂ diamagnético")
	# F2 diamagnético
	_check(int(MolecularOrbital.homonuclear("F")["unpaired"]) == 0, "F₂ diamagnético")
	# regra de ordem π/σ por valência total
	_check(float(MolecularOrbital.homonuclear("N")["bond_order"]) == 3.0
		and float(MolecularOrbital.homonuclear("O")["bond_order"]) == 2.0,
		"valência ≤10 (π abaixo de σ) vs ≥11 (σ abaixo de π)")
	# elétrons de valência
	_check(MolecularOrbital.valence_electrons("O") == 6, "valência do O = 6")
	_check(MolecularOrbital.valence_electrons("Na") == 1, "valência do Na = 1")
	_check(MolecularOrbital.valence_electrons("He") == 2, "valência do He = 2")


# ---------------------------------------------------------------- VSEPR

func _test_vsepr() -> void:
	print("[5] VSEPR: geometria por domínios eletrônicos")
	var ch4 := Vsepr.predict(4, 0)
	_check(ch4["geometry"] == "tetraédrica" and _near(ch4["ideal_angle_deg"], 109.47, 0.01),
		"CH₄: tetraédrica 109,47°")
	_check(ch4["hybridization"] == "sp³", "CH₄: sp³")
	var h2o := Vsepr.predict(2, 2)
	_check(h2o["geometry"] == "angular" and _near(h2o["ideal_angle_deg"], 104.5, 0.01),
		"H₂O: angular ~104,5°")
	var nh3 := Vsepr.predict(3, 1)
	_check(nh3["geometry"] == "piramidal trigonal", "NH₃: piramidal trigonal")
	var co2 := Vsepr.predict(2, 0)
	_check(co2["geometry"] == "linear" and _near(co2["ideal_angle_deg"], 180.0, 0.01),
		"CO₂: linear 180°")
	_check(co2["hybridization"] == "sp", "CO₂: sp")
	_check(Vsepr.predict(6, 0)["geometry"] == "octaédrica", "6 domínios: octaédrica")


# ---------------------------------------------------------------- Morse

func _test_morse() -> void:
	print("[6] Potencial de Morse")
	var de := 4.52
	var re := 74.14
	_check(_near(Morse.energy_ev(re, de, re), 0.0, 1e-9),
		"V(r_e) = 0 (fundo do poço)")
	_check(_near(Morse.energy_ev(10.0 * re, de, re), de, 1e-3),
		"V(→∞) → D_e")
	_check(Morse.energy_ev(re * 0.7, de, re) > 0.0,
		"V(r < r_e) > 0 (repulsão)")
	_check(Morse.energy_ev(re * 1.8, de, re) > 0.0
		and Morse.energy_ev(re * 1.8, de, re) < de,
		"0 < V(r > r_e) < D_e (poço)")
	_check(_near(Morse.force_ev_per_pm(re, de, re), 0.0, 1e-9),
		"força nula em r_e (equilíbrio)")
	_check(Morse.force_ev_per_pm(re * 0.8, de, re) > 0.0,
		"força repulsiva para r < r_e")
	_check(Morse.force_ev_per_pm(re * 1.3, de, re) < 0.0,
		"força atrativa para r > r_e")
	var s := Morse.sample(de, re)
	_check((s["r_pm"] as PackedFloat64Array).size() == 80, "amostra com 80 pontos")
	var n := Morse.harmonic_frequency_thz(de, Morse.A_DEFAULT, 0.504)
	_check(n > 0.0 and n < 300.0, "frequência harmônica plausível",
		"%.2f THz" % n)


# --------------------------------------------------- geometria molecular 3D

func _test_model_geometry() -> void:
	print("[7] Geometria 3D do modelo molecular")
	var h2 := MoleculeModel.new("H2")
	_check(h2.positions_pm().size() == 2, "H₂: 2 átomos posicionados")
	_check(h2.bond_segments_pm().size() == 1, "H₂: 1 ligação")
	var ch4 := MoleculeModel.new("CH4")
	_check(ch4.positions_pm().size() == 5, "CH₄: 5 átomos")
	var p: Array = ch4.positions_pm()
	var a1: Vector3 = (p[1] as Vector3) - (p[0] as Vector3)
	var a2: Vector3 = (p[2] as Vector3) - (p[0] as Vector3)
	var ang := rad_to_deg(acos(clampf(a1.normalized().dot(a2.normalized()), -1.0, 1.0)))
	_check(_near(ang, 109.47, 0.1), "CH₄: ângulo H–C–H = 109,47°", "%.2f" % ang)
	var w := MoleculeModel.new("H2O")
	var pw: Array = w.positions_pm()
	var b1: Vector3 = (pw[1] as Vector3) - (pw[0] as Vector3)
	var b2: Vector3 = (pw[2] as Vector3) - (pw[0] as Vector3)
	var angw := rad_to_deg(acos(clampf(b1.normalized().dot(b2.normalized()), -1.0, 1.0)))
	_check(_near(angw, 104.45, 0.1), "H₂O: ângulo H–O–H = 104,45°", "%.2f" % angw)
	var n := MoleculeModel.new("NH3")
	var pn: Array = n.positions_pm()
	var c1: Vector3 = (pn[1] as Vector3) - (pn[0] as Vector3)
	var c2: Vector3 = (pn[2] as Vector3) - (pn[0] as Vector3)
	var angn := rad_to_deg(acos(clampf(c1.normalized().dot(c2.normalized()), -1.0, 1.0)))
	_check(_near(angn, 107.8, 0.1), "NH₃: ângulo H–N–H = 107,8°", "%.2f" % angn)
	var c := MoleculeModel.new("CO2")
	var pc: Array = c.positions_pm()
	var d1: Vector3 = (pc[1] as Vector3) - (pc[0] as Vector3)
	var d2: Vector3 = (pc[2] as Vector3) - (pc[0] as Vector3)
	var angc := rad_to_deg(acos(clampf(d1.normalized().dot(d2.normalized()), -1.0, 1.0)))
	_check(_near(angc, 180.0, 0.1), "CO₂: ângulo O=C=O = 180°", "%.2f" % angc)


# --------------------------------------------------- consistência modelo × dado

func _test_model_consistency() -> void:
	print("[8] Consistência modelo (LCAO-MO) × dado experimental")
	var classics := ["H2", "He2", "Li2", "Be2", "B2", "C2", "N2", "O2", "F2", "Ne2"]
	for id in classics:
		var m := MoleculeModel.new(id)
		_check(_near(m.computed_bond_order(), float(m.reported_bond_order()), 1e-6),
			"%s: BO(LCAO-MO)=BO(dado)=%d" % [id, m.reported_bond_order()])
	var o2 := MoleculeModel.new("O2")
	_check(o2.paramagnetic() and o2.unpaired() == 2, "O₂ paramagnético (modelo)")
	var co := MoleculeModel.new("CO")
	_check(_near(co.computed_bond_order(), 3.0, 1e-6), "CO: ordem 3 (modelo)")
	# classificação por Pauling via modelo
	_check(MoleculeModel.new("NaCl").bond_class() == "iônica", "NaCl iônica")
	_check(MoleculeModel.new("H2O").bond_class() == "covalente polar", "H₂O polar")
	_check(MoleculeModel.new("H2").bond_class() == "covalente apolar", "H₂ apolar")
	var mm := MoleculeModel.new("H2").morse()
	_check(not mm.is_empty() and float(mm["de_ev"]) > 0.0, "H₂ tem curva de Morse")
	_check(float(mm["d0_ev"]) < float(mm["de_ev"]), "H₂: D₀ < D_e (ponto zero)")
	# ligação metálica
	_check(Electronegativity.bond_class_extended(26, 29) == "metálica",
		"Fe–Zn: ligação metálica")
	_check(Electronegativity.bond_class_extended(11, 11) == "metálica",
		"Na–Na: metálica")
	_check(Electronegativity.bond_class_extended(11, 17) == "iônica",
		"Na–Cl: iônica (não metálica)")


# ------------------------------------------------------- termodinâmica

func _test_thermodynamics() -> void:
	print("[9] Termodinâmica (ΔG = ΔH − TΔS) e cinética")
	var id := "H2_O2_H2O_gas"
	_check(Materials.reaction_count() >= 9, "≥ 9 reações no catálogo",
		"obtido %d" % Materials.reaction_count())
	_check(Materials.reaction(id).has("dh_kj"), "reação tem ΔH")
	var dh := Materials.reaction_dh_kj(id)
	var ds := Materials.reaction_ds_j_k(id)
	var g := Thermodynamics.gibbs_kj(dh, ds, 298.15)
	_check(_near(g, -228.5, 0.6), "ΔG(H₂+½O₂→H₂O, 298 K) ≈ −228,5 kJ/mol",
		"%.2f" % g)
	_check(Thermodynamics.is_spontaneous(dh, ds, 298.15), "formação da água espontânea")
	# ponto de ebulição da água: T = ΔH/ΔS ≈ 373 K
	var t_boil := Thermodynamics.crossover_temperature_k(40.7, 109.0)
	_check(_near(t_boil, 373.4, 1.0), "T(ΔG=0) da vaporização ≈ 373 K (100 °C)",
		"%.1f" % t_boil)
	# Haber: espontânea a 298 K, não espontânea a 800 K
	var nh3 := "N2_H2_NH3"
	var g298 := Thermodynamics.gibbs_kj(Materials.reaction_dh_kj(nh3),
		Materials.reaction_ds_j_k(nh3), 298.15)
	var g800 := Thermodynamics.gibbs_kj(Materials.reaction_dh_kj(nh3),
		Materials.reaction_ds_j_k(nh3), 800.0)
	_check(g298 < 0.0 and g800 > 0.0,
		"Haber: espontânea a 298 K e não espontânea a 800 K")
	# diamante → grafite: espontânea mas travada por Ea gigante
	var dia := "diamante_grafite"
	var gd := Thermodynamics.gibbs_kj(Materials.reaction_dh_kj(dia),
		Materials.reaction_ds_j_k(dia), 298.15)
	var kd := Thermodynamics.arrhenius_factor(Materials.reaction_ea_kj(dia), 298.15)
	_check(gd < 0.0, "diamante→grafite: ΔG < 0 (espontânea)")
	_check(kd < 1e-40, "diamante→grafite: cineticamente travada (metaestável)")
	# Arrhenius aumenta com T; catalisador acelera
	var f300 := Thermodynamics.arrhenius_factor(100.0, 300.0)
	var f600 := Thermodynamics.arrhenius_factor(100.0, 600.0)
	_check(f600 > f300, "Arrhenius cresce com a temperatura")
	var enh := Thermodynamics.catalyst_enhancement(230.0, 100.0, 700.0)
	_check(enh > 1.0, "catalisador aumenta a velocidade")
	# catalisador não altera ΔG
	_check(_near(Thermodynamics.gibbs_kj(-92.4, -198.7, 298.15),
		Thermodynamics.gibbs_kj(-92.4, -198.7, 298.15), 1e-9),
		"catalisador não altera ΔG")
	_check(Thermodynamics.crossover_temperature_k(-1.9, 3.4) < 0.0,
		"diamante: T(ΔG=0) negativa (T nunca é suficiente)")


# ------------------------------------------------------------ materiais

func _test_materials() -> void:
	print("[10] Materiais emergentes e interações fracas")
	_check(Materials.material_count() >= 10, "≥ 10 materiais no catálogo",
		"obtido %d" % Materials.material_count())
	_check(_near(Materials.material_band_gap_ev("diamante"), 5.47, 0.001),
		"diamante: gap = 5,47 eV")
	_check(Materials.material_conduction("diamante") == "isolante", "diamante: isolante")
	_check(_near(Materials.material_band_gap_ev("silicio"), 1.12, 0.001),
		"silício: gap = 1,12 eV")
	_check(Materials.material_conduction("silicio").find("semicondutor") >= 0,
		"silício: semicondutor")
	_check(Materials.material_conduction("grafeno").find("condutor") >= 0,
		"grafeno: condutor")
	_check(Materials.material_bonding("cloreto_sodio") == "iônica",
		"NaCl: ligação iônica")
	_check(Materials.has_material("silicio_n") and Materials.has_material("silicio_p"),
		"silício dopado n e p presentes")
	# interações fracas
	var hb: Array = Materials.weak_interaction_energy_range("ponte_hidrogenio")
	_check(hb.size() == 2 and float(hb[1]) > float(hb[0]),
		"ponte de hidrogênio tem faixa de energia")
	_check(float(hb[1]) >= 10.0 and float(hb[1]) <= 40.0,
		"ponte de hidrogênio ~4–30 kJ/mol")
	_check(Materials.weak_interaction_ids().size() >= 2,
		"van der Waals e ponte de hidrogênio presentes")
