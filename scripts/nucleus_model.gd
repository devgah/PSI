extends RefCounted
## FASE 3 — Estado de um núcleo (Z prótons, N nêutrons) e suas propriedades
## físicas: energia de ligação (dado medido e Weizsäcker), meia-vida, modos de
## decaimento, Q-valores, números mágicos e raio.

const Nuclear = preload("res://scripts/nuclear.gd")
const NuclideData = preload("res://scripts/nuclide_data.gd")
const Decay = preload("res://scripts/decay.gd")

var z: int = 0
var n: int = 0


func _init(z0: int = 0, n0: int = 0) -> void:
	z = maxi(z0, 0)
	n = maxi(n0, 0)


func a() -> int:
	return z + n


func symbol() -> String:
	if NuclideData.has_nuclide(z, a()):
		var s := NuclideData.symbol(z, a())
		if s != "" and s.length() <= 2:
			return s
	return "?"


## Excesso de massa (keV): medido se existir, senão Weizsäcker.
func mass_excess_kev() -> float:
	return Decay.effective_me_kev(z, a())


func has_measured_mass() -> bool:
	return NuclideData.has_nuclide(z, a()) and not is_nan(NuclideData.mass_excess_kev(z, a()))


## Energia de ligação total (MeV): medida quando disponível, senão Weizsäcker.
func binding_mev() -> float:
	if has_measured_mass():
		return Nuclear.binding_from_me_mev(z, a(), NuclideData.mass_excess_kev(z, a()))
	return Nuclear.binding_weizsacker_mev(a(), z)


func binding_weizsacker_mev() -> float:
	return Nuclear.binding_weizsacker_mev(a(), z)


## Energia de ligação por núcleon (MeV/A).
func binding_per_a_mev() -> float:
	if a() <= 0:
		return 0.0
	return binding_mev() / float(a())


func stable() -> bool:
	return NuclideData.is_stable(z, a())


func half_life_s() -> float:
	return NuclideData.half_life_s(z, a())


func modes() -> Array:
	return Decay.modes(z, a())


func dominant_mode() -> String:
	return Decay.dominant_mode(z, a())


func radius_fm() -> float:
	return Nuclear.radius_fm(a())


## Distância ao vale de estabilidade (em unidades de Z) para o mesmo A.
func valley_z() -> int:
	return Nuclear.z_valley(a())


func valley_distance() -> int:
	return absi(z - valley_z())


func magic_z() -> bool:
	return Nuclear.is_magic(z)


func magic_n() -> bool:
	return Nuclear.is_magic(n)


func doubly_magic() -> bool:
	return Nuclear.is_doubly_magic(z, n)


## Aplica um decaimento e atualiza o estado. Retorna o dicionário do decaimento.
func decay_once(mode: String = "") -> Dictionary:
	var m := mode
	if m == "":
		m = dominant_mode()
	if m == "":
		return {"ok": false, "note": "núcleo estável — não decai"}
	var res := Decay.apply_decay(z, a(), m)
	if res["ok"]:
		z = clampi(int(res["z"]), 0, 118)
		n = maxi(int(res["a"]) - z, 0)
	return res
