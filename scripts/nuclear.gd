extends RefCounted
## FASE 3 — Modelo nuclear (teoria). Fórmula semi-empírica de massa de
## Weizsäcker (gota líquida), números mágicos, vale de estabilidade e potencial
## de Yukawa com caroço repulsivo.
##
## Massas: excesso de massa de referência (keV):
##   D_H = M(H-1 atom) - u ; D_n = M(n) - u.
## Para um núcleo (Z,A):  B = Z*D_H + N*D_n - Me(Z,A)   [keV]
## (equivale a  B = Z*M_H + N*M_n - M_atom ).  Usaremos B em MeV na interface.

# --- Coeficientes de Weizsäcker (MeV) — valores do roteiro do projeto ---
const A_V := 15.8   # volume
const A_S := 18.3   # superfície
const A_C := 0.714  # Coulomb
const A_A := 23.2   # assimetria
const PAIRING := 12.0  # termo de emparelhamento: ±12/√A (MeV)

# --- Excesso de massa das referências (keV) ---
const D_H_KEV := 7288.971064   # H-1 (átomo neutro)
const D_N_KEV := 8071.31806    # nêutron

# --- Números mágicos (camadas nucleares fechadas) ---
const MAGIC := [2, 8, 20, 28, 50, 82, 126]

# --- Potencial de Yukawa (ilustrativo, MeV / fm) ---
const CORE_FM := 0.7     # raio do caroço repulsivo
const LAMBDA_FM := 1.2   # alcance ~ 1/m_pi
const V0_MEV := 50.0     # profundidade atrativa (escala ilustrativa)
const V_CORE_MEV := 200.0


# ------------------------------------------------------------------ Weizsäcker

## Termo de emparelhamento (MeV): + par-par, − ímpar-ímpar, 0 para A ímpar.
static func pairing(a: int, z: int) -> float:
	if a <= 0:
		return 0.0
	if a % 2 == 1:
		return 0.0
	var n := a - z
	if z % 2 == 0 and n % 2 == 0:
		return PAIRING / sqrt(float(a))
	return -PAIRING / sqrt(float(a))


## Energia de ligação pela fórmula de Weizsäcker (MeV). N = A - Z.
static func binding_weizsacker_mev(a: int, z: int) -> float:
	if a <= 0:
		return 0.0
	var n := a - z
	var b := A_V * float(a) - A_S * pow(float(a), 2.0 / 3.0)
	if z > 0:
		b -= A_C * float(z) * float(z - 1) / pow(float(a), 1.0 / 3.0)
	b -= A_A * pow(float(a - 2 * z), 2.0) / float(a)
	b += pairing(a, z)
	return b


static func binding_per_a_weizsacker(a: int, z: int) -> float:
	if a <= 0:
		return 0.0
	return binding_weizsacker_mev(a, z) / float(a)


## Energia de ligação a partir de um excesso de massa medido (keV) → MeV.
static func binding_from_me_mev(z: int, a: int, me_kev: float) -> float:
	var n := a - z
	return (float(z) * D_H_KEV + float(n) * D_N_KEV - me_kev) / 1000.0


## Excesso de massa estimado por Weizsäcker (keV).
static func mass_excess_weizsacker_kev(a: int, z: int) -> float:
	var n := a - z
	return float(z) * D_H_KEV + float(n) * D_N_KEV - binding_weizsacker_mev(a, z) * 1000.0


# ------------------------------------------------------------------- mágicos

static func is_magic(x: int) -> bool:
	return MAGIC.has(x)


static func is_doubly_magic(z: int, n: int) -> bool:
	return is_magic(z) and is_magic(n)


## Distância ao número mágico mais próximo (0 se já for mágico).
static func magic_distance(x: int) -> int:
	var best := 1000
	for m in MAGIC:
		best = mini(best, absi(x - m))
	return best


static func magic_near(x: int) -> int:
	var best := MAGIC[0]
	var bd := 1000
	for m in MAGIC:
		var d := absi(x - m)
		if d < bd:
			bd = d
			best = m
	return best


# --------------------------------------------------------------------- vale

## Z do vale de estabilidade (β-estabilidade) para um dado A: minimiza o
## excesso de massa de Weizsäcker sobre Z.
static func z_valley(a: int) -> int:
	if a < 2:
		return maxi(a - 1, 0)
	var best_z := 1
	var best_me := INF
	for z in range(1, a):
		var me := mass_excess_weizsacker_kev(a, z)
		if me < best_me:
			best_me = me
			best_z = z
	return best_z


# -------------------------------------------------------------------- Yukawa

## Potencial nucleon-nucleon ilustrativo (MeV) em função da distância (fm).
## Repulsivo no caroço (r < 0,7 fm), atrativo e decaindo fora dele.
static func yukawa_mev(r_fm: float) -> float:
	if r_fm <= 0.0:
		return V_CORE_MEV
	if r_fm < CORE_FM:
		return V_CORE_MEV * (1.0 - r_fm / CORE_FM)
	return -V0_MEV * exp(-(r_fm - CORE_FM) / LAMBDA_FM) / (r_fm / CORE_FM)


# ------------------------------------------------------------------- raio

const R0_FM := 1.2

## Raio nuclear R ≈ r0 · A^(1/3) em femtômetros.
static func radius_fm(a: int) -> float:
	return R0_FM * pow(maxf(float(a), 1.0), 1.0 / 3.0)
