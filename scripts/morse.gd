extends RefCounted
## FASE 4 — Potencial de Morse (curva de energia potencial de uma ligação):
##   V(r) = D_e · (1 − e^{−a(r − r_e)})²
## com D_e = profundidade do poço (energia de dissociação), r_e = comprimento de
## ligação de equilíbrio e a = parâmetro de largura (controla a curvatura).
## Complementa o poço com a frequência vibracional harmônica no fundo.

# Relaxamento usado quando a largura 'a' é derivada apenas de (D_e, r_e):
# escolha ilustrativa para reproduzir curvaturas de ligação típicas.
const A_DEFAULT := 0.025  # em pm⁻¹ (≈ 2,5 Å⁻¹)


## Energia potencial (eV) a uma distância r_pm. V(r_e) = 0; V(∞) = D_e.
static func energy_ev(r_pm: float, de_ev: float, re_pm: float, a_inv_pm: float = A_DEFAULT) -> float:
	var x := exp(-a_inv_pm * (r_pm - re_pm))
	var d := 1.0 - x
	return de_ev * d * d


## Força ao longo da ligação (eV/pm): F = −dV/dr. Negativa = atrativa.
static func force_ev_per_pm(r_pm: float, de_ev: float, re_pm: float, a_inv_pm: float = A_DEFAULT) -> float:
	var x := exp(-a_inv_pm * (r_pm - re_pm))
	# dV/dr = 2·D·(1−x)·x·a
	return -2.0 * de_ev * (1.0 - x) * x * a_inv_pm


## Profundidade do poço menos a energia de ponto zero (D_0 ≈ D_e − ħω/2).
## Frequência angular harmônica: ω = a·√(2·D_e / μ) em unidades atômicas.
## Aqui devolvemos apenas a frequência clássica em função da massa reduzida (u).
static func harmonic_frequency_thz(de_ev: float, a_inv_pm: float, mu_u: float) -> float:
	if mu_u <= 0.0:
		return 0.0
	# k = d²V/dr² em r_e = 2·D_e·a²  (eV/pm²) → converte para SI
	var k_ev_pm2 := 2.0 * de_ev * a_inv_pm * a_inv_pm
	var k_si := k_ev_pm2 * 1.602176634e-19 / (1.0e-12 * 1.0e-12)  # J/m²
	var m_si := mu_u * 1.66053906660e-27  # kg (u)
	var omega := sqrt(k_si / m_si)
	return omega / TAU / 1.0e12  # THz


## Massa reduzida de dois átomos em unidades de massa atômica.
static func reduced_mass_u(m_a_u: float, m_b_u: float) -> float:
	var s := m_a_u + m_b_u
	if s <= 0.0:
		return 0.0
	return m_a_u * m_b_u / s


## Amostra a curva V(r) num intervalo [r_min, r_max] com n pontos.
static func sample(de_ev: float, re_pm: float, a_inv_pm: float = A_DEFAULT,
		r_min: float = 0.0, r_max: float = 400.0, n: int = 80) -> Dictionary:
	var rs := PackedFloat64Array()
	var vs := PackedFloat64Array()
	rs.resize(n)
	vs.resize(n)
	for i in range(n):
		var r := lerpf(r_min, r_max, float(i) / float(maxi(n - 1, 1)))
		rs[i] = r
		vs[i] = energy_ev(r, de_ev, re_pm, a_inv_pm)
	return {"r_pm": rs, "energy_ev": vs}
