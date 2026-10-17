extends RefCounted
## FASE 4 — Eletronegatividade de Pauling e classificação de ligações.
## Dados externos (data/en_pauling.json). A classificação por ΔEN segue os
## limiares usuais: < 0,4 covalente apolar; 0,4–1,7 covalente polar; ≳ 1,7 iônica.

const DATA_PATH := "res://data/en_pauling.json"

const ElementData = preload("res://scripts/element_data.gd")

const THRESHOLD_APOLAR := 0.4
const THRESHOLD_IONIC := 1.7

static var _cache: Dictionary = {}


static func _load() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	if f == null:
		push_error("en_pauling.json não encontrado: %s" % DATA_PATH)
		_cache = {"meta": {}, "values": {}}
		return _cache
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed == null:
		push_error("JSON inválido em en_pauling.json")
		_cache = {"meta": {}, "values": {}}
		return _cache
	_cache = parsed
	return _cache


static func meta() -> Dictionary:
	return _load().get("meta", {})


## Eletronegatividade de Pauling por número atômico; NAN se não definida.
static func en_of(z: int) -> float:
	var v = (_load().get("values", {}) as Dictionary).get(str(z), null)
	return float(v) if v != null else NAN


static func en_of_symbol(sym: String) -> float:
	return en_of(ElementData.z_of_symbol(sym))


static func has_en(z: int) -> bool:
	return not is_nan(en_of(z))


## Diferença |χ_A − χ_B|; NAN se algum valor faltar.
static func delta_en(za: int, zb: int) -> float:
	var a := en_of(za)
	var b := en_of(zb)
	if is_nan(a) or is_nan(b):
		return NAN
	return absf(a - b)


## Classificação do tipo de ligação pela diferença de eletronegatividade.
static func bond_class(za: int, zb: int) -> String:
	var d := delta_en(za, zb)
	if is_nan(d):
		return "indefinida"
	if d < THRESHOLD_APOLAR:
		return "covalente apolar"
	if d < THRESHOLD_IONIC:
		return "covalente polar"
	return "iônica"


## Caráter iônico aproximado (Pauling): 1 − exp(−ΔEN²/4), em [0,1].
static func ionic_character(za: int, zb: int) -> float:
	var d := delta_en(za, zb)
	if is_nan(d):
		return NAN
	return 1.0 - exp(-d * d / 4.0)


## Categorias (data/elements.json) tratadas como metais.
const METAL_CATEGORIES := [
	"metal alcalino", "alcalino-terroso", "metal de transição", "pós-transição",
]


static func is_metal(z: int) -> bool:
	return METAL_CATEGORIES.has(ElementData.category(z))


## Classificação estendida: metálica (metal–metal) ou pelos limiares de ΔEN.
static func bond_class_extended(za: int, zb: int) -> String:
	if is_metal(za) and is_metal(zb):
		return "metálica"
	return bond_class(za, zb)
