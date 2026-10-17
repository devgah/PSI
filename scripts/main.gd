extends Node3D
## FASE 1 — Átomo hidrogenoide (nuvem |psi|^2, canhão de fótons, espectro).
## FASE 2 — Tabela periódica, blindagem de Slater (Z_eff), energias de ionização
##          medidas (NIST) e raios atômicos.
## FASE 3 — Núcleo atômico: prótons/nêutrons, fórmula de Weizsäcker, números
##          mágicos, vale de estabilidade, Yukawa e cadeias de decaimento.
## FASE 5 — Zoom partônico (QCD): quarks de valência, glúons, mar de quarks,
##          conservação estrita e quebra de corda.
## Trabalha em unidades atômicas; converte só na interface.

const AtomConstants = preload("res://scripts/atom_constants.gd")
const OrbitalMath = preload("res://scripts/orbital_math.gd")
const OrbitalSampler = preload("res://scripts/orbital_sampler.gd")
const ElectronConfig = preload("res://scripts/electron_config.gd")
const PhotonCannon = preload("res://scripts/photon_cannon.gd")
const OrbitCamera = preload("res://scripts/orbit_camera.gd")
const OrbitalCloud = preload("res://scripts/orbital_cloud.gd")
const Slater = preload("res://scripts/slater.gd")
const ElementData = preload("res://scripts/element_data.gd")
const AtomicProperties = preload("res://scripts/atomic_properties.gd")
const PeriodicTable = preload("res://scripts/periodic_table.gd")
const Nuclear = preload("res://scripts/nuclear.gd")
const NuclideData = preload("res://scripts/nuclide_data.gd")
const Decay = preload("res://scripts/decay.gd")
const Nucleus = preload("res://scripts/nucleus_model.gd")
const NucleusView = preload("res://scripts/nucleus_view.gd")
const MoleculeData = preload("res://scripts/molecule_data.gd")
const MoleculeModel = preload("res://scripts/molecule_model.gd")
const MoleculeView = preload("res://scripts/molecule_view.gd")
const MorsePlot = preload("res://scripts/morse_plot.gd")
const ReactionsPanel = preload("res://scripts/reactions_panel.gd")
const ParticleData = preload("res://scripts/particle_data.gd")
const NucleonModel = preload("res://scripts/nucleon_model.gd")
const NucleonView = preload("res://scripts/nucleon_view.gd")
const PartonPanel = preload("res://scripts/parton_panel.gd")
const CollapsePanel = preload("res://scripts/collapse_panel.gd")
const FieldsPanel = preload("res://scripts/fields_panel.gd")
const AdvancedPanel = preload("res://scripts/advanced_panel.gd")

const MAX_ELECTRONS := 18
const POINT_BUDGET := 18000

var rng := RandomNumberGenerator.new()

var z := 1
var n_electrons := 1
var n_neutrons := 0
var nucleus_mode := false
var molecule_mode := false
var parton_mode := false
var molecule_id := "H2"
var nucleon_id := "proton"
var ground_occ: Array = []
var active_ground: Dictionary = {}
var active: Dictionary = {}
var action_gen := 0
var busy := false
var pending_z_eff := 1.0
var spectrum: Array = []

# mundo 3D
var cloud: Node3D
var collapse_dot: MeshInstance3D
var beam: MeshInstance3D
var beam_mat: StandardMaterial3D
var nucleus_mat: StandardMaterial3D
var nucleus_mesh: MeshInstance3D
var nucleus_view: Node3D
var molecule_view: Node3D
var nucleon_view: Node3D
var cam: Camera3D

# UI
var z_spin: SpinBox
var e_spin: SpinBox
var n_spin: SpinBox
var config_lbl: RichTextLabel
var props_lbl: RichTextLabel
var nuc_lbl: RichTextLabel
var orbital_lbl: Label
var level_lbl: Label
var photon_sl: HSlider
var photon_lbl: Label
var log_lbl: RichTextLabel
var barcode: HBoxContainer
var spectrum_lbl: RichTextLabel
var scale_lbl: Label
var periodic: Control
var mode_btn: Button
var mol_btn: Button
var mol_opt: OptionButton
var mol_lbl: RichTextLabel
var morse_plot: Control
var reactions: Control
var parton_btn: Button
var nucleon_opt: OptionButton
var parton_lbl: RichTextLabel
var parton_panel: Control
var collapse_panel: Control
var advanced_panel: Control
var fields_panel: Control


func _ready() -> void:
	rng.seed = 20261015
	_build_world()
	_build_ui()
	_log("Fase 6 ativa: colapso gravitacional (anã branca → estrela de nêutrons → buraco negro), forja estelar (nucleossíntese até o ferro) e colisor (massa invariante, curvatura p/(qB)).")
	_log("Fase 8 ativa: campos & leis — efeito Zeeman (μ_B, fator de Landé), efeito Stark (linear/quadrático) e sandbox de constantes fundamentais (α, mₑ, força forte).")
	_log("Fase 7 ativa: realismo avançado — estrutura fina (Sommerfeld), equação de Dirac e evolução temporal da função de onda (Crank–Nicolson, norma conservada).")
	_log("Fase 5 ativa: zoom partônico (QCD) — quarks/glúons, validador estrito de conservação e quebra de corda (~1 GeV/fm).")
	_log("Fase 4 ativa: ligação química — orbitais moleculares (LCAO), eletronegatividade de Pauling, VSEPR, termodinâmica (ΔG) e materiais emergentes.")
	_log("Fase 3: núcleo atômico — prótons/nêutrons, Weizsäcker, números mágicos e decaimentos (NUBASE2020/AME2020).")
	_log("Elétrons são nuvens de probabilidade |ψ|² — o modelo de Bohr está proibido.")
	_refresh(true)


# ---------------------------------------------------------------- mundo 3D

func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.008, 0.01, 0.025)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.55, 0.7)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	cam = OrbitCamera.new()
	add_child(cam)

	# núcleo (marcador visual do átomo — partículas são pontuais no Modelo Padrão)
	nucleus_mesh = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.15
	sphere.height = 0.30
	nucleus_mat = StandardMaterial3D.new()
	nucleus_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	nucleus_mat.albedo_color = Color(1.0, 0.85, 0.35)
	nucleus_mat.emission_enabled = true
	nucleus_mat.emission = Color(1.0, 0.75, 0.25)
	nucleus_mat.emission_energy_multiplier = 2.0
	sphere.material = nucleus_mat
	nucleus_mesh.mesh = sphere
	add_child(nucleus_mesh)

	# caroço nuclear detalhado (modo núcleo — Fase 3)
	nucleus_view = NucleusView.new()
	nucleus_view.visible = false
	add_child(nucleus_view)

	# visualização molecular (modo molécula — Fase 4)
	molecule_view = MoleculeView.new()
	molecule_view.visible = false
	add_child(molecule_view)

	# interior do núcleon / QCD (modo partônico — Fase 5)
	nucleon_view = NucleonView.new()
	nucleon_view.visible = false
	add_child(nucleon_view)

	# corpo do canhão de fótons
	var cannon := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.10
	cyl.bottom_radius = 0.20
	cyl.height = 2.6
	var cannon_mat := StandardMaterial3D.new()
	cannon_mat.albedo_color = Color(0.55, 0.6, 0.72)
	cannon_mat.metallic = 0.8
	cannon_mat.roughness = 0.3
	cyl.material = cannon_mat
	cannon.mesh = cyl
	cannon.rotation_degrees = Vector3(0, 0, 90)
	cannon.position = Vector3(10.2, 0, 0)
	add_child(cannon)

	# feixe (flash do tiro)
	beam = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	beam_mat = StandardMaterial3D.new()
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	beam_mat.albedo_color = Color(1.0, 0.95, 0.7, 0.0)
	box.material = beam_mat
	beam.mesh = box
	beam.transform = Transform3D(Basis.from_scale(Vector3(9.6, 0.05, 0.05)), Vector3(4.8, 0, 0))
	beam.visible = false
	add_child(beam)

	# nuvem de probabilidade
	cloud = OrbitalCloud.new()
	add_child(cloud)

	# ponto "colapsado" da medição
	collapse_dot = MeshInstance3D.new()
	var dsphere := SphereMesh.new()
	dsphere.radius = 0.11
	dsphere.height = 0.22
	var dmat := StandardMaterial3D.new()
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dmat.albedo_color = Color(1, 1, 1)
	dmat.emission_enabled = true
	dmat.emission = Color(1, 1, 1)
	dmat.emission_energy_multiplier = 5.0
	dsphere.material = dmat
	collapse_dot.mesh = dsphere
	collapse_dot.visible = false
	add_child(collapse_dot)


# ---------------------------------------------------------------------- UI

func _make_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.09, 0.9)
	sb.border_color = Color(0.25, 0.35, 0.5, 0.6)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 12.0
	return sb


func _title(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", Color(0.55, 0.8, 1.0))
	return l


func _label(text: String, size: int = 14) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	return l


## Rótulo de texto longo, com quebra de linha (usar apenas fora de HBox).
func _wrap_label(text: String, size: int = 14) -> Label:
	var l := _label(text, size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _rich(size: int = 14, min_size := Vector2.ZERO) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_following = true
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.custom_minimum_size = min_size
	return r


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)

	# ---- esqueleto responsivo: área de informações rolável + barra inferior fixa
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	root.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	margin.add_child(col)

	var top_scroll := ScrollContainer.new()
	top_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	top_scroll.follow_focus = true
	col.add_child(top_scroll)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 16)
	top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_scroll.add_child(top_row)

	# ---- painel esquerdo: átomo

	var left := PanelContainer.new()
	left.add_theme_stylebox_override("panel", _make_style())
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 8)
	left.add_child(lv)
	lv.add_child(_title("ÁTOMO — FASE 1 (HIDROGENOIDE)"))

	var zrow := HBoxContainer.new()
	zrow.add_child(_label("Carga nuclear Z:", 14))
	z_spin = SpinBox.new()
	z_spin.min_value = 1
	z_spin.max_value = 118
	z_spin.step = 1
	z_spin.value = 1
	z_spin.custom_minimum_size = Vector2(110, 0)
	z_spin.value_changed.connect(_on_z_changed)
	zrow.add_child(z_spin)
	lv.add_child(zrow)

	var erow := HBoxContainer.new()
	erow.add_child(_label("Elétrons:", 14))
	e_spin = SpinBox.new()
	e_spin.min_value = 0
	e_spin.max_value = z  # N <= Z: só cátions/átomos neutros (sem anions na Fase 1)
	e_spin.step = 1
	e_spin.value = 1
	e_spin.custom_minimum_size = Vector2(110, 0)
	e_spin.value_changed.connect(_on_e_changed)
	erow.add_child(e_spin)
	lv.add_child(erow)

	var nrow := HBoxContainer.new()
	nrow.add_child(_label("Nêutrons (N):", 14))
	n_spin = SpinBox.new()
	n_spin.min_value = 0
	n_spin.max_value = 200
	n_spin.step = 1
	n_spin.value = n_neutrons
	n_spin.custom_minimum_size = Vector2(110, 0)
	n_spin.value_changed.connect(_on_n_changed)
	nrow.add_child(n_spin)
	lv.add_child(nrow)

	config_lbl = _rich(15, Vector2(360, 72))
	config_lbl.fit_content = false
	lv.add_child(config_lbl)

	lv.add_child(HSeparator.new())
	level_lbl = _label("—", 14)
	level_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lv.add_child(level_lbl)
	orbital_lbl = _label("—", 14)
	orbital_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lv.add_child(orbital_lbl)

	lv.add_child(HSeparator.new())
	lv.add_child(_title("PROPRIEDADES (FASE 2)"))
	props_lbl = _rich(13, Vector2(360, 150))
	props_lbl.fit_content = false
	lv.add_child(props_lbl)

	left.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top_row.add_child(left)

	# ---- coluna direita: espectro + núcleo (empurrada para a borda direita)
	var right_col := VBoxContainer.new()
	right_col.add_theme_constant_override("separation", 10)
	right_col.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var vspacer := Control.new()
	vspacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(vspacer)
	top_row.add_child(right_col)

	var right := PanelContainer.new()
	right.add_theme_stylebox_override("panel", _make_style())
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 8)
	right.add_child(rv)
	rv.add_child(_title("ESPECTRO — LINHAS DE RYDBERG"))
	barcode = HBoxContainer.new()
	barcode.add_theme_constant_override("separation", 3)
	rv.add_child(barcode)
	spectrum_lbl = _rich(13, Vector2(330, 140))
	spectrum_lbl.fit_content = false
	spectrum_lbl.scroll_following = false
	rv.add_child(spectrum_lbl)
	right_col.add_child(right)

	# ---- painel do núcleo (Fase 3)
	var nuc := PanelContainer.new()
	nuc.add_theme_stylebox_override("panel", _make_style())
	nuc.custom_minimum_size = Vector2(360, 0)
	var nv := VBoxContainer.new()
	nv.add_theme_constant_override("separation", 8)
	nuc.add_child(nv)
	nv.add_child(_title("NÚCLEO — FASE 3 (WEIZSÄCKER / DECAIMENTO)"))
	nuc_lbl = _rich(13, Vector2(340, 150))
	nuc_lbl.fit_content = false
	nv.add_child(nuc_lbl)

	var nbr := HBoxContainer.new()
	nbr.add_theme_constant_override("separation", 8)
	mode_btn = Button.new()
	mode_btn.text = "MODO NÚCLEO"
	mode_btn.tooltip_text = "Alterna a visualização entre o átomo e o caroço nuclear"
	mode_btn.pressed.connect(_on_toggle_nucleus_mode)
	nbr.add_child(mode_btn)
	var d1 := Button.new()
	d1.text = "DECAIR"
	d1.pressed.connect(_on_decay_once)
	nbr.add_child(d1)
	var d2 := Button.new()
	d2.text = "CADEIA"
	d2.pressed.connect(_on_decay_chain)
	nbr.add_child(d2)
	var d3 := Button.new()
	d3.text = "MONTE CARLO"
	d3.tooltip_text = "Simula N(t) de um conjunto e compara com N0·e^(−λt)"
	d3.pressed.connect(_on_monte_carlo)
	nbr.add_child(d3)
	nv.add_child(nbr)
	right_col.add_child(nuc)

	# ---- painel da molécula (Fase 4)
	var mol := PanelContainer.new()
	mol.add_theme_stylebox_override("panel", _make_style())
	mol.custom_minimum_size = Vector2(360, 0)
	var mv := VBoxContainer.new()
	mv.add_theme_constant_override("separation", 8)
	mol.add_child(mv)
	mv.add_child(_title("MOLÉCULA — FASE 4 (LCAO / PAULING / VSEPR)"))

	var mrow := HBoxContainer.new()
	mrow.add_theme_constant_override("separation", 8)
	mol_btn = Button.new()
	mol_btn.text = "MODO MOLÉCULA"
	mol_btn.tooltip_text = "Alterna a visualização para a molécula selecionada"
	mol_btn.pressed.connect(_on_toggle_molecule_mode)
	mrow.add_child(mol_btn)
	mol_opt = OptionButton.new()
	mol_opt.custom_minimum_size = Vector2(150, 0)
	for id in MoleculeData.ids():
		mol_opt.add_item("%s — %s" % [MoleculeData.formula(id), MoleculeData.name(id)])
	mol_opt.item_selected.connect(_on_molecule_selected)
	mrow.add_child(mol_opt)
	mv.add_child(mrow)

	mol_lbl = _rich(13, Vector2(340, 150))
	mol_lbl.fit_content = false
	mv.add_child(mol_lbl)

	morse_plot = MorsePlot.new()
	mv.add_child(morse_plot)
	right_col.add_child(mol)

	# ---- painel partônico (Fase 5)
	var par := PanelContainer.new()
	par.add_theme_stylebox_override("panel", _make_style())
	par.custom_minimum_size = Vector2(360, 0)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 8)
	par.add_child(pv)
	pv.add_child(_title("PARTÔNICO — FASE 5 (QCD)"))
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 8)
	parton_btn = Button.new()
	parton_btn.text = "MODO PARTÔNICO"
	parton_btn.tooltip_text = "Zoom no interior do núcleon: quarks de valência, glúons e mar de quarks"
	parton_btn.pressed.connect(_on_toggle_parton_mode)
	prow.add_child(parton_btn)
	nucleon_opt = OptionButton.new()
	nucleon_opt.custom_minimum_size = Vector2(120, 0)
	nucleon_opt.add_item("Próton (uud)")
	nucleon_opt.add_item("Nêutron (udd)")
	nucleon_opt.item_selected.connect(_on_nucleon_selected)
	prow.add_child(nucleon_opt)
	pv.add_child(prow)
	parton_lbl = _rich(13, Vector2(340, 130))
	parton_lbl.fit_content = false
	pv.add_child(parton_lbl)
	right_col.add_child(par)

	# ---- painel inferior: canhão de fótons
	var bottom := PanelContainer.new()
	bottom.add_theme_stylebox_override("panel", _make_style())
	bottom.custom_minimum_size = Vector2(1040, 0)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 8)
	bottom.add_child(bv)
	bv.add_child(_title("CANHÃO DE FÓTONS"))

	photon_lbl = _label("E_fóton = 0,000 eV", 15)
	photon_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bv.add_child(photon_lbl)

	photon_sl = HSlider.new()
	photon_sl.min_value = 0.0
	photon_sl.max_value = 18.6
	photon_sl.step = 0.01
	photon_sl.value = 10.2
	photon_sl.custom_minimum_size = Vector2(760, 0)
	photon_sl.value_changed.connect(_on_photon_changed)
	bv.add_child(photon_sl)

	var brow := HFlowContainer.new()
	brow.add_theme_constant_override("h_separation", 10)
	brow.add_theme_constant_override("v_separation", 8)
	var fire := Button.new()
	fire.text = "DISPARAR FÓTON"
	fire.pressed.connect(_on_fire)
	brow.add_child(fire)
	var measure := Button.new()
	measure.text = "MEDIR POSIÇÃO (COLAPSAR)"
	measure.pressed.connect(_on_measure)
	brow.add_child(measure)
	var reset := Button.new()
	reset.text = "REDEFINIR"
	reset.pressed.connect(_on_reset)
	brow.add_child(reset)
	var table := Button.new()
	table.text = "TABELA PERIÓDICA"
	table.tooltip_text = "Escolher elemento (Z=1..54)"
	table.pressed.connect(_on_open_table)
	brow.add_child(table)
	var react := Button.new()
	react.text = "REAÇÕES & MATERIAIS"
	react.tooltip_text = "Termodinâmica (ΔG), catalisadores e propriedades emergentes"
	react.pressed.connect(_on_open_reactions)
	brow.add_child(react)
	var parton := Button.new()
	parton.text = "MODELO PADRÃO"
	parton.tooltip_text = "Partículas elementares, hádrons e leis de conservação (QCD)"
	parton.pressed.connect(_on_open_parton)
	brow.add_child(parton)
	var collapse := Button.new()
	collapse.text = "COLAPSO ESTELAR"
	collapse.tooltip_text = "Anã branca → estrela de nêutrons → buraco negro; nucleossíntese e colisor"
	collapse.pressed.connect(_on_open_collapse)
	brow.add_child(collapse)
	var adv := Button.new()
	adv.text = "REALISMO AVANÇADO"
	adv.tooltip_text = "Estrutura fina/Dirac e evolução temporal da função de onda"
	adv.pressed.connect(_on_open_advanced)
	brow.add_child(adv)
	var fields := Button.new()
	fields.text = "CAMPOS & LEIS"
	fields.tooltip_text = "Efeitos Zeeman/Stark e sandbox de constantes fundamentais"
	fields.pressed.connect(_on_open_fields)
	brow.add_child(fields)
	bv.add_child(brow)

	log_lbl = _rich(13, Vector2(760, 96))
	log_lbl.fit_content = false
	log_lbl.scroll_following = true
	bv.add_child(log_lbl)

	scale_lbl = _label(
		"MODO EDUCATIVO ESTILIZADO · unidades atômicas (ħ = mₑ = e = 4πε₀ = 1) · "
		+ "régua atômica: 1 Å = 10⁻¹⁰ m · no modo núcleo: 1 fm = 10⁻¹⁵ m · "
		+ "energias usam Z_eff (Slater); IE1 é medida (NIST); massas nucleares são "
		+ "medidas (AME2020) e B/Weizsäcker é estimativa. No modo molécula: "
		+ "comprimentos/energias/ângulos são medidos; BO/Pauling/VSEPR são modelo. "
		+ "No modo partônico: massas e cargas são medidas (PDG); a cor é rótulo de "
			+ "carga de cor e o confinamento ~1 GeV/fm é modelo. Sem órbitas planetárias.",
		10)
	scale_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scale_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	bv.add_child(scale_lbl)

	col.add_child(bottom)

	# ---- overlay da tabela periódica (Fase 2)
	periodic = PeriodicTable.new()
	periodic.visible = false
	periodic.element_selected.connect(_on_element_selected)
	root.add_child(periodic)

	# ---- overlay de reações e materiais (Fase 4)
	reactions = ReactionsPanel.new()
	reactions.visible = false
	root.add_child(reactions)

	# ---- overlay do Modelo Padrão (Fase 5)
	parton_panel = PartonPanel.new()
	parton_panel.visible = false
	root.add_child(parton_panel)

	# ---- overlay de colapso & forja estelar (Fase 6)
	collapse_panel = CollapsePanel.new()
	collapse_panel.visible = false
	root.add_child(collapse_panel)

	# ---- overlay de realismo avançado (Fase 7)
	advanced_panel = AdvancedPanel.new()
	advanced_panel.visible = false
	root.add_child(advanced_panel)

	# ---- overlay de campos & leis (Fase 8)
	fields_panel = FieldsPanel.new()
	fields_panel.visible = false
	root.add_child(fields_panel)

	_on_photon_changed(photon_sl.value)


# ------------------------------------------------------------------ refresh

func _points_per_electron() -> int:
	return clampi(POINT_BUDGET / maxi(n_electrons, 1), 500, 6000)


func _render_occ() -> Array:
	var out := []
	var active_is_excited := not active.is_empty() \
		and not _same_orbital(active, active_ground)
	for e in ground_occ:
		var count := int(e["count"])
		# o elétron ativo só sai da órbita de base se estiver excitado
		if active_is_excited and _same_orbital(active_ground, e):
			count -= 1
		if count > 0:
			out.append(_with_scale({"n": e["n"], "l": e["l"], "m": e["m"], "count": count}))
	if active_is_excited:
		out.append(_with_scale({"n": active["n"], "l": active["l"], "m": active["m"], "count": 1}))
	return out


## Anexa o fator de escala radial 1/Z_eff (Slater) a cada orbital renderizado.
func _with_scale(entry: Dictionary) -> Dictionary:
	var ze := _z_eff_for_orbital(int(entry["n"]), int(entry["l"]))
	entry["scale"] = 1.0 / maxf(ze, 0.05)
	entry["z_eff"] = ze
	return entry


## Z_eff (Slater) para um elétron em (n, l) considerando o elétron ativo
## removido da órbita de base — válido também no estado excitado.
func _z_eff_for_orbital(n: int, l: int) -> float:
	if active_ground.is_empty():
		return float(z)
	return Slater.z_eff_for(z, n_electrons, active_ground, n, l)


func _active_z_eff() -> float:
	if active.is_empty():
		return float(z)
	return _z_eff_for_orbital(int(active["n"]), int(active["l"]))


func _same_orbital(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("n", -1)) == int(b.get("n", -2)) \
		and int(a.get("l", -1)) == int(b.get("l", -2)) \
		and int(a.get("m", -99)) == int(b.get("m", -98))


func _refresh(rebuild: bool = true) -> void:
	ground_occ = ElectronConfig.occupancy_list(z, n_electrons)
	active_ground = ElectronConfig.highest_orbital(z, n_electrons)
	if active.is_empty():
		active = active_ground.duplicate()

	var sym := ElementData.symbol(z)
	var nm := ElementData.name(z)
	config_lbl.text = "[b]%s (%s)[/b]\n[b]Z = %d[/b] · elétrons = %d\n%s" % [
		nm, sym, z, n_electrons, ElectronConfig.config_string(z, n_electrons)]

	_update_props()
	_update_nuclear()
	_update_molecule()
	_update_parton()

	if active.is_empty():
		level_lbl.text = "Nenhum elétron — adicione elétrons."
		orbital_lbl.text = ""
	else:
		var n := int(active["n"])
		var l := int(active["l"])
		var m := int(active["m"])
		var ze := _active_z_eff()
		var e_n := OrbitalMath.energy_ev(ze, n)
		var e_ion := PhotonCannon.ionization_energy_ev(ze, n)
		level_lbl.text = "Nível n=%d · E = %s eV · ionização = %s eV" % [
			n, _fmt(e_n), _fmt(e_ion)]
		orbital_lbl.text = "Orbital ativo: %s · l = %d · m = %d · Z_eff = %.2f%s" % [
			OrbitalMath.orbital_label(n, l), l, m, ze,
			"" if active == active_ground else "  [EXCITADO]" ]

	# faixa do canhão acompanha o limiar de ionização do orbital ativo
	var thr := PhotonCannon.ionization_energy_ev(_active_z_eff(), maxi(int(active.get("n", 1)), 1))
	photon_sl.max_value = maxf(thr * 1.4 + 3.0, 18.6)

	if rebuild:
		nucleus_mat.emission_energy_multiplier = clampf(1.4 + 0.12 * float(z), 1.4, 6.0)
		if parton_mode:
			cloud.visible = false
			nucleus_mesh.visible = false
			nucleus_view.visible = false
			molecule_view.visible = false
			_apply_parton_view()
		elif molecule_mode:
			cloud.visible = false
			nucleus_mesh.visible = false
			nucleus_view.visible = false
			_apply_molecule_view()
		else:
			var occ := _render_occ()
			cloud.rebuild(occ, _points_per_electron())
			if nucleus_mode:
				cloud.visible = false
				nucleus_mesh.visible = false
				_apply_nucleus_view()
			else:
				nucleus_view.visible = false
				cloud.visible = true
				nucleus_mesh.visible = true
				# enquadramento automático pelo maior raio efetivo renderizado (n^2 / Z_eff)
				var max_r := 1.0
				for e in occ:
					max_r = maxf(max_r, float(int(e["n"]) * int(e["n"])) / maxf(float(e.get("z_eff", 1.0)), 0.05))
				var want := clampf(max_r * 3.0 + 9.0, 10.0, 140.0)
				cam.distance = lerpf(cam.distance, want, 0.65)


## Painel de propriedades: separa MEDIÇÃO (NIST) de ESTIMATIVA (Slater).
func _update_props() -> void:
	var ze_v := AtomicProperties.valence_z_eff(z)
	var r_au := AtomicProperties.slater_radius_au(z)
	var r_ang := AtomicProperties.slater_radius_angstrom(z)
	var ie_nist := AtomicProperties.nist_ie1_ev(z)
	var ie_slater := AtomicProperties.slater_ie1_ev(z)
	var err := AtomicProperties.slater_ie1_error(z)
	var err_txt := "—" if ie_nist <= 0.0 else "%.1f%%" % (err * 100.0)
	props_lbl.text = (
		"[b]%s[/b] · %s\n" +
		"Tipo: %s · bloco %s\n" +
		"Período %d · grupo %d\n" +
		"Z_eff(valência, Slater) = [b]%.2f[/b]\n" +
		"Raio atômico (Slater) = %.2f a₀ = %.3f Å\n" +
		"IE1 medida (NIST) = [b]%s eV[/b]\n" +
		"IE1 estimada (Slater) = %s eV (erro %s)\n" +
		"[i]Slater é aproximação; IE1 NIST é experimental.[/i]"
	) % [
		ElementData.symbol(z), ElementData.name(z),
		ElementData.category(z), ElementData.block(z),
		ElementData.period(z), ElementData.group(z),
		ze_v, r_au, r_ang,
		_fmt4(ie_nist), _fmt4(ie_slater), err_txt]


## Painel nuclear (Fase 3): A, Z, N, B (medida vs Weizsäcker), meia-vida,
## modos de decaimento, Q-valores e distância ao vale de estabilidade.
func _update_nuclear() -> void:
	var nu := Nucleus.new(z, n_neutrons)
	var a := nu.a()
	var me := nu.mass_excess_kev()
	var me_txt := "—" if is_nan(me) else _fmt1(me) + " keV"
	var b := nu.binding_mev()
	var bw := nu.binding_weizsacker_mev()
	var bpa := nu.binding_per_a_mev()
	var hl_txt := "estável" if nu.stable() else _hl_str(nu.half_life_s())
	var mode := nu.dominant_mode()
	var mode_txt := Decay.mode_label(mode) if mode != "" else "—"
	var mode_lines := ""
	for m in nu.modes():
		var pct = m.get("pct", null)
		mode_lines += "   · %s%s\n" % [
			Decay.mode_label(String(m.get("m", ""))),
			(" %.2f%%" % float(pct)) if pct != null else ""]
	var magic := []
	if nu.magic_z():
		magic.append("Z=%d" % z)
	if nu.magic_n():
		magic.append("N=%d" % n_neutrons)
	var magic_txt := "—" if magic.is_empty() else "mágico: " + ", ".join(magic)
	var valley := nu.valley_z()
	var dval := nu.valley_distance()
	var qa := Decay.q_alpha_mev(z, a)
	var qb := Decay.q_beta_minus_mev(z, a)
	var measured := nu.has_measured_mass()
	var mass_note := "massa medida (AME2020)" if measured else "massa estimada (Weizsäcker)"
	nuc_lbl.text = (
		"[b]%s-%d[/b] · Z=%d · N=%d · A=%d\n" +
		"Excesso de massa = %s  [i](%s)[/i]\n" +
		"Energia de ligação B = [b]%s MeV[/b] (B/A = %s MeV)\n" +
		"B (Weizsäcker) = %s MeV\n" +
		"Raio R = r₀·A^(1/3) = [b]%s fm[/b]\n" +
		"Meia-vida = %s\n" +
		"Decaimento dominante = %s\n" +
		"%s" +
		"Q(α) = %s MeV · Q(β⁻) = %s MeV\n" +
		"Vale de estabilidade: Z≈%d (%s %d)\n" +
		"%s"
	) % [
		nu.symbol(), a, z, n_neutrons, a,
		me_txt, mass_note,
		_fmt1(b), _fmt4(bpa), _fmt1(bw),
		_fmt4(nu.radius_fm()),
		hl_txt, mode_txt, mode_lines,
		_fmt4(qa), _fmt4(qb),
		valley, "distante" if dval > 2 else "próximo", dval,
		magic_txt]


## Visualiza (ou não) o caroço nuclear conforme o modo atual.
func _apply_nucleus_view() -> void:
	if nucleus_mode:
		nucleus_view.visible = true
		nucleus_view.build(z, n_neutrons)
		var rvis := 0.05 * Nuclear.radius_fm(maxi(z + n_neutrons, 1)) + 0.05
		cam.distance = rvis * 8.0 + 1.5
	else:
		nucleus_view.visible = false


# ------------------------------------------------------------------- molécula

## Painel da molécula (Fase 4): BO (MO), magnetismo, ΔEN, VSEPR e Morse.
## Diferencia o MODELO (LCAO/Pauling/VSEPR) dos DADOS experimentais.
func _update_molecule() -> void:
	var m := MoleculeModel.new(molecule_id)
	var lines: Array = []
	lines.append("[b]%s[/b] — %s  [i](%s)[/i]" % [
		m.formula(), m.name(), m.geometry()])
	var re := MoleculeData.bond_length_pm(molecule_id)
	var re_txt := "—" if is_nan(re) else "%.2f pm" % re
	var ang := MoleculeData.bond_angle_deg(molecule_id)
	var ang_txt := "" if is_nan(ang) else " · ângulo = %.1f°" % ang
	var bo_rep := m.reported_bond_order()
	var bo_mo := m.computed_bond_order()
	var bo_txt := "%d" % bo_rep
	if m.atoms.size() == 2:
		bo_txt = "%d (dado) · %.0f (LCAO-MO)" % [bo_rep, bo_mo]
	lines.append("Comprimento de ligação = [b]%s[/b]%s" % [re_txt, ang_txt])
	lines.append("Ordem de ligação = [b]%s[/b]" % bo_txt)
	var un := m.unpaired()
	lines.append("Elétrons desemparelhados = %d → [b]%s[/b]" % [
		un, "paramagnético" if m.paramagnetic() else "diamagnético"])
	var d := m.delta_en()
	var d_txt := "—" if is_nan(d) else "%.2f" % d
	var ic := m.ionic_character()
	var ic_txt := "—" if is_nan(ic) else "%.0f%%" % (ic * 100.0)
	lines.append("ΔEN (Pauling) = %s → [b]%s[/b] (caráter iônico %s)" % [
		d_txt, m.bond_class(), ic_txt])
	if m.atoms.size() == 2:
		var mo := m.mo()
		if not mo.is_empty():
			lines.append("HOMO = %s · LUMO = %s" % [mo["homo"], mo["lumo"]])
	else:
		var v := m.vsepr()
		lines.append("VSEPR: %d domínios (%d lig. + %d par. isolado) → [b]%s[/b] · %s" % [
			int(v["domains"]), int(v["ligands"]), int(v["lone_pairs"]),
			v["geometry"], v["hybridization"]])
	var de := MoleculeData.bond_energy_ev(molecule_id)
	var de_txt := "—" if is_nan(de) else "%.2f eV" % de
	var dip := MoleculeData.dipole_debye(molecule_id)
	var dip_txt := "—" if is_nan(dip) else "%.3f D" % dip
	lines.append("Energia de dissociação D_e = [b]%s[/b] · dipolo = %s" % [de_txt, dip_txt])
	var mm := m.morse()
	if not mm.is_empty():
		lines.append("Morse: a = %.4f pm⁻¹ · D₀ ≈ %.2f eV · ν = %.1f THz" % [
			float(mm["a_inv_pm"]), float(mm["d0_ev"]), float(mm["frequency_thz"])])
	lines.append("[i]%s[/i]" % MoleculeData.note(molecule_id))
	lines.append("[i]LCAO-MO: ordem = (ligantes − antiligantes)/2. Energias dos "
		+ "níveis são esquemáticas; BO, magnetismo e VSEPR são predições do modelo.[/i]")
	mol_lbl.text = "\n".join(PackedStringArray(lines))

	var plot := m.morse()
	if plot.is_empty():
		morse_plot.set_curve(0.0, 0.0, 0.1)
	else:
		morse_plot.set_curve(float(plot["de_ev"]), float(plot["re_pm"]),
			float(plot["a_inv_pm"]))


func _apply_molecule_view() -> void:
	if not molecule_mode:
		molecule_view.visible = false
		return
	molecule_view.visible = true
	molecule_view.build(MoleculeModel.new(molecule_id))
	# enquadramento: raio aproximado da molécula (maior distância ao centro)
	var maxd := 1.0
	for p in MoleculeModel.new(molecule_id).positions_pm():
		maxd = maxf(maxd, (p as Vector3).length())
	cam.distance = maxf(maxd * MoleculeView.SCENE_PER_PM * 2.6 + 3.5, 8.0)


func _on_toggle_molecule_mode() -> void:
	molecule_mode = not molecule_mode
	mol_btn.text = "MODO ÁTOMO" if molecule_mode else "MODO MOLÉCULA"
	if molecule_mode:
		nucleus_mode = false
		mode_btn.text = "MODO NÚCLEO"
		parton_mode = false
		parton_btn.text = "MODO PARTÔNICO"
		nucleon_view.visible = false
		collapse_dot.visible = false
		busy = false
		var m := MoleculeModel.new(molecule_id)
		_log("MODO MOLÉCULA: %s — BO(LCAO-MO) = %.0f · %s · %s." % [
			m.formula(), m.computed_bond_order(), m.bond_class(),
			"paramagnético" if m.paramagnetic() else "diamagnético"])
	else:
		_log("MODO ÁTOMO: nuvem de probabilidade |ψ|².")
	_refresh(true)


func _on_molecule_selected(index: int) -> void:
	var ids := MoleculeData.ids()
	if index < 0 or index >= ids.size():
		return
	molecule_id = String(ids[index])
	_update_molecule()
	if molecule_mode:
		_apply_molecule_view()
	var m := MoleculeModel.new(molecule_id)
	_log("MOLÉCULA: %s — %s · ordem de ligação (LCAO-MO) = %.0f · ΔEN = %s → %s." % [
		m.formula(), m.geometry(), m.computed_bond_order(),
		("—" if is_nan(m.delta_en()) else "%.2f" % m.delta_en()), m.bond_class()])


# ------------------------------------------------------------------ partônico

## Painel partônico (Fase 5): quarks de valência, energia dos glúons e mar.
func _update_parton() -> void:
	var nid := nucleon_id
	var v := NucleonModel.valence(nid)
	var quarks := ""
	for q in v:
		quarks += "%s(%s) " % [String(q["flavor"]), String(q["color"])]
	var m := ParticleData.mass_mev(nid)
	var vmass := NucleonModel.valence_mass_mev(nid)
	var gfrac := NucleonModel.gluon_fraction(nid)
	var lines: Array = []
	lines.append("[b]%s[/b] = %s" % [ParticleData.symbol(nid), quarks.strip_edges()])
	lines.append("Quarks de valência: %s MeV de %.1f MeV (%.1f%%)" % [
		_fmt1(vmass), m, 100.0 * vmass / maxf(m, 1.0)])
	lines.append("Glúons + mar de quarks: [b]%s MeV[/b] (%.1f%%)" % [
		_fmt1(NucleonModel.gluon_energy_mev(nid)), 100.0 * gfrac])
	lines.append("3 quarks ligados por tubos de fluxo de glúons; pares q q̄ virtuais "
		+ "surgem e somem continuamente.")
	lines.append("[i]As cores (r, g, b) são rótulos de carga de cor, não cores "
		+ "ópticas. Partículas são pontuais no Modelo Padrão.[/i]")
	parton_lbl.text = "\n".join(PackedStringArray(lines))


func _apply_parton_view() -> void:
	if not parton_mode:
		nucleon_view.visible = false
		return
	nucleon_view.visible = true
	nucleon_view.build(nucleon_id)
	cam.distance = 6.0


func _on_toggle_parton_mode() -> void:
	parton_mode = not parton_mode
	parton_btn.text = "MODO ÁTOMO" if parton_mode else "MODO PARTÔNICO"
	if parton_mode:
		nucleus_mode = false
		mode_btn.text = "MODO NÚCLEO"
		molecule_mode = false
		mol_btn.text = "MODO MOLÉCULA"
		molecule_view.visible = false
		collapse_dot.visible = false
		busy = false
		var nv := NucleonModel.valence(nucleon_id)
		var qs := ""
		for q in nv:
			qs += String(q["flavor"])
		_log("MODO PARTÔNICO: %s = %s — 3 quarks de valência + glúons (%.1f%% da massa); o restante do núcleon é energia do campo de cor." % [
			ParticleData.symbol(nucleon_id), qs,
			100.0 * NucleonModel.gluon_fraction(nucleon_id)])
	else:
		_log("MODO ÁTOMO: nuvem de probabilidade |ψ|².")
	_refresh(true)


func _on_nucleon_selected(index: int) -> void:
	nucleon_id = "neutron" if index == 1 else "proton"
	_update_parton()
	if parton_mode:
		_apply_parton_view()
	_log("NÚCLEON: %s — %s." % [ParticleData.symbol(nucleon_id),
		str(ParticleData.get_particle(nucleon_id)["content"])])


func _on_open_parton() -> void:
	parton_panel.open()


func _on_open_collapse() -> void:
	collapse_panel.open()


func _on_open_advanced() -> void:
	advanced_panel.open()


func _on_open_fields() -> void:
	fields_panel.open()


func _fmt(v: float) -> String:
	var s := "%.4f" % v
	return s.replace(".", ",")


func _fmt4(v: float) -> String:
	var s := "%.4f" % v
	return s.replace(".", ",")


func _fmt1(v: float) -> String:
	var s := "%.1f" % v
	return s.replace(".", ",")


## Formata uma meia-vida (s) em unidade legível.
func _hl_str(s: float) -> String:
	if not is_finite(s):
		return "estável"
	if s >= 3.1556952e16:
		return "%.2f Ga" % (s / 3.1556952e16)
	if s >= 3.1556952e7:
		return "%.2f anos" % (s / 3.1556952e7)
	if s >= 86400.0:
		return "%.2f dias" % (s / 86400.0)
	if s >= 3600.0:
		return "%.2f h" % (s / 3600.0)
	if s >= 60.0:
		return "%.2f min" % (s / 60.0)
	if s >= 1.0:
		return "%.2f s" % s
	if s >= 1e-3:
		return "%.2f ms" % (s * 1e3)
	if s >= 1e-6:
		return "%.2f µs" % (s * 1e6)
	if s >= 1e-9:
		return "%.2f ns" % (s * 1e9)
	if s >= 1e-12:
		return "%.2f ps" % (s * 1e12)
	if s >= 1e-15:
		return "%.2f fs" % (s * 1e15)
	return _sci(s) + " s"


func _sci(v: float) -> String:
	if v == 0.0:
		return "0"
	var e := int(floor(log(absf(v)) / log(10.0)))
	var m := v / pow(10.0, float(e))
	return "%.2f×10^%d" % [m, e]


## Nêutrons do isótopo representativo (mais estável/abundante) do elemento.
func _default_neutrons(zz: int) -> int:
	var e := NuclideData.ground_isotope(zz)
	if e.is_empty():
		return 0
	return maxi(int(e["a"]) - zz, 0)


# ------------------------------------------------------------------ interação

func _log(msg: String) -> void:
	log_lbl.append_text(msg + "\n")


func _beam_flash() -> void:
	beam.visible = true
	beam_mat.albedo_color = Color(1.0, 0.95, 0.7, 0.85)
	var tw := create_tween()
	tw.tween_property(beam_mat, "albedo_color:a", 0.0, 0.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): beam.visible = false)


func _on_z_changed(v: float) -> void:
	z = int(v)
	e_spin.max_value = z
	if n_electrons > z:
		n_electrons = z
		e_spin.set_value_no_signal(z)
	_set_default_isotope()
	action_gen += 1
	busy = false
	active = {}
	spectrum.clear()
	_update_spectrum()
	_refresh(true)


func _on_e_changed(v: float) -> void:
	n_electrons = int(v)
	action_gen += 1
	busy = false
	active = {}
	_refresh(true)


func _on_n_changed(v: float) -> void:
	n_neutrons = int(v)
	_update_nuclear()
	if nucleus_mode:
		_apply_nucleus_view()


func _on_photon_changed(v: float) -> void:
	var wl := AtomConstants.photon_wavelength_nm(v)
	var txt := "E_fóton = %.3f eV" % v
	if v > 0.0:
		if wl >= 1.0:
			txt += "  ·  λ = %.1f nm" % wl
		else:
			txt += "  ·  λ = %.4f nm (gama/UV extremo)" % wl
	if not active.is_empty():
		var e_ion := PhotonCannon.ionization_energy_ev(_active_z_eff(), int(active["n"]))
		if v >= e_ion and e_ion > 0.0:
			txt += "   [color=#ff9d5c]≥ ionização (%.3f eV)[/color]" % e_ion
	photon_lbl.text = txt
	photon_lbl.add_theme_color_override("font_color",
		Color(1.0, 0.9, 0.6) if v > 0.0 else Color(0.7, 0.7, 0.7))


func _on_fire() -> void:
	if busy:
		return
	if active.is_empty():
		_log("Sem elétrons para interagir — adicione elétrons.")
		return
	action_gen += 1
	var gen := action_gen
	var energy := photon_sl.value
	var ze := _active_z_eff()
	var res := PhotonCannon.interact(energy, ze, int(active["n"]), int(active["l"]),
		int(active["m"]))
	_beam_flash()
	match String(res.get("type", "")):
		"ionization":
			_log("EFEITO FOTOELÉTRICO: fóton de %.3f eV ≥ ionização de %.3f eV → elétron arrancado (E_cin = %.3f eV)." % [
				energy, float(res["threshold_ev"]), float(res["kinetic_ev"])])
			n_electrons -= 1
			e_spin.set_value_no_signal(maxf(n_electrons, 0))
			n_electrons = int(e_spin.value)
			active = {}
			busy = false
			_refresh(true)
		"excitation":
			busy = true
			pending_z_eff = ze
			var from_n := int(active["n"])
			_log("ABSORÇÃO: fóton de %.3f eV casou com ΔE(n=%d→n=%d) = %.3f eV (tol. ±0,05) e Δl = ±1." % [
				energy, from_n, int(res["n"]), float(res["delta_e"])])
			active = {"n": int(res["n"]), "l": int(res["l"]), "m": int(res["m"])}
			cloud.pulse(1.16)
			_refresh(true)
			get_tree().create_timer(1.5).timeout.connect(_run_cascade.bind(gen))
		_:
			_log("SEM INTERAÇÃO: %.3f eV não corresponde a nenhuma transição permitida (Δl = ±1). O átomo é transparente a este fóton." % energy)


func _run_cascade(gen: int) -> void:
	if gen != action_gen:
		return
	var steps := PhotonCannon.cascade(pending_z_eff, active, active_ground)
	if steps.is_empty():
		_log("Desexcitação direta sem fóton (estado fundamental).")
	else:
		for s in steps:
			var msg := "EMISSÃO: %s→%s · ΔE = %s eV · λ = %.2f nm" % [
				OrbitalMath.orbital_label(int(s["n_from"]), int(s["l_from"])),
				OrbitalMath.orbital_label(int(s["n_to"]), int(s["l_to"])),
				_fmt(float(s["energy_ev"])), float(s["lambda_nm"])]
			_log(msg)
			spectrum.append({"lambda_nm": float(s["lambda_nm"]),
				"energy_ev": float(s["energy_ev"]),
				"n_from": int(s["n_from"]), "n_to": int(s["n_to"])})
		_log("→ Código de barras espectral atualizado (espectro único do elemento Z=%d)." % z)
	active = active_ground.duplicate()
	busy = false
	cloud.pulse(1.08)
	_update_spectrum()
	_refresh(true)


func _on_measure() -> void:
	if busy:
		return
	if active.is_empty():
		_log("Sem elétrons — nada a medir.")
		return
	action_gen += 1
	var gen := action_gen
	busy = true
	var ze := _active_z_eff()
	var p := OrbitalSampler.sample_one(int(active["n"]), int(active["l"]),
		int(active["m"]), rng) / maxf(ze, 0.05)
	collapse_dot.position = p
	collapse_dot.visible = true
	cloud.visible = false
	_log("MEDIÇÃO DE POSIÇÃO: |ψ|² colapsou em um ponto (regra de Born) em (%.2f, %.2f, %.2f) [unidades de Bohr]." % [p.x, p.y, p.z])
	get_tree().create_timer(1.2).timeout.connect(func():
		if gen != action_gen:
			return
		collapse_dot.visible = false
		cloud.visible = not nucleus_mode
		cloud.spread_to(2.1, 4.0)
		_log("Δx↓ → Δp↑ (Δx·Δp ≥ ħ/2): a incerteza de momento aumentou e a nuvem se reexpande.")
		busy = false)


func _on_reset() -> void:
	action_gen += 1
	busy = false
	z = 1
	n_electrons = 1
	z_spin.set_value_no_signal(1)
	e_spin.max_value = 1
	e_spin.set_value_no_signal(1)
	_set_default_isotope()
	active = {}
	spectrum.clear()
	_update_spectrum()
	photon_sl.set_value_no_signal(10.2)
	_on_photon_changed(10.2)
	_refresh(true)
	_log("Estado redefinido: hidrogênio no 1s.")


## Ajusta N para o isótopo representativo do elemento e sincroniza o controle.
func _set_default_isotope() -> void:
	n_neutrons = _default_neutrons(z)
	n_spin.set_value_no_signal(n_neutrons)


# ------------------------------------------------------------ tabela periódica

func _on_open_table() -> void:
	periodic.open(z)


func _on_open_reactions() -> void:
	reactions.open()


func _on_element_selected(zz: int) -> void:
	z = zz
	n_electrons = zz  # átomo neutro
	z_spin.set_value_no_signal(zz)
	e_spin.max_value = zz
	e_spin.set_value_no_signal(zz)
	_set_default_isotope()
	action_gen += 1
	busy = false
	active = {}
	spectrum.clear()
	_update_spectrum()
	_refresh(true)
	_on_photon_changed(photon_sl.value)
	var ze := AtomicProperties.valence_z_eff(zz)
	_log("ELEMENTO: %s (%s) — Z=%d, %s. Z_eff(valência) = %.2f · IE1(NIST) = %.4f eV · IE1(Slater) = %.4f eV." % [
		ElementData.name(zz), ElementData.symbol(zz), zz,
		ElectronConfig.config_string(zz, zz), ze,
		ElementData.ie1_ev(zz), AtomicProperties.slater_ie1_ev(zz)])


# -------------------------------------------------------------------- núcleo

func _on_toggle_nucleus_mode() -> void:
	nucleus_mode = not nucleus_mode
	mode_btn.text = "MODO ÁTOMO" if nucleus_mode else "MODO NÚCLEO"
	if nucleus_mode:
		molecule_mode = false
		mol_btn.text = "MODO MOLÉCULA"
		molecule_view.visible = false
		parton_mode = false
		parton_btn.text = "MODO PARTÔNICO"
		nucleon_view.visible = false
		collapse_dot.visible = false
		busy = false
		_log("MODO NÚCLEO: R = r₀·A^(1/3) = %.2f fm (%s-%d). %s" % [
			Nuclear.radius_fm(maxi(z + n_neutrons, 1)), Nucleus.new(z, n_neutrons).symbol(),
			z + n_neutrons,
			"núcleo duplamente mágico!" if Nuclear.is_doubly_magic(z, n_neutrons) else ""])
	else:
		cloud.visible = true
		nucleus_mesh.visible = true
		_log("MODO ÁTOMO: nuvem de probabilidade |ψ|².")
	_refresh(true)


func _on_decay_once() -> void:
	var nu := Nucleus.new(z, n_neutrons)
	if nu.stable():
		_log("DECAIMENTO: %s-%d é estável — não decai." % [nu.symbol(), nu.a()])
		return
	var sym_from := nu.symbol()
	var a_from := nu.a()
	var z_from := nu.z
	var res := nu.decay_once()
	if not res.get("ok", false):
		_log("DECAIMENTO: não modelado — %s" % res.get("note", ""))
		return
	var emitted := ", ".join(PackedStringArray(res.get("emitted", [])))
	_log("DECAIMENTO %s: %s-%d → %s-%d · Q = %s MeV · emitido: %s." % [
		Decay.mode_label(String(res["mode"])), sym_from, a_from,
		nu.symbol(), nu.a(), _fmt(float(res["q_mev"])), emitted])
	_apply_nuclear_state(nu)
	nucleus_view.pulse(1.25)


func _on_decay_chain() -> void:
	var steps := Decay.chain(z, n_neutrons, 30)
	if steps.is_empty():
		_log("CADEIA: %s-%d já é estável." % [Nucleus.new(z, n_neutrons).symbol(),
			z + n_neutrons])
		return
	_log("CADEIA DE DECAIMENTO — %d etapas até a estabilidade:" % steps.size())
	var cz := z
	var ca := z + n_neutrons
	for s in steps:
		var res := Decay.apply_decay(int(s["z"]), int(s["a"]), String(s["mode"]))
		var emitted := ", ".join(PackedStringArray(res.get("emitted", [])))
		_log("   · %s-%d --[%s]--> %s-%d  (Q=%s MeV, t½=%s)  emitido: %s" % [
			Nucleus.new(int(s["z"]), int(s["a"]) - int(s["z"])).symbol(), int(s["a"]),
			Decay.mode_label(String(s["mode"])), int(res["z"]) + 0,
			int(res["a"]), _fmt(float(s["q_mev"])),
			_hl_str(float(s["hl_s"])), emitted])
		cz = int(res["z"])
		ca = int(res["a"])
	_apply_nuclear_state(Nucleus.new(cz, ca - cz))
	_log("   → estável em %s-%d." % [Nucleus.new(cz, ca - cz).symbol(), ca])


func _on_monte_carlo() -> void:
	var a := z + n_neutrons
	var nu := Nucleus.new(z, n_neutrons)
	if nu.stable():
		_log("MONTE CARLO: %s-%d é estável (λ=0) — nada a decair." % [nu.symbol(), a])
		return
	var hl := nu.half_life_s()
	if not is_finite(hl) or hl <= 0.0:
		_log("MONTE CARLO: meia-vida desconhecida para %s-%d." % [nu.symbol(), a])
		return
	var n0 := 2000
	var t_max := 5.0 * hl
	var mc := Decay.monte_carlo(n0, hl, t_max, 10, rng)
	var ts: PackedFloat64Array = mc["t"]
	var ns: PackedFloat64Array = mc["n_sim"]
	var na: PackedFloat64Array = mc["n_analytic"]
	var txt := "MONTE CARLO N(t) — %d núcleos de %s-%d · t½ = %s · λ = %s s⁻¹\n" % [
		n0, nu.symbol(), a, _hl_str(hl), _sci(Decay.lambda_of(hl))]
	for i in range(ts.size()):
		txt += "   t = %.1f·t½   N_sim = %.0f   N_analít = %.0f\n" % [
			ts[i] / hl, ns[i], na[i]]
	txt += "   [i]Monte Carlo segue N(t) = N₀·e^(−λt); desvios são ruído estatístico.[/i]"
	_log(txt)


## Aplica um novo estado (Z,N) após decaimento, sincronizando átomo e controles.
func _apply_nuclear_state(nu: Nucleus) -> void:
	z = clampi(nu.z, 1, 118)
	n_neutrons = clampi(nu.n, 0, 250)
	z_spin.set_value_no_signal(z)
	n_spin.set_value_no_signal(n_neutrons)
	# mantém o átomo neutro após o decaimento (Z muda em β⁻/β⁺/EC)
	n_electrons = z
	e_spin.max_value = z
	e_spin.set_value_no_signal(n_electrons)
	action_gen += 1
	busy = false
	active = {}
	spectrum.clear()
	_update_spectrum()
	_refresh(true)


# ------------------------------------------------------------------- espectro

func _update_spectrum() -> void:
	for c in barcode.get_children():
		c.free()
	spectrum.sort_custom(func(a, b): return float(a["lambda_nm"]) < float(b["lambda_nm"]))
	if spectrum.is_empty():
		spectrum_lbl.text = "[i](nenhuma linha ainda — dispare um fóton próximo da ressonância e observe a cascata de emissão)[/i]"
		return
	var txt := ""
	for ln in spectrum:
		barcode.add_child(_make_bar(float(ln["lambda_nm"])))
		txt += "λ = %.2f nm · E = %s eV · n %d → %d%s\n" % [
			float(ln["lambda_nm"]), _fmt(float(ln["energy_ev"])),
			int(ln["n_from"]), int(ln["n_to"]),
			"  (fora do visível)" if _wl_outside_visible(float(ln["lambda_nm"])) else ""]
	spectrum_lbl.text = txt


func _make_bar(wl: float) -> ColorRect:
	var cr := ColorRect.new()
	cr.color = _wl_rgb(wl)
	cr.custom_minimum_size = Vector2(8, 34)
	return cr


func _wl_outside_visible(wl: float) -> bool:
	return wl < 380.0 or wl > 740.0


## Aproximação de comprimento de onda -> cor (comparações de Bruton).
static func _wl_rgb(wl: float) -> Color:
	if wl < 380.0:
		return Color(0.45, 0.1, 0.55)  # UV (indicativo)
	if wl > 740.0:
		return Color(0.5, 0.12, 0.1)   # infravermelho (indicativo)
	var r := 0.0
	var g := 0.0
	var b := 0.0
	if wl < 440.0:
		r = -(wl - 440.0) / 60.0
		b = 1.0
	elif wl < 490.0:
		g = (wl - 440.0) / 50.0
		b = 1.0
	elif wl < 510.0:
		g = 1.0
		b = -(wl - 510.0) / 20.0
	elif wl < 580.0:
		r = (wl - 510.0) / 70.0
		g = 1.0
	elif wl < 645.0:
		r = 1.0
		g = -(wl - 645.0) / 65.0
	else:
		r = 1.0
	var f := 1.0
	if wl > 700.0:
		f = 0.35 + 0.65 * (740.0 - wl) / 40.0
	elif wl < 420.0:
		f = 0.35 + 0.65 * (wl - 380.0) / 40.0
	f = clampf(f, 0.0, 1.0)
	return Color(r * f, g * f, b * f, 1.0)
