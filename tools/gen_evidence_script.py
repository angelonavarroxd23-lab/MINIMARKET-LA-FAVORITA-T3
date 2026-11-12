"""Genera tests/evidence_run.sql: ejecuta cada vista (EJEMPLO), subconsulta, consulta multitabla y procedimiento
(EJEMPLO dentro de BEGIN TRAN ... ROLLBACK) imprimiendo una marca @@RES <id> antes de cada resultado.
La salida se usa como evidencia real en el informe (tools/build_report.py)."""
import os, re, sys
sys.path.insert(0, os.path.dirname(__file__))
from blocks import parse_blocks

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
out = ["""/* evidence_run.sql - GENERADO por tools/gen_evidence_script.py. Ejecuta todos los ejercicios para capturar su salida real.
   Los procedimientos se prueban dentro de BEGIN TRANSACTION ... ROLLBACK: la base no se modifica. */
USE MinimarketLaFavorita;
GO"""]
for fname, kind in (("04_views.sql", "view"), ("05_subqueries.sql", "query"), ("06_multitable_queries.sql", "query"),
                    ("07_procedures_insert.sql", "proc"), ("08_procedures_update.sql", "proc"),
                    ("09_procedures_delete.sql", "proc"), ("10_procedures_select.sql", "proc")):
    for b in parse_blocks(os.path.join(ROOT, "database", fname)):
        i = b["ID"]
        out.append(f"PRINT '@@RES {i}';")
        if kind == "view":
            out.append(b["EJEMPLO"].strip() + "\nGO")
        elif kind == "query":
            out.append(re.sub(r"\n\s*GO\s*$", "", b["CODIGO"]).strip() + "\nGO")
        else:
            out.append("BEGIN TRANSACTION;\n" + b["EJEMPLO"].strip() + "\nROLLBACK TRANSACTION;\nGO")
        out.append(f"PRINT '@@END {i}';\nGO")
open(os.path.join(ROOT, "tests", "evidence_run.sql"), "w", encoding="utf-8").write("\n".join(out) + "\n")
print("ok")
