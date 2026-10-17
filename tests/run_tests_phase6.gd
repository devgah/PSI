extends SceneTree
## Suite de testes — FASE 6 (Modos de jogo: colapso gravitacional, forja
## estelar/nucleossíntese e colisor de partículas).
## Executar: godot --headless --path . --script res://tests/run_tests_phase6.gd

const Star = preload("res://scripts/star.gd")
const Nucleosynthesis = preload("res://scripts/nucleosynthesis.gd")
const Collider = preload("res://scripts/collider.gd")

var failed := 0
var passed := 0


func _init() -> void:
	print("=== QA — Simulador Atômico / Fase 6 (colapso, nucleossíntese, colisor) ===")
	_test_constants()
	_test_collapse()
	_test_qgp()
	_test_nucleosynthesis()
	_test_collider()
	_test_data_integrity()
	print("--------------------------------------------------")
	print("RESULTADO FASE 6: %d OK, %d FALHAS" % [passed, failed])
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


func _sci(v: float) -> String:
	if v <= 0.0:
		return "0"
	var e := int(floor(log(v) / log(10.0)))
	return "%.3f×10^%d" % [v / pow(10.0, e), e]


# --------------------------------------------------------------- constantes

func _test_constants() -> void:
	print("[1] Constantes e limiares de colapso")
	_check(_near(Star.chandrasekhar_msun(), 1.44, 1e-6),
		"limite de Chandrasekhar = 1,44 M☉")
	_check(_near(Star.tov_msun(), 2.2, 1e-6), "limite TOV = 2,2 M☉")
	_check(_near(Star.nuclear_density_kg_m3(), 2.3e17, 1e14),
		"densidade nuclear ≈ 2,3×10¹⁷ kg/m³")
	_check(_near(Star.qgp_temperature_k(), 2.0e12, 1.0),
		"limiar de QGP ≈ 2×10¹² K")
	_check(_near(Star.qgp_energy_mev(), 155.0, 1e-6),
		"limiar de QGP ≈ 155 MeV")
	_check(_near(Star.schwarzschild_radius_km(1.0), 2.953, 0.01),
		"r_s(1 M☉) ≈ 2,95 km", "%.3f" % Star.schwarzschild_radius_km(1.0))
	_check(_near(Star.schwarzschild_radius_km(10.0), 29.53, 0.1),
		"r_s(10 M☉) ≈ 29,5 km")
	_check(_near(Star.hawking_temperature_k(1.0), 6.17e-8, 0.1e-8),
		"T_Hawking(1 M☉) ≈ 6,2×10⁻⁸ K", _sci(Star.hawking_temperature_k(1.0)))


# ------------------------------------------------ colapso gravitacional

func _test_collapse() -> void:
	print("[2] Colapso gravitacional (anã branca → nêutrons → buraco negro)")
	_check(String(Star.classify(0.5)["state"]) == "ana_branca",
		"0,5 M☉ → anã branca")
	_check(String(Star.classify(1.0)["state"]) == "ana_branca",
		"1,0 M☉ → anã branca")
	_check(String(Star.classify(1.44)["state"]) == "estrela_neutrons",
		"1,44 M☉ (limite) → estrela de nêutrons")
	_check(String(Star.classify(2.0)["state"]) == "estrela_neutrons",
		"2,0 M☉ → estrela de nêutrons")
	_check(String(Star.classify(2.5)["state"]) == "buraco_negro",
		"2,5 M☉ → buraco negro")
	_check(Star.is_black_hole(2.5) and not Star.is_black_hole(2.0),
		"classificação de buraco negro pelo limite TOV")
	# raio da anã branca: tamanho da Terra e diminui com a massa
	var r01 := Star.white_dwarf_radius_km(0.5)
	var r1 := Star.white_dwarf_radius_km(1.0)
	var r13 := Star.white_dwarf_radius_km(1.3)
	_check(r1 > 5000.0 and r1 < 15000.0,
		"anã branca de 1 M☉ é do tamanho da Terra (~%.0f km)" % r1)
	_check(r01 > r1 and r1 > r13,
		"raio da anã branca diminui com a massa (R ∝ M^(−1/3))")
	var rns := Star.neutron_star_radius_km(1.8)
	_check(rns > 9.0 and rns < 15.0,
		"estrela de nêutrons tem ~%.1f km de raio" % rns)
	# buraco negro: o raio é o de Schwarzschild
	var bn := Star.classify(10.0)
	_check(_near(float(bn["radius_km"]), Star.schwarzschild_radius_km(10.0), 1e-9),
		"buraco negro: raio = raio de Schwarzschild")
	# densidade da anã branca é da ordem de 10⁹ kg/m³
	var wd := Star.classify(1.0)
	var rho := float(wd["density_kg_m3"])
	_check(rho > 1.0e8 and rho < 1.0e10,
		"densidade da anã branca ≈ %s kg/m³" % _sci(rho))
	# cada estado tem nome e descrição não vazios
	for m in [0.5, 1.8, 5.0]:
		var info := Star.classify(m)
		_check(String(info["name"]) != "" and String(info["description"]) != "" \
			and String(info["supported_by"]) != "",
			"estado de %.1f M☉ tem nome/suporte/descrição" % m)


# ------------------------------------------------------------ QGP

func _test_qgp() -> void:
	print("[3] Plasma de Quarks e Glúons")
	_check(not Star.is_qgp_temperature(1.0e12), "10¹² K ainda não é QGP")
	_check(Star.is_qgp_temperature(2.0e12), "2×10¹² K entra no regime QGP")
	_check(Star.is_qgp_temperature(3.0e12), "3×10¹² K é QGP")
	_check(not Star.is_qgp_energy(100.0), "100 MeV não atinge o QGP")
	_check(Star.is_qgp_energy(155.0), "155 MeV atinge o QGP")
	_check(Star.energy_to_temperature_k(155.0) > 1.7e12 \
		and Star.energy_to_temperature_k(155.0) < 1.9e12,
		"155 MeV ↔ ~1,8×10¹² K",
		_sci(Star.energy_to_temperature_k(155.0)))


# ---------------------------------------------------- nucleossíntese

func _test_nucleosynthesis() -> void:
	print("[3'] Forja estelar (nucleossíntese)")
	_check(_near(Nucleosynthesis.pp_chain_q_mev(), 26.73, 0.02),
		"cadeia pp libera 26,73 MeV", "%.3f" % Nucleosynthesis.pp_chain_q_mev())
	_check(_near(Nucleosynthesis.pp_chain_q_mev_computed(), 26.73, 0.05),
		"Q(4p→He-4) calculado das massas ≈ 26,73 MeV",
		"%.3f" % Nucleosynthesis.pp_chain_q_mev_computed())
	_check(_near(Nucleosynthesis.triple_alpha_q_mev(), 7.275, 0.02),
		"triplo-alfa libera 7,275 MeV")
	_check(_near(Nucleosynthesis.triple_alpha_q_mev_computed(), 7.275, 0.02),
		"Q(3He4→C12) calculado das massas ≈ 7,28 MeV")
	_check(_near(Nucleosynthesis.hoyle_state_mev(), 7.65, 1e-6),
		"estado de Hoyle está a 7,65 MeV")
	_check(Nucleosynthesis.fusion_ladder().size() >= 5,
		"escada de fusão tem ≥ 5 estágios",
		"obtido %d" % Nucleosynthesis.fusion_ladder().size())
	_check(Nucleosynthesis.cumulative_fusion_energy_mev(-1) \
		>= Nucleosynthesis.pp_chain_q_mev(),
		"energia acumulada da escada é ≥ Q(pp)")
	var c1 := Nucleosynthesis.cumulative_fusion_energy_mev(1)
	var c0 := Nucleosynthesis.cumulative_fusion_energy_mev(0)
	_check(c1 > c0, "energia acumulada cresce com os passos da escada")
	_check(Nucleosynthesis.max_binding_element() == "Fe-56",
		"máximo da energia de ligação é o Fe-56")
	_check(_near(Nucleosynthesis.max_binding_per_a_mev(), 8.79, 0.01),
		"B/A(Fe-56) ≈ 8,79 MeV/núcleon")
	_check(_near(Nucleosynthesis.fission_q_mev(), 200.0, 5.0),
		"fissão do U-235 libera ~200 MeV")
	_check(Nucleosynthesis.fission_equation().find("U-235") >= 0,
		"equação de fissão menciona U-235")
	var procs := Nucleosynthesis.process_ids()
	_check(procs.has("s_process") and procs.has("r_process"),
		"processos s e r catalogados")
	_check(String(Nucleosynthesis.process("r_process").get("site", "")).find("nêutrons") >= 0,
		"processo r associado a estrelas de nêutrons")


# ------------------------------------------------------------ colisor

func _test_collider() -> void:
	print("[3''] Colisor de partículas")
	_check(_near(Collider.radius_of_curvature_m(1.0, 1.0, 1.0), 3.33564, 1e-3),
		"r(p=1 GeV, z=1, B=1 T) ≈ 3,34 m",
		"%.4f" % Collider.radius_of_curvature_m(1.0, 1.0, 1.0))
	_check(_near(Collider.radius_of_curvature_m(1.0, 2.0, 1.0), 1.66782, 1e-3),
		"carga dobrada reduz o raio à metade")
	_check(_near(Collider.radius_of_curvature_m(10.0, 1.0, 2.0), 16.6782, 1e-2),
		"r(p=10 GeV, B=2 T) ≈ 16,68 m")
	_check(_near(Collider.momentum_from_curvature_gev(3.33564, 1.0, 1.0), 1.0, 1e-4),
		"momento recuperado a partir da curvatura")
	# massa invariante: partícula em repouso
	_check(_near(Collider.invariant_mass_mev(
		[{"e_mev": 938.272, "px": 0.0, "py": 0.0, "pz": 0.0}]), 938.272, 1e-3),
		"massa invariante em repouso = m")
	# partícula sem massa: E = |p| → m = 0
	_check(_near(Collider.invariant_mass_mev(
		[{"e_mev": 1.0, "px": 1.0, "py": 0.0, "pz": 0.0}]), 0.0, 1e-6),
		"fóton tem massa invariante nula")
	# dois corpos back-to-back e sem massa: √s = 2E
	var mm := Collider.invariant_mass_mev([
		{"e_mev": 1000.0, "px": 800.0, "py": 0.0, "pz": 600.0},
		{"e_mev": 1000.0, "px": -800.0, "py": 0.0, "pz": -600.0},
	])
	_check(_near(mm, 2000.0, 1e-3),
		"massa invariante de 2 corpos back-to-back = 2E",
		"%.1f" % mm)
	_check(_near(Collider.com_energy_symmetric_gev(6500.0), 13000.0, 1e-6),
		"√s de feixes simétricos 2×6500 GeV = 13 TeV")
	_check(_near(Collider.com_energy_fixed_target_gev(30.0, 0.938), 7.618, 0.05),
		"√s de alvo fixo (p de 30 GeV) ≈ 7,6 GeV",
		"%.3f" % Collider.com_energy_fixed_target_gev(30.0, 0.938))
	_check(_near(Collider.total_energy_gev(0.938, 0.0), 0.938, 1e-6),
		"energia total em repouso = massa")
	_check(Collider.curvature_per_m(2.0) < Collider.curvature_per_m(1.0),
		"raio maior → curvatura menor")


# ------------------------------------------------------ integridade de dados

func _test_data_integrity() -> void:
	print("[4] Integridade dos dados da Fase 6")
	_check(Star.states().size() == 3, "stellar.json define 3 estados",
		"obtido %d" % Star.states().size())
	_check(Star.state_name("ana_branca") != "", "estado tem nome legível")
	_check(Star.qgp_name() != "" and Star.qgp_description() != "",
		"QGP tem nome e descrição")
	_check(Nucleosynthesis.fusion_ladder().size() >= 6,
		"escada de fusão cobre H→Fe")
