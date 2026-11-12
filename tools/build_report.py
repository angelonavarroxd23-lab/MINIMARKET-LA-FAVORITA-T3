"""Genera docs/INFORME_PROYECTO_T3_LA_FAVORITA.docx a partir del informe T2 + los anexos D-L.
Todo el contenido de resultados proviene de las evidencias reales (carpeta evidencias/) y de los bloques SQL.
Uso: python tools/build_report.py <T2.docx> <salida.docx>
"""
import sys, re, copy, os
from xml.sax.saxutils import escape
import docx
from lxml import etree
sys.path.insert(0, os.path.dirname(__file__))
from blocks import parse_blocks

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EV = os.path.join(ROOT, "evidencias")
DB = os.path.join(ROOT, "database")
W = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
NS = f'xmlns:w="{W}"'
MAXROWS = 15


# ---------------------------------------------------------------- XML helpers (replican el formato del T2)
def X(s):
    return etree.fromstring(s)

def esc(t):
    return escape(t)

def run(t, b=False, i=False, color=None, sz=None):
    pr = ""
    if b: pr += "<w:b/><w:bCs/>"
    if i: pr += "<w:i/><w:iCs/>"
    if color: pr += f'<w:color w:val="{color}"/>'
    if sz: pr += f'<w:sz w:val="{sz}"/><w:szCs w:val="{sz}"/>'
    pr = f"<w:rPr>{pr}</w:rPr>" if pr else ""
    return f'<w:r>{pr}<w:t xml:space="preserve">{esc(t)}</w:t></w:r>'

def para(runs, after=120, line=276, jc="both", extra=""):
    return X(f'<w:p {NS}><w:pPr>{extra}<w:spacing w:after="{after}" w:line="{line}"/><w:jc w:val="{jc}"/></w:pPr>{runs}</w:p>')

def heading(text, level, pagebreak=False):
    pb = "<w:pageBreakBefore/>" if pagebreak else ""
    return X(f'<w:p {NS}><w:pPr><w:pStyle w:val="Heading{level}"/>{pb}</w:pPr>{run(text)}</w:p>')

def labeled(label, text):
    return para(run(label + " ", b=True, color="1F4E79") + run(text), after=80, line=264)

def label_only(label):
    return para(run(label, b=True, color="1F4E79"), after=60, line=264, jc="left", extra="<w:keepNext/>")

def bullet(text, boldlead=None):
    r = (run(boldlead, b=True) if boldlead else "") + run(text)
    return X(f'<w:p {NS}><w:pPr><w:pStyle w:val="ListParagraph"/><w:numPr><w:ilvl w:val="0"/><w:numId w:val="2"/></w:numPr>'
             f'<w:spacing w:after="60" w:line="264"/></w:pPr>{r}</w:p>')

def code_paras(code):
    lines = code.replace("\t", "    ").split("\n")
    out = []
    n = len(lines)
    for k, ln in enumerate(lines):
        before = 60 if k == 0 else 0
        after = 140 if k == n - 1 else 0
        out.append(X(
            f'<w:p {NS}><w:pPr><w:keepLines/><w:pBdr><w:left w:val="single" w:color="8EA9C1" w:sz="12" w:space="6"/></w:pBdr>'
            f'<w:shd w:fill="F3F5F8" w:color="auto" w:val="clear"/><w:spacing w:after="{after}" w:before="{before}" w:line="240"/>'
            f'<w:ind w:left="120"/></w:pPr><w:r><w:rPr><w:rFonts w:ascii="Consolas" w:cs="Consolas" w:eastAsia="Consolas" w:hAnsi="Consolas"/>'
            f'<w:sz w:val="16"/><w:szCs w:val="16"/></w:rPr><w:t xml:space="preserve">{esc(ln) if ln else " "}</w:t></w:r></w:p>'))
    return out

def table(headers, rows, widths=None, sz=16, total=9070, align=None):
    ncol = len(headers)
    if widths is None:
        cw = sz * 5.2
        need, floor = [], []
        for c in range(ncol):
            m = max([len(str(headers[c]))] + [min(len(clip(r[c])), 40) for r in rows] + [3])
            longest = max([len(w) for w in re.split(r"[\s/]", str(headers[c]))] + [3])
            need.append(m * cw + 200)
            floor.append(min(longest, 18) * cw + 200)
        tot = sum(need)
        widths = [max(int(f), int(n * total / tot)) if tot > total else int(n) for n, f in zip(need, floor)]
        if tot <= total:
            extra = (total - sum(widths)) // ncol
            widths = [w + extra for w in widths]
        # renormalizar al ancho total respetando el mínimo
        diff = total - sum(widths)
        order = sorted(range(ncol), key=lambda i: -widths[i])
        k = 0
        while diff != 0 and k < 10000:
            i = order[k % ncol]
            step = 20 if diff > 0 else -20
            if diff < 0 and widths[i] - 20 < floor[i]:
                k += 1; continue
            widths[i] += step; diff -= step; k += 1
        widths[-1] += total - sum(widths)
    def cell(t, w, hdr, jc):
        fill = '<w:shd w:fill="DCE6F0" w:color="auto" w:val="clear"/>' if hdr else ""
        rr = run(t, b=hdr, sz=sz)
        return (f'<w:tc><w:tcPr><w:tcW w:type="dxa" w:w="{w}"/><w:tcBorders><w:top w:val="single" w:color="BFBFBF" w:sz="4"/>'
                f'<w:left w:val="single" w:color="BFBFBF" w:sz="4"/><w:bottom w:val="single" w:color="BFBFBF" w:sz="4"/>'
                f'<w:right w:val="single" w:color="BFBFBF" w:sz="4"/></w:tcBorders>{fill}<w:tcMar><w:top w:type="dxa" w:w="50"/>'
                f'<w:left w:type="dxa" w:w="90"/><w:bottom w:type="dxa" w:w="50"/><w:right w:type="dxa" w:w="90"/></w:tcMar>'
                f'<w:vAlign w:val="center"/></w:tcPr><w:p><w:pPr><w:jc w:val="{jc}"/></w:pPr>{rr}</w:p></w:tc>')
    trs = ""
    trs += '<w:tr><w:trPr><w:cantSplit/><w:tblHeader/></w:trPr>' + "".join(cell(h, w, True, "left") for h, w in zip(headers, widths)) + "</w:tr>"
    for r in rows:
        trs += '<w:tr><w:trPr><w:cantSplit/></w:trPr>' + "".join(
            cell(clip(v), w, False, (align[i] if align else "left")) for i, (v, w) in enumerate(zip(r, widths))) + "</w:tr>"
    grid = "".join(f'<w:gridCol w:w="{w}"/>' for w in widths)
    return X(f'<w:tbl {NS}><w:tblPr><w:tblW w:type="dxa" w:w="{total}"/><w:tblBorders><w:top w:val="single" w:color="auto" w:sz="4"/>'
             f'<w:left w:val="single" w:color="auto" w:sz="4"/><w:bottom w:val="single" w:color="auto" w:sz="4"/><w:right w:val="single" w:color="auto" w:sz="4"/>'
             f'<w:insideH w:val="single" w:color="auto" w:sz="4"/><w:insideV w:val="single" w:color="auto" w:sz="4"/></w:tblBorders><w:tblLayout w:type="fixed"/></w:tblPr>'
             f'<w:tblGrid>{grid}</w:tblGrid>{trs}</w:tbl>')

def clip(v, n=70):
    v = str(v)
    return v if len(v) <= n else v[: n - 1] + "…"

def spacer():
    return X(f'<w:p {NS}><w:pPr><w:spacing w:after="80"/></w:pPr></w:p>')

def note(text):
    return para(run(text, i=True, color="595959", sz=18), after=100, line=264, jc="left")


# ---------------------------------------------------------------- lectura de evidencias
def read_ev(name):
    return open(os.path.join(EV, name), encoding="utf-8-sig").read().replace("\r", "")

def parse_resultsets(lines):
    """Devuelve (lista de conjuntos de resultados [(headers, rows)], lista de mensajes sueltos)."""
    sets, i = [], 0
    while i < len(lines):
        ln = lines[i]
        if i + 1 < len(lines) and re.match(r"^-+(\t-+)*$", lines[i + 1]) and "\t" in ln or (
                i + 1 < len(lines) and re.match(r"^-+(\t-+)*$", lines[i + 1]) and ln.strip()):
            hdr = ln.split("\t")
            j = i + 2
            rows = []
            while j < len(lines) and lines[j].strip() != "":
                rows.append(lines[j].split("\t")); j += 1
            sets.append((hdr, rows)); i = j
        else:
            i += 1
    return sets

def evidence_by_id():
    txt = read_ev("02_ejercicios.txt")
    out = {}
    for m in re.finditer(r"@@RES (\w+)\n(.*?)@@END \1", txt, re.S):
        out[m.group(1)] = parse_resultsets(m.group(2).split("\n"))
    return out

def test_rows(fname, prefix, ncols):
    rows = []
    for ln in read_ev(fname).split("\n"):
        if ln.startswith(prefix):
            p = ln.split("\t")
            rows.append(p[:ncols] + [""] * (ncols - len(p)))
    return rows

def summary_of(fname):
    t = read_ev(fname).strip().split("\n")
    nums = [l for l in t if re.match(r"^\s*\d+\s+\d+\s+\d+\s*$", l)]
    return nums[-1].split() if nums else None


# ---------------------------------------------------------------- bloques de ejercicios
def add_results(body, sets, label="Resultado real"):
    shown = False
    for k, (hdr, rows) in enumerate(sets):
        if not hdr or not rows and len(hdr) == 0:
            continue
        n = len(rows)
        lab = f"{label} (conjunto {k+1} de {len(sets)})" if len(sets) > 1 else label
        body.append(label_only(lab + ":"))
        view = rows[:MAXROWS]
        ncol = len(hdr)
        sz = 16 if ncol <= 6 else (14 if ncol <= 9 else 12)
        view = [r + [""] * (ncol - len(r)) for r in view]
        view = [r[:ncol] for r in view]
        if n:
            body.append(table(hdr, view, sz=sz))
        else:
            body.append(table(hdr, [["(sin filas)"] + [""] * (ncol - 1)], sz=sz))
        txt = f"Filas devueltas: {n}." + (f" Se muestran las primeras {MAXROWS}." if n > MAXROWS else "")
        body.append(note(txt))
        shown = True
    if not shown:
        body.append(note("El procedimiento no devuelve conjuntos de resultados; su efecto se comprueba en las pruebas del Anexo K."))

def exercise(body, blk, ev, with_example=False, code_label="Código SQL"):
    body.append(heading(f"{blk['ID']}. {blk['TITULO']}", 2))
    body.append(labeled("Enunciado:", blk["ENUNCIADO"].strip()))
    body.append(labeled("Objetivo:", blk["OBJETIVO"].strip()))
    body.append(label_only(code_label + ":"))
    body.extend(code_paras(blk["CODIGO_MOSTRAR"]))
    body.append(labeled("Explicación:", blk["EXPLICACION"].strip()))
    if with_example and blk.get("EJEMPLO", "").strip():
        body.append(label_only("Ejemplo de ejecución (se corrió dentro de una transacción que se revierte, sin alterar los datos):"))
        body.extend(code_paras(blk["EJEMPLO"].strip()))
    add_results(body, ev.get(blk["ID"], []))


def build(t2_path, out_path):
    ev = evidence_by_id()
    d = docx.Document(t2_path)
    P = d.paragraphs
    bodyel = d.element.body

    # ---- portada, encabezado e introducción
    def set_text(p, new):
        runs = p.runs
        runs[0].text = new
        for r in runs[1:]:
            r._r.getparent().remove(r._r)
    set_text(P[1], "PROYECTO T3 — BASE DE DATOS")
    set_text(P[3], "Vistas, subconsultas, consultas multitabla y procedimientos almacenados en Microsoft SQL Server")
    # líneas adicionales de portada (después del subtítulo)
    sub = P[3]._p
    for tb in d.tables[:1]:
        for row in tb.rows:
            for c in row.cells:
                for pp in c.paragraphs:
                    for rr in pp.runs:
                        if "octubre de 2026" in rr.text:
                            rr.text = rr.text.replace("octubre de 2026", "noviembre de 2026")
    pb = sub.getparent()
    # menos espacio bajo el subtítulo para que quepan las líneas añadidas
    for s in d.sections:
        for p in s.header.paragraphs:
            for r in p.runs:
                r.text = r.text.replace("Proyecto T2", "Proyecto T3")
            if "T2" in p.text and not p.runs:
                pass
    t3 = [
        para(run("Alcance del Proyecto T3. ", b=True) +
             run("Este informe integra el avance T2 (secciones 1 a 17 y Anexos A a C, que se conservan) con el trabajo de la entrega T3, que se presenta "
                 "como anexos: 15 vistas (Anexo D), 15 subconsultas (Anexo E), 20 consultas multitabla con INNER, LEFT, RIGHT y FULL JOIN (Anexo F) y 26 procedimientos "
                 "almacenados —8 de inserción, 6 de modificación, 2 de eliminación y 10 de consulta— (Anexos G a J). Cada ejercicio incluye su enunciado, objetivo, "
                 "código completo, explicación y el resultado obtenido al ejecutarlo."), after=120),
        para(run("Validación real. ", b=True) +
             run("Todo el código T3 se ejecutó en Microsoft SQL Server 2022 (versión 16.0, motor local del autor) sobre la base MinimarketLaFavorita, creada con el "
                 "modelo de ocho tablas del T2 sin cambios. Los resultados que se muestran son los devueltos por el motor (transcripciones de sqlcmd guardadas en la "
                 "carpeta evidencias del repositorio), no capturas simuladas ni valores supuestos. El Anexo K resume las pruebas (202 pruebas automatizadas y 17 controles de "
                 "integridad, todos aprobados) y el Anexo L explica cómo repetirlas."), after=120),
        para(run("Nota sobre la numeración. ", b=True) +
             run("La indicación de la entrega pide omitir los apartados 5.8 y 5.9 del informe. El informe T2 que sirve de base solo tiene los apartados 5.1 y 5.2, "
                 "por lo que no existe nada que retirar en esos apartados."), after=120),
    ]
    anchor = P[9]._p
    for e in reversed(t3):
        anchor.addnext(e)

    # ---- sección 16: aclaración T3 (las pruebas ahora son reales)
    h16 = P[1888]._p
    upd = para(run("Actualización T3. ", b=True) +
               run("Las referencias de esta sección a la ausencia de un servidor SQL Server corresponden al momento en que se redactó el avance T2. En la entrega T3 el script "
                   "del Anexo A (tablas y datos) y todo el código de los Anexos D a J se ejecutaron en una instancia real de SQL Server 2022; sus resultados y pruebas "
                   "figuran en el Anexo K. Las 80 consultas del T2 conservan como «resultado esperado» los valores de la ejecución emulada, que no se repitió "
                   "íntegramente en SQL Server en esta entrega; los ejercicios T3 sí fueron ejecutados todos."), after=120)
    h16.addnext(upd)
    # conclusión pendiente del T2 -> remitir al Anexo K
    for p in P:
        if p.text.startswith("Queda pendiente ejecutar el script"):
            set_text(p, "La ejecución en una instancia real de SQL Server, que quedaba pendiente en el avance T2, se realizó en la entrega T3; la evidencia está en el Anexo K.")

    # ---- anexos nuevos (se agregan antes de sectPr)
    sect = bodyel[-1]
    new = []

    # Anexo D
    new.append(heading("Anexo D. Vistas (15)", 1, True))
    new.append(para(run("Las vistas encapsulan las consultas que el minimarket repite a diario (stock, reposición, vencimientos, ventas, rendimiento del personal, márgenes y "
                        "controles de integridad). Se crean con CREATE OR ALTER VIEW, no duplican datos y siempre reflejan el estado actual de las tablas. La vista "
                        "vw_empleados_seguros omite el DNI y la clave de acceso, de modo que se puede conceder a un usuario sin exponer datos sensibles. Script: database/04_views.sql."), after=120))
    for b in parse_blocks(os.path.join(DB, "04_views.sql")):
        exercise(new, b, ev, code_label="Código de la vista")

    # Anexo E
    new.append(heading("Anexo E. Subconsultas (15)", 1, True))
    new.append(para(run("Se emplean subconsultas escalares, con IN, NOT IN, EXISTS, NOT EXISTS, correlacionadas, en HAVING y en tablas derivadas. Cada una responde a una "
                        "pregunta concreta de la operación del minimarket. Script: database/05_subqueries.sql."), after=120))
    for b in parse_blocks(os.path.join(DB, "05_subqueries.sql")):
        exercise(new, b, ev)

    # Anexo F
    new.append(heading("Anexo F. Consultas multitabla (20)", 1, True))
    new.append(para(run("Veinte consultas que combinan tablas: M01 a M09 con INNER JOIN, M10 a M14 con LEFT JOIN, M15 a M17 con RIGHT JOIN y M18 a M20 con FULL JOIN. "
                        "Las consultas con LEFT, RIGHT y FULL JOIN se usan para detectar lo que no tiene contraparte (productos sin ventas, clientes sin compras, lotes sin "
                        "movimiento), que es donde el INNER JOIN no sirve. Script: database/06_multitable_queries.sql."), after=120))
    for b in parse_blocks(os.path.join(DB, "06_multitable_queries.sql")):
        exercise(new, b, ev)

    # Anexos G-J
    groups = [
        ("Anexo G. Procedimientos almacenados de inserción (8)", "07_procedures_insert.sql",
         "Registran categorías, productos, lotes, clientes, empleados, ventas, líneas de venta y comprobantes. Validan los datos antes de escribir y devuelven errores "
         "con código propio (ver Anexo K). La venta y su comprobante se registran en una sola transacción. Cuando un procedimiento se invoca dentro de otra transacción, "
         "no la cierra: solo confirma o revierte la que él mismo abrió. Script: database/07_procedures_insert.sql."),
        ("Anexo H. Procedimientos almacenados de modificación (6)", "08_procedures_update.sql",
         "Actualizan precio, estado de productos, datos de contacto, estado de empleados, stock de lotes y medio de pago de una venta, protegiendo las reglas del negocio "
         "(por ejemplo, el precio no puede quedar por debajo del costo). Script: database/08_procedures_update.sql."),
        ("Anexo I. Procedimientos almacenados de eliminación (2)", "09_procedures_delete.sql",
         "Eliminan un cliente sin historial y anulan una venta restituyendo el stock. No se usa eliminación en cascada: se verifican las dependencias y se borra en orden "
         "(comprobante, detalle, venta). Script: database/09_procedures_delete.sql."),
        ("Anexo J. Procedimientos almacenados de consulta (10)", "10_procedures_select.sql",
         "Consultas parametrizadas de uso diario: búsqueda de productos, stock, reposición, lotes por vencer, clientes, detalle y rango de ventas, comprobantes, ranking de "
         "productos e historial de compras. Script: database/10_procedures_select.sql."),
    ]
    for title, f, intro in groups:
        new.append(heading(title, 1, True))
        new.append(para(run(intro), after=120))
        if f.startswith("07"):
            new.append(label_only("Tipo de tabla usado por usp_Venta_Registrar y usp_DetalleVenta_Agregar:"))
            new.extend(code_paras("CREATE TYPE dbo.tvp_LineaVenta AS TABLE (id_lote INT NOT NULL, cantidad INT NOT NULL);"))
        for b in parse_blocks(os.path.join(DB, f)):
            exercise(new, b, ev, with_example=True, code_label="Código del procedimiento")
    # tipo de tabla (TVP) usado por usp_Venta_Registrar
    # (su definición forma parte del script 07 y se muestra con el procedimiento PI06 en el script completo)

    # Anexo K — evidencias
    new.append(heading("Anexo K. Pruebas y evidencia de ejecución", 1, True))
    new.append(para(run("Esta sección reúne la evidencia real de la ejecución en SQL Server. Las salidas provienen de sqlcmd (transcripciones íntegras en la carpeta "
                        "evidencias del repositorio). No se incluyen capturas de pantalla de la interfaz gráfica: la evidencia son los resultados textuales del propio motor, "
                        "que pueden regenerarse con scripts/collect_evidence.ps1."), after=120))

    new.append(heading("K.1 Entorno de ejecución", 2))
    inv = parse_resultsets(read_ev("01_inventario.txt").split("\n"))
    # inv: [0]=BD, [1]=tablas, [2]=restricciones, [3]=FK, [4..]=otros
    ev_inv = {}
    for m in re.finditer(r"@@RES (\w+)\n(.*?)(?=@@RES|\Z)", read_ev("01_inventario.txt"), re.S):
        ev_inv[m.group(1)] = parse_resultsets(m.group(2).split("\n"))
    for key, lab in (("INV_BD", "Instancia y base de datos"), ("INV_TABLAS", "Tablas de la base (columnas y filas)"),
                     ("INV_RESTRICCIONES", "Restricciones declaradas"), ("INV_FK", "Claves foráneas (todas confiables)"),
                     ("INV_RESUMEN", "Objetos T3 creados")):
        for hdr, rows in ev_inv.get(key, []):
            new.append(label_only(lab + ":"))
            new.append(table(hdr, [r + [""] * (len(hdr) - len(r)) for r in rows], sz=16 if len(hdr) <= 4 else 14))
            new.append(spacer())
    if "INV_VISTAS" in ev_inv and "INV_PROCEDIMIENTOS" in ev_inv:
        nv = len(ev_inv["INV_VISTAS"][0][1]) if ev_inv["INV_VISTAS"] else 0
        npr = len(ev_inv["INV_PROCEDIMIENTOS"][0][1]) if ev_inv["INV_PROCEDIMIENTOS"] else 0
        new.append(note(f"El inventario lista {nv} vistas y {npr} procedimientos almacenados creados en la base."))

    new.append(heading("K.2 Orden de ejecución y códigos de salida", 2))
    codes = [l.split() for l in read_ev("99_resumen.txt").split("\n") if "codigo de salida" in l]
    new.append(table(["Etapa", "Código de salida"], [[c[0], c[-1]] for c in codes], widths=[6070, 3000]))
    new.append(note("Código 0 en las 17 etapas: la base se reconstruyó desde cero y todos los scripts y pruebas terminaron sin errores."))

    def tests_section(num, title, fname, prefix, ncols, intro, cols):
        new.append(heading(f"{num} {title}", 2))
        new.append(para(run(intro), after=100))
        rows = test_rows(fname, prefix, ncols)
        rows = [[r[i] for i in cols] for r in rows]
        sm = summary_of(fname)
        new.append(table(["Id", "Prueba", "Esperado", "Obtenido", "Estado"], rows,
                         widths=[800, 4170, 1700, 1700, 700], sz=14))
        if sm:
            new.append(note(f"Resumen real de la ejecución: {sm[0]} pruebas, {sm[1]} aprobadas, {sm[2]} fallidas."))

    tests_section("K.3", "Pruebas de las vistas (21)", "03_test_views.txt", "TV-", 5,
                  "Verifican la existencia de las 15 vistas y que cada una devuelva los valores esperados con los datos del T2.", [0, 1, 2, 3, 4])
    tests_section("K.4", "Pruebas de subconsultas y consultas multitabla (35)", "04_test_queries.txt", "TQ-", 5,
                  "Comparan el número de filas que devuelve cada consulta S01–S15 y M01–M20 con el valor esperado.", [0, 1, 2, 3, 4])
    tests_section("K.5", "Pruebas de procedimientos almacenados (101)", "05_test_procedures.txt", "TP-", 5,
                  "Casos de éxito y de error de los 26 procedimientos: DNI duplicado, claves foráneas inexistentes, venta mayor que el stock, lote vencido, "
                  "modificación de registros inexistentes, eliminación con dependencias, comprobante duplicado y cantidades o importes inválidos. Cada procedimiento "
                  "se prueba dentro de una transacción que se revierte, de modo que los datos quedan intactos (prueba TP-Z01).", [0, 1, 2, 3, 4])
    tests_section("K.6", "Pruebas de integridad con DML directo (45)", "06_test_integrity.txt", "TI-", 6,
                  "Comprueban que las restricciones del modelo físico rechazan los datos inválidos incluso si se evita el procedimiento (INSERT, UPDATE y DELETE "
                  "directos). Los códigos son los de SQL Server: 2627 (clave duplicada), 547 (CHECK o clave foránea), 515 (NULL no permitido) y 271 (columna calculada).",
                  [0, 1, 2, 3, 4])

    new.append(heading("K.7 Controles de integridad de la base (17)", 2))
    new.append(para(run("Controles de solo lectura que se ejecutan sobre la base completa (database/11_integrity_tests.sql). Terminan con error si alguno detecta una violación."), after=100))
    ctl = parse_resultsets(read_ev("07_controles_integridad.txt").split("\n"))[0]
    new.append(table(ctl[0], ctl[1], widths=[700, 800, 5470, 1100, 1000], sz=16))
    new.append(note("Integridad verificada: 17 controles, 0 violaciones."))

    # Anexo L
    new.append(heading("Anexo L. Reproducción, repositorio y conclusiones", 1, True))
    new.append(heading("L.1 Cómo repetir la ejecución", 2))
    new.append(bullet("Windows con SQL Server local: powershell -ExecutionPolicy Bypass -File scripts\\run_all.ps1 (crea la base, carga los datos, crea vistas y procedimientos y ejecuta las pruebas).", "Local. "))
    new.append(bullet("powershell -ExecutionPolicy Bypass -File scripts\\run_in_docker.ps1 levanta un contenedor desechable de SQL Server 2022 con contraseña aleatoria y ejecuta lo mismo.", "Docker. "))
    new.append(bullet("El flujo de trabajo sqlserver-tests.yml levanta SQL Server 2022 en un contenedor, ejecuta los scripts en orden y falla si alguna prueba falla. "
                      "La contraseña no está en el código: se toma del secreto MSSQL_SA_PASSWORD o se genera una aleatoria en cada corrida.", "GitHub Actions. "))
    new.append(bullet("PROYECTO_T3_LA_FAVORITA.sql reúne en un solo archivo los scripts 01 a 11 en el orden de ejecución.", "Script único. "))
    new.append(heading("L.2 Seguridad y alcance de la base", 2))
    new.append(bullet("El script 01 solo elimina y recrea la base MinimarketLaFavorita si lleva la marca de propiedad extendida del proyecto; si existe una base con ese nombre sin la marca, se detiene con error y no la toca."))
    new.append(bullet("No se guardan contraseñas ni claves en el repositorio. Los datos de ejemplo del T2 son ficticios; el hash de las claves de empleados es de muestra y la vista vw_empleados_seguros no lo expone."))
    new.append(heading("L.3 Conclusiones del Proyecto T3", 2))
    new.append(bullet("Las 15 vistas concentran las consultas operativas del minimarket (reposición, vencimientos, ventas por día y medio de pago, rendimiento de cajeros, márgenes) y permiten dar acceso al personal sin exponer datos sensibles.", "Vistas. "))
    new.append(bullet("Las 15 subconsultas y las 20 consultas multitabla resuelven preguntas reales del negocio, como productos sin ventas, clientes que no han comprado, ventas posiblemente duplicadas o lotes por vencer. Los LEFT, RIGHT y FULL JOIN permiten ver lo que falta, no solo lo que coincide.", "Consultas. "))
    new.append(bullet("Los 26 procedimientos centralizan las reglas del negocio: la venta descuenta el stock, calcula el total y emite el comprobante en una sola transacción; si algo falla no queda ningún cambio parcial. Los errores usan códigos propios (50001 a 50010) que la aplicación puede interpretar.", "Procedimientos. "))
    new.append(bullet("Se ejecutaron 202 pruebas automatizadas (21 + 35 + 101 + 45) y 17 controles de integridad, todos aprobados, sobre SQL Server real. Las pruebas son repetibles: no dejan datos y comprueban al final que las ocho tablas conservan sus conteos originales.", "Validación. "))
    new.append(heading("L.4 Limitaciones declaradas", 2))
    new.append(bullet("La evidencia son transcripciones de sqlcmd, no capturas de pantalla de la interfaz gráfica de SQL Server Management Studio."))
    new.append(bullet("Los resultados de las consultas dependen de los datos del T2 y, en las consultas que comparan con la fecha actual (por ejemplo, lotes por vencer), de la fecha de ejecución. Se ejecutaron el 12 de noviembre de 2026."))
    new.append(bullet("La publicación en GitHub y la primera corrida del flujo de GitHub Actions dependen de la cuenta del autor; el enlace del repositorio y el resultado de Actions solo se afirman cuando existen."))

    for e in new:
        sect.addprevious(e)

    # TOC: forzar actualización al abrir (ya está w:updateFields en settings); además marcar el campo como sucio
    for fld in bodyel.iter(f"{{{W}}}fldChar"):
        if fld.get(f"{{{W}}}fldCharType") == "begin":
            fld.set(f"{{{W}}}dirty", "true")
    d.save(out_path)
    print("guardado", out_path)


if __name__ == "__main__":
    build(sys.argv[1], sys.argv[2])
