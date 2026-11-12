"""Lee los bloques /*@@ ... @@*/ de los scripts SQL (enunciado, objetivo, explicación, ejemplo y código)."""
import re

KEYS = ("ID", "TITULO", "ENUNCIADO", "OBJETIVO", "EXPLICACION", "EJEMPLO")


def parse_blocks(path):
    text = open(path, encoding="utf-8").read()
    parts = re.split(r"/\*@@\n", text)[1:]
    blocks = []
    for part in parts:
        head, _, code = part.partition("@@*/")
        fields, cur = {}, None
        for line in head.splitlines():
            m = re.match(r"^(ID|TITULO|ENUNCIADO|OBJETIVO|EXPLICACION|EJEMPLO):\s?(.*)$", line)
            if m:
                cur = m.group(1)
                fields[cur] = m.group(2)
            elif cur:
                fields[cur] += "\n" + line
        code_lines = []
        for ln in code.splitlines():
            if re.match(r"^\s*/\*\s*-{5,}.*-{5,}\s*\*/\s*$", ln):   # separadores de sección
                continue
            code_lines.append(ln)
        code = "\n".join(code_lines).strip("\n")
        fields["CODIGO"] = code
        # código sin GO final (para mostrar en el informe)
        fields["CODIGO_MOSTRAR"] = re.sub(r"\n\s*GO\s*$", "", code).strip()
        blocks.append(fields)
    return blocks
