extends RefCounted
## FASE 5 — Confinamento e "quebra de corda" (string breaking).
## Os quarks de valência estão ligados por tubos de fluxo de glúons com tensão
## aproximadamente constante κ ≈ 1 GeV/fm. Ao afastar um quark, a energia cresce
## linearmente, V(r) = κ·r. Quando V(r) atinge o limiar de criação de um par
## quark-antiquark (≈ 2·m_q^constituinte ≈ 0,6 GeV), o vácuo produz um par q q̄:
## a corda se rompe e formam-se DOIS hádrons SEM COR (brancos). Nunca se observa
## um quark isolado (confinamento).

const Hadron = preload("res://scripts/hadron.gd")
const ParticleData = preload("res://scripts/particle_data.gd")

const STRING_TENSION_GEV_FM := 1.0        # κ ≈ 1 GeV/fm
const CONSTITUENT_MASS_MEV := 300.0       # massa constituinte efetiva
const PAIR_THRESHOLD_MEV := 2.0 * CONSTITUENT_MASS_MEV  # 600 MeV


## Energia armazenada na corda a uma separação r (fm), em MeV.
static func pull_energy_mev(distance_fm: float) -> float:
	return STRING_TENSION_GEV_FM * distance_fm * 1000.0


## Distância (fm) em que a corda rompe.
static func breaking_distance_fm(thresh_mev := PAIR_THRESHOLD_MEV) -> float:
	return thresh_mev / (STRING_TENSION_GEV_FM * 1000.0)


## A corda ainda está intacta (quark confinado) nessa separação?
static func confined_at(distance_fm: float) -> bool:
	return pull_energy_mev(distance_fm) < PAIR_THRESHOLD_MEV


## Quebra a corda a partir de um bárion: afasta-se o quark de índice
## `pulled_index`; o vácuo cria um par do sabor `new_flavor` (leve, ex.: d d̄).
## Retorna os dois hádrons resultantes (um méson e um bárion).
static func break_baryon(content: Array, pulled_index: int, new_flavor := "d") -> Dictionary:
	var n := content.size()
	if pulled_index < 0 or pulled_index >= n:
		return {"ok": false, "reason": "índice inválido"}
	var pulled := String(content[pulled_index])
	var rest: Array = []
	for i in range(n):
		if i != pulled_index:
			rest.append(String(content[i]))
	var meson_tokens := [pulled, new_flavor + "_bar"]
	var baryon_tokens := rest.duplicate()
	baryon_tokens.append(new_flavor)
	var meson := Hadron.build(meson_tokens)
	var baryon := Hadron.build(baryon_tokens)
	return {
		"ok": true,
		"tension_gev_fm": STRING_TENSION_GEV_FM,
		"threshold_mev": PAIR_THRESHOLD_MEV,
		"breaking_distance_fm": breaking_distance_fm(),
		"pair": [new_flavor, new_flavor + "_bar"],
		"meson": meson,
		"baryon": baryon,
	}


## Simula o processo completo a partir de um núcleon ("proton"/"neutron").
static func split_nucleon(nucleon_id: String, pulled_index: int, new_flavor := "d") -> Dictionary:
	var p := ParticleData.get_particle(nucleon_id)
	if p.is_empty():
		return {"ok": false, "reason": "núcleon desconhecido"}
	return break_baryon(p.get("content", []), pulled_index, new_flavor)


## Aniquilação partícula-antipartícula: e⁻ + e⁺ → 2γ (511 keV por fóton).
static func annihilation_energy_mev(id_a: String, id_b: String) -> float:
	return ParticleData.mass_mev(id_a) + ParticleData.mass_mev(id_b)
