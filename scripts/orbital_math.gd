extends RefCounted
## Matemática dos orbitais hidrogenoides em unidades atômicas (a0 = 1, hbar = 1, m_e = 1).
## psi_{n,l,m}(r) = R_{n,l}(r) * Y_{l,m}(theta, phi), normalizados: integral |psi|^2 dV = 1.

const AtomConstants = preload("res://scripts/atom_constants.gd")

static var _fact_cache: Dictionary = {}


static func factorial(n: int) -> float:
	if n <= 1:
		return 1.0
	if _fact_cache.has(n):
		return _fact_cache[n]
	var v := 1.0
	for i in range(2, n + 1):
		v *= float(i)
	_fact_cache[n] = v
	return v


## Polinômio de Laguerre associado L_k^alpha(x) via recorrência.
static func laguerre(k: int, alpha: float, x: float) -> float:
	if k <= 0:
		return 1.0
	var lm1 := 1.0
	var l := 1.0 + alpha - x
	if k == 1:
		return l
	for i in range(2, k + 1):
		var li := ((2.0 * i - 1.0 + alpha - x) * l - (float(i) - 1.0 + alpha) * lm1) / float(i)
		lm1 = l
		l = li
	return l


## Polinômio associado de Legendre P_l^m(x), fase Condon-Shortley, 0 <= m <= l.
static func legendre(l: int, m: int, x: float) -> float:
	var pmm := 1.0
	if m > 0:
		var somx2 := sqrt(maxf(0.0, 1.0 - x * x))
		var fact := 1.0
		for _i in range(1, m + 1):
			pmm *= -fact * somx2
			fact += 2.0
	if l == m:
		return pmm
	var pmmp1 := x * (2.0 * m + 1.0) * pmm
	if l == m + 1:
		return pmmp1
	var pll := 0.0
	for ll in range(m + 2, l + 1):
		pll = ((2.0 * ll - 1.0) * x * pmmp1 - (float(ll) + float(m) - 1.0) * pmm) / float(ll - m)
		pmm = pmmp1
		pmmp1 = pll
	return pll


## Harmônico esférico real Y_{l,m}(cos_theta, phi).
static func real_sh(l: int, m: int, cos_t: float, phi: float) -> float:
	var am: int = absi(m)
	var p := legendre(l, am, cos_t)
	var norm: float
	if m == 0:
		norm = sqrt((2.0 * l + 1.0) / (4.0 * PI))
	else:
		norm = sqrt(2.0 * (2.0 * l + 1.0) / (4.0 * PI) \
			* factorial(l - am) / factorial(l + am))
	var v := norm * p
	if m > 0:
		v *= cos(float(am) * phi)
	elif m < 0:
		v *= sin(float(am) * phi)
	return v


## Parte radial R_{n,l}(r) em unidades atômicas.
static func radial(n: int, l: int, r: float) -> float:
	var norm := sqrt(pow(2.0 / float(n), 3.0) * factorial(n - l - 1) \
		/ (2.0 * float(n) * factorial(n + l)))
	var rho := 2.0 * r / float(n)
	return norm * exp(-0.5 * rho) * pow(rho, float(l)) * laguerre(n - l - 1, 2 * l + 1, rho)


## Função de onda completa (a.u.).
static func psi(n: int, l: int, m: int, r: float, cos_t: float, phi: float) -> float:
	return radial(n, l, r) * real_sh(l, m, cos_t, phi)


## Densidade radial de probabilidade P(r) = r^2 |R|^2.
static func radial_probability(n: int, l: int, r: float) -> float:
	var rv := radial(n, l, r)
	return r * r * rv * rv


## Energia do nível n para carga efetiva z (eV): E_n = -Ry * z^2 / n^2.
## z pode ser a carga nuclear Z (hidrogenoide) ou Z_eff de Slater (multieletrônico).
static func energy_ev(z: float, n: int) -> float:
	if n <= 0:
		return 0.0
	return -AtomConstants.RYDBERG_EV * z * z / float(n * n)


## ΔE da transição entre n1 e n2 (positiva), em eV.
static func transition_energy_ev(z: float, n1: int, n2: int) -> float:
	if n1 <= 0 or n2 <= 0 or n1 == n2:
		return 0.0
	var lo := mini(n1, n2)
	var hi := maxi(n1, n2)
	return AtomConstants.RYDBERG_EV * z * z * (1.0 / float(lo * lo) - 1.0 / float(hi * hi))


## Comprimento de onda da linha espectral n1 <-> n2 (nm). Fórmula de Rydberg.
static func wavelength_nm(z: float, n1: int, n2: int) -> float:
	if n1 <= 0 or n2 <= 0 or n1 == n2:
		return 0.0
	var lo := mini(n1, n2)
	var hi := maxi(n1, n2)
	var inv_lambda := AtomConstants.RYDBERG_CONSTANT_M * z * z \
		* (1.0 / float(lo * lo) - 1.0 / float(hi * hi))
	if inv_lambda <= 0.0:
		return 0.0
	return 1.0e9 / inv_lambda


## Letra do subcamada (s, p, d, f).
static func orbital_letter(l: int) -> String:
	match l:
		0:
			return "s"
		1:
			return "p"
		2:
			return "d"
		3:
			return "f"
	return "l=%d" % l


## Rótulo do orbital: 1s, 2p, 3d...
static func orbital_label(n: int, l: int) -> String:
	return "%d%s" % [n, orbital_letter(l)]


## Energia média <r> em unidades de Bohr: (3n^2 - l(l+1)) / 2.
static func mean_radius_au(n: int, l: int) -> float:
	return (3.0 * float(n * n) - float(l * (l + 1))) / 2.0


## Regra de seleção dipolar: delta_l = +-1 e delta_m in {0, +-1}.
static func is_allowed_transition(n1: int, l1: int, m1: int, n2: int, l2: int, m2: int) -> bool:
	if n1 == n2:
		return false
	if absi(l2 - l1) != 1:
		return false
	if absi(m2 - m1) > 1:
		return false
	return true
