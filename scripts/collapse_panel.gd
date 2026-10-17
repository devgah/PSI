extends Control
## FASE 6 — Overlay "Colapso & Forja Estelar". Três colunas:
##  1) Colapso gravitacional (anã branca → estrela de nêutrons → buraco negro);
##  2) Forja estelar (nucleossíntese: pp, triplo-alfa, escada até o ferro, s/r);
##  3) Colisor (massa invariante, raio de curvatura, energia de centro de massa).
## Fecha com Esc.

const Star = preload("res://scripts/star.gd")
const Nucleosynthesis = preload("res://scripts/nucleosynthesis.gd")
const Collider = preload("res://scripts/collider.gd")

var _mass_sl: HSlider
var _temp_sl: HSlider
var _star_lbl: RichTextLabel

var _fusion_lbl: RichTextLabel

var _p_sl: HSlider
var _b_sl: HSlider
var _collider_lbl: RichTextLabel


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


# --------------------------------------------------------------- estilo

func _style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.09, 0.98)
	sb.border_color = Color(0.85, 0.60, 0.35, 0.8)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(18)
	return sb


func _title(text: String, size: int = 16) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(1.0, 0.80, 0.58))
	return l


func _rich(min_size := Vector2(0, 0)) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.add_theme_font_size_override("normal_font_size", 12)
	r.add_theme_font_size_override("bold_font_size", 12)
	r.custom_minimum_size = min_size
	return r


func _slider(mn: float, mx: float, step: float, val: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = step
	s.value = val
	s.custom_minimum_size = Vector2(330, 0)
	return s


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.02, 0.74)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style())
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT,
		Control.PRESET_MODE_MINSIZE, 24)
	add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	panel.add_child(root)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	head.add_child(_title("COLAPSO & FORJA ESTELAR — FASE 6", 18))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	var close := Button.new()
	close.text = "FECHAR (Esc)"
	close.pressed.connect(_close)
	head.add_child(close)
	root.add_child(head)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 22)
	root.add_child(cols)

	_build_star(cols)
	_build_fusion(cols)
	_build_collider(cols)

	_update_star()
	_update_fusion()
	_update_collider()


# --------------------------------------------------------------- colapso

func _build_star(parent: Node) -> void:
	var c := VBoxContainer.new()
	c.add_theme_constant_override("separation", 8)
	c.custom_minimum_size = Vector2(420, 0)
	parent.add_child(c)
	c.add_child(_title("COLAPSO GRAVITACIONAL"))
	c.add_child(_small("Massa da amostra (massas solares):"))
	_mass_sl = _slider(0.1, 3.0, 0.01, 1.0)
	_mass_sl.value_changed.connect(func(_v): _update_star())
	c.add_child(_mass_sl)
	c.add_child(_small("Temperatura do núcleo (K):"))
	_temp_sl = _slider(1.0e6, 3.0e12, 1.0e6, 1.0e8)
	_temp_sl.value_changed.connect(func(_v): _update_star())
	c.add_child(_temp_sl)
	_star_lbl = _rich(Vector2(410, 0))
	c.add_child(_star_lbl)


func _small(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color(0.8, 0.82, 0.9))
	return l


func _fmt1(v: float) -> String:
	return ("%.1f" % v).replace(".", ",")


func _sci(v: float) -> String:
	if v <= 0.0:
		return "0"
	var exp := int(floor(log(v) / log(10.0)))
	var mant := v / pow(10.0, exp)
	return "%.2f×10^%d" % [mant, exp]


func _update_star() -> void:
	var m := _mass_sl.value
	var t := _temp_sl.value
	var info := Star.classify(m)
	var state := String(info["state"])
	var color := "#8fd0ff"
	if state == "estrela_neutrons":
		color = "#ffd27f"
	elif state == "buraco_negro":
		color = "#ff8080"
	var qgp := Star.is_qgp_temperature(t)
	var lines := ""
	lines += "[color=%s][b]%s[/b][/color]\n" % [color, String(info["name"])]
	lines += "[i]Sustentada por: %s[/i]\n\n" % String(info["supported_by"])
	lines += "Massa = %.2f M☉\n" % m
	lines += "Raio ≈ [b]%.1f km[/b] (%.4f R☉)\n" % [
		float(info["radius_km"]), float(info["radius_km"]) / Star.r_sun_km()]
	lines += "Densidade ≈ %s kg/m³\n" % _sci(float(info["density_kg_m3"]))
	lines += "Raio de Schwarzschild r_s = %.2f km\n" % float(info["schwarzschild_km"])
	if state == "buraco_negro":
		lines += "Horizonte de eventos: [b]%.1f km[/b]\n" % float(info["radius_km"])
		lines += "Temperatura de Hawking ≈ %s K\n" % _sci(Star.hawking_temperature_k(m))
	else:
		lines += "T. de Hawking: %s K\n" % _sci(Star.hawking_temperature_k(m))
	var qgp_txt := "SIM — hádrons dissolvidos em quarks e glúons" if qgp else "não (matéria hadrônica)"
	lines += "\nTemperatura = %s K (%s MeV)\n" % [_sci(t), _fmt1(t / Star.energy_to_temperature_k(1.0))]
	lines += "QGP (>2×10¹² K / 155 MeV): [b]%s[/b]\n\n" % ("SIM" if qgp else "não")
	lines += "[b]Limiares[/b]\n"
	lines += "  Chandrasekhar (anã branca): %.2f M☉\n" % Star.chandrasekhar_msun()
	lines += "  TOV (estrela de nêutrons): %.1f M☉\n" % Star.tov_msun()
	lines += "[i]%s[/i]" % String(info["description"])
	_star_lbl.text = lines


# --------------------------------------------------------------- forja estelar

func _build_fusion(parent: Node) -> void:
	var c := VBoxContainer.new()
	c.add_theme_constant_override("separation", 8)
	c.custom_minimum_size = Vector2(430, 0)
	parent.add_child(c)
	c.add_child(_title("FORJA ESTELAR (NUCLEOSSÍNTESE)"))
	_fusion_lbl = _rich(Vector2(420, 0))
	c.add_child(_fusion_lbl)


func _update_fusion() -> void:
	var t := ""
	t += "[b]Cadeia próton-próton[/b]\n  %s\n  Q = [b]%.2f MeV[/b]\n\n" % [
		Nucleosynthesis.pp_chain_equation(),
		Nucleosynthesis.pp_chain_q_mev()]
	t += "[b]Triplo-alfa[/b]\n  3 He-4 → C-12 · Q = %.2f MeV\n" % [
		Nucleosynthesis.triple_alpha_q_mev()]
	t += "  Estado de Hoyle: %.2f MeV acima do fundamental\n\n" % [
		Nucleosynthesis.hoyle_state_mev()]
	t += "[b]Escada de fusão (até o ferro)[/b]\n"
	for step in Nucleosynthesis.fusion_ladder():
		var eq := String(step.get("equation", step.get("name", "")))
		var q := float(step.get("q_mev", 0.0))
		if eq == "":
			continue
		t += "  → %s" % eq
		if q > 0.0:
			t += "  [%.2f MeV]" % q
		t += "\n"
	t += "\n  Máximo da energia de ligação: [b]%s[/b]\n" % [
		Nucleosynthesis.max_binding_element()]
	t += "  B/A = %.2f MeV/núcleon — fim da forja (fusão além disso consome energia)\n\n" % [
		Nucleosynthesis.max_binding_per_a_mev()]
	t += "[b]Fissão nuclear[/b]\n  %s\n  Q ≈ [b]%.0f MeV[/b] por fissão\n\n" % [
		Nucleosynthesis.fission_equation(), Nucleosynthesis.fission_q_mev()]
	var sp := Nucleosynthesis.process("s_process")
	var rp := Nucleosynthesis.process("r_process")
	t += "[b]Processos de captura de nêutrons[/b]\n"
	t += "  s (lento, %s): %s\n" % [
		String(sp.get("site", "")), String(sp.get("description", ""))]
	t += "  r (rápido, %s): %s\n" % [
		String(rp.get("site", "")), String(rp.get("description", ""))]
	_fusion_lbl.text = t


# --------------------------------------------------------------- colisor

func _build_collider(parent: Node) -> void:
	var c := VBoxContainer.new()
	c.add_theme_constant_override("separation", 8)
	c.custom_minimum_size = Vector2(380, 0)
	parent.add_child(c)
	c.add_child(_title("COLISOR DE PARTÍCULAS"))
	c.add_child(_small("Momento transverso p (GeV/c):"))
	_p_sl = _slider(0.1, 100.0, 0.1, 5.0)
	_p_sl.value_changed.connect(func(_v): _update_collider())
	c.add_child(_p_sl)
	c.add_child(_small("Campo magnético B (T):"))
	_b_sl = _slider(0.5, 8.0, 0.1, 2.0)
	_b_sl.value_changed.connect(func(_v): _update_collider())
	c.add_child(_b_sl)
	_collider_lbl = _rich(Vector2(370, 0))
	c.add_child(_collider_lbl)


func _update_collider() -> void:
	var p := _p_sl.value
	var b := _b_sl.value
	var r1 := Collider.radius_of_curvature_m(p, 1.0, b)
	var r2 := Collider.radius_of_curvature_m(p, 2.0, b)
	var t := ""
	t += "r = p / (0,2998 · z · B)\n\n"
	t += "p = %.1f GeV/c · B = %.1f T\n" % [p, b]
	t += "  z = 1 (e): r = [b]%.2f m[/b]\n" % r1
	t += "  z = 2 (2e): r = [b]%.2f m[/b] (dobra a curvatura)\n\n" % r2
	t += "[b]Massa invariante (ressonâncias)[/b]\n"
	var m1 := Collider.invariant_mass_mev([
		{"e_mev": 900.0, "px": 700.0, "py": 0.0, "pz": 0.0},
		{"e_mev": 900.0, "px": -700.0, "py": 0.0, "pz": 0.0},
	])
	t += "  2 fótons de 900 MeV contrários:\n    m_inv = %.0f MeV/c²\n" % m1
	var m2 := Collider.invariant_mass_two_body_mev(500.0, 400.0, 500.0, 400.0, PI)
	t += "  Par e⁺e⁻ back-to-back (E = 500 MeV):\n    m_inv = %.0f MeV/c²\n\n" % m2
	t += "[b]Energia de centro de massa[/b]\n"
	t += "  Feixes simétricos (LHC-style):\n"
	t += "    2 × 6500 GeV → √s = %.0f GeV\n" % [
		Collider.com_energy_symmetric_gev(6500.0)]
	t += "  Alvo fixo (p + p, E = 30 GeV):\n"
	t += "    √s = %.1f GeV\n" % [
		Collider.com_energy_fixed_target_gev(30.0, 0.938)]
	_collider_lbl.text = t


# --------------------------------------------------------------- overlay

func open() -> void:
	visible = true


func _close() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close()
		get_viewport().set_input_as_handled()
