extends Node3D
## FASE 5 — Visualização do interior do núcleon (QCD).
## Três quarks de valência (esferas) coloridos pelo rótulo de CARGA DE COR
## (vermelho/verde/azul — não são cores ópticas), conectados por tubos de fluxo
## de glúons luminescentes, imersos num mar de pares quark-antiquark virtuais
## que surgem e somem. A turbulência dos glúons representa ~99% da massa.

const NucleonModel = preload("res://scripts/nucleon_model.gd")
const SCENE_PER_FM := 1.4
const QUARK_RADIUS := 0.16
const TUBE_RADIUS := 0.035
const SEA_RADIUS := 0.055

const COLOR_CHARGE := {
	"r": Color(0.95, 0.25, 0.25),
	"g": Color(0.30, 0.90, 0.35),
	"b": Color(0.30, 0.45, 0.98),
}

var _quarks: Array = []      # {node, base, phase, axis}
var _pos: Array = []         # Vector3 atuais
var _tubes: Array = []       # MeshInstance3D
var _sea_q: Array = []       # {node, phase, radius, axis, speed}
var _sea_a: Array = []
var _time := 0.0
var _rng := RandomNumberGenerator.new()
var _built := false


func _ready() -> void:
	set_process(false)


func build(nucleon_id: String) -> void:
	clear()
	_rng.seed = 0xA7D5E3 ^ nucleon_id.hash()
	_time = 0.0

	var v := NucleonModel.valence(nucleon_id)
	var base: Array = []
	for i in range(v.size()):
		var ang := TAU * float(i) / float(maxi(v.size(), 1)) + PI * 0.5
		base.append(Vector3(cos(ang), sin(ang), 0.0) * 0.55 * SCENE_PER_FM)

	for i in range(v.size()):
		var q: Dictionary = v[i]
		var col: Color = COLOR_CHARGE.get(String(q["color"]), Color.WHITE)
		var node := _make_sphere(Vector3.ONE * QUARK_RADIUS, col, 1.1)
		add_child(node)
		var lbl := _make_label(String(q["flavor"]), col)
		node.add_child(lbl)
		_quarks.append({
			"node": node,
			"base": base[i],
			"phase": _rng.randf() * TAU,
			"axis": Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)).normalized(),
		})
		_pos.append(base[i])

	# tubos de fluxo: conectam cada par de quarks
	var n := v.size()
	for i in range(n):
		for j in range(i + 1, n):
			var tube := _make_tube()
			add_child(tube)
			_tubes.append({"node": tube, "i": i, "j": j})

	# mar de quarks virtuais
	var pairs := NucleonModel.sea_pairs(14, int(_rng.randi()))
	for pair in pairs:
		var radius := float(pair["radius"]) * SCENE_PER_FM
		var phase := float(pair["phase"])
		var axis := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1),
			_rng.randf_range(-1, 1)).normalized()
		var qcol: Color = COLOR_CHARGE.get(["r", "g", "b"][_rng.randi() % 3], Color.WHITE)
		var qn := _make_sphere(Vector3.ONE * SEA_RADIUS, qcol, 0.8)
		var an := _make_sphere(Vector3.ONE * SEA_RADIUS, qcol.lerp(Color.WHITE, 0.4), 0.5)
		add_child(qn)
		add_child(an)
		var speed := _rng.randf_range(1.2, 3.0)
		_sea_q.append({"node": qn, "phase": phase, "radius": radius, "axis": axis, "speed": speed})
		_sea_a.append({"node": an, "phase": phase + PI, "radius": radius, "axis": axis, "speed": speed})

	_built = true
	set_process(true)


func clear() -> void:
	for c in get_children():
		c.queue_free()
	_quarks.clear()
	_pos.clear()
	_tubes.clear()
	_sea_q.clear()
	_sea_a.clear()
	_built = false
	set_process(false)


func _process(delta: float) -> void:
	if not _built:
		return
	_time += delta
	var amp := 0.06 * SCENE_PER_FM
	for i in range(_quarks.size()):
		var q: Dictionary = _quarks[i]
		var off: Vector3 = q["axis"] * sin(_time * 5.0 + float(q["phase"])) * amp
		_pos[i] = q["base"] + off
		(q["node"] as Node3D).position = _pos[i]
	for t in _tubes:
		var a: Vector3 = _pos[int(t["i"])]
		var b: Vector3 = _pos[int(t["j"])]
		_place_tube(t["node"], a, b)
	for s in _sea_q:
		_update_sea(s)
	for s in _sea_a:
		_update_sea(s)


func sea_count() -> int:
	return _sea_q.size()


func valence_count() -> int:
	return _quarks.size()


func _update_sea(s: Dictionary) -> void:
	var ang := _time * float(s["speed"]) + float(s["phase"])
	var r := float(s["radius"])
	var axis: Vector3 = s["axis"]
	var ref := Vector3(0, 1, 0)
	if absf(axis.dot(ref)) > 0.9:
		ref = Vector3(1, 0, 0)
	var u := axis.cross(ref).normalized()
	var w := axis.cross(u).normalized()
	var p := (u * cos(ang) + w * sin(ang)) * r
	(s["node"] as Node3D).position = p
	(s["node"] as Node3D).scale = Vector3.ONE * (0.7 + 0.5 * absf(sin(_time * 2.0 + float(s["phase"]))))


# ------------------------------------------------------------------ helpers

func _make_sphere(scale: Vector3, col: Color, energy: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 16
	sm.rings = 8
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	sm.material = m
	mi.mesh = sm
	mi.scale = scale
	return mi


func _make_label(text: String, col: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = 48
	l.pixel_size = 0.002
	l.modulate = col.lerp(Color.WHITE, 0.4)
	l.outline_size = 6
	l.outline_modulate = Color(0, 0, 0, 0.8)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = Vector3(0.0, 0.22, 0.0)
	return l


func _make_tube() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = TUBE_RADIUS
	cm.bottom_radius = TUBE_RADIUS
	cm.height = 1.0
	cm.radial_segments = 8
	cm.rings = 1
	var col := Color(1.0, 0.85, 0.35)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 0.9
	m.no_depth_test = true
	cm.material = m
	mi.mesh = cm
	return mi


func _place_tube(mi: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var dir := b - a
	var length := dir.length()
	if length < 1e-4:
		mi.visible = false
		return
	mi.visible = true
	var d := dir / length
	var basis := _basis_from_y(d)
	basis = basis.scaled(Vector3(1.0, length, 1.0))
	mi.transform = Transform3D(basis, (a + b) * 0.5)


static func _basis_from_y(d: Vector3) -> Basis:
	var y := d.normalized()
	var ref := Vector3(0, 0, 1)
	if absf(y.z) > 0.99:
		ref = Vector3(1, 0, 0)
	var x := ref.cross(y).normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)
