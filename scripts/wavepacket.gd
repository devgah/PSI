extends RefCounted
## FASE 7 — Realismo avançado: evolução temporal da função de onda (1D) pelo
## método de Crank–Nicolson (incondicionalmente estável, unitário). Unidades
## internas ħ = m = 1 (como em todo o simulador). Dirichlet nas bordas.
## Este é o análogo CPU/honesto da "evolução 3D em GPU" — conserva a norma e
## reproduz a dispersão de um pacote de onda.

var n := 0                 # número de pontos da grade
var length := 20.0
var hbar := 1.0
var mass := 1.0
var dx := 0.0

var x: PackedFloat64Array = PackedFloat64Array()
var re: PackedFloat64Array = PackedFloat64Array()
var im: PackedFloat64Array = PackedFloat64Array()
var vpot: PackedFloat64Array = PackedFloat64Array()

var _re0: PackedFloat64Array = PackedFloat64Array()
var _im0: PackedFloat64Array = PackedFloat64Array()


func configure(points: int, length_: float, mass_: float = 1.0, hbar_: float = 1.0) -> void:
	n = points
	length = length_
	mass = mass_
	hbar = hbar_
	dx = length / float(n - 1)
	x.resize(n)
	re.resize(n)
	im.resize(n)
	vpot.resize(n)
	_re0.resize(n)
	_im0.resize(n)
	for i in range(n):
		x[i] = float(i) * dx
		re[i] = 0.0
		im[i] = 0.0
		vpot[i] = 0.0


func clear() -> void:
	for i in range(n):
		re[i] = 0.0
		im[i] = 0.0


## Ausência de potencial (partícula livre).
func set_free() -> void:
	for i in range(n):
		vpot[i] = 0.0


## Poço infinito: o próprio Dirichlet nas bordas define V = ∞ fora; V = 0 dentro.
func set_infinite_well() -> void:
	for i in range(n):
		vpot[i] = 0.0


## Oscilador harmônico V = ½·k·(x−x0)².
func set_harmonic(k: float, x0: float = 0.0) -> void:
	var mid := 0.5 * length
	for i in range(n):
		var d := x[i] - (mid + x0)
		vpot[i] = 0.5 * k * d * d


func init_gaussian(x0: float, sigma: float, k0: float) -> void:
	for i in range(n):
		var d := x[i] - x0
		var amp := exp(-(d * d) / (2.0 * sigma * sigma))
		re[i] = amp * cos(k0 * x[i])
		im[i] = amp * sin(k0 * x[i])
	normalize()
	_snapshot()


## Auto-estado do poço infinito: ψ = sin(qπx/L).
func init_sine_state(q: int) -> void:
	for i in range(n):
		var val := sin(float(q) * PI * x[i] / length)
		re[i] = val
		im[i] = 0.0
	normalize()
	_snapshot()


func _snapshot() -> void:
	for i in range(n):
		_re0[i] = re[i]
		_im0[i] = im[i]


func normalize() -> void:
	var nrm := norm()
	if nrm <= 0.0:
		return
	var s := 1.0 / sqrt(nrm)
	for i in range(n):
		re[i] *= s
		im[i] *= s


# ------------------------------------------------------------------ observáveis

func norm() -> float:
	var s := 0.0
	for i in range(n):
		s += re[i] * re[i] + im[i] * im[i]
	return s * dx


func expect_x() -> float:
	var s := 0.0
	var w := 0.0
	for i in range(n):
		var p := re[i] * re[i] + im[i] * im[i]
		s += x[i] * p
		w += p
	if w <= 0.0:
		return 0.0
	return s / w


func expect_x2() -> float:
	var s := 0.0
	var w := 0.0
	for i in range(n):
		var p := re[i] * re[i] + im[i] * im[i]
		s += x[i] * x[i] * p
		w += p
	if w <= 0.0:
		return 0.0
	return s / w


func width() -> float:
	var mx := expect_x()
	var mx2 := expect_x2()
	return sqrt(maxf(mx2 - mx * mx, 0.0))


## Auto-sobreposição |⟨ψ0|ψ⟩| — 1 se o estado só mudou por uma fase global.
func overlap_abs() -> float:
	var sr := 0.0
	var si := 0.0
	for i in range(n):
		# conj(ψ0)·ψ
		sr += _re0[i] * re[i] + _im0[i] * im[i]
		si += _re0[i] * im[i] - _im0[i] * re[i]
	return sqrt(sr * sr + si * si) * dx


## ⟨E⟩ = ∫ [ (ħ²/2m)|∂ψ/∂x|² + V|ψ|² ] dx (diferença finita à frente).
func energy_expectation() -> float:
	var kin := 0.0
	for i in range(n - 1):
		var drx := re[i + 1] - re[i]
		var dix := im[i + 1] - im[i]
		kin += (drx * drx + dix * dix) / (dx * dx)
	kin *= (hbar * hbar) / (2.0 * mass) * dx
	var pot := 0.0
	for i in range(n):
		pot += vpot[i] * (re[i] * re[i] + im[i] * im[i]) * dx
	return kin + pot


# ------------------------------------------------------------------ passo CN

## Um passo temporal de Crank–Nicolson: (1 + i H dt/2ħ)ψ' = (1 − i H dt/2ħ)ψ.
func step(dt: float) -> void:
	if n < 3:
		return
	var r := dt * 0.5 / hbar
	var c := (hbar * hbar) / (2.0 * mass * dx * dx)
	var nb := n - 2
	var ar := 0.0
	var ai := -r * c
	var ur := 0.0
	var ui := -r * c
	var cpr := PackedFloat64Array(); cpr.resize(nb)
	var cpi := PackedFloat64Array(); cpi.resize(nb)
	var dpr := PackedFloat64Array(); dpr.resize(nb)
	var dpi := PackedFloat64Array(); dpi.resize(nb)

	for k in range(nb):
		var i := k + 1
		var g := r * (2.0 * c + vpot[i])
		var br := 1.0
		var bi := g
		var sre := re[i - 1] + re[i + 1]
		var sim := im[i - 1] + im[i + 1]
		var xre := re[i]
		var xim := im[i]
		var drhs := r * c * (-sim) + (xre + g * xim)
		var dihs := r * c * (sre) + (xim - g * xre)
		if k == 0:
			var inv0 := 1.0 / (br * br + bi * bi)
			cpr[0] = (ur * br + ui * bi) * inv0
			cpi[0] = (ui * br - ur * bi) * inv0
			dpr[0] = (drhs * br + dihs * bi) * inv0
			dpi[0] = (dihs * br - drhs * bi) * inv0
		else:
			var acr := ar * cpr[k - 1] - ai * cpi[k - 1]
			var aci := ar * cpi[k - 1] + ai * cpr[k - 1]
			var denr := br - acr
			var deni := bi - aci
			var invd := 1.0 / (denr * denr + deni * deni)
			cpr[k] = (ur * denr + ui * deni) * invd
			cpi[k] = (ui * denr - ur * deni) * invd
			var adr := ar * dpr[k - 1] - ai * dpi[k - 1]
			var adi := ar * dpi[k - 1] + ai * dpr[k - 1]
			var numr := drhs - adr
			var numi := dihs - adi
			dpr[k] = (numr * denr + numi * deni) * invd
			dpi[k] = (numi * denr - numr * deni) * invd

	var xr := PackedFloat64Array(); xr.resize(nb)
	var xi := PackedFloat64Array(); xi.resize(nb)
	xr[nb - 1] = dpr[nb - 1]
	xi[nb - 1] = dpi[nb - 1]
	for k in range(nb - 2, -1, -1):
		xr[k] = dpr[k] - (cpr[k] * xr[k + 1] - cpi[k] * xi[k + 1])
		xi[k] = dpi[k] - (cpr[k] * xi[k + 1] + cpi[k] * xr[k + 1])

	for k in range(nb):
		re[k + 1] = xr[k]
		im[k + 1] = xi[k]


func evolve(steps: int, dt: float) -> void:
	for _s in range(steps):
		step(dt)
