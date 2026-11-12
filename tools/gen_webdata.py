"""Genera app/data/explorer.json (lista blanca de vistas y consultas S/M con su texto) a partir de los bloques SQL."""
import os, re, sys, json
sys.path.insert(0, os.path.dirname(__file__))
from blocks import parse_blocks
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
def load(f): return parse_blocks(os.path.join(root, "database", f))
vistas = []
for b in load("04_views.sql"):
    m = re.search(r"VIEW\s+dbo\.(vw_\w+)", b["CODIGO"])
    vistas.append(dict(id=b["ID"], titulo=b["TITULO"], enunciado=b["ENUNCIADO"].strip(), objetivo=b["OBJETIVO"].strip(),
                       explicacion=b["EXPLICACION"].strip(), codigo=b["CODIGO_MOSTRAR"], vista=m.group(1)))
consultas = []
for f in ("05_subqueries.sql", "06_multitable_queries.sql"):
    for b in load(f):
        consultas.append(dict(id=b["ID"], titulo=b["TITULO"], enunciado=b["ENUNCIADO"].strip(), objetivo=b["OBJETIVO"].strip(),
                              explicacion=b["EXPLICACION"].strip(), codigo=b["CODIGO_MOSTRAR"], sql=b["CODIGO_MOSTRAR"].rstrip().rstrip(";")))
assert len(vistas) == 15 and len(consultas) == 35
json.dump(dict(vistas=vistas, consultas=consultas), open(os.path.join(root, "app", "data", "explorer.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print(len(vistas), "vistas,", len(consultas), "consultas")
