extends RefCounted
## Regras de Slater para blindagem eletrônica e carga nuclear efetiva (Z_eff).
## Referência: J. C. Slater, Phys. Rev. 36, 57 (1930).
##
## Grupos (na ordem de Slater): (1s)(2s,2p)(3s,3p)(3d)(4s,4p)(4d)(4f)(5s,5p)...
## Para elétron em ns/np: 0,35 por par no mesmo grupo (0,30 no 1s);
##   0,85 por elétron da camada n-1; 1,00 por elétron de n-2 ou menor.
## Para elétron em nd/nf: 0,35 no mesmo grupo; 1,00 por todos à esquerda.
## Elétrons à direita contribuem 0.
## Z_eff = Z - sigma.  Serve para estimar energias e raios de forma aproximada.

const ElectronConfig = preload("res://scripts/electron_config.gd")


## chave do grupo de Slater para (n, l): "2|sp", "3|d", "4|f"...
static func group_key(n: int, l: int) -> String:
	if l <= 1:
		return "%d|sp" % n
	return "%d|%s" % [n, "d" if l == 2 else "f"]


## ordenação dos grupos: por n e depois por tipo (sp < d < f).
static func _group_rank(n: int, l: int) -> int:
	var base := n * 10
	if l <= 1:
		return base
	if l == 2:
		return base + 1
	return base + 2


static func _letter(l: int) -> String:
	match l:
		0:
			return "s"
		1:
			return "p"
		2:
			return "d"
		3:
			return "f"
	return "?"


## Agrega occupancy_list em {label: total} — label no formato "2p".
static func _counts_from_occupancy(occ: Array) -> Dictionary:
	var counts := {}
	for e in occ:
		var label := String(e.get("label", "%d%s" % [int(e.get("n", 0)), _letter(int(e.get("l", 0)))]))
		counts[label] = int(counts.get(label, 0)) + int(e.get("count", 1))
	return counts


## sigma (blindagem) para um elétron em (n, l). O mapa `counts` já deve EXCLUIR
## o elétron de interesse (o chamador remove-o antes de contar a blindagem).
static func shielding_from_counts(counts: Dictionary, n: int, l: int) -> float:
	var target := _group_rank(n, l)
	var same_other := 0
	var sigma := 0.0
	for label in counts:
		var cn := int(String(label).substr(0, String(label).length() - 1))
		var cl := ElectronConfig._l_of(String(label))
		var cnt := int(counts[label])
		if cnt <= 0:
			continue
		var grank := _group_rank(cn, cl)
		if grank == target:
			same_other += cnt
		elif grank < target:
			if l <= 1:
				if cn == n - 1:
					sigma += 0.85 * float(cnt)
				elif cn <= n - 2:
					sigma += 1.00 * float(cnt)
			else:
				sigma += 1.00 * float(cnt)
		# grank > target (à direita) -> 0
	var per: float = 0.30 if n == 1 else 0.35
	sigma += per * float(same_other)
	return sigma


## Z_eff para o elétron ativo: remove-o da órbita de base (onde ele "nasceu")
## e aplica as regras para a órbita alvo (n, l) — funciona para estado excitado.
static func z_eff_for(z: int, n_electrons: int, ground_orbital: Dictionary,
		n: int, l: int) -> float:
	if ground_orbital.is_empty():
		return float(z)
	var counts := _counts_from_occupancy(ElectronConfig.occupancy_list(z, n_electrons))
	var glabel := "%d%s" % [int(ground_orbital["n"]), _letter(int(ground_orbital["l"]))]
	if counts.has(glabel):
		counts[glabel] = maxi(int(counts[glabel]) - 1, 0)
	return float(z) - shielding_from_counts(counts, n, l)


## Z_eff do elétron de valência do átomo neutro: escolhe a maior camada n
## (e, em empate, o grupo de maior rank — ex.: Fe -> 4s; Pd -> 4d, sem 5s).
static func z_eff_outer(z: int) -> float:
	var occ := ElectronConfig.occupancy_list(z, z)
	if occ.is_empty():
		return float(z)
	var best: Dictionary = occ[0]
	for e in occ:
		var en := int(e["n"])
		var bn := int(best["n"])
		if en > bn or (en == bn and _group_rank(en, int(e["l"])) > _group_rank(bn, int(best["l"]))):
			best = e
	return z_eff_for(z, z, best, int(best["n"]), int(best["l"]))


## Maior n ocupado (número quântico principal da camada de valência).
static func outer_n(z: int, n_electrons: int) -> int:
	var occ := ElectronConfig.occupancy_list(z, n_electrons)
	var n := 1
	for e in occ:
		n = maxi(n, int(e["n"]))
	return n
