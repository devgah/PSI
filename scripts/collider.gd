extends RefCounted
## FASE 6 — Colisor de partículas (modo de jogo). Ferramentas cinemáticas:
## massa invariante de um sistema (picos de ressonância), raio de curvatura
## r = p/(0,2998·z·B), energia de centro de massa (√s) e momento a partir da
## curvatura. Relativístico: E² = (pc)² + (mc²)².

const C_LIGHT := 2.99792458e8
const K_CONV := 0.299792458   # [GeV/c] = K·z·B[T]·r[m]


## Massa invariante (MeV/c²) de um conjunto de 4-vetores {e_mev, px, py, pz}.
## Usa E² − (pc)² = (mc²)² com p em MeV/c e E em MeV.
static func invariant_mass_mev(particles: Array) -> float:
	var e_tot := 0.0
	var px := 0.0
	var py := 0.0
	var pz := 0.0
	for p in particles:
		e_tot += float(p.get("e_mev", 0.0))
		px += float(p.get("px", 0.0))
		py += float(p.get("py", 0.0))
		pz += float(p.get("pz", 0.0))
	var m2 := e_tot * e_tot - (px * px + py * py + pz * pz)
	return sqrt(maxf(m2, 0.0))


## Massa invariante de dois corpos com energia E e momento p (magnitudes) e
## ângulo θ entre eles (radianos).
static func invariant_mass_two_body_mev(e1: float, p1: float, e2: float, p2: float,
		theta_rad: float) -> float:
	var p1v := Vector3(p1, 0.0, 0.0)
	var p2v := Vector3(p2 * cos(theta_rad), p2 * sin(theta_rad), 0.0)
	return invariant_mass_mev([
		{"e_mev": e1, "px": p1v.x, "py": p1v.y, "pz": p1v.z},
		{"e_mev": e2, "px": p2v.x, "py": p2v.y, "pz": p2v.z},
	])


## Raio de curvatura (m) de uma partícula de momento p (GeV/c), carga z·e num
## campo magnético B (tesla). r = p / (0,2998·z·B).
static func radius_of_curvature_m(p_gev: float, z: float, b_tesla: float) -> float:
	if b_tesla <= 0.0 or z == 0.0:
		return INF
	return p_gev / (K_CONV * absf(z) * b_tesla)


## Momento (GeV/c) inferido a partir do raio de curvatura (m).
static func momentum_from_curvature_gev(r_m: float, z: float, b_tesla: float) -> float:
	return K_CONV * z * b_tesla * r_m


## Curvatura (m⁻¹) no plano transverso.
static func curvature_per_m(r_m: float) -> float:
	if r_m <= 0.0:
		return INF
	return 1.0 / r_m


## Energia de centro de massa para feixes simétricos: √s = 2E.
static func com_energy_symmetric_gev(beam_energy_gev: float) -> float:
	return 2.0 * beam_energy_gev


## Energia de centro de massa para colisão feixe fixo-alvo:
## √s = √(2 m c² E + 2 (m c²)²) com E a energia do projétil.
static func com_energy_fixed_target_gev(proj_e_gev: float, target_mass_gev: float) -> float:
	var s := 2.0 * target_mass_gev * proj_e_gev + 2.0 * target_mass_gev * target_mass_gev
	return sqrt(maxf(s, 0.0))


## Energia total relativística de uma massa m (GeV/c²) com momento p (GeV/c).
static func total_energy_gev(mass_gev: float, p_gev: float) -> float:
	return sqrt(mass_gev * mass_gev + p_gev * p_gev)


## Momento (GeV/c) a partir da energia cinética K (GeV) e massa m (GeV/c²).
static func momentum_from_kinetic_gev(k_gev: float, mass_gev: float) -> float:
	return sqrt(maxf(k_gev * k_gev + 2.0 * k_gev * mass_gev, 0.0))
