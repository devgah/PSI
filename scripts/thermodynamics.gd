extends RefCounted
## FASE 4 — Termodinâmica química e cinética: energia de Gibbs ΔG = ΔH − TΔS,
## espontaneidade, temperatura de cruzamento e fator de Arrhenius / catalisador.

const R_GAS := 8.31446261815324  # J/(mol·K)


## Energia de Gibbs padrão (kJ) a uma temperatura T (K).
static func gibbs_kj(dh_kj: float, ds_j_k: float, t_k: float) -> float:
	return dh_kj - t_k * ds_j_k / 1000.0


static func is_spontaneous(dh_kj: float, ds_j_k: float, t_k: float) -> bool:
	return gibbs_kj(dh_kj, ds_j_k, t_k) < 0.0


## Temperatura em que ΔG = 0 (T = ΔH/ΔS, em K). NAN se ΔS = 0.
static func crossover_temperature_k(dh_kj: float, ds_j_k: float) -> float:
	if absf(ds_j_k) < 1e-12:
		return NAN
	return dh_kj * 1000.0 / ds_j_k


## Fator de Boltzmann/Arrhenius exp(−Ea/RT), adimensional.
static func arrhenius_factor(ea_kj: float, t_k: float) -> float:
	return exp(-ea_kj * 1000.0 / (R_GAS * maxf(t_k, 1e-6)))


## Ganho de velocidade ao reduzir a barreira de Ea1 para Ea2 a temperatura T.
static func catalyst_enhancement(ea1_kj: float, ea2_kj: float, t_k: float) -> float:
	return exp((ea1_kj - ea2_kj) * 1000.0 / (R_GAS * maxf(t_k, 1e-6)))


## Converte um fator exp(−Ea/RT) em uma fração qualitativa legível.
static func kinetics_label(factor: float) -> String:
	if factor >= 0.5:
		return "muito rápida"
	if factor >= 1e-3:
		return "rápida"
	if factor >= 1e-8:
		return "lenta"
	if factor >= 1e-20:
		return "muito lenta"
	return "praticamente parada"
