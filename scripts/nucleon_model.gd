extends RefCounted
## FASE 5 — Modelo do núcleon (próton/nêutron) para visualização da QCD.
## Quarks de valência (uud / udd) com carga de cor atribuída (r, g, b), ligados
## por tubos de fluxo de glúons, imersos num MAR de pares quark-antiquark
## virtuais. Como os quarks de valência somam apenas ~9 MeV dos ~938 MeV do
## próton, o restante (~99%) está na energia dos glúons e do mar.

const ParticleData = preload("res://scripts/particle_data.gd")

const COLORS := ["r", "g", "b"]


## Quarks de valência do núcleon, com cor de carga e massa.
static func valence(nucleon_id: String) -> Array:
	var p := ParticleData.get_particle(nucleon_id)
	var content: Array = p.get("content", [])
	var out: Array = []
	for i in range(content.size()):
		var token := String(content[i])
		var base := token
		if base.ends_with("_bar"):
			base = base.substr(0, base.length() - 4)
		out.append({
			"flavor": base,
			"color": COLORS[i % 3],
			"charge_e3": ParticleData.charge_e3(token),
			"mass_mev": ParticleData.mass_mev(token),
		})
	return out


## Soma das massas dos quarks de valência (ex.: próton ≈ 9 MeV).
static func valence_mass_mev(nucleon_id: String) -> float:
	var s := 0.0
	for q in valence(nucleon_id):
		s += float(q["mass_mev"])
	return s


## Energia atribuída aos glúons/mar (~99% da massa do núcleon).
static func gluon_energy_mev(nucleon_id: String) -> float:
	return maxf(ParticleData.mass_mev(nucleon_id) - valence_mass_mev(nucleon_id), 0.0)


## Fração da massa vinda dos glúons/mar.
static func gluon_fraction(nucleon_id: String) -> float:
	var m := ParticleData.mass_mev(nucleon_id)
	if m <= 0.0:
		return 0.0
	return gluon_energy_mev(nucleon_id) / m


## Gera pares quark-antiquark virtuais do mar (semente reprodutível).
static func sea_pairs(n: int, seed_value: int, light := true) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var flavors := ["u", "d", "s"] if light else ["u", "d", "s", "c"]
	var out: Array = []
	for i in range(n):
		var f: String = flavors[rng.randi() % flavors.size()]
		out.append({
			"flavor": f,
			"anti": f + "_bar",
			"life_fm": rng.randf_range(0.05, 0.30),
			"phase": rng.randf() * TAU,
			"radius": rng.randf_range(0.15, 1.5),
		})
	return out
