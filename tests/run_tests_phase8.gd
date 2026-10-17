extends SceneTree
## Suite de testes — FASE 8 (Campos & Leis: Zeeman, Stark, sandbox de leis).
## Executar: godot --headless --path . --script res://tests/run_tests_phase8.gd

const Fields = preload("res://scripts/fields.gd")
const LawsSandbox = preload("res://scripts/laws_sandbox.gd")

var _passed := 0
var _failed := 0


func _init() -> void:
	print("=== QA FASE 8 — Campos & Leis ===")
	_test_zeeman()
	_test_stark()
	_test_sandbox()
	print("--------------------------------------------------")
	print("RESULTADO FASE 8: %d OK, %d FALHAS" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check(cond: bool, name: String, detail: String = "") -> void:
	if cond:
		_passed += 1
		print("  OK    %s" % name)
	else:
		_failed += 1
		print("  FALHA %s %s" % [name, detail])


func _near(a: float, b: float, tol: float) -> bool:
	return absf(a - b) <= tol


func _sci(v: float) -> String:
	if v == 0.0:
		return "0"
	var e := int(floor(log(absf(v)) / log(10.0)))
	return "%.4f×10^%d" % [v / pow(10.0, e), e]


# --------------------------------------------------------------- Zeeman

func _test_zeeman() -> void:
	print("[1] Efeito Zeeman")
	_check(_near(Fields.bohr_magneton_ev_t(), 5.7883818060e-5, 1e-14),
		"magnéton de Bohr μ_B = 5,788×10⁻⁵ eV/T",
		_sci(Fields.bohr_magneton_ev_t()))
	_check(_near(Fields.lande_g(0.0, 0.5, 0.5), 2.0, 1e-9),
		"g_J(2S₁/₂) = 2", "%.4f" % Fields.lande_g(0.0, 0.5, 0.5))
	_check(_near(Fields.lande_g(1.0, 0.5, 0.5), 0.666667, 1e-5),
		"g_J(2P₁/₂) = 2/3")
	_check(_near(Fields.lande_g(1.0, 0.5, 1.5), 1.333333, 1e-5),
		"g_J(2P₃/₂) = 4/3")
	_check(_near(Fields.lande_g(2.0, 0.5, 2.5), 1.2, 1e-6),
		"g_J(2D₅/₂) = 6/5")
	# Zeeman normal: ΔE(Δm=1) = μ_B·B
	var de := Fields.normal_zeeman_shift_ev(1.0, 1.0)
	_check(_near(de, Fields.bohr_magneton_ev_t(), 1e-15),
		"Zeeman normal: ΔE(Δm=1) a 1 T = μ_B",
		_sci(de))
	# proporcional a B
	_check(_near(Fields.normal_zeeman_shift_ev(1.0, 5.0), 5.0 * de, 1e-15),
		"desdobramento cresce linearmente com B")
	_check(_near(Fields.normal_zeeman_shift_ev(-1.0, 1.0), -de, 1e-18),
		"linha m=−1 desloca para baixo")
	# anômalo: g_J μ_B B
	_check(_near(Fields.zeeman_splitting_ev(Fields.lande_g(1.0, 0.5, 1.5), 2.0),
		(4.0 / 3.0) * Fields.bohr_magneton_ev_t() * 2.0, 1e-15),
		"Zeeman anômalo usa g_J (4/3) em B=2 T")
	# deslocamento espectral da linha D (589 nm)
	var dl := Fields.wavelength_shift_nm(589.0, de)
	_check(_near(dl, 0.0162, 0.001),
		"Δλ da linha de 589 nm ≈ 0,016 nm", "%.5f" % dl)
	_check(Fields.wavelength_shift_nm(589.0, 2.0 * de) > dl,
		"campo maior desloca mais a linha")


# --------------------------------------------------------------- Stark

func _test_stark() -> void:
	print("[2] Efeito Stark")
	# Stark linear: n=2, k=1, E=10⁶ V/m
	var s2 := Fields.stark_linear_ev(2, 1, 1.0e6)
	_check(_near(s2, 1.5875e-4, 1e-6),
		"Stark linear n=2,k=1,E=10⁶ V/m ≈ 1,59×10⁻⁴ eV", _sci(s2))
	_check(_near(Fields.stark_linear_ev(3, 2, 1.0e6), 4.7626e-4, 1e-6),
		"Stark linear n=3,k=2 ≈ 4,76×10⁻⁴ eV")
	_check(Fields.stark_linear_ev(2, -1, 1.0e6) < 0.0,
		"k negativo → deslocamento negativo")
	_check(_near(Fields.stark_linear_ev(2, 1, 2.0e6), 2.0 * s2, 1e-9),
		"Stark linear cresce linearmente com E")
	# Stark quadrático do hidrogênio
	var qh := Fields.stark_quadratic_symbol_ev("H", 1.0e6)
	_check(qh < 0.0 and _near(qh, -2.316e-10, 2e-12),
		"Stark quadrático do H a 10⁶ V/m ≈ −2,3×10⁻¹⁰ eV", _sci(qh))
	_check(Fields.stark_quadratic_symbol_ev("Cs", 1.0e6)
		< Fields.stark_quadratic_symbol_ev("He", 1.0e6),
		"Cs (muito polarizável) desloca mais que He")
	_check(absf(Fields.stark_quadratic_symbol_ev("H", 2.0e6))
		> absf(qh),
		"Stark quadrático cresce com E²")
	_check(_near(Fields.stark_quadratic_symbol_ev("H", 2.0e6) / qh, 4.0, 1e-6),
		"dobrar E quadruplica o Stark quadrático (E²)")
	_check(_near(Fields.polarizability_volume_ang3("He"), 0.2049, 1e-6),
		"polarizabilidade do He na tabela")


# --------------------------------------------------------------- sandbox

func _test_sandbox() -> void:
	print("[2] Sandbox de leis")
	_check(_near(LawsSandbox.rydberg_ev(1.0, 1.0),
		LawsSandbox.baseline_rydberg_ev(), 1e-9),
		"Rydberg real = %.3f eV" % LawsSandbox.baseline_rydberg_ev())
	_check(_near(LawsSandbox.rydberg_ev(2.0, 1.0),
		4.0 * LawsSandbox.baseline_rydberg_ev(), 1e-6),
		"α em dobro → Rydberg ×4 (∝α²)")
	_check(_near(LawsSandbox.rydberg_ev(1.0, 0.5), 0.5 * LawsSandbox.baseline_rydberg_ev(), 1e-9),
		"mₑ metade → Rydberg metade")
	_check(_near(LawsSandbox.bohr_radius_ang(2.0, 1.0),
		LawsSandbox.baseline_bohr_ang() / 2.0, 1e-9),
		"α dobrado → raio de Bohr metade")
	_check(_near(LawsSandbox.fine_splitting_relative(2.0), 16.0, 1e-9),
		"estrutura fina ∝ α⁴ (α×2 → ×16)")
	_check(_near(LawsSandbox.fine_splitting_relative(0.5), 0.0625, 1e-9),
		"α metade → estrutura fina 1/16")
	# dêuteron
	_check(_near(LawsSandbox.deuteron_binding_scaled_mev(1.0), 2.224, 1e-9),
		"dêuteron liga 2,224 MeV com forte real")
	_check(_near(LawsSandbox.deuteron_binding_scaled_mev(0.5), 0.0, 1e-12),
		"forte fraca (0,5×) desfaz o dêuteron")
	_check(LawsSandbox.stars_ignite(1.0) and not LawsSandbox.stars_ignite(0.5),
		"estrelas acendem só com forte suficiente")
	# veredito do universo
	var u := LawsSandbox.evaluate(1.0, 1.0, 1.0)
	_check(String(u["verdict"]).find("habit") >= 0,
		"universo real é classificado como habitável")
	_check(bool(u["stars"]), "universo real tem estrelas")
	var dark := LawsSandbox.evaluate(1.0, 1.0, 0.5)
	_check(String(dark["verdict"]).find("ESTRELAS") >= 0,
		"forte 0,5× → 'SEM ESTRELAS'")
	var big := LawsSandbox.evaluate(1.8, 1.0, 1.0)
	_check(String(big["chemistry"]).find("compact") >= 0,
		"α grande → átomos compactos/muito ligados")
