extends Control
## FASE 7 — Visualizador da função de onda 1D (evolução temporal). Desenha
## Re(ψ) em torno da linha média e a densidade |ψ|² a partir do topo.
## Apenas renderização; a física fica em wavepacket.gd.

var wp: RefCounted = null
var show_real := true
var show_density := true


func _ready() -> void:
	custom_minimum_size = Vector2(420, 240)


func _scan() -> Dictionary:
	var min_re := 0.0
	var max_re := 0.0
	var max_dens := 0.0
	for i in range(wp.n):
		var r: float = wp.re[i]
		var im: float = wp.im[i]
		var dens: float = r * r + im * im
		min_re = minf(min_re, r)
		max_re = maxf(max_re, r)
		max_dens = maxf(max_dens, dens)
	return {"min_re": min_re, "max_re": max_re, "max_dens": max_dens}


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.06, 0.9), true)
	if wp == null or wp.n < 2:
		return
	var s := _scan()
	var amp := maxf(maxf(absf(float(s["min_re"])), float(s["max_re"])), 1e-6)
	var dmax := maxf(float(s["max_dens"]), 1e-6)
	var scale_r := (size.y * 0.40) / amp
	var scale_d := (size.y * 0.40) / dmax
	var prev_r := Vector2.ZERO
	var prev_d := Vector2.ZERO
	var first := true
	for i in range(wp.n):
		var px: float = float(i) / float(wp.n - 1) * size.x
		var r: float = wp.re[i]
		var im: float = wp.im[i]
		var dens: float = r * r + im * im
		var pr := Vector2(px, size.y * 0.5 - r * scale_r)
		var pd := Vector2(px, size.y - 6.0 - dens * scale_d)
		if not first:
			if show_real:
				draw_line(prev_r, pr, Color(0.45, 0.75, 1.0, 0.9), 1.5)
			if show_density:
				draw_line(prev_d, pd, Color(1.0, 0.6, 0.3, 0.9), 1.5)
		prev_r = pr
		prev_d = pd
		first = false
	var xm: float = wp.expect_x() / wp.length * size.x
	draw_line(Vector2(xm, 0.0), Vector2(xm, size.y), Color(1.0, 1.0, 1.0, 0.25), 1.0)


func refresh() -> void:
	queue_redraw()
