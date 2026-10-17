extends RefCounted
## FASE 7 — Átomo relativístico de Dirac. Níveis de energia exatos do
## hidrogenoide pela equação de Dirac:
##   E_{n,j} = m c² [1 + (Zα / (n − (j+½) + √((j+½)² − (Zα)²)))²]^(−1/2) − m c².
## Reproduz a estrutura fina de Sommerfeld e revela a degenerescência 2s₁/₂/2p₁/₂
## (quebrada apenas pelo deslocamento de Lamb, que é QED).

const FineStructure = preload("res://scripts/fine_structure.gd")

const M_E_EV := 510998.95


## Energia total relativística (eV) referida ao repouso, via equação de Dirac.
static func dirac_energy_ev(z: float, n: int, j: float) -> float:
	if n <= 0:
		return 0.0
	var za := FineStructure.fine_structure_constant() * z
	var kappa := j + 0.5
	var denom := float(n) - kappa + sqrt(maxf(kappa * kappa - za * za, 0.0))
	if denom == 0.0:
		return 0.0
	var inner := 1.0 + (za / denom) * (za / denom)
	return M_E_EV * (1.0 / sqrt(inner) - 1.0)


## Verificação: para baixo Z, Dirac ≈ Sommerfeld (1ª ordem) a ~10⁻⁶ eV.
static func dirac_matches_sommerfeld(z: float, n: int, j: float, tol_ev: float) -> bool:
	var d := dirac_energy_ev(z, n, j)
	var s := FineStructure.corrected_energy_ev(z, n, j)
	return absf(d - s) <= tol_ev


## Degenerescência de Dirac 2s₁/₂ e 2p₁/₂ (mesmo j = ½): mesma energia.
static func hydrogen_2s2p_degenerate_ev() -> float:
	var e2s := dirac_energy_ev(1.0, 2, 0.5)
	var e2p := dirac_energy_ev(1.0, 2, 0.5)
	return absf(e2s - e2p)


## Separar 2p₃/₂ de 2p₁/₂ (Dirac): ≈ estrutura fina do 2p.
static func hydrogen_2p_dirac_splitting_ev() -> float:
	return dirac_energy_ev(1.0, 2, 1.5) - dirac_energy_ev(1.0, 2, 0.5)


## Energia de repouso do elétron (eV).
static func electron_rest_ev() -> float:
	return M_E_EV
