extends Control
## FASE 5 — Overlay "Modelo Padrão & Conservação". Mostra o catálogo de
## partículas elementares, o espectro de hádrons, o validador estrito das leis
## de conservação (processos permitidos/proibidos) e a quebra de corda (QCD).
## Fecha com Esc.

const ParticleData = preload("res://scripts/particle_data.gd")
const ProcessData = preload("res://scripts/process_data.gd")
const Conservation = preload("res://scripts/conservation.gd")
const Hadron = preload("res://scripts/hadron.gd")
const StringBreaking = preload("res://scripts/string_breaking.gd")

var _process_ids: Array = []
var _process := ""

var _proc_opt: OptionButton
var _proc_lbl: RichTextLabel
var _particle_lbl: RichTextLabel
var _hadron_lbl: RichTextLabel


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.10, 0.98)
	sb.border_color = Color(0.55, 0.40, 0.70, 0.8)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(18)
	return sb


func _title(text: String, size: int = 16) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(0.80, 0.68, 1.0))
	return l


func _rich(min_size := Vector2(0, 0)) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.add_theme_font_size_override("normal_font_size", 12)
	r.add_theme_font_size_override("bold_font_size", 12)
	r.custom_minimum_size = min_size
	return r


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.02, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style())
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	add_child(panel)

	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 20)
	panel.add_child(root)

	# ---------------- coluna 1: catálogo de partículas
	var col1 := VBoxContainer.new()
	col1.add_theme_constant_override("separation", 8)
	col1.custom_minimum_size = Vector2(330, 0)
	root.add_child(col1)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	head.add_child(_title("MODELO PADRÃO — FASE 5", 16))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	var close := Button.new()
	close.text = "FECHAR (Esc)"
	close.pressed.connect(_close)
	head.add_child(close)
	col1.add_child(head)
	_particle_lbl = _rich(Vector2(320, 0))
	col1.add_child(_particle_lbl)

	# ---------------- coluna 2: validador de conservação
	var col2 := VBoxContainer.new()
	col2.add_theme_constant_override("separation", 8)
	col2.custom_minimum_size = Vector2(400, 0)
	root.add_child(col2)
	col2.add_child(_title("VALIDADOR DE CONSERVAÇÃO", 16))
	_proc_opt = OptionButton.new()
	_process_ids = ProcessData.ids()
	_process_ids.sort()
	for id in _process_ids:
		_proc_opt.add_item(ProcessData.name(id))
	_proc_opt.item_selected.connect(_on_process_selected)
	col2.add_child(_proc_opt)
	_proc_lbl = _rich(Vector2(390, 0))
	col2.add_child(_proc_lbl)

	# ---------------- coluna 3: hádrons + quebra de corda
	var col3 := VBoxContainer.new()
	col3.add_theme_constant_override("separation", 8)
	col3.custom_minimum_size = Vector2(370, 0)
	root.add_child(col3)
	col3.add_child(_title("HÁDRONS & QUEBRA DE CORDA", 16))
	_hadron_lbl = _rich(Vector2(360, 0))
	col3.add_child(_hadron_lbl)

	if not _process_ids.is_empty():
		_process = String(_process_ids[0])
	_build_particles()
	_build_hadrons()
	_update_process()


# ----------------------------------------------------------- catálogo

func _mass_str(mev: float) -> String:
	if mev <= 0.0:
		return "~0"
	if mev >= 1000.0:
		return "%.2f GeV" % (mev / 1000.0)
	return "%.2f MeV" % mev


func _build_particles() -> void:
	var t := ""
	t += "[b]Quarks[/b] (fermions, spin ½, B = ⅓)\n"
	for id in ParticleData.elementary_ids_by_group("quarks"):
		var p := ParticleData.get_particle(id)
		t += "  %s · carga %s · %s\n" % [
			ParticleData.symbol(id), Conservation.fmt_e3(int(p["charge_e3"])),
			_mass_str(float(p["mass_mev"]))]
	t += "\n[b]Léptons[/b] (fermions, spin ½)\n"
	for id in ParticleData.elementary_ids_by_group("leptons"):
		var p := ParticleData.get_particle(id)
		t += "  %s · carga %s · %s\n" % [
			ParticleData.symbol(id), Conservation.fmt_e3(int(p["charge_e3"])),
			_mass_str(float(p["mass_mev"]))]
	t += "\n[b]Bósons[/b] (mediadores)\n"
	for id in ParticleData.elementary_ids_by_group("bosons"):
		var p := ParticleData.get_particle(id)
		t += "  %s · spin %s · %s\n" % [
			ParticleData.symbol(id), _spin_str(int(p["spin2"])),
			_mass_str(float(p["mass_mev"]))]
	t += "\n[i]Cores (r, g, b) dos quarks são rótulos de carga de cor, "
	t += "não cores ópticas.[/i]"
	_particle_lbl.text = t


func _spin_str(spin2: int) -> String:
	if spin2 % 2 == 0:
		return "%d" % (spin2 / 2)
	return "%d/2" % spin2


func _build_hadrons() -> void:
	var t := "[b]Bárions e mésons[/b] (compostos, sempre brancos)\n"
	for id in ParticleData.hadron_ids():
		var p := ParticleData.get_particle(id)
		var content: Array = p.get("content", [])
		var cs := ""
		for c in content:
			cs += ParticleData.symbol(String(c))
		t += "  %s · %s · %s · B=%s\n" % [
			String(p.get("symbol", id)), cs,
			Conservation.fmt_e3(int(p["charge_e3"])),
			Conservation.fmt_e3(int(p["baryon_e3"]))]
	t += "\n[b]Quebra de corda[/b] (κ ≈ 1 GeV/fm)\n"
	var br := StringBreaking.split_nucleon("proton", 0, "d")
	if bool(br.get("ok", false)):
		t += "  Afastar um u do próton além de %.1f fm cria um par d d̄:\n" % [
			float(br["breaking_distance_fm"])]
		t += "  → %s + %s\n" % [
			String(br["meson"]["symbol"]), String(br["baryon"]["symbol"])]
		t += "  Dois hádrons BRANCOS; nunca se vê quark isolado."
	_hadron_lbl.text = t


# ----------------------------------------------------------- validador

func _on_process_selected(index: int) -> void:
	if index >= 0 and index < _process_ids.size():
		_process = String(_process_ids[index])
		_update_process()


func _update_process() -> void:
	if _process == "":
		return
	var res := ProcessData.validate(_process)
	var allowed := bool(res.get("ok", false))
	var expected := ProcessData.expected(_process)
	var match_ok := bool(res.get("matches_expected", false))
	var d: Dictionary = res.get("details", {})
	var lines := ""
	var laws := [
		["carga", d.get("charge_e3", {})],
		["bárion", d.get("baryon_e3", {})],
		["leptônico (e)", d.get("le", {})],
		["leptônico (μ)", d.get("lmu", {})],
		["leptônico (τ)", d.get("ltau", {})],
	]
	for pair in laws:
		var dd: Dictionary = pair[1]
		var ini := int(dd.get("in", 0))
		var out := int(dd.get("out", 0))
		var mark := "✓" if ini == out else "✗"
		lines += "  %s %s: %d → %d\n" % [mark, String(pair[0]), ini, out]
	for fl in ["strangeness", "charm", "bottomness", "topness"]:
		var dd2: Dictionary = d.get(fl, {})
		if dd2.is_empty():
			continue
		var ini2 := int(dd2.get("in", 0))
		var out2 := int(dd2.get("out", 0))
		if ini2 != 0 or out2 != 0:
			var mark2 := "✓" if ini2 == out2 else "✗"
			lines += "  %s sabor (%s): %d → %d\n" % [mark2,
				Conservation.flavor_label(fl), ini2, out2]
	var verdict_col := "green" if allowed else "red"
	var verdict_txt := "PERMITIDA" if allowed else "PROIBIDA"
	var viol := ""
	var vlist: Array = res.get("violations", [])
	if not vlist.is_empty():
		viol = "\n[b]Violações:[/b]\n"
		for v in vlist:
			viol += "  • %s\n" % String(v)
	var cmp := "bate com o esperado" if match_ok else "DIVERGE do esperado"
	_proc_lbl.text = (
		"[b]%s[/b]\n%s\n\n" +
		"[color=%s][b]%s[/b][/color]\n" +
		"Fraca: %s · Expectativa: [b]%s[/b] (%s)\n\n" +
		"[b]Leis conservadas:[/b]\n%s%s\n[i]%s[/i]"
	) % [
		ProcessData.name(_process), ProcessData.equation(_process),
		verdict_col, verdict_txt,
		("sim" if ProcessData.is_weak(_process) else "não"),
		expected, cmp, lines, viol, ProcessData.note(_process)]


# ----------------------------------------------------------- overlay

func open() -> void:
	visible = true


func _close() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close()
		get_viewport().set_input_as_handled()
