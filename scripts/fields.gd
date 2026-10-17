extends RefCounted
## FASE 8 — Sondas de campo. Efeito Zeeman (desdobramento magnético, incluindo
## o fator de Landé g_J) e efeito Stark (deslocamento elétrico: linear para o
## hidrogênio, quadrático via polarizabilidade para os demais átomos).
## Constantes/dados em data/fields.json.

const PATH := "res://data/fields.json"
const HC_EV_M := 1.239841984e-6

static var _data: Dictionary = {}


static func _load() -> Dictionary:
	if not _data.is_empty():
		return _data
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		push_error("fields.json não encontrado")
		_data = {"constants": {}, "polarizability_volume_ang3": {}}
		return _data
	_data = JSON.parse_string(f.get_as_text())
	if _data == null:
		_data = {"constants": {}, "polarizability_volume_ang3": {}}
	return _data


static func _c(key: String, fb: float) -> float:
	var v = _load().get("constants", {}).get(key, null)
	return float(v) if v != null else fb


static func bohr_magneton_ev_t() -> float:
	return _c("mu_b_ev_t", 5.7883818060e-5)


static func bohr_radius_m() -> float:
	return _c("bohr_radius_m", 5.29177210903e-11)


static func epsilon_0() -> float:
	return _c("epsilon_0", 8.8541878128e-12)


static func electron_charge() -> float:
	return _c("e_charge", 1.602176634e-19)


static func polarizability_volume_ang3(symbol: String) -> float:
	return float(_load().get("polarizability_volume_ang3", {}).get(symbol, 0.0))


static func polarizability_symbols() -> Array:
	return (_load().get("polarizability_volume_ang3", {}) as Dictionary).keys()


# ------------------------------------------------------------------ Zeeman

## Fator de Landé g_J = 1 + [J(J+1) + S(S+1) − L(L+1)] / [2 J(J+1)]
## (L, S, J em unidades de ħ; J = 0 → g = 0).
static func lande_g(l: float, s: float, j: float) -> float:
	if j <= 0.0:
		return 0.0
	return 1.0 + (j * (j + 1.0) + s * (s + 1.0) - l * (l + 1.0)) / (2.0 * j * (j + 1.0))


## Deslocamento Zeeman (eV): ΔE = m_J · g_J · μ_B · B.
static func zeeman_shift_ev(mj: float, g_j: float, b_tesla: float) -> float:
	return mj * g_j * bohr_magneton_ev_t() * b_tesla


## Efeito Zeeman NORMAL (spin desprezado): ΔE = m_l · μ_B · B.
static func normal_zeeman_shift_ev(m_l: float, b_tesla: float) -> float:
	return m_l * bohr_magneton_ev_t() * b_tesla


## Separação entre componentes adjacentes (Δm = 1): g_J · μ_B · B.
static func zeeman_splitting_ev(g_j: float, b_tesla: float) -> float:
	return g_j * bohr_magneton_ev_t() * b_tesla


## Comprimento de onda (nm) de uma transição de energia em eV.
static func wavelength_nm(energy_ev: float) -> float:
	if energy_ev <= 0.0:
		return INF
	return HC_EV_M / energy_ev * 1.0e9


# ------------------------------------------------------------------ Stark

## Efeito Stark LINEAR (hidrogênio, níveis degenerados de mesmo n):
## ΔE = (3/2)·n·a₀·E·k, com k = n₁ − n₂ inteiro (0, ±1, ... ±(n−1)).
## Retorna eV (a carga cancela: a₀·e·E / e).
static func stark_linear_ev(n: int, k: int, e_field_vm: float) -> float:
	return 1.5 * float(n) * bohr_radius_m() * e_field_vm * float(k)


## Efeito Stark QUADRÁTICO para átomos não-hidrogenoides:
## ΔE = −½ · 4πε₀ · α' · E², com α' = volume de polarizabilidade (Å³).
## Retorna eV.
static func stark_quadratic_ev(alpha_volume_ang3: float, e_field_vm: float) -> float:
	var alpha_si := alpha_volume_ang3 * 1.0e-30
	var u_j := -0.5 * 4.0 * PI * epsilon_0() * alpha_si * e_field_vm * e_field_vm
	return u_j / electron_charge()


## Deslocamento Stark quadrático de um átomo pelo símbolo (usa a tabela).
static func stark_quadratic_symbol_ev(symbol: String, e_field_vm: float) -> float:
	return stark_quadratic_ev(polarizability_volume_ang3(symbol), e_field_vm)


## Deslocamento em comprimento de onda (nm) de uma transição cujo
## comprimento de onda é `lambda_nm` (nm) e cuja energia varia `delta_ev` (eV):
## Δλ = λ²·ΔE/(hc), com sinal preservado.
static func wavelength_shift_nm(lambda_nm: float, delta_ev: float) -> float:
	var lam_m := lambda_nm * 1.0e-9
	return lam_m * lam_m * delta_ev / HC_EV_M * 1.0e9
