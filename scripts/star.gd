extends RefCounted
## FASE 6 — Colapso gravitacional e matéria degenerada.
## Classifica uma amostra de matéria pela massa: Anã Branca (degenerescência
## eletrônica) → Estrela de Nêutrons (neutronização + degenerescência de
## nêutrons) → Buraco Negro (r_s = 2GM/c²). Inclui o limiar de QGP em
## temperatura/energia. Constantes lidas de data/stellar.json.

const PATH := "res://data/stellar.json"

static var _data: Dictionary = {}


static func _load() -> Dictionary:
	if not _data.is_empty():
		return _data
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		push_error("stellar.json não encontrado")
		_data = {"constants": {}, "states": {}, "qgp": {}}
		return _data
	_data = JSON.parse_string(f.get_as_text())
	if _data == null:
		_data = {"constants": {}, "states": {}, "qgp": {}}
	return _data


static func _c(key: String, fallback: float) -> float:
	var v = _load().get("constants", {}).get(key, null)
	return float(v) if v != null else fallback


# ------------------------------------------------------------------ constantes

static func G() -> float:
	return _c("G", 6.67430e-11)


static func c_light() -> float:
	return _c("c", 2.99792458e8)


static func hbar() -> float:
	return _c("hbar", 1.054571817e-34)


static func k_b() -> float:
	return _c("k_b", 1.380649e-23)


static func m_sun_kg() -> float:
	return _c("m_sun_kg", 1.98892e30)


static func r_sun_km() -> float:
	return _c("r_sun_km", 696340.0)


static func chandrasekhar_msun() -> float:
	return _c("chandrasekhar_msun", 1.44)


static func tov_msun() -> float:
	return _c("tov_msun", 2.2)


static func nuclear_density_kg_m3() -> float:
	return _c("nuclear_density_kg_m3", 2.3e17)


static func qgp_temperature_k() -> float:
	return _c("qgp_temperature_k", 2.0e12)


static func qgp_energy_mev() -> float:
	return _c("qgp_energy_mev", 155.0)


static func states() -> Dictionary:
	return _load().get("states", {})


static func state_name(key: String) -> String:
	return String(states().get(key, {}).get("name", key))


static func qgp_name() -> String:
	return String(_load().get("qgp", {}).get("name", "QGP"))


static func qgp_description() -> String:
	return String(_load().get("qgp", {}).get("description", ""))


# ------------------------------------------------------------------ raios

## Raio de Schwarzschild (km) para uma massa em massas solares.
static func schwarzschild_radius_km(mass_msun: float) -> float:
	return 2.0 * G() * mass_msun * m_sun_kg() / (c_light() * c_light()) / 1000.0


## Raio da anã branca (km): R ≈ 0,0126 R☉ · M^(−1/3) — mais massa, menor raio.
static func white_dwarf_radius_km(mass_msun: float) -> float:
	if mass_msun <= 0.0:
		return INF
	var ref := _c("wd_radius_ref_rsun", 0.0126) * r_sun_km()
	return ref * pow(mass_msun, -1.0 / 3.0)


## Raio aproximado da estrela de nêutrons (km): quase constante ~11 km.
static func neutron_star_radius_km(mass_msun: float) -> float:
	var r0 := _c("ns_radius_km", 11.0)
	if mass_msun <= 0.0:
		return r0
	return r0 * pow(mass_msun / 1.4, 0.1)


## Densidade média (kg/m³) de uma esfera de raio R (km) e massa M (M☉).
static func mean_density_kg_m3(mass_msun: float, radius_km: float) -> float:
	if radius_km <= 0.0:
		return INF
	var r_m := radius_km * 1000.0
	var volume := 4.0 / 3.0 * PI * r_m * r_m * r_m
	return mass_msun * m_sun_kg() / volume


## Temperatura de Hawking (K) de um buraco negro de massa M (M☉).
static func hawking_temperature_k(mass_msun: float) -> float:
	if mass_msun <= 0.0:
		return INF
	return hbar() * pow(c_light(), 3.0) \
		/ (8.0 * PI * G() * mass_msun * m_sun_kg() * k_b())


# ------------------------------------------------------------------ classificação

static func is_below_chandrasekhar(mass_msun: float) -> bool:
	return mass_msun < chandrasekhar_msun()


static func is_black_hole(mass_msun: float) -> bool:
	return mass_msun > tov_msun()


## Classifica o objeto e devolve raio, densidade e descrição.
static func classify(mass_msun: float) -> Dictionary:
	var state := "ana_branca"
	if is_black_hole(mass_msun):
		state = "buraco_negro"
	elif not is_below_chandrasekhar(mass_msun):
		state = "estrela_neutrons"
	var info: Dictionary = states().get(state, {})
	var radius := 0.0
	var density := 0.0
	match state:
		"ana_branca":
			radius = white_dwarf_radius_km(mass_msun)
			density = mean_density_kg_m3(mass_msun, radius)
		"estrela_neutrons":
			radius = neutron_star_radius_km(mass_msun)
			density = nuclear_density_kg_m3()
		"buraco_negro":
			radius = schwarzschild_radius_km(mass_msun)
			density = mean_density_kg_m3(mass_msun, radius)
	return {
		"state": state,
		"name": String(info.get("name", state)),
		"supported_by": String(info.get("supported_by", "")),
		"description": String(info.get("description", "")),
		"mass_msun": mass_msun,
		"radius_km": radius,
		"density_kg_m3": density,
		"schwarzschild_km": schwarzschild_radius_km(mass_msun),
	}


# ------------------------------------------------------------------ QGP

static func is_qgp_temperature(temperature_k: float) -> bool:
	return temperature_k >= qgp_temperature_k()


static func is_qgp_energy(energy_mev: float) -> bool:
	return energy_mev >= qgp_energy_mev()


## Temperatura equivalente a uma energia térmica (E = k_B T).
static func energy_to_temperature_k(energy_mev: float) -> float:
	return energy_mev * 1.0e6 / k_b() * 1.602176634e-19
