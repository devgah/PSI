extends Node3D
## FASE 4 — Visualização 3D da molécula: núcleos (esferas, cores CPK) e ligações
## (cilindros; ordem 2 e 3 desenhadas como múltiplos cilindros paralelos).
## Escala ilustrativa: ligações em pm convertidas por SCENE_PER_PM.

const SCENE_PER_PM := 0.02
const ATOM_RADIUS := 0.32
const BOND_RADIUS := 0.06

## Cores CPK aproximadas.
const COLORS := {
	"H": Color(0.92, 0.92, 0.92), "He": Color(0.85, 0.95, 1.0),
	"Li": Color(0.80, 0.50, 0.95), "Be": Color(0.45, 0.80, 0.45),
	"B": Color(0.95, 0.65, 0.55), "C": Color(0.35, 0.35, 0.38),
	"N": Color(0.30, 0.45, 0.95), "O": Color(0.95, 0.25, 0.25),
	"F": Color(0.45, 0.90, 0.45), "Ne": Color(0.75, 0.95, 1.0),
	"Na": Color(0.70, 0.35, 0.90), "Cl": Color(0.35, 0.85, 0.35),
}


func _color_of(sym: String) -> Color:
	return COLORS.get(sym, Color(0.7, 0.7, 0.75))


## Constrói a geometria a partir de um MoleculeModel.
func build(model) -> void:
	clear()
	var pos: Array = model.positions_pm()
	var syms: Array = model.atoms
	# átomos
	for i in range(pos.size()):
		add_child(_make_atom(pos[i] * SCENE_PER_PM,
			_color_of(String(syms[i]) if i < syms.size() else "C")))
	# ligações
	for seg in model.bond_segments_pm():
		var a: Vector3 = seg[0] * SCENE_PER_PM
		var b: Vector3 = seg[1] * SCENE_PER_PM
		var order: int = int(seg[2])
		_make_bond(a, b, order, model)


func clear() -> void:
	for c in get_children():
		c.queue_free()


func _make_atom(p: Vector3, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = ATOM_RADIUS
	s.height = ATOM_RADIUS * 2.0
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 0.7
	s.material = m
	mi.mesh = s
	mi.position = p
	return mi


func _make_bond(a: Vector3, b: Vector3, order: int, model) -> void:
	var dir := b - a
	var length := dir.length()
	if length < 0.001:
		return
	var d := dir / length
	var offsets: Array = [Vector3.ZERO]
	if order == 2:
		offsets = [_perp(d) * 0.11, -_perp(d) * 0.11]
	elif order >= 3:
		offsets = [_perp(d) * 0.14, -_perp(d) * 0.14, Vector3.ZERO]
	var col := Color(0.78, 0.80, 0.85)
	for off in offsets:
		var mi := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = BOND_RADIUS
		cyl.bottom_radius = BOND_RADIUS
		cyl.height = 1.0
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = col
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = 0.35
		cyl.material = m
		mi.mesh = cyl
		var basis := _basis_from_y(d)
		basis = basis.scaled(Vector3(1.0, length, 1.0))
		mi.transform = Transform3D(basis, (a + b) * 0.5 + off)
		add_child(mi)


static func _perp(d: Vector3) -> Vector3:
	var ref := Vector3(0, 1, 0)
	if absf(d.dot(ref)) > 0.9:
		ref = Vector3(1, 0, 0)
	return d.cross(ref).normalized()


static func _basis_from_y(d: Vector3) -> Basis:
	var y := d.normalized()
	var ref := Vector3(0, 0, 1)
	if absf(y.z) > 0.99:
		ref = Vector3(1, 0, 0)
	var x := ref.cross(y).normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)
