extends Control
## FASE 4 — Overlay "Reações & Materiais": termodinâmica (ΔG = ΔH − TΔS),
## barreira de ativação / catalisador, propriedades emergentes de materiais e
## interações fracas. Fecha com Esc.

const Materials = preload("res://scripts/materials.gd")
const Thermodynamics = preload("res://scripts/thermodynamics.gd")

var _reaction_ids: Array = []
var _material_ids: Array = []
var _reaction := ""
var _material := ""
var _temp_k := 298.15
var _use_catalyst := false

var _react_opt: OptionButton
var _react_lbl: RichTextLabel
var _temp_slider: HSlider
var _temp_lbl: Label
var _cat_check: CheckBox
var _mat_opt: OptionButton
var _mat_lbl: RichTextLabel


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.10, 0.98)
	sb.border_color = Color(0.30, 0.42, 0.60, 0.8)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(18)
	return sb


func _title(text: String, size: int = 18) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(0.6, 0.82, 1.0))
	return l


func _rich(min_size := Vector2(0, 0)) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.add_theme_font_size_override("normal_font_size", 13)
	r.add_theme_font_size_override("bold_font_size", 13)
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

	# ---------------- coluna de reações
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.custom_minimum_size = Vector2(430, 0)
	root.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	head.add_child(_title("REAÇÕES & MATERIAIS — FASE 4"))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	var close := Button.new()
	close.text = "FECHAR (Esc)"
	close.pressed.connect(_close)
	head.add_child(close)
	col.add_child(head)

	_react_opt = OptionButton.new()
	_reaction_ids = Materials.reaction_ids()
	for id in _reaction_ids:
		_react_opt.add_item(Materials.reaction_name(id))
	_react_opt.item_selected.connect(_on_reaction_selected)
	col.add_child(_react_opt)

	_temp_lbl = Label.new()
	col.add_child(_temp_lbl)
	_temp_slider = HSlider.new()
	_temp_slider.min_value = 1.0
	_temp_slider.max_value = 3000.0
	_temp_slider.step = 1.0
	_temp_slider.value = _temp_k
	_temp_slider.custom_minimum_size = Vector2(400, 0)
	_temp_slider.value_changed.connect(_on_temp_changed)
	col.add_child(_temp_slider)

	_cat_check = CheckBox.new()
	_cat_check.text = "Usar catalisador"
	_cat_check.toggled.connect(_on_catalyst_toggled)
	col.add_child(_cat_check)

	_react_lbl = _rich(Vector2(410, 0))
	col.add_child(_react_lbl)

	# ---------------- coluna de materiais
	var col2 := VBoxContainer.new()
	col2.add_theme_constant_override("separation", 8)
	col2.custom_minimum_size = Vector2(330, 0)
	root.add_child(col2)

	col2.add_child(_title("MATERIAIS E INTERAÇÕES", 16))
	_mat_opt = OptionButton.new()
	_material_ids = Materials.material_ids()
	for id in _material_ids:
		_mat_opt.add_item(Materials.material_name(id))
	_mat_opt.item_selected.connect(_on_material_selected)
	col2.add_child(_mat_opt)

	_mat_lbl = _rich(Vector2(310, 0))
	col2.add_child(_mat_lbl)

	col2.add_child(_title("Interações fracas", 14))
	var weak := _rich(Vector2(310, 0))
	var wtxt := ""
	for id in Materials.weak_interaction_ids():
		var rng: Array = Materials.weak_interaction_energy_range(id)
		wtxt += "· [b]%s[/b] (%.1f–%.1f kJ/mol)\n   %s\n" % [
			Materials.weak_interaction_name(id),
			float(rng[0]) if rng.size() > 0 else 0.0,
			float(rng[1]) if rng.size() > 1 else 0.0,
			String(Materials.weak_interaction(id).get("description", ""))]
	weak.text = wtxt
	col2.add_child(weak)

	# estado inicial
	if not _reaction_ids.is_empty():
		_reaction = String(_reaction_ids[0])
	if not _material_ids.is_empty():
		_material = String(_material_ids[0])
	_update_reaction()
	_update_material()


# ------------------------------------------------------------------- reações

func _on_reaction_selected(index: int) -> void:
	if index >= 0 and index < _reaction_ids.size():
		_reaction = String(_reaction_ids[index])
		_update_reaction()


func _on_temp_changed(v: float) -> void:
	_temp_k = v
	_update_reaction()


func _on_catalyst_toggled(pressed: bool) -> void:
	_use_catalyst = pressed
	_update_reaction()


func _update_reaction() -> void:
	if _reaction == "":
		return
	var dh := Materials.reaction_dh_kj(_reaction)
	var ds := Materials.reaction_ds_j_k(_reaction)
	var ea := Materials.reaction_ea_kj(_reaction)
	var ea_cat := Materials.reaction_ea_catalyzed_kj(_reaction)
	var catalyst := Materials.reaction_catalyst(_reaction)
	var g := Thermodynamics.gibbs_kj(dh, ds, _temp_k)
	var spont := g < 0.0
	var t_cross := Thermodynamics.crossover_temperature_k(dh, ds)
	var t_cross_txt := "—"
	if not is_nan(t_cross):
		if t_cross > 0.0:
			t_cross_txt = "%.0f K (%.0f °C)" % [t_cross, t_cross - 273.15]
		else:
			t_cross_txt = "%.0f K (nunca espontânea com T>0)" % t_cross
	var has_cat := not is_nan(ea_cat) and catalyst != ""
	_cat_check.disabled = not has_cat
	if not has_cat and _use_catalyst:
		_cat_check.set_pressed_no_signal(false)
		_use_catalyst = false
	var ea_eff := ea_cat if (_use_catalyst and has_cat) else ea
	var factor := Thermodynamics.arrhenius_factor(ea_eff, _temp_k)
	var kin := Thermodynamics.kinetics_label(factor)
	var cat_txt := "—"
	if has_cat:
		var enh := Thermodynamics.catalyst_enhancement(ea, ea_cat, _temp_k)
		cat_txt = "%s: Ea %.0f → %.0f kJ/mol (%s× a %.0f K)" % [
			catalyst, ea, ea_cat, _sci(enh), _temp_k]
	_temp_lbl.text = "Temperatura = %.0f K  (%.0f °C)" % [_temp_k, _temp_k - 273.15]
	_react_lbl.text = (
		"[b]%s[/b]\n%s\n" +
		"ΔH° = [b]%+.1f kJ/mol[/b] · ΔS° = %+.1f J/(mol·K)\n" +
		"ΔG(T) = [b]%+.1f kJ/mol[/b] → %s\n" +
		"ΔG = 0 em T = %s\n" +
		"Energia de ativação Ea = %.0f kJ/mol\n" +
		"Catálise: %s\n" +
		"Fator de Arrhenius exp(−Ea/RT) = %s → cinética %s\n" +
		"[i]%s[/i]"
	) % [
		Materials.reaction_name(_reaction), Materials.reaction_equation(_reaction),
		dh, ds, g, ("espontânea" if spont else "não espontânea"),
		t_cross_txt, ea, cat_txt, _sci(factor), kin,
		Materials.reaction_note(_reaction)]


# ----------------------------------------------------------------- materiais

func _on_material_selected(index: int) -> void:
	if index >= 0 and index < _material_ids.size():
		_material = String(_material_ids[index])
		_update_material()


func _update_material() -> void:
	if _material == "":
		return
	var gap := Materials.material_band_gap_ev(_material)
	var gap_txt := "—" if is_nan(gap) else "%.2f eV" % gap
	_mat_lbl.text = (
		"[b]%s[/b] (%s)\n%s\nLigação: %s\nIntervalo de banda = [b]%s[/b]\n"
		+ "Condução: %s\n[i]%s[/i]"
	) % [
		Materials.material_name(_material), Materials.material_formula(_material),
		Materials.material_structure(_material), Materials.material_bonding(_material),
		gap_txt, Materials.material_conduction(_material),
		Materials.material_note(_material)]


# ------------------------------------------------------------------ overlay

func open() -> void:
	visible = true


func _sci(v: float) -> String:
	if v == 0.0:
		return "0"
	var e := int(floor(log(absf(v)) / log(10.0)))
	var m := v / pow(10.0, float(e))
	return "%.2f×10^%d" % [m, e]


func _close() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close()
		get_viewport().set_input_as_handled()
