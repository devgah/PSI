extends RefCounted
## Propriedades atômicas derivadas. Combina dados medidos (NIST) com estimativas
## do modelo de Slater. Deixa EXPLÍCITO o que é medição e o que é aproximação.

const AtomConstants = preload("res://scripts/atom_constants.gd")
const ElementData = preload("res://scripts/element_data.gd")
const Slater = preload("res://scripts/slater.gd")


## Raio atômico efetivo estimado (Slater): r ~ n_val^2 / Z_eff, em unidades de Bohr.
static func slater_radius_au(z: int) -> float:
	var n := Slater.outer_n(z, z)
	var ze := Slater.z_eff_outer(z)
	if ze <= 0.0:
		return 0.0
	return float(n * n) / ze


static func slater_radius_angstrom(z: int) -> float:
	return AtomConstants.bohr_to_angstrom(slater_radius_au(z))


## Energia de ionização estimada por Slater: E = Ry * Z_eff^2 / n_val^2 (eV).
static func slater_ie1_ev(z: int) -> float:
	var n := Slater.outer_n(z, z)
	var ze := Slater.z_eff_outer(z)
	return AtomConstants.RYDBERG_EV * ze * ze / float(n * n)


## Energia de ionização medida (NIST).
static func nist_ie1_ev(z: int) -> float:
	return ElementData.ie1_ev(z)


## Z_eff do elétron de valência (config fundamental neutra).
static func valence_z_eff(z: int) -> float:
	return Slater.z_eff_outer(z)


## Erro relativo da estimativa de Slater frente ao valor do NIST.
static func slater_ie1_error(z: int) -> float:
	var nist := nist_ie1_ev(z)
	if nist <= 0.0:
		return 0.0
	return absf(slater_ie1_ev(z) - nist) / nist
