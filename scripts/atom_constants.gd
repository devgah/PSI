extends RefCounted
## Constantes fundamentais (CODATA) e conversoes de unidades.
## Internamente o motor trabalha em unidades atomicas (hbar = m_e = e = 4*pi*eps0 = 1).

# --- CODATA ---
const HARTREE_EV := 27.211386245988
const RYDBERG_EV := 13.605693122994
const BOHR_M := 5.29177210903e-11
const BOHR_ANG := 0.529177210903
const RYDBERG_CONSTANT_M := 1.0973731568160e7
const HC_EV_NM := 1239.8419843320026
const ALPHA := 1.0 / 137.035999177
const C_M_S := 2.99792458e8
const E_CHARGE_C := 1.602176634e-19
const PLANCK_EV_S := 4.135667696e-15
const K_B_EV := 8.617333262e-5
const M_E_KG := 9.1093837015e-31
const M_E_MEV := 0.51099895069
const M_P_MEV := 938.27208816
const M_N_MEV := 939.56542052
const FEMTO_M := 1.0e-15
const ANG := 1.0e-10

# --- Unidades atomicas -> unidades SI/interface ---
static func hartree_to_ev(h: float) -> float:
	return h * HARTREE_EV


static func ev_to_hartree(ev: float) -> float:
	return ev / HARTREE_EV


static func bohr_to_m(r_au: float) -> float:
	return r_au * BOHR_M


static func bohr_to_angstrom(r_au: float) -> float:
	return r_au * BOHR_ANG


static func angstrom_to_bohr(a: float) -> float:
	return a / BOHR_ANG


static func fm_to_bohr(fm: float) -> float:
	return fm * 1.0e-15 / BOHR_M


# --- Foton ---
static func photon_energy_ev(lambda_nm: float) -> float:
	if lambda_nm <= 0.0:
		return 0.0
	return HC_EV_NM / lambda_nm


static func photon_wavelength_nm(energy_ev: float) -> float:
	if energy_ev <= 0.0:
		return 0.0
	return HC_EV_NM / energy_ev


# --- Constante tipada por nivel de escala (HUD honestidade) ---
static func scale_note(level: String) -> String:
	match level:
		"atom":
			return "Régua: 1 Å = 10^-10 m (escala atômica)"
		"nucleus":
			return "Régua: 1 fm = 10^-15 m (escala nuclear)"
		"molecule":
			return "Régua: 1 nm = 10^-9 m (escala molecular)"
		"parton":
			return "Régua: < 10^-18 m (escala partônica)"
	return "Régua logarítmica de escala ativa"
