extends SceneTree
## Smoke test da cena principal (headless): UI + canhão + cascata + medição.
## Executar: godot --headless --path . --script res://tests/smoke_scene.gd

var scene: Node
var ok := 0
var bad := 0


func _init() -> void:
	print("=== SMOKE TEST — cena principal (Fases 1 a 7) ===")
	scene = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	create_timer(0.2).timeout.connect(_step_fire)
	create_timer(1.0).timeout.connect(_check_excited)
	create_timer(3.0).timeout.connect(_check_cascade_done)
	create_timer(3.1).timeout.connect(_check_ionize)
	create_timer(3.4).timeout.connect(_check_measure)
	create_timer(5.0).timeout.connect(_check_periodic_table)
	create_timer(5.3).timeout.connect(_check_nucleus)
	create_timer(5.6).timeout.connect(_check_molecule)
	create_timer(5.75).timeout.connect(_check_reactions)
	create_timer(5.9).timeout.connect(_check_parton)
	create_timer(6.1).timeout.connect(_check_parton_panel)
	create_timer(6.35).timeout.connect(_check_collapse)
	create_timer(6.7).timeout.connect(_check_advanced)
	create_timer(6.9).timeout.connect(_check_fields)
	create_timer(7.2).timeout.connect(_finish)


func _check(cond: bool, name: String) -> void:
	if cond:
		ok += 1
		print("  OK    %s" % name)
	else:
		bad += 1
		print("  FALHA %s" % name)


func _step_fire() -> void:
	_check(scene.cloud.get_child_count() > 0, "nuvem inicial do estado fundamental (1s)")
	scene.photon_sl.value = 10.2
	scene._on_fire()
	_check(scene.busy, "disparo ressonante deixa o sistema ocupado (absorção)")
	_check(int(scene.active.get("n", 0)) == 2, "elétron excitado para n=2")
	_check(scene.cloud.get_child_count() > 0, "nuvem de pontos renderizada")


func _check_excited() -> void:
	_check(int(scene.active.get("n", 0)) == 2, "estado excitado mantido até a cascata")
	_check(scene.collapse_dot.visible == false, "ponto colapsado invisível (não medido)")


func _check_cascade_done() -> void:
	_check(int(scene.active.get("n", 0)) == 1, "cascata voltou ao estado fundamental")
	_check(scene.busy == false, "sistema livre após a cascata")
	_check(scene.spectrum.size() >= 1, "linhas espectrais registradas")
	_check(scene.cloud.get_child_count() > 0,
		"nuvem do estado fundamental renderizada após a cascata")
	_check(scene.barcode.get_child_count() == scene.spectrum.size(),
		"barcode renderizado com todas as linhas")
	_check(scene.log_lbl.get_parsed_text().find("EMISSÃO") >= 0,
		"log contém emissões com comprimento de onda")


func _check_ionize() -> void:
	var before := int(scene.n_electrons)
	scene.photon_sl.value = 14.0
	scene._on_fire()
	_check(int(scene.n_electrons) == before - 1, "ionização remove um elétron")
	_check(scene.log_lbl.get_parsed_text().find("FOTOEL") >= 0, "log registra efeito fotoelétrico")
	# recoloca o elétron
	scene.e_spin.value = 1.0
	scene._on_e_changed(1.0)
	_check(scene.cloud.get_child_count() > 0, "nuvem reconstruída após recolocar elétron")


func _check_measure() -> void:
	scene._on_measure()
	_check(scene.collapse_dot.visible, "medição colapsa a nuvem em um ponto")
	_check(scene.cloud.visible == false, "nuvem oculta durante a medição")
	_check(scene.busy, "medição ocupa o sistema")


func _check_periodic_table() -> void:
	# abre o overlay e valida a grade
	scene._on_open_table()
	_check(scene.periodic.visible, "overlay da tabela periódica abre")
	var grid := _find_grid(scene.periodic)
	_check(grid != null and grid.columns == 18, "grade da tabela tem 18 colunas")
	_check(grid != null and grid.get_child_count() >= 90,
		"grade preenche 5 períodos x 18 grupos")
	# seleciona o sódio (Z=11)
	scene._on_element_selected(11)
	_check(int(scene.z) == 11, "seleção de elemento ajusta Z = 11 (Na)")
	_check(int(scene.n_electrons) == 11, "átomo neutro: 11 elétrons")
	_check(scene.cloud.get_child_count() > 0, "nuvem reconstruída para o novo elemento")
	_check(scene.props_lbl.get_parsed_text().find("Z_eff") >= 0,
		"painel de propriedades mostra Z_eff")
	var logtxt: String = scene.log_lbl.get_parsed_text()
	_check(logtxt.find("ELEMENTO") >= 0 and logtxt.find("IE1(NIST)") >= 0,
		"log registra o elemento selecionado e a IE1 medida")


func _check_nucleus() -> void:
	# ativa o modo núcleo
	scene._on_toggle_nucleus_mode()
	_check(scene.nucleus_mode, "modo núcleo ativado")
	_check(scene.nucleus_view.visible, "caroço nuclear visível")
	_check(scene.cloud.visible == false, "nuvem oculta no modo núcleo")
	# urânio-238
	scene._on_element_selected(92)
	scene._on_n_changed(146)
	_check(int(scene.z) == 92 and int(scene.n_neutrons) == 146,
		"U-238 selecionado (Z=92, N=146)")
	var mm = scene.nucleus_view._mmi.multimesh
	_check(mm.instance_count == 238, "caroço renderiza A=238 núcleons",
		)
	_check(scene.nuc_lbl.get_parsed_text().find("Weizs") >= 0,
		"painel nuclear mostra energia de Weizsäcker")
	_check(scene.nuc_lbl.get_parsed_text().find("4,26") >= 0,
		"painel mostra Q(α) do U-238 ≈ 4,27 MeV")
	# um decaimento α: U-238 -> Th-234
	scene._on_decay_once()
	_check(int(scene.z) == 90 and int(scene.n_neutrons) == 144,
		"α do U-238 → Th-234 (Z=90, N=144)")
	# cadeia completa e Monte Carlo
	scene._on_decay_chain()
	_check(scene.log_lbl.get_parsed_text().find("CADEIA") >= 0,
		"cadeia de decaimento executada")
	scene._on_monte_carlo()
	_check(scene.log_lbl.get_parsed_text().find("MONTE CARLO") >= 0,
		"curva N(t) Monte Carlo executada")
	# volta ao modo átomo
	scene._on_toggle_nucleus_mode()
	_check(not scene.nucleus_mode and scene.cloud.visible,
		"modo átomo restaurado (nuvem visível)")


func _check_molecule() -> void:
	# ativa o modo molécula (a partir do modo átomo)
	scene._on_toggle_molecule_mode()
	_check(scene.molecule_mode, "modo molécula ativado")
	_check(scene.molecule_view.visible, "molécula visível na cena")
	_check(not scene.nucleus_mode and scene.cloud.visible == false,
		"átomo/núcleo ocultos no modo molécula")
	# seleciona O₂ (índice 7 na ordem de exibição)
	scene._on_molecule_selected(7)
	_check(scene.molecule_id == "O2", "O₂ selecionado")
	var txt: String = scene.mol_lbl.get_parsed_text()
	_check(txt.find("paramagn") >= 0, "painel marca O₂ como paramagnético")
	_check(txt.find("LCAO-MO") >= 0, "painel mostra a predição LCAO-MO")
	_check(scene.molecule_view.get_child_count() > 0,
		"núcleos e ligações renderizados")
	# seleciona a água e confere VSEPR
	scene._on_molecule_selected(13)
	_check(scene.molecule_id == "H2O", "H₂O selecionada")
	var tw: String = scene.mol_lbl.get_parsed_text()
	_check(tw.find("angular") >= 0, "painel mostra geometria angular da água")
	_check(tw.find("Morse") >= 0, "painel mostra parâmetros de Morse")
	# volta ao modo átomo
	scene._on_toggle_molecule_mode()
	_check(not scene.molecule_mode and scene.cloud.visible,
		"modo átomo restaurado após molécula")


func _check_reactions() -> void:
	scene._on_open_reactions()
	_check(scene.reactions.visible, "overlay de reações & materiais abre")
	var txt: String = scene.reactions._react_lbl.get_parsed_text()
	_check(txt.find("ΔG") >= 0, "painel mostra ΔG(T)")
	_check(txt.find("ativação") >= 0, "painel mostra energia de ativação")
	# sobe a temperatura e confirma que o texto atualiza
	scene.reactions._temp_slider.value = 800.0
	scene.reactions._on_temp_changed(800.0)
	_check(scene.reactions._temp_lbl.text.find("800") >= 0,
		"temperatura atualiza o painel de reação")
	var mtxt: String = scene.reactions._mat_lbl.get_parsed_text()
	_check(mtxt.find("banda") >= 0, "painel de materiais mostra intervalo de banda")
	scene.reactions._close()
	_check(not scene.reactions.visible, "overlay de reações fecha")


func _check_parton() -> void:
	# ativa o modo partônico (a partir do modo átomo)
	scene._on_toggle_parton_mode()
	_check(scene.parton_mode, "modo partônico ativado")
	_check(scene.nucleon_view.visible, "interior do núcleon visível")
	_check(scene.cloud.visible == false, "nuvem oculta no modo partônico")
	_check(scene.nucleon_view.valence_count() == 3,
		"3 quarks de valência renderizados")
	_check(scene.nucleon_view.sea_count() > 0,
		"mar de quarks virtuais renderizado")
	var t: String = scene.parton_lbl.get_parsed_text()
	_check(t.find("Glúons") >= 0, "painel mostra a energia dos glúons")
	# seleciona o nêutron
	scene._on_nucleon_selected(1)
	_check(scene.nucleon_id == "neutron", "nêutron selecionado")
	_check(scene.nucleon_view.visible, "nêutron visível no modo partônico")
	# volta ao modo átomo
	scene._on_toggle_parton_mode()
	_check(not scene.parton_mode and scene.cloud.visible,
		"modo átomo restaurado após partônico")


func _check_parton_panel() -> void:
	scene._on_open_parton()
	_check(scene.parton_panel.visible, "overlay do Modelo Padrão abre")
	var pt: String = scene.parton_panel._particle_lbl.get_parsed_text()
	_check(pt.find("Quarks") >= 0 and pt.find("Léptons") >= 0,
		"catálogo lista quarks e léptons")
	var ht: String = scene.parton_panel._hadron_lbl.get_parsed_text()
	_check(ht.find("quebra de corda") >= 0 or ht.find("QUEBRA") >= 0
		or ht.find("Branco") >= 0 or ht.find("brancos") >= 0,
		"hádrons e quebra de corda exibidos")
	# seleciona o primeiro processo e confere o veredito
	scene.parton_panel._on_process_selected(0)
	var vt: String = scene.parton_panel._proc_lbl.get_parsed_text()
	_check(vt.find("PERMITIDA") >= 0 or vt.find("PROIBIDA") >= 0,
		"validador exibe veredito de conservação")
	scene.parton_panel._close()
	_check(not scene.parton_panel.visible, "overlay do Modelo Padrão fecha")


func _check_collapse() -> void:
	scene._on_open_collapse()
	_check(scene.collapse_panel.visible, "overlay de colapso abre")
	# 1,0 M☉ → anã branca
	scene.collapse_panel._mass_sl.value = 1.0
	scene.collapse_panel._update_star()
	var st1: String = scene.collapse_panel._star_lbl.get_parsed_text()
	_check(st1.find("Anã Branca") >= 0, "1 M☉ classificado como anã branca")
	_check(st1.find("Chandrasekhar") >= 0, "painel mostra o limite de Chandrasekhar")
	# 2,5 M☉ → buraco negro
	scene.collapse_panel._mass_sl.value = 2.5
	scene.collapse_panel._update_star()
	var st2: String = scene.collapse_panel._star_lbl.get_parsed_text()
	_check(st2.find("Buraco Negro") >= 0, "2,5 M☉ classificado como buraco negro")
	_check(st2.find("Schwarzschild") >= 0, "painel mostra o raio de Schwarzschild")
	# forja estelar
	var ft: String = scene.collapse_panel._fusion_lbl.get_parsed_text()
	_check(ft.find("próton-próton") >= 0, "painel mostra a cadeia pp")
	_check(ft.find("Fe") >= 0, "painel mostra a escada até o ferro")
	# colisor
	var ct: String = scene.collapse_panel._collider_lbl.get_parsed_text()
	_check(ct.find("Massa invariante") >= 0, "colisor mostra massa invariante")
	_check(ct.find("curvatura") >= 0 or ct.find("r = p") >= 0,
		"colisor mostra o raio de curvatura")
	scene.collapse_panel._close()
	_check(not scene.collapse_panel.visible, "overlay de colapso fecha")


func _check_advanced() -> void:
	scene._on_open_advanced()
	_check(scene.advanced_panel.visible, "overlay de realismo avançado abre")
	var ft: String = scene.advanced_panel._fs_lbl.get_parsed_text()
	_check(ft.find("estrutura fina") >= 0 or ft.find("α") >= 0,
		"painel mostra a constante de estrutura fina")
	_check(ft.find("Dirac") >= 0, "painel mostra os níveis de Dirac")
	_check(ft.find("Lamb") >= 0, "painel menciona o deslocamento de Lamb (QED)")
	# evolução temporal: um passo conserva a norma
	_check(scene.advanced_panel._wp != null, "pacote de onda inicializado")
	var n0: float = scene.advanced_panel._wp.norm()
	scene.advanced_panel._on_step()
	var n1: float = scene.advanced_panel._wp.norm()
	_check(absf(n1 - n0) < 1e-4, "evolução temporal conserva a norma")
	_check(scene.advanced_panel._stats_lbl.get_parsed_text().find("norma") >= 0,
		"painel de estatísticas mostra a norma")
	scene.advanced_panel._close()
	_check(not scene.advanced_panel.visible, "overlay de realismo avançado fecha")


func _check_fields() -> void:
	scene._on_open_fields()
	_check(scene.fields_panel.visible, "overlay de campos & leis abre")
	var z: String = scene.fields_panel._zeeman_lbl.get_parsed_text()
	_check(z.find("Zeeman") >= 0 and z.find("Landé") >= 0,
		"painel mostra o efeito Zeeman e o fator de Landé")
	var s: String = scene.fields_panel._stark_lbl.get_parsed_text()
	_check(s.find("Stark linear") >= 0 and s.find("quadrático") >= 0,
		"painel mostra os efeitos Stark linear e quadrático")
	var u: String = scene.fields_panel._sandbox_lbl.get_parsed_text()
	_check(u.find("Rydberg") >= 0 and u.find("dêuteron") >= 0,
		"sandbox mostra Rydberg e ligação do dêuteron")
	_check(u.find("habitável") >= 0, "sandbox avalia o universo real como habitável")
	scene.fields_panel._strong_sl.value = 0.5
	scene.fields_panel._update_sandbox()
	_check(scene.fields_panel._sandbox_lbl.get_parsed_text().find("SEM ESTRELAS") >= 0,
		"sandbox detecta universo sem estrelas (forte fraca)")
	scene.fields_panel._close()
	_check(not scene.fields_panel.visible, "overlay de campos & leis fecha")


func _find_grid(node: Node) -> GridContainer:
	for c in node.get_children():
		if c is GridContainer:
			return c
		var r := _find_grid(c)
		if r != null:
			return r
	return null


func _finish() -> void:
	_check(scene.collapse_dot.visible == false and scene.cloud.visible,
		"nuvem se reexpandiu após a medição (Heisenberg)")
	_check(scene.busy == false, "sistema livre ao final")
	print("--------------------------------------------------")
	print("SMOKE: %d OK, %d FALHAS" % [ok, bad])
	quit(1 if bad > 0 else 0)
