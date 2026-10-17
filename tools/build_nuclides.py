#!/usr/bin/env python3
"""Gera data/nuclides.json a partir da tabela NUBASE2020 (estados fundamentais).

Fonte: F.G. Kondev, M. Wang, W.J. Huang, S. Naimi, G. Audi,
"The NUBASE2020 evaluation of nuclear physics properties",
Chin. Phys. C 45, 030001 (2021). Massas do AME2020 (W.J. Huang et al.).

Uso:
    curl -sL -o nubase.mas20 \
      https://www-nds.iaea.org/amdc/ame2020/nubase_4.mas20.txt
    python3 tools/build_nuclides.py nubase.mas20 data/nuclides.json

Este passo é um pré-cálculo offline (o jogo apenas lê o JSON resultante).
"""
import json
import re
import sys
import os

# half-life unit -> seconds (1 ano juliano = 31556952 s)
UNITS = {
    "ys": 1e-24, "zs": 1e-21, "as": 1e-18, "fs": 1e-15, "ps": 1e-12,
    "ns": 1e-9, "us": 1e-6, "ms": 1e-3, "s": 1.0, "ks": 1e3, "Ms": 1e6,
    "Gs": 1e9, "m": 60.0, "h": 3600.0, "d": 86400.0, "y": 31556952.0,
    "ky": 3.1556952e10, "My": 3.1556952e13, "Gy": 3.1556952e16,
    "Ty": 3.1556952e19, "Py": 3.1556952e22, "Ey": 3.1556952e25,
    "Zy": 3.1556952e28, "Yy": 3.1556952e31,
}


def fnum(s):
    """Parse a NUBASE numeric field; '#' marks estimated. Returns (value, est)."""
    if s is None:
        return None, False
    t = s.strip()
    est = "#" in t
    t = t.replace("#", "").strip()
    if t == "" or t in ("*",):
        return None, est
    m = re.match(r"^[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?", t)
    if not m:
        return None, est
    try:
        return float(m.group(0)), est
    except ValueError:
        return None, est


def parse_modes(br):
    modes = []
    abund = None
    for tok in br.split(";"):
        tok = tok.strip()
        if not tok:
            continue
        if "=" in tok:
            key, val = tok.split("=", 1)
            key = key.strip()
            nums = re.findall(r"[-+]?\d*\.?\d+", val)
            pct = float(nums[0]) if nums else None
            if key == "IS":
                abund = pct
            else:
                modes.append({"m": key, "pct": pct})
        else:
            modes.append({"m": tok, "pct": None})
    return modes, abund


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else "nubase.mas20"
    out_path = sys.argv[2] if len(sys.argv) > 2 else "data/nuclides.json"
    out = []
    with open(src, "r", encoding="utf-8", errors="replace") as fh:
        for line in fh:
            if line.startswith("#") or len(line) < 31:
                continue
            a_s = line[0:3].strip()
            z_s = line[4:7].strip()
            iso = line[7:8].strip()
            if not a_s.isdigit() or not z_s.isdigit() or iso != "0":
                continue
            a = int(a_s)
            z = int(z_s)
            el = re.sub(r"[^A-Za-z]", "", line[11:16])
            if not el or a < 1:
                continue
            me, me_est = fnum(line[18:31])
            dm, _ = fnum(line[31:42])
            t_field = line[69:78].strip()
            unit = line[78:80].strip()
            hl_s = None
            hl_text = t_field
            stable = False
            p_unst = False
            if t_field in ("stbl", "STBL"):
                stable = True
                hl_text = "estável"
            elif t_field.startswith("p-unst"):
                p_unst = True
                hl_text = "p-instável"
            else:
                val, _ = fnum(t_field)
                if val is not None and unit in UNITS:
                    hl_s = val * UNITS[unit]
                    hl_text = "%s %s" % (t_field, unit)
            modes, abund = parse_modes(line[119:209])
            out.append({
                "z": z, "n": a - z, "a": a, "sym": el,
                "me_kev": round(me, 5) if me is not None else None,
                "me_est": me_est,
                "dm_kev": round(dm, 5) if dm is not None else None,
                "hl_s": hl_s, "hl_text": hl_text,
                "stable": stable, "p_unst": p_unst,
                "modes": modes, "abund": abund,
                "jpi": line[88:102].strip(), "year": line[114:118].strip(),
            })

    out.sort(key=lambda e: (e["z"], e["a"]))
    doc = {
        "meta": {
            "source": "NUBASE2020 / AME2020",
            "citation": ("F.G. Kondev, M. Wang, W.J. Huang, S. Naimi, G. Audi, "
                         "Chin. Phys. C 45, 030001 (2021); masses from AME2020"),
            "url": "https://www-nds.iaea.org/amdc/ame2020/nubase_4.mas20.txt",
            "doi": "10.1088/1674-1137/abddae",
            "units": {"me_kev": "keV", "hl_s": "s"},
            "filter": "ground states (isomer index 0)",
            "count": len(out),
        },
        "nuclides": out,
    }
    os.makedirs(os.path.dirname(out_path) or ".", exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as fh:
        json.dump(doc, fh, separators=(",", ":"), ensure_ascii=False)
    print("gravados %d nuclídeos em %s" % (len(out), out_path))


if __name__ == "__main__":
    main()
