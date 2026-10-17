extends Node3D
## Nuvem de probabilidade: MultiMesh de pontos billboards com blending aditivo.
## Duas fases (psi > 0 / psi < 0) -> duas cores. Nada de bolinhas em órbita.

const OrbitalSampler = preload("res://scripts/orbital_sampler.gd")

const PHASE_POS := Color(0.36, 0.78, 1.0, 1.0)
const PHASE_NEG := Color(1.0, 0.55, 0.32, 1.0)
const DOT_SIZE := 0.075

static var _dot_tex: ImageTexture = null

var _mesh_pos: QuadMesh
var _mesh_neg: QuadMesh
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 987654321
	_mesh_pos = _make_mesh(PHASE_POS)
	_mesh_neg = _make_mesh(PHASE_NEG)


static func dot_texture() -> ImageTexture:
	if _dot_tex != null:
		return _dot_tex
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in range(64):
		for x in range(64):
			var d := Vector2(float(x) - 31.5, float(y) - 31.5).length() / 32.0
			var a := clampf(1.0 - d, 0.0, 1.0)
			a *= a
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	_dot_tex = ImageTexture.create_from_image(img)
	return _dot_tex


func _make_mesh(color: Color) -> QuadMesh:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.albedo_texture = dot_texture()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	mat.disable_receive_shadows = true
	var quad := QuadMesh.new()
	quad.size = Vector2(DOT_SIZE, DOT_SIZE)
	quad.material = mat
	return quad


func clear_points() -> void:
	for c in get_children():
		c.free()


## occ: Array de {n, l, m, count[, scale]}. points_per_electron controla a densidade.
## radius_scale é um fator global; entry.scale (ex.: 1/Z_eff) ajusta cada orbital.
func rebuild(occ: Array, points_per_electron: int, radius_scale: float = 1.0) -> void:
	clear_points()
	var pos := PackedVector3Array()
	var neg := PackedVector3Array()
	for entry in occ:
		var n := int(entry["n"])
		var l := int(entry["l"])
		var m := int(entry["m"])
		var count := int(entry.get("count", 1))
		var how_many := points_per_electron * count
		var sc := radius_scale * float(entry.get("scale", 1.0))
		var d := OrbitalSampler.sample_orbital(n, l, m, how_many, _rng, sc)
		pos.append_array(d["pos"])
		neg.append_array(d["neg"])
	_add_mmi("pos", pos, _mesh_pos)
	_add_mmi("neg", neg, _mesh_neg)


func _add_mmi(tag: String, points: PackedVector3Array, mesh: Mesh) -> void:
	if points.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = points.size()
	for i in range(points.size()):
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, points[i]))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "cloud_%s" % tag
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


## Pulso visual ao absorver/emitter fóton.
func pulse(amount: float = 1.18) -> void:
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * amount, 0.12) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector3.ONE, 0.45) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


## Re-espalhamento visual pós-medição (relação de incerteza).
func spread_to(amount: float, seconds: float) -> void:
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * amount, 0.1)
	tw.tween_property(self, "scale", Vector3.ONE, seconds) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
