"""Genera tests/test_queries.sql a partir de database/05_subqueries.sql y 06_multitable_queries.sql.
Cada consulta se envuelve en SELECT COUNT(*) FROM (...) y se compara con el número de filas de referencia
(tools/expected_counts.json). Uso:  python tools/gen_test_queries.py"""
import json, os, re, sys
sys.path.insert(0, os.path.dirname(__file__))
from blocks import parse_blocks

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
exp_path = os.path.join(ROOT, "tools", "expected_counts.json")
expected = json.load(open(exp_path)) if os.path.exists(exp_path) else {}

out = ["""/* ============================================================================
   test_queries.sql - Pruebas de las 15 subconsultas y las 20 consultas multitabla
   (archivo GENERADO por tools/gen_test_queries.py; no editar a mano)
   Cada consulta se ejecuta dentro de SELECT COUNT(*) y su número de filas se
   compara con el valor de referencia verificado contra los datos de prueba.
   ============================================================================ */
USE MinimarketLaFavorita;
GO
SET NOCOUNT ON;
CREATE TABLE #r (
    id VARCHAR(8) NOT NULL, prueba NVARCHAR(160) NOT NULL, esperado NVARCHAR(200) NOT NULL, obtenido NVARCHAR(200) NULL,
    estado AS CASE WHEN esperado = ISNULL(obtenido, N'') THEN 'PASS' ELSE 'FAIL' END);
GO"""]
for fname in ("05_subqueries.sql", "06_multitable_queries.sql"):
    for b in parse_blocks(os.path.join(ROOT, "database", fname)):
        code = re.sub(r"\n\s*GO\s*$", "", b["CODIGO"]).strip()
        code = re.sub(r";\s*$", "", code)
        idx = [m.start() for m in re.finditer(r"\nORDER BY ", code)]
        if idx:
            code = code[: idx[-1]]
        tid = "TQ-" + b["ID"]
        title = b["TITULO"].replace("'", "''")
        exp = expected.get(b["ID"], -1)
        exp_sql = f"CAST({exp[1:]} AS NVARCHAR(20))" if isinstance(exp, str) and exp.startswith("=") else f"'{exp}'"
        out.append(f"INSERT #r (id, prueba, esperado, obtenido)\nSELECT '{tid}', N'{b['ID']}: {title} (filas)', {exp_sql}, CAST(COUNT(*) AS NVARCHAR(20))\nFROM (\n{code}\n) q;")
out.append("""GO
SELECT id, prueba, esperado, obtenido, estado FROM #r ORDER BY id;
SELECT COUNT(*) AS pruebas, SUM(CASE WHEN estado = 'PASS' THEN 1 ELSE 0 END) AS aprobadas, SUM(CASE WHEN estado = 'FAIL' THEN 1 ELSE 0 END) AS fallidas FROM #r;
DECLARE @fallidas INT = (SELECT COUNT(*) FROM #r WHERE estado = 'FAIL');
IF @fallidas > 0 THROW 50095, N'Hay consultas con resultados distintos a los esperados.', 1;
GO""")
open(os.path.join(ROOT, "tests", "test_queries.sql"), "w", encoding="utf-8").write("\n".join(out) + "\n")
print("generado:", len(out) - 2, "consultas")
