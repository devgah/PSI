extends SceneTree
## Suite de testes — FASE 7 (Realismo avançado: estrutura fina, Dirac,
## evolução temporal da função de onda).
## Executar: godot --headless --path . --script res://tests/run_tests_phase7.gd

const FineStructure = preload("res://scripts/fine_structure.gd")
const Dirac = preload("res://scripts/dirac.gd")
const Wavepacket = preload("res://scripts/wavepacket.gd")

var failed := 0
var passed := 0


func _init() -> void:
	print("=== QA — Simulador Atômico / Fase 7 (realismo avançado) ===")
	_test_fine_structure()
	_test_dirac()
	_test_wavepacket()
	_test_infinite_well()
	print("--------------------------------------------------")
	print("RESULTADO FASE 7: %d OK, %d FALHAS" % [passed, failed])
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
	if v == 0.0:
		return "0"
	var e := int(floor(log(absf(v)) / log(10.0)))
	return "%.3f×10^%d" % [v / pow(10.0, e), e]


# ------------------------------------------------------- estrutura fina

func _test_fine_structure() -> void:
	print("[1] Estrutura fina (Sommerfeld)")
	_check(_near(FineStructure.fine_structure_constant(), 0.0072973525693, 1e-12),
		"constante de estrutura fina α ≈ 1/137,036")
	_check(_near(FineStructure.inv_fine_structure_constant(), 137.035999084, 1e-6),
		"1/α ≈ 137,036")
	_check(_near(FineStructure.gross_energy_ev(1.0, 1), -13.605693122994, 1e-9),
		"energia de Bohr do H(1s) = −13,606 eV")
	_check(_near(FineStructure.gross_energy_ev(1.0, 2), -3.4014, 1e-3),
		"E(n=2) = −3,401 eV")
	# correção de estrutura fina do 2p₁/₂ é da ordem de 10⁻⁵ eV
	var corr := FineStructure.fine_correction_ev(1.0, 2, 0.5)
	_check(corr < 0.0 and absf(corr) > 1.0e-5 and absf(corr) < 1.0e-4,
		"correção de estrutura fina do 2p₁/₂ ≈ −5,7×10⁻⁵ eV",
		_sci(corr))
	# desdobramento do 2p: 4,5×10⁻⁵ eV
	var split2p := FineStructure.hydrogen_2p_splitting_ev()
	_check(_near(split2p, 4.528e-5, 2e-7),
		"desdobramento 2p₃/₂−2p₁/₂ ≈ 4,5×10⁻⁵ eV",
		_sci(split2p))
	# o desdobramento escala com Z⁴ (para Z=2 é 16× maior)
	var split2p_z2 := FineStructure.fine_splitting_ev(2.0, 2)
	_check(_near(split2p_z2 / split2p, 16.0, 0.1),
		"desdobramento fino escala com Z⁴ (Z=2 → 16×)")
	# nível j maior fica mais alto (menos negativo)
	_check(FineStructure.corrected_energy_ev(1.0, 2, 1.5)
		> FineStructure.corrected_energy_ev(1.0, 2, 0.5),
		"2p₃/₂ fica acima de 2p₁/₂")
	# Hα
	_check(_near(FineStructure.halpha_wavelength_angstrom(), 6562.8, 0.1),
		"comprimento de onda do Hα = 6562,8 Å (medido)")
	var w := FineStructure.halpha_fine_width_angstrom()
	_check(w > 0.15 and w < 0.30,
		"estrutura fina do Hα espalha ~%.2f Å" % w)
	# Lamb shift é QED (medido), não previsto por Dirac
	_check(_near(FineStructure.lamb_shift_ev(), 4.37e-6, 1e-8),
		"deslocamento de Lamb 2s₁/₂−2p₁/₂ ≈ 4,37×10⁻⁶ eV (QED)")
	_check(FineStructure.lamb_to_fine_ratio() > 0.05
		and FineStructure.lamb_to_fine_ratio() < 0.2,
		"Lamb é ~10% da escala de estrutura fina do 2p")


# [2] Dirac

func _test_dirac() -> void:
	print("[2] Equação de Dirac (hidrogenoide relativístico)")
	_check(_near(Dirac.electron_rest_ev(), 510998.95, 1e-2),
		"energia de repouso do elétron = 511 keV")
	# Dirac ≈ Sommerfeld no regime de baixo Z
	_check(Dirac.dirac_matches_sommerfeld(1.0, 1, 0.5, 1.0e-6),
		"Dirac(n=1) ≈ Sommerfeld (10⁻⁶ eV)")
	_check(Dirac.dirac_matches_sommerfeld(1.0, 2, 0.5, 1.0e-6),
		"Dirac(n=2, j=½) ≈ Sommerfeld")
	_check(Dirac.dirac_matches_sommerfeld(1.0, 3, 1.5, 1.0e-6),
		"Dirac(n=3, j=3/2) ≈ Sommerfeld")
	# 2s₁/₂ e 2p₁/₂ degenerados em Dirac (mesmo j)
	_check(_near(Dirac.hydrogen_2s2p_degenerate_ev(), 0.0, 1e-12),
		"2s₁/₂ e 2p₁/₂ degenerados em Dirac (mesmo j)")
	# separação 2p por Dirac ≈ estrutura fina do 2p
	_check(_near(Dirac.hydrogen_2p_dirac_splitting_ev(),
		FineStructure.hydrogen_2p_splitting_ev(), 1.0e-6),
		"separação 2p por Dirac coincide com a estrutura fina")
	# nível desdobrado: 2p₃/₂ acima de 2p₁/₂
	_check(Dirac.dirac_energy_ev(1.0, 2, 1.5) > Dirac.dirac_energy_ev(1.0, 2, 0.5),
		"Dirac: 2p₃/₂ acima de 2p₁/₂")


# [3] Evolução temporal — partícula livre

func _test_wavepacket() -> void:
	print("[3] Evolução temporal (Crank–Nicolson) — partícula livre")
	var w := Wavepacket.new()
	w.configure(400, 40.0, 1.0, 1.0)
	w.set_free()
	w.init_gaussian(8.0, 2.0, 0.5)
	_check(_near(w.norm(), 1.0, 1e-9), "pacote inicial normalizado")
	var w0 := w.width()
	var x0 := w.expect_x()
	# ⟨E⟩ = ½k₀² + 1/(4σ²) para pacote gaussiano
	var e_expected := 0.5 * 0.5 * 0.5 + 1.0 / (4.0 * 4.0)
	_check(_near(w.energy_expectation(), e_expected, 0.01),
		"⟨E⟩ inicial ≈ %.4f (livre)" % e_expected, "%.4f" % w.energy_expectation())
	# t = 4 (velocidade de grupo v = p/m = k₀ = 0,5)
	w.evolve(400, 0.01)
	_check(_near(w.norm(), 1.0, 1e-6),
		"norma conservada após 400 passos", "%.8f" % w.norm())
	_check(_near(w.expect_x(), x0 + 0.5 * 4.0, 0.1),
		"⟨x⟩ avança com velocidade de grupo v = k₀ = 0,5",
		"%.3f" % w.expect_x())
	# alargamento: σ(t) = σ₀·√(1+(ħt/(2mσ₀²))²), com σ₀ = largura inicial
	var t_end := 4.0
	var sz_expected := w0 * sqrt(1.0 + pow(t_end / (2.0 * w0 * w0), 2.0))
	_check(w.width() > w0, "o pacote se dispersa com o tempo")
	_check(absf(w.width() - sz_expected) < 0.06,
		"largura ≈ σ₀√(1+(t/2σ₀²)²) ≈ %.3f" % sz_expected,
		"%.3f" % w.width())


# [3'] Evolução temporal — auto-estado

func _test_infinite_well() -> void:
	print("[3'] Evolução temporal — auto-estado do poço infinito")
	var w := Wavepacket.new()
	w.configure(200, 10.0, 1.0, 1.0)
	w.set_infinite_well()
	w.init_sine_state(1)
	var e1 := PI * PI / (2.0 * 10.0 * 10.0)
	_check(_near(w.energy_expectation(), e1, 0.03 * e1),
		"⟨E⟩ do auto-estado ≈ π²/2L² = %.4f" % e1,
		"%.4f" % w.energy_expectation())
	var w_before := w.width()
	w.evolve(300, 0.01)
	# auto-estado evolui apenas por fase global → sobreposição ≈ 1
	_check(_near(w.overlap_abs(), 1.0, 1e-3),
		"auto-estado permanece (só fase global): |⟨ψ0|ψt⟩| ≈ 1",
		"%.5f" % w.overlap_abs())
	_check(_near(w.norm(), 1.0, 1e-8), "norma conservada no poço")
	_check(_near(w.width(), w_before, 1e-3),
		"largura do auto-estado não muda")
