extends Control
## FASE 8 — Overlay "Campos & Leis". Três colunas:
##  1) Efeito Zeeman (campo magnético B, fator de Landé, desdobramento);
##  2) Efeito Stark (campo elétrico E, linear para H e quadrático);
##  3) Sandbox de leis (escalas de α, mₑ e força forte → universo resultante).
## Fecha com Esc.

const Fields = preload("res://scripts/fields.gd")
const LawsSandbox = preload("res://scripts/laws_sandbox.gd")

var _b_sl: HSlider
var _zeeman_lbl: RichTextLabel

var _e_sl: HSlider
var _n_opt: OptionButton
var _elem_opt: OptionButton
var _stark_lbl: RichTextLabel

var _alpha_sl: HSlider
var _me_sl: HSlider
var _strong_sl: HSlider
var _sandbox_lbl: RichTextLabel


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.045, 0.05, 0.075, 0.985)
	sb.border_color = Color(0.65, 0.55, 0.30, 0.85)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(18)
	return sb


func _title(text: String, sz: int = 16) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", Color(0.98, 0.86, 0.55))
	return l


func _rich(min_size := Vector2(0, 0)) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.add_theme_font_size_override("normal_font_size", 12)
	r.add_theme_font_size_override("bold_font_size", 12)
	r.custom_minimum_size = min_size
	return r


func _small(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color(0.8, 0.82, 0.9))
	return l


func _sci(v: float) -> String:
	if v == 0.0:
		return "0"
	var e := int(floor(log(absf(v)) / log(10.0)))
	return "%.4f×10^%d" % [v / pow(10.0, e), e]


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.02, 0.76)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style())
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT,
		Control.PRESET_MODE_MINSIZE, 22)
	add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	panel.add_child(root)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	head.add_child(_title("CAMPOS & LEIS — FASE 8", 18))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	var close := Button.new()
	close.text = "FECHAR (Esc)"
	close.pressed.connect(_close)
	head.add_child(close)
	root.add_child(head)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 20)
	root.add_child(cols)

	_build_zeeman(cols)
	_build_stark(cols)
	_build_sandbox(cols)

	_update_zeeman()
	_update_stark()
	_update_sandbox()


# --------------------------------------------------------------- Zeeman

func _build_zeeman(parent: Node) -> void:
	var c := VBoxContainer.new()
	c.add_theme_constant_override("separation", 8)
	c.custom_minimum_size = Vector2(360, 0)
	parent.add_child(c)
	c.add_child(_title("EFEITO ZEEMAN (magnético)"))
	c.add_child(_small("Campo magnético B (tesla):"))
	_b_sl = HSlider.new()
	_b_sl.min_value = 0.0
	_b_sl.max_value = 10.0
	_b_sl.step = 0.1
	_b_sl.value = 2.0
	_b_sl.custom_minimum_size = Vector2(340, 0)
	_b_sl.value_changed.connect(func(_v): _update_zeeman())
	c.add_child(_b_sl)
	_zeeman_lbl = _rich(Vector2(355, 0))
	c.add_child(_zeeman_lbl)


func _update_zeeman() -> void:
	var b := _b_sl.value
	var mu := Fields.bohr_magneton_ev_t()
	var t := ""
	t += "μ_B = %s eV/T\n\n" % _sci(mu)
	t += "[b]Zeeman normal[/b] (spin ignorado)\n"
	t += "  ΔE(Δm=1) = μ_B·B = %s eV\n" % _sci(mu * b)
	t += "  linhas em m = −1, 0, +1 (tripleto)\n\n"
	t += "[b]Zeeman anômalo[/b] — fator de Landé g_J\n"
	var cases := [
		{"s": "2S₁/₂ (L=0,S=½,J=½)", "l": 0.0, "s_": 0.5, "j": 0.5},
		{"s": "2P₁/₂ (L=1,S=½,J=½)", "l": 1.0, "s_": 0.5, "j": 0.5},
		{"s": "2P₃/₂ (L=1,S=½,J=3/2)", "l": 1.0, "s_": 0.5, "j": 1.5},
		{"s": "2D₅/₂ (L=2,S=½,J=5/2)", "l": 2.0, "s_": 0.5, "j": 2.5},
	]
	for cs in cases:
		var g := Fields.lande_g(float(cs["l"]), float(cs["s_"]), float(cs["j"]))
		t += "  %s\n    g_J = %.4f → ΔE(Δm=1) = %s eV\n" % [
			String(cs["s"]), g, _sci(g * mu * b)]
	# deslocamento em comprimento de onda da linha D do sódio (589,0 nm)
	var de := mu * b
	var dl := Fields.wavelength_shift_nm(589.0, de)
	t += "\n[b]Deslocamento espectral[/b] (linha de 589 nm)\n"
	t += "  Δλ = λ²ΔE/(hc) = %.4f nm\n" % dl
	t += "[i]μ_B é medido (CODATA); g_J e o padrão das linhas são modelo.[/i]"
	_zeeman_lbl.text = t


# --------------------------------------------------------------- Stark

func _build_stark(parent: Node) -> void:
	var c := VBoxContainer.new()
	c.add_theme_constant_override("separation", 8)
	c.custom_minimum_size = Vector2(360, 0)
	parent.add_child(c)
	c.add_child(_title("EFEITO STARK (elétrico)"))
	c.add_child(_small("Campo elétrico E (V/m):"))
	_e_sl = HSlider.new()
	_e_sl.min_value = 0.0
	_e_sl.max_value = 5.0e6
	_e_sl.step = 1.0e5
	_e_sl.value = 1.0e6
	_e_sl.custom_minimum_size = Vector2(340, 0)
	_e_sl.value_changed.connect(func(_v): _update_stark())
	c.add_child(_e_sl)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(_small("Nível n:"))
	_n_opt = OptionButton.new()
	_n_opt.add_item("n = 2")
	_n_opt.add_item("n = 3")
	_n_opt.add_item("n = 4")
	_n_opt.item_selected.connect(func(_i): _update_stark())
	row.add_child(_n_opt)
	row.add_child(_small("Átomo:"))
	_elem_opt = OptionButton.new()
	for s in Fields.polarizability_symbols():
		_elem_opt.add_item(String(s))
	_elem_opt.item_selected.connect(func(_i): _update_stark())
	row.add_child(_elem_opt)
	c.add_child(row)
	_stark_lbl = _rich(Vector2(355, 0))
	c.add_child(_stark_lbl)


func _update_stark() -> void:
	var e := _e_sl.value
	var n := _n_opt.selected + 2
	var t := ""
	t += "[b]Stark linear[/b] (hidrogênio, k = n₁−n₂)\n"
	t += "  ΔE = (3/2)·n·a₀·E·k\n"
	t += "  n = %d · a₀ = %.4f Å\n" % [n, Fields.bohr_radius_m() * 1.0e10]
	var step := Fields.stark_linear_ev(n, 1, e)
	t += "  ΔE(k=±1) = ±%s eV\n" % _sci(absf(step))
	t += "  ΔE(k=±%d) = ±%s eV\n\n" % [n - 1, _sci(absf(Fields.stark_linear_ev(n, n - 1, e)))]
	var sym := Fields.polarizability_symbols()
	var idx := clampi(_elem_opt.selected, 0, sym.size() - 1)
	var s := String(sym[idx])
	var q := Fields.stark_quadratic_symbol_ev(s, e)
	t += "[b]Stark quadrático[/b] (átomo %s)\n" % s
	t += "  α' = %.4f Å³\n" % Fields.polarizability_volume_ang3(s)
	t += "  ΔE = −½·4πε₀·α'·E² = %s eV\n" % _sci(q)
	t += "[i]Efeito Stark linear é modelo exato do H degenerado; o quadrático "
	t += "usa polarizabilidades de referência.[/i]"
	_stark_lbl.text = t


# --------------------------------------------------------------- sandbox

func _build_sandbox(parent: Node) -> void:
	var c := VBoxContainer.new()
	c.add_theme_constant_override("separation", 8)
	c.custom_minimum_size = Vector2(380, 0)
	parent.add_child(c)
	c.add_child(_title("SANDBOX DE LEIS"))
	c.add_child(_small("Constante de estrutura fina α (×real):"))
	_alpha_sl = _slider(0.2, 2.0, 0.05, 1.0)
	_alpha_sl.value_changed.connect(func(_v): _update_sandbox())
	c.add_child(_alpha_sl)
	c.add_child(_small("Massa do elétron mₑ (×real):"))
	_me_sl = _slider(0.2, 2.0, 0.05, 1.0)
	_me_sl.value_changed.connect(func(_v): _update_sandbox())
	c.add_child(_me_sl)
	c.add_child(_small("Força forte (×real):"))
	_strong_sl = _slider(0.5, 1.5, 0.01, 1.0)
	_strong_sl.value_changed.connect(func(_v): _update_sandbox())
	c.add_child(_strong_sl)
	_sandbox_lbl = _rich(Vector2(375, 0))
	c.add_child(_sandbox_lbl)


func _slider(mn: float, mx: float, step: float, val: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = step
	s.value = val
	s.custom_minimum_size = Vector2(340, 0)
	return s


func _update_sandbox() -> void:
	var r := LawsSandbox.evaluate(_alpha_sl.value, _me_sl.value, _strong_sl.value)
	var t := ""
	t += "Escalas: α = %.2f× · mₑ = %.2f× · forte = %.2f×\n\n" % [
		_alpha_sl.value, _me_sl.value, _strong_sl.value]
	t += "Rydberg (ionização) = [b]%.3f eV[/b] (real %.3f)\n" % [
		float(r["rydberg_ev"]), LawsSandbox.baseline_rydberg_ev()]
	t += "Raio de Bohr = [b]%.4f Å[/b] (real %.4f)\n" % [
		float(r["bohr_ang"]), LawsSandbox.baseline_bohr_ang()]
	t += "Estrutura fina = %.2f× a real (∝ α⁴)\n" % float(r["fine_relative"])
	t += "Ligação do dêuteron = %.3f MeV\n" % float(r["deuteron_mev"])
	t += "Estrelas acendem: [b]%s[/b]\n" % ("SIM" if bool(r["stars"]) else "não")
	t += "Química: %s\n\n" % String(r["chemistry"])
	t += "[b]%s[/b]\n\n" % String(r["verdict"])
	t += "[i]%s[/i]" % LawsSandbox.scenario("nota")
	_sandbox_lbl.text = t


# --------------------------------------------------------------- overlay

func open() -> void:
	visible = true


func _close() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close()
		get_viewport().set_input_as_handled()
