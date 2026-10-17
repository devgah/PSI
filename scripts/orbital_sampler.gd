extends RefCounted
## Amostragem Monte Carlo de |psi_{n,l,m}|^2 -> nuvem de pontos.
## Regra de Born: cada ponto é uma observação possível do elétron.

const OrbitalMath = preload("res://scripts/orbital_math.gd")


## Retorna {"pos": PackedVector3Array, "neg": PackedVector3Array} separando
## as regiões onde psi > 0 e psi < 0 (fase -> cor no render).
## radius_scale permite o "re-espalhamento" visual pós-medição (Heisenberg).
static func sample_orbital(n: int, l: int, m: int, count: int, rng: RandomNumberGenerator,
		radius_scale: float = 1.0) -> Dictionary:
	var out := {"pos": PackedVector3Array(), "neg": PackedVector3Array()}
	if count <= 0 or n < 1:
		return out

	# --- Raio por transformada inversa da CDF de P(r) = r^2 |R|^2 ---
	var r_max := 4.0 * float(n * n) + 12.0
	var bins := 1024
	var dr := r_max / float(bins)
	var cdf := PackedFloat32Array()
	cdf.resize(bins + 1)
	cdf[0] = 0.0
	var acc := 0.0
	for i in range(1, bins + 1):
		var r := (float(i) - 0.5) * dr
		acc += OrbitalMath.radial_probability(n, l, r) * dr
		cdf[i] = acc
	if acc <= 0.0:
		return out
	for i in range(bins + 1):
		cdf[i] /= acc

	# --- Y_max^2 para rejeição angular ---
	var ymax2 := _y2_max(l, m)
	if ymax2 <= 0.0:
		return out

	var pos: PackedVector3Array = out["pos"]
	var neg: PackedVector3Array = out["neg"]

	var guard := 0
	var made := 0
	while made < count and guard < count * 400:
		guard += 1
		# amostra radial pela CDF
		var u := rng.randf()
		var lo := 0
		var hi := bins
		while lo < hi:
			var mid := (lo + hi) >> 1
			if cdf[mid] < u:
				lo = mid + 1
			else:
				hi = mid
		var idx: int = maxi(1, lo)
		var r := (float(idx - 1) + rng.randf()) * dr * radius_scale
		# direção uniforme na esfera + rejeição por |Y|^2
		var cz := rng.randf_range(-1.0, 1.0)
		var phi := rng.randf() * TAU
		var y := OrbitalMath.real_sh(l, m, cz, phi)
		if rng.randf() * ymax2 > y * y:
			continue
		var st := sqrt(maxf(0.0, 1.0 - cz * cz))
		var p := Vector3(st * cos(phi), st * sin(phi), cz) * r
		# fase = sinal(R) * sinal(Y)
		var rv := OrbitalMath.radial(n, l, r / maxf(radius_scale, 0.0001))
		if rv * y >= 0.0:
			pos.append(p)
		else:
			neg.append(p)
		made += 1

	out["pos"] = pos
	out["neg"] = neg
	return out


## Amostra um único ponto (usado para o colapso da medição).
static func sample_one(n: int, l: int, m: int, rng: RandomNumberGenerator) -> Vector3:
	var d := sample_orbital(n, l, m, 1, rng)
	var pos: PackedVector3Array = d["pos"]
	var neg: PackedVector3Array = d["neg"]
	if pos.size() > 0:
		return pos[0]
	if neg.size() > 0:
		return neg[0]
	return Vector3.ZERO


## máximo de Y_lm^2 varrendo cos(theta) (phi no máximo de cosseno/seno).
static func _y2_max(l: int, m: int) -> float:
	var am: int = absi(m)
	var best := 0.0
	for i in range(0, 721):
		var ct := -1.0 + 2.0 * float(i) / 720.0
		var p := OrbitalMath.legendre(l, am, ct)
		var ang_peak := 1.0
		if am > 0:
			ang_peak = 1.0  # cos/seno varia em [-1,1], pico = 1
		var y := p * ang_peak
		var v := y * y
		if v > best:
			best = v
	# norma do harmônico
	var norm: float
	if m == 0:
		norm = (2.0 * l + 1.0) / (4.0 * PI)
	else:
		norm = 2.0 * (2.0 * l + 1.0) / (4.0 * PI) \
			* OrbitalMath.factorial(l - am) / OrbitalMath.factorial(l + am)
	return maxf(best * norm, 1.0e-9)
