# PSI — Simulador Atômico 3D

> simulação interativa de estrutura atômica em Godot 4.4, com GDScript e conjuntos de dados em JSON.

```text
$ cat about.txt
nome no project.godot: Atom - Simulador Atômico 3D
objetivo: visualizar e manipular física atômica e nuclear em tempo real
cena principal: scenes/Main.tscn
```

## o que tem dentro

- nuvem eletrônica da função de onda, canhão de fótons e espectro
- tabela periódica, blindagem de Slater, Z_eff, raios atômicos e energias de ionização
- núcleo atômico: fórmula de Weizsäcker, números mágicos, vale de estabilidade e cadeias de decaimento
- moléculas, potencial de Morse, reações, campos e zoom partônico com quarks e glúons

## stack

- Godot 4.4 com Forward Plus
- GDScript
- Python
- dados tabulados em JSON

## como rodar

1. instale o Godot 4.4 ou superior
2. abra o arquivo `project.godot`
3. rode a cena principal com F5, ou execute:

```bash
godot --path .
```

## estrutura

- `scenes/Main.tscn` - cena principal
- `scripts/` - física, modelos 3D e painéis
- `data/` - tabelas e conjuntos de dados em JSON
