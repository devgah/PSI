extends RefCounted
## FASE 4 — VSEPR: geometria a partir dos domínios eletrônicos do átomo central
## (ligações σ + pares isolados). Devolve a geometria, o ângulo ideal e a
## hibridização correspondente. Os pares isolados comprimem os ângulos.

const TETRA_ANGLE := 109.4712206


## doms = número de ligantes σ; lone = pares isolados no átomo central.
static func predict(ligands: int, lone: int) -> Dictionary:
	var doms := ligands + lone
	var geom := "linear"
	var angle := 180.0
	var hyb := "sp"
	match doms:
		1:
			geom = "linear"; angle = 180.0; hyb = "s"
		2:
			if lone == 0:
				geom = "linear"; angle = 180.0; hyb = "sp"
			else:
				geom = "angular"; angle = 180.0; hyb = "sp"
		3:
			if lone == 0:
				geom = "trigonal plana"; angle = 120.0; hyb = "sp²"
			elif lone == 1:
				geom = "angular"; angle = 120.0; hyb = "sp²"
			else:
				geom = "linear"; angle = 180.0; hyb = "sp²"
		4:
			if lone == 0:
				geom = "tetraédrica"; angle = TETRA_ANGLE; hyb = "sp³"
			elif lone == 1:
				geom = "piramidal trigonal"; angle = 107.0; hyb = "sp³"
			else:
				geom = "angular"; angle = 104.5; hyb = "sp³"
		5:
			if lone == 0:
				geom = "bipiramidal trigonal"; angle = 90.0; hyb = "sp³d"
			else:
				geom = "bipiramidal trigonal (distorcida)"; angle = 90.0; hyb = "sp³d"
		6:
			geom = "octaédrica"; angle = 90.0; hyb = "sp³d²"
		_:
			geom = "desconhecida"; angle = 0.0; hyb = "—"
	return {
		"domains": doms,
		"geometry": geom,
		"ideal_angle_deg": angle,
		"hybridization": hyb,
		"lone_pairs": lone,
		"ligands": ligands,
	}
