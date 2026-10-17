extends Control
## FASE 7 — Overlay "Realismo Avançado". Duas colunas:
##  1) Estrutura fina (Sommerfeld) e níveis de Dirac do hidrogenoide;
##  2) Evolução temporal da função de onda (Crank–Nicolson) com painel de
##     observáveis. Fecha com Esc.

const FineStructure = preload("res://scripts/fine_structure.gd")
const Dirac = preload("res://scripts/dirac.gd")
const Wavepacket = preload("res://scripts/wavepacket.gd")
const WavepacketView = preload("res://scripts/wavepacket_view.gd")

const DT := 0.01
const STEPS_PER_FRAME := 6

var _z_spin: SpinBox
var _fs_lbl: RichTextLabel

var _wp: RefCounted = null
var _plot: Control
var _pot_opt: OptionButton
var _k_sl: HSlider
var _stats_lbl: RichTextLabel
var _play_btn: Button
var _playing := false
var _time := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_reset_wp()


func _style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.08, 0.98)
	sb.border_color = Color(0.40, 0.70, 0.85, 0.8)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(18)
	return sb


func _title(text: String, sz: int = 16) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", Color(0.62, 0.88, 1.0))
	return l


func _rich(min_size := Vector2(0, 0)) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.add_theme_font_size_override("normal_font_size", 12)
	r.add_theme_font_size_override("bold_font_size", 12)
	r.custom_minimum_size = min_size
	return r


func _sci(v: float) -> String:
	if v == 0.0:
		return "0"
	var e := int(floor(log(absf(v)) / log(10.0)))
	return "%.4f×10^%d" % [v / pow(10.0, e), e]


func _small(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color(0.8, 0.82, 0.9))
	return l


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
	head.add_child(_title("REALISMO AVANÇADO — FASE 7", 18))
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

	_build_fine(cols)
	_build_wave(cols)
	_update_fine()


# ----------------------------------------------------------- estrutura fina

func _build_fine(parent: Node) -> void:
	var c := VBoxContainer.new()
	c.add_theme_constant_override("separation", 8)
	c.custom_minimum_size = Vector2(430, 0)
	parent.add_child(c)
	c.add_child(_title("ESTRUTURA FINA & DIRAC"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(_small("Carga nuclear Z:"))
	_z_spin = SpinBox.new()
	_z_spin.min_value = 1
	_z_spin.max_value = 20
	_z_spin.value = 1
	_z_spin.custom_minimum_size = Vector2(90, 0)
	_z_spin.value_changed.connect(func(_v): _update_fine())
	row.add_child(_z_spin)
	c.add_child(row)
	_fs_lbl = _rich(Vector2(420, 0))
	c.add_child(_fs_lbl)


func _update_fine() -> void:
	var z := _z_spin.value
	var a := FineStructure.fine_structure_constant()
	var t := ""
	t += "α = %.6f · 1/α = %.3f\n\n" % [a, FineStructure.inv_fine_structure_constant()]
	t += "[b]Níveis do hidrogenoide (eV)[/b]\n"
	t += "  n    Bohr          Sommerfeld(j=½)  Dirac(j=½)\n"
	for n in [1, 2, 3]:
		var g := FineStructure.gross_energy_ev(z, n)
		var s := FineStructure.corrected_energy_ev(z, n, 0.5)
		var d := Dirac.dirac_energy_ev(z, n, 0.5)
		t += "  %d  %.5f    %.8f    %.8f\n" % [n, g, s, d]
	t += "\n[b]Desdobramentos[/b]\n"
	if z > 1.0:
		t += "  Δ(2p₃/₂−2p₁/₂) = %s eV (Z⁴: %.0f× o H)\n" % [
			_sci(FineStructure.fine_splitting_ev(z, 2)), pow(z, 4.0)]
	else:
		t += "  Δ(2p₃/₂−2p₁/₂) = %s eV\n" % _sci(FineStructure.hydrogen_2p_splitting_ev())
		t += "  estrutura fina do Hα ≈ %.3f Å\n" % FineStructure.halpha_fine_width_angstrom()
	t += "\n[b]Lamb (QED, medido)[/b]\n"
	t += "  ΔE(2s₁/₂−2p₁/₂) = %s eV (~%.0f%% da estrutura fina)\n" % [
		_sci(FineStructure.lamb_shift_ev()), 100.0 * FineStructure.lamb_to_fine_ratio()]
	t += "\n[i]Dirac ≡ Sommerfeld no baixo Z (diferença < 10⁻⁶ eV). O Lamb fura a "
	t += "degenerescência de Dirac e é efeito de QED (não calculado aqui).[/i]"
	_fs_lbl.text = t


# ----------------------------------------------------------- função de onda

func _build_wave(parent: Node) -> void:
	var c := VBoxContainer.new()
	c.add_theme_constant_override("separation", 8)
	c.custom_minimum_size = Vector2(440, 0)
	parent.add_child(c)
	c.add_child(_title("EVOLUÇÃO TEMPORAL (Crank–Nicolson)"))
	_plot = WavepacketView.new()
	_plot.custom_minimum_size = Vector2(430, 190)
	c.add_child(_plot)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_play_btn = Button.new()
	_play_btn.text = "EVOLUIR"
	_play_btn.pressed.connect(_on_toggle_play)
	row.add_child(_play_btn)
	var stepb := Button.new()
	stepb.text = "PASSO"
	stepb.pressed.connect(_on_step)
	row.add_child(stepb)
	var reset := Button.new()
	reset.text = "REINICIAR"
	reset.pressed.connect(_reset_wp)
	row.add_child(reset)
	c.add_child(row)
	c.add_child(_small("Potencial:"))
	_pot_opt = OptionButton.new()
	_pot_opt.add_item("Partícula livre")
	_pot_opt.add_item("Poço infinito (auto-estado)")
	_pot_opt.add_item("Oscilador harmônico")
	_pot_opt.item_selected.connect(func(_i): _reset_wp())
	c.add_child(_pot_opt)
	c.add_child(_small("Momento inicial k₀:"))
	_k_sl = HSlider.new()
	_k_sl.min_value = 0.0
	_k_sl.max_value = 1.5
	_k_sl.step = 0.05
	_k_sl.value = 0.5
	_k_sl.custom_minimum_size = Vector2(420, 0)
	_k_sl.value_changed.connect(func(_v): _reset_wp())
	c.add_child(_k_sl)
	_stats_lbl = _rich(Vector2(430, 0))
	c.add_child(_stats_lbl)


func _reset_wp() -> void:
	_playing = false
	if _play_btn != null:
		_play_btn.text = "EVOLUIR"
	_time = 0.0
	var wp := Wavepacket.new()
	wp.configure(360, 40.0, 1.0, 1.0)
	var which := 0
	if _pot_opt != null:
		which = _pot_opt.selected
	match which:
		1:
			wp.set_infinite_well()
			wp.init_sine_state(1)
		2:
			wp.set_harmonic(0.05, 4.0)
			wp.init_gaussian(12.0, 2.0, 0.0)
		_:
			wp.set_free()
			wp.init_gaussian(10.0, 2.0, _k_sl.value if _k_sl != null else 0.5)
	_wp = wp
	_plot.wp = wp
	_plot.refresh()
	_update_stats()


func _on_toggle_play() -> void:
	_playing = not _playing
	_play_btn.text = "PAUSAR" if _playing else "EVOLUIR"


func _on_step() -> void:
	if _wp == null:
		return
	_wp.evolve(STEPS_PER_FRAME, DT)
	_time += STEPS_PER_FRAME * DT
	_plot.refresh()
	_update_stats()


func _update_stats() -> void:
	if _wp == null:
		return
	_stats_lbl.text = (
		"t = %.2f · norma = %.6f\n" +
		"⟨x⟩ = %.3f · largura = %.3f\n" +
		"⟨E⟩ = %.4f\n" +
		"[i]Crank–Nicolson é unitário: a norma se conserva ao longo do tempo. " +
		"No análogo 3D em GPU, a mesma equação é resolvida em paralelo.[/i]"
	) % [_time, _wp.norm(), _wp.expect_x(), _wp.width(), _wp.energy_expectation()]


func _process(_delta: float) -> void:
	if visible and _playing and _wp != null:
		_wp.evolve(STEPS_PER_FRAME, DT)
		_time += STEPS_PER_FRAME * DT
		_plot.refresh()
		_update_stats()


# ----------------------------------------------------------- overlay

func open() -> void:
	visible = true
	if _wp == null:
		_reset_wp()


func _close() -> void:
	visible = false
	_playing = false
	if _play_btn != null:
		_play_btn.text = "EVOLUIR"


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close()
		get_viewport().set_input_as_handled()
