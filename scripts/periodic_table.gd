extends Control
## Overlay interativo da tabela periódica (Fase 2). Grade 18x5 (Z=1..54).
## Clique em um elemento emite element_selected(z) e fecha o overlay.

signal element_selected(z: int)

const ElementData = preload("res://scripts/element_data.gd")

const COLS := 18
const ROWS := 5

const CAT_COLORS := {
	"não-metal": Color(0.28, 0.66, 0.50),
	"gás nobre": Color(0.52, 0.42, 0.82),
	"halogênio": Color(0.85, 0.72, 0.30),
	"metal alcalino": Color(0.90, 0.48, 0.32),
	"alcalino-terroso": Color(0.88, 0.66, 0.36),
	"semimetal": Color(0.40, 0.66, 0.78),
	"metal de transição": Color(0.55, 0.57, 0.64),
	"pós-transição": Color(0.50, 0.62, 0.56),
}

var _grid: GridContainer
var _selected_z := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.02, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.10, 0.98)
	sb.border_color = Color(0.30, 0.42, 0.60, 0.8)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	var title := Label.new()
	title.text = "TABELA PERIÓDICA — escolha um elemento"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.6, 0.82, 1.0))
	head.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	var close := Button.new()
	close.text = "FECHAR  (Esc)"
	close.pressed.connect(_close)
	head.add_child(close)
	col.add_child(head)

	_grid = GridContainer.new()
	_grid.columns = COLS
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	col.add_child(_grid)

	var by := {}
	for z in ElementData.all_z():
		by[Vector2i(ElementData.period(z), ElementData.group(z))] = z
	for r in range(1, ROWS + 1):
		for c in range(1, COLS + 1):
			if by.has(Vector2i(r, c)):
				_grid.add_child(_make_cell(by[Vector2i(r, c)]))
			else:
				var gap := Control.new()
				gap.custom_minimum_size = Vector2(58, 42)
				_grid.add_child(gap)

	# legenda
	var legend := HBoxContainer.new()
	legend.add_theme_constant_override("separation", 12)
	col.add_child(legend)
	for cat in CAT_COLORS:
		legend.add_child(_legend_item(String(cat), CAT_COLORS[cat]))
	var src := Label.new()
	src.text = "IE1: NIST ASD v5.12 · Z_eff/raio: estimativa de Slater"
	src.add_theme_font_size_override("font_size", 11)
	src.add_theme_color_override("font_color", Color(0.65, 0.7, 0.8))
	col.add_child(src)


func _make_cell(z: int) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(58, 42)
	b.text = "%d\n%s" % [z, ElementData.symbol(z)]
	b.add_theme_font_size_override("font_size", 12)
	b.tooltip_text = "%s — %s (grupo %d, período %d)\nIE1 = %.3f eV" % [
		ElementData.name(z), ElementData.category(z),
		ElementData.group(z), ElementData.period(z), ElementData.ie1_ev(z)]
	var c: Color = CAT_COLORS.get(ElementData.category(z), Color(0.5, 0.5, 0.5))
	var sb := StyleBoxFlat.new()
	sb.bg_color = c.darkened(0.55)
	sb.border_color = c
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	b.add_theme_stylebox_override("normal", sb)
	var sh := sb.duplicate()
	sh.bg_color = c.darkened(0.25)
	b.add_theme_stylebox_override("hover", sh)
	if z == _selected_z:
		var sf := sb.duplicate()
		sf.border_color = Color(1, 1, 1)
		sf.set_border_width_all(3)
		b.add_theme_stylebox_override("normal", sf)
	b.pressed.connect(func(): _on_cell(z))
	return b


func _legend_item(text: String, color: Color) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	var sw := ColorRect.new()
	sw.color = color
	sw.custom_minimum_size = Vector2(14, 14)
	h.add_child(sw)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 11)
	h.add_child(l)
	return h


func set_current(z: int) -> void:
	_selected_z = z


func open(current_z: int) -> void:
	_selected_z = current_z
	for c in get_children():
		c.queue_free()
	_build()
	visible = true


func _on_cell(z: int) -> void:
	_selected_z = z
	element_selected.emit(z)
	_close()


func _close() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close()
		get_viewport().set_input_as_handled()
