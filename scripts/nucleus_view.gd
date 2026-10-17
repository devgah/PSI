extends Node3D
## FASE 3 — Visualização do caroço nuclear: A nucleons (prótons/neutrôns) como
## esferas que vibram coesas, com raio R ≈ r0·A^(1/3). Representação ilustrativa
## (nucleons não são esferas rígidas; a cor distingue próton de nêutron).

const Nuclear = preload("res://scripts/nuclear.gd")

const PROTON_COLOR := Color(0.95, 0.34, 0.30)
const NEUTRON_COLOR := Color(0.36, 0.60, 0.95)
const MAGIC_TINT := Color(1.0, 0.86, 0.35)

var _mmi: MultiMeshInstance3D
var _base: PackedVector3Array = []
var _phase: PackedFloat32Array = []
var _axis: PackedVector3Array = []
var _time := 0.0
var _rng := RandomNumberGenerator.new()
var _count := 0
var _magic := false
var _radius := 0.15


func _ready() -> void:
	_mmi = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	_mmi.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.emission_enabled = true
	mat.emission = Color(1, 1, 1)
	mat.emission_energy_multiplier = 0.6
	_mmi.material_override = mat
	add_child(_mmi)
	set_process(false)


## Reconstrói o caroço para Z prótons e N nêutrons.
func build(z: int, n: int) -> void:
	_count = maxi(z + n, 1)
	_magic = Nuclear.is_magic(z) or Nuclear.is_magic(n)
	_radius = 0.05 * Nuclear.radius_fm(_count) + 0.05
	_rng.seed = 0x9E3779B9 ^ (_count * 2654435761)

	var mm := _mmi.multimesh
	mm.instance_count = _count
	_base.resize(_count)
	_phase.resize(_count)
	_axis.resize(_count)

	# raio da esfera de nucleon (encolhe conforme A cresce)
	var nucleon_r := clampf(_radius * 0.55 / pow(float(_count), 1.0 / 3.0), 0.02, 0.11)
	# empacotamento: pontos aleatórios no volume com separação mínima simples
	var min_d := nucleon_r * 1.5
	for i in range(_count):
		var p := Vector3.ZERO
		for attempt in range(24):
			var u := _rng.randf()
			var r := _radius * pow(u, 1.0 / 3.0)
			var theta := acos(1.0 - 2.0 * _rng.randf())
			var phi := TAU * _rng.randf()
			p = Vector3(r * sin(theta) * cos(phi),
				r * sin(theta) * sin(phi), r * cos(theta))
			var clash := false
			for j in range(i):
				if p.distance_to(_base[j]) < min_d:
					clash = true
					break
			if not clash:
				break
		_base[i] = p
		_phase[i] = TAU * _rng.randf()
		_axis[i] = Vector3(_rng.randf_range(-1, 1),
			_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)).normalized()

	# intercala a cor para não aglomerar (visual)
	for i in range(_count):
		var c := PROTON_COLOR if (i % 2 == 0) else NEUTRON_COLOR
		if _magic:
			c = c.lerp(MAGIC_TINT, 0.25)
		mm.set_instance_color(i, c)
		var scale := nucleon_r
		mm.set_instance_transform(i,
			Transform3D(Basis.from_scale(Vector3.ONE * scale), _base[i]))

	_mmi.visible = true
	set_process(true)


func pulse(scale: float = 1.2) -> void:
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * scale, 0.12)
	tw.tween_property(self, "scale", Vector3.ONE, 0.35)


func _process(delta: float) -> void:
	if _count <= 0 or not _mmi.visible:
		return
	_time += delta
	var mm := _mmi.multimesh
	var amp := _radius * 0.06
	for i in range(_count):
		var off := _axis[i] * sin(_time * 6.0 + _phase[i]) * amp
		var tr := mm.get_instance_transform(i)
		var b := tr.basis
		mm.set_instance_transform(i, Transform3D(b, _base[i] + off))
