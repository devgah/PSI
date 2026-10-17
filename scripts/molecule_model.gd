extends RefCounted
## FASE 4 — Modelo de uma molécula: geometria 3D (posições em pm), ligações,
## orbitais moleculares (diatômicos), classificação por eletronegatividade,
## VSEPR e parâmetros do potencial de Morse.

const MoleculeData = preload("res://scripts/molecule_data.gd")
const ElementData = preload("res://scripts/element_data.gd")
const MolecularOrbital = preload("res://scripts/molecular_orbital.gd")
const Electronegativity = preload("res://scripts/electronegativity.gd")
const Vsepr = preload("res://scripts/vsepr.gd")
const Morse = preload("res://scripts/morse.gd")

## Massas atômicas padrão (u) dos elementos usados nas moléculas.
const MASS_U := {
	"H": 1.008, "He": 4.0026, "Li": 6.94, "Be": 9.0122, "B": 10.81,
	"C": 12.011, "N": 14.007, "O": 15.999, "F": 18.998, "Ne": 20.180,
	"Na": 22.990, "Cl": 35.45,
}

var id: String
var atoms: Array = []
var bonds: Array = []


func _init(molecule_id: String) -> void:
	id = molecule_id
	atoms = MoleculeData.atoms(id).duplicate()
	bonds = MoleculeData.bonds(id).duplicate()


# ----------------------------------------------------------------- propriedades

func formula() -> String:
	return MoleculeData.formula(id)


func name() -> String:
	return MoleculeData.name(id)


func geometry() -> String:
	return MoleculeData.geometry(id)


func bonds_count() -> int:
	return bonds.size()


func center_index() -> int:
	return 0


func ligand_count() -> int:
	return bonds.size()


func lone_pairs() -> int:
	return MoleculeData.lone_pairs(id)


## Par de elementos (central, ligante) para eletronegatividade.
func _pair() -> Array:
	if atoms.size() >= 2:
		return [String(atoms[0]), String(atoms[1])]
	return [String(atoms[0]), String(atoms[0])]


func delta_en() -> float:
	var p := _pair()
	return Electronegativity.delta_en(
		ElementData.z_of_symbol(p[0]), ElementData.z_of_symbol(p[1]))


func bond_class() -> String:
	var p := _pair()
	return Electronegativity.bond_class(
		ElementData.z_of_symbol(p[0]), ElementData.z_of_symbol(p[1]))


func bond_class_extended() -> String:
	var p := _pair()
	return Electronegativity.bond_class_extended(
		ElementData.z_of_symbol(p[0]), ElementData.z_of_symbol(p[1]))


func ionic_character() -> float:
	var p := _pair()
	return Electronegativity.ionic_character(
		ElementData.z_of_symbol(p[0]), ElementData.z_of_symbol(p[1]))


## Informação de orbitais moleculares (apenas diatómicos).
func mo() -> Dictionary:
	if atoms.size() != 2:
		return {}
	return MolecularOrbital.diatomic(String(atoms[0]), String(atoms[1]))


func computed_bond_order() -> float:
	var d := mo()
	if d.is_empty():
		return float(MoleculeData.bond_order(id))
	return float(d["bond_order"])


func reported_bond_order() -> int:
	return MoleculeData.bond_order(id)


func unpaired() -> int:
	var d := mo()
	return int(d.get("unpaired", 0))


func paramagnetic() -> bool:
	return bool(mo().get("paramagnetic", false))


func vsepr() -> Dictionary:
	if atoms.size() == 2:
		return Vsepr.predict(1, 0)
	return Vsepr.predict(ligand_count(), lone_pairs())


# ------------------------------------------------------------------- geometria 3D

## Massa atômica (u) de um símbolo.
static func mass_u(sym: String) -> float:
	return float(MASS_U.get(sym, 1.0))


## Massa reduzida média dos dois átomos do primeiro par (u).
func reduced_mass_u() -> float:
	var p := _pair()
	return Morse.reduced_mass_u(mass_u(p[0]), mass_u(p[1]))


## Posições dos átomos em pm, indexadas como em data/molecules.json.
func positions_pm() -> Array:
	var n := atoms.size()
	var re := MoleculeData.bond_length_pm(id)
	if is_nan(re) or re <= 0.0:
		re = 100.0
	var geom := geometry()
	var out: Array = []

	if n == 2:
		out = [Vector3(-re * 0.5, 0, 0), Vector3(re * 0.5, 0, 0)]
	elif geom == "linear" and n == 3:
		# central (índice 0) na origem; dois ligantes nos eixos ±x
		out = [Vector3.ZERO, Vector3(re, 0, 0), Vector3(-re, 0, 0)]
	elif geom == "bent":
		var half := deg_to_rad(MoleculeData.bond_angle_deg(id) * 0.5)
		var d := Vector3(sin(half), cos(half), 0) * re
		out = [Vector3.ZERO, d, Vector3(-d.x, d.y, 0)]
	elif geom == "trigonal_pyramidal":
		var ang := MoleculeData.bond_angle_deg(id)
		var c := (cos(deg_to_rad(ang)) + 0.5) / 1.5
		var cos_t := clampf(c, -1.0, 1.0)
		var cos_th := sqrt(maxf(cos_t, 0.0))
		var sin_th := sqrt(maxf(1.0 - cos_t, 0.0))
		out = [Vector3.ZERO]
		for k in range(3):
			var phi := TAU * float(k) / 3.0
			out.append(Vector3(sin_th * cos(phi), sin_th * sin(phi), -cos_th) * re)
	elif geom == "tetrahedral":
		var dirs := [
			Vector3(1, 1, 1), Vector3(1, -1, -1),
			Vector3(-1, 1, -1), Vector3(-1, -1, 1),
		]
		out = [Vector3.ZERO]
		for v in dirs:
			out.append(v.normalized() * re)
	else:
		# fallback: cadeia ao longo de x
		for i in range(n):
			out.append(Vector3(float(i) * re, 0, 0))
	return out


## Pares (a, b) de posições (pm) para cada ligação.
func bond_segments_pm() -> Array:
	var pos := positions_pm()
	var segs: Array = []
	for b in bonds:
		var i := int(b[0])
		var j := int(b[1])
		if i < pos.size() and j < pos.size():
			segs.append([pos[i], pos[j], int(b[2]) if b.size() > 2 else 1])
	return segs


# ---------------------------------------------------------------------- Morse

func morse() -> Dictionary:
	var de := MoleculeData.bond_energy_ev(id)
	var re := MoleculeData.bond_length_pm(id)
	if is_nan(de) or is_nan(re) or de <= 0.0 or re <= 0.0:
		return {}
	var a := Morse.A_DEFAULT
	var thz := Morse.harmonic_frequency_thz(de, a, reduced_mass_u())
	var zpe := 0.0
	if thz > 0.0:
		zpe = 0.5 * 4.135667696e-15 * thz * 1.0e12  # eV
	return {
		"de_ev": de, "re_pm": re, "a_inv_pm": a,
		"frequency_thz": thz, "zpe_ev": zpe, "d0_ev": de - zpe,
	}
