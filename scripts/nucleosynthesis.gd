extends RefCounted
## FASE 6 — Forja estelar (nucleossíntese). Reações de fusão até o Ferro-56
## (máximo da energia de ligação) e fissão do U-235. Dados em
## data/nucleosynthesis.json. Também calcula Q a partir de massas atômicas.

const PATH := "res://data/nucleosynthesis.json"

const U_MEV := 931.494102      # MeV por unidade de massa atômica
const M_H_U := 1.007825032
const M_HE4_U := 4.002603254
const M_C12_U := 12.0

static var _data: Dictionary = {}


static func _load() -> Dictionary:
	if not _data.is_empty():
		return _data
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		push_error("nucleosynthesis.json não encontrado")
		_data = {"pp_chain": {}, "triple_alpha": {}, "fusion_ladder": []}
		return _data
	_data = JSON.parse_string(f.get_as_text())
	if _data == null:
		_data = {"pp_chain": {}, "triple_alpha": {}, "fusion_ladder": []}
	return _data


# ------------------------------------------------------------------ cadeias

## Q da cadeia próton-próton: 4p → He-4 (+2e⁺ + 2νₑ), calculado de massas.
static func pp_chain_q_mev() -> float:
	return _load().get("pp_chain", {}).get("q_mev", 26.73)


## Q calculado das massas: (4·m_H − m_He4)·c².
static func pp_chain_q_mev_computed() -> float:
	return (4.0 * M_H_U - M_HE4_U) * U_MEV


static func pp_chain_equation() -> String:
	return String(_load().get("pp_chain", {}).get("equation", ""))


## Q da reação triplo-alfa: 3 He-4 → C-12.
static func triple_alpha_q_mev() -> float:
	return _load().get("triple_alpha", {}).get("q_mev", 7.275)


static func triple_alpha_q_mev_computed() -> float:
	return (3.0 * M_HE4_U - M_C12_U) * U_MEV


## Energia do estado de Hoyle acima do estado fundamental do C-12 (res Sonância).
static func hoyle_state_mev() -> float:
	return _load().get("triple_alpha", {}).get("hoyle_state_mev", 7.65)


# ------------------------------------------------------------------ escada de fusão

static func fusion_ladder() -> Array:
	return _load().get("fusion_ladder", [])


## Energia total liberada (MeV) somando a escada até o índice `up_to` (inclusive).
static func cumulative_fusion_energy_mev(up_to: int = -1) -> float:
	var ladder := fusion_ladder()
	var n := ladder.size() if up_to < 0 else mini(up_to + 1, ladder.size())
	var total := 0.0
	for i in range(n):
		total += float(ladder[i].get("q_mev", 0.0))
	return total


## Energia média liberada por núcleon até o ferro (6,7 MeV/núcleon para 4p→He,
## até ~8,8 MeV/núcleon no Fe-56). Retorna a razão Q/A da cadeia até He-4.
static func energy_per_nucleon_to_helium_mev() -> float:
	return pp_chain_q_mev() / 4.0


# ------------------------------------------------------------------ fissão e além

static func fission_q_mev() -> float:
	return _load().get("fission", {}).get("q_mev", 200.0)


static func fission_equation() -> String:
	return String(_load().get("fission", {}).get("equation", ""))


static func process_ids() -> Array:
	return (_load().get("nucleosynthesis_processes", {}) as Dictionary).keys()


static func process(key: String) -> Dictionary:
	return _load().get("nucleosynthesis_processes", {}).get(key, {})


## Elemento de máxima energia de ligação (fim da forja estelar).
static func max_binding_element() -> String:
	return "Fe-56"


static func max_binding_per_a_mev() -> float:
	return 8.790
