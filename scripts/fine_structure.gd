extends RefCounted
## FASE 7 — Realismo avançado: estrutura fina relativística.
## Fórmula de Sommerfeld (correção de 1ª ordem relativística: massa-velocidade,
## Darwin e spin-órbita) para o átomo hidrogenoide, a constante de estrutura
## fina e o desdobramento de linhas (ex.: Hα). O deslocamento de Lamb é um
## efeito de QED além de Dirac — informado como MEDIÇÃO, não calculado aqui.

const ALPHA := 7.2973525693e-3          # constante de estrutura fina (CODATA)
const INV_ALPHA := 137.035999084
const RY_EV := 13.605693122994          # Ry (CODATA)
const M_E_EV := 510998.95               # energia de repouso do elétron (eV)
const H_PLANCK_EV_S := 4.135667696e-15
const C_M_S := 2.99792458e8
const HC_EV_M := 1.239841984e-6         # hc em eV·m


static func fine_structure_constant() -> float:
	return ALPHA


static func inv_fine_structure_constant() -> float:
	return INV_ALPHA


# ---------------------------------------------------------------- energias

## Energia de Bohr (gross) do átomo hidrogenoide: E_n = −Ry·Z²/n² (eV).
static func gross_energy_ev(z: float, n: int) -> float:
	if n <= 0:
		return 0.0
	return -RY_EV * z * z / float(n * n)


## Energia com estrutura fina (Sommerfeld, 1ª ordem):
## E = −Ry·Z²/n² · [1 + (αZ/n)² · (n/(j+½) − 3/4)].
## j é o momento angular total (½, 3/2, …).
static func corrected_energy_ev(z: float, n: int, j: float) -> float:
	if n <= 0:
		return 0.0
	var e_n := gross_energy_ev(z, n)
	var a := ALPHA * z
	var corr := (a * a) / float(n * n) * (float(n) / (j + 0.5) - 0.75)
	return e_n * (1.0 + corr)


## Contribuição de estrutura fina (E_corrigido − E_Bohr), em eV.
static func fine_correction_ev(z: float, n: int, j: float) -> float:
	return corrected_energy_ev(z, n, j) - gross_energy_ev(z, n)


## Desdobramento total do multipleto de estrutura fina do nível n:
## E(n, j = n−1/2) − E(n, j = 1/2).
static func fine_splitting_ev(z: float, n: int) -> float:
	if n < 2:
		return 0.0
	return corrected_energy_ev(z, n, float(n) - 0.5) \
		- corrected_energy_ev(z, n, 0.5)


## Desdobramento do par 2p (2p₃/₂ − 2p₁/₂) para o hidrogênio: ≈ 4,5×10⁻⁵ eV.
static func hydrogen_2p_splitting_ev() -> float:
	return fine_splitting_ev(1.0, 2)


# ---------------------------------------------------------------- Hα

## Comprimento de onda medido da linha Hα (n=3→2), em Å.
static func halpha_wavelength_angstrom() -> float:
	return 6562.8


## Largura total do multipleto de estrutura fina do Hα em comprimento de onda
## (Å): soma o espalhamento dos níveis n=3 (superior) e n=2 (inferior),
## ΔE = ΔE_fino(3) + ΔE_fino(2), e converte Δλ = λ²·ΔE/(hc).
static func halpha_fine_width_angstrom() -> float:
	var lam_m := halpha_wavelength_angstrom() * 1.0e-10
	var de_ev := fine_splitting_ev(1.0, 3) + fine_splitting_ev(1.0, 2)
	return lam_m * lam_m * de_ev / HC_EV_M * 1.0e10


# ---------------------------------------------------------------- Lamb (QED)

## Deslocamento de Lamb 2s₁/₂ − 2p₁/₂ do hidrogênio (eV) — MEDIÇÃO (QED),
## não é previsto pela equação de Dirac.
static func lamb_shift_ev() -> float:
	return 4.37e-6


## Razão Lamb / desdobramento fino do 2p: ~10% da escala de estrutura fina.
static func lamb_to_fine_ratio() -> float:
	return lamb_shift_ev() / hydrogen_2p_splitting_ev()


## Comprimento de onda (nm) de uma transição de energia em eV.
static func wavelength_nm(energy_ev: float) -> float:
	if energy_ev <= 0.0:
		return INF
	return HC_EV_M / energy_ev * 1.0e9
