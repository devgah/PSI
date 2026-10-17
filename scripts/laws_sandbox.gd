extends RefCounted
## FASE 8 — Sandbox de leis da física. Altera constantes fundamentais
## (α, massa do elétron mₑ, força forte) e observa as consequências sobre
## átomos, estrutura fina e estrelas. Escalas reais, modelos qualitativos.

const PATH := "res://data/laws_sandbox.json"

const ALPHA_BASE := 0.0072973525693
const RY_BASE := 13.605693122994      # eV
const A0_BASE := 0.529177210903       # Å
const DEUTERON_BASE := 2.224          # MeV
const CRITICAL_STRONG := 0.8

static var _data: Dictionary = {}


static func _load() -> Dictionary:
	if not _data.is_empty():
		return _data
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		push_error("laws_sandbox.json não encontrado")
		_data = {"baseline": {}, "scenarios": {}}
		return _data
	_data = JSON.parse_string(f.get_as_text())
	if _data == null:
		_data = {"baseline": {}, "scenarios": {}}
	return _data


static func _base(key: String, fb: float) -> float:
	var v = _load().get("baseline", {}).get(key, null)
	return float(v) if v != null else fb


static func baseline_alpha() -> float:
	return _base("alpha", ALPHA_BASE)


static func baseline_rydberg_ev() -> float:
	return _base("rydberg_ev", RY_BASE)


static func baseline_bohr_ang() -> float:
	return _base("bohr_ang", A0_BASE)


static func deuteron_binding_mev() -> float:
	return _base("deuteron_binding_mev", DEUTERON_BASE)


static func critical_strong_scale() -> float:
	return _base("critical_strong_scale", CRITICAL_STRONG)


static func scenario(key: String) -> String:
	return String(_load().get("scenarios", {}).get(key, ""))


# ------------------------------------------------------------------ escalas

## Energia de Rydberg (eV) em função das escalas de α e mₑ: Ry ∝ α²·mₑ.
static func rydberg_ev(alpha_scale: float, me_scale: float) -> float:
	return RY_BASE * alpha_scale * alpha_scale * me_scale


## Raio de Bohr (Å) em função das escalas: a₀ ∝ 1/(α·mₑ).
static func bohr_radius_ang(alpha_scale: float, me_scale: float) -> float:
	if alpha_scale <= 0.0 or me_scale <= 0.0:
		return INF
	return A0_BASE / (alpha_scale * me_scale)


## Escala relativa do desdobramento de estrutura fina: ∝ α⁴.
static func fine_splitting_relative(alpha_scale: float) -> float:
	return pow(alpha_scale, 4.0)


## Energia de ligação do dêuteron (MeV) em função da escala da força forte.
## Abaixo da escala crítica o dêuteron se desfaz (0).
static func deuteron_binding_scaled_mev(strong_scale: float) -> float:
	var crit := critical_strong_scale()
	if strong_scale <= crit:
		return 0.0
	return DEUTERON_BASE * (strong_scale - crit) / (1.0 - crit)


static func stars_ignite(strong_scale: float) -> bool:
	return deuteron_binding_scaled_mev(strong_scale) > 0.0


# ------------------------------------------------------------------ avaliação

## Avalia um "universo" alternativo e devolve todas as consequências.
static func evaluate(alpha_scale: float, me_scale: float, strong_scale: float) -> Dictionary:
	var ry := rydberg_ev(alpha_scale, me_scale)
	var a0 := bohr_radius_ang(alpha_scale, me_scale)
	var fine := fine_splitting_relative(alpha_scale)
	var deu := deuteron_binding_scaled_mev(strong_scale)
	var stars := deu > 0.0
	var chem := "normal"
	if alpha_scale >= 1.5:
		chem = "muito ligada (átomos compactos)"
	elif alpha_scale <= 0.5:
		chem = "frouxa (átomos grandes)"
	var verdict := ""
	if not stars:
		verdict = "SEM ESTRELAS: o dêuteron não se liga (força forte < %.2f×). Universo escuro." % critical_strong_scale()
	elif alpha_scale >= 1.5:
		verdict = "Átomos muito ligados e compactos — química como a conhecemos fica difícil."
	elif alpha_scale <= 0.5:
		verdict = "Átomos frouxos: ligações químicas fracas e frágeis."
	else:
		verdict = "Universo habitável: estrelas acendem e a química funciona."
	return {
		"rydberg_ev": ry,
		"bohr_ang": a0,
		"fine_relative": fine,
		"deuteron_mev": deu,
		"stars": stars,
		"chemistry": chem,
		"verdict": verdict,
	}
