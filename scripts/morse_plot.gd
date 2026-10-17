extends Control
## FASE 4 — Gráfico 2D da curva de Morse V(r) = D_e(1 − e^{−a(r−r_e)})².
## Desenha o poço, marca r_e (mínimo) e a profundidade D_e.

const Morse = preload("res://scripts/morse.gd")

var _de := 0.0
var _re := 0.0
var _a := Morse.A_DEFAULT
var _has := false


func _ready() -> void:
	custom_minimum_size = Vector2(300, 150)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_curve(de_ev: float, re_pm: float, a_inv_pm: float) -> void:
	_de = de_ev
	_re = re_pm
	_a = a_inv_pm
	_has = de_ev > 0.0 and re_pm > 0.0
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.04, 0.07, 0.85), true)
	if not _has:
		draw_string(ThemeDB.fallback_font, Vector2(10, h * 0.5),
			"(sem curva)", HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
			Color(0.6, 0.65, 0.75))
		return
	# janela de r: de 0,4·r_e a 2,6·r_e ; janela de V: 0 .. 1,15·D_e
	var r_min := _re * 0.4
	var r_max := _re * 2.6
	var v_max := _de * 1.15
	var pad := 8.0
	var steps := 140
	var pts := PackedVector2Array()
	for i in range(steps + 1):
		var r := lerpf(r_min, r_max, float(i) / float(steps))
		var v := Morse.energy_ev(r, _de, _re, _a)
		var x := pad + (r - r_min) / (r_max - r_min) * (w - 2.0 * pad)
		var y := h - pad - clampf(v / v_max, 0.0, 1.0) * (h - 2.0 * pad)
		pts.append(Vector2(x, y))
	draw_polyline(pts, Color(0.55, 0.85, 1.0), 2.0, true)
	# nível D_e (assíntota de dissociação)
	var y_de := h - pad - (_de / v_max) * (h - 2.0 * pad)
	draw_line(Vector2(pad, y_de), Vector2(w - pad, y_de),
		Color(0.95, 0.75, 0.35, 0.7), 1.0, true)
	# marcador de r_e no fundo do poço
	var x_re := pad + (_re - r_min) / (r_max - r_min) * (w - 2.0 * pad)
	draw_line(Vector2(x_re, pad), Vector2(x_re, h - pad),
		Color(0.6, 1.0, 0.6, 0.5), 1.0, true)
	draw_string(ThemeDB.fallback_font, Vector2(x_re + 3, pad + 12),
		"r_e", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.6, 1.0, 0.6))
	draw_string(ThemeDB.fallback_font, Vector2(pad + 4, y_de - 3),
		"D_e", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.95, 0.75, 0.35))
