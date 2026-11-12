"""Genera README.md y docs/VALIDACION_TECNICA.md (+ copia en la raíz) con las listas tomadas de los bloques SQL."""
import os, sys, glob
sys.path.insert(0, os.path.dirname(__file__))
from blocks import parse_blocks
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
def lst(f, cols=("ID", "TITULO")):
    return "\n".join(f"| {b['ID']} | {b['TITULO']} |" for b in parse_blocks(os.path.join(root, "database", f)))
tabla = lambda f: "| Id | Nombre |\n|---|---|\n" + lst(f)

readme = f"""# Minimarket «La Favorita» — Proyecto T3 (SQL Server)

Sistema de gestión de ventas y control de inventario para un minimarket de Comas, Lima. Este repositorio contiene la entrega **T3** de Base de Datos:
vistas, subconsultas, consultas multitabla y procedimientos almacenados sobre el modelo de **8 tablas** del T2
(`Categoria`, `Producto`, `Lote`, `Cliente`, `Empleado`, `Venta`, `Detalle_Venta`, `Comprobante`), sin cambios al modelo.

[![Pruebas SQL Server](https://github.com/angelonavarroxd23-lab/MINIMARKET-LA-FAVORITA-T3/actions/workflows/sqlserver-tests.yml/badge.svg)](https://github.com/angelonavarroxd23-lab/MINIMARKET-LA-FAVORITA-T3/actions/workflows/sqlserver-tests.yml)

## 🖥️ Aplicación web interactiva (frontend + SQL Server)

Interfaz web real sobre la base: **panel**, **punto de venta** (carrito, stock, comprobante), **ventas** (detalle y anulación), **inventario**, **clientes**, los **26 procedimientos** con formularios, las **15 vistas** y las **35 consultas** con su enunciado, código y resultado en vivo.

[![Abrir en GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/angelonavarroxd23-lab/MINIMARKET-LA-FAVORITA-T3)

- **En GitHub (Codespaces):** pulsa el botón; se crea un entorno en la nube que levanta SQL Server y la aplicación y abre la web (tarda unos minutos la primera vez). Usa tu cuota gratuita de Codespaces.
- **En tu PC (Docker Desktop):** `powershell -ExecutionPolicy Bypass -File scripts\\start_web.ps1` y abre http://localhost:3000. En Linux/macOS: `bash scripts/start_web.sh`.
- Parar: `docker compose down` (con `-v` borra también los datos). La contraseña de SQL Server se genera al azar en `.env`, que no se sube a git.
- Es una demostración académica: no hay inicio de sesión de usuarios y la API solo ejecuta los procedimientos, vistas y consultas del proyecto (no acepta SQL libre).
- Pruebas de la API contra SQL Server: `node tests/web_smoke.js` (81 pruebas); también corren en GitHub Actions (trabajo «web»).

## ▶ Ejecutar todo en GitHub (sin instalar nada)

**[Abrir el flujo «sqlserver-tests» →](https://github.com/angelonavarroxd23-lab/MINIMARKET-LA-FAVORITA-T3/actions/workflows/sqlserver-tests.yml)** y pulsar **Run workflow** (botón a la derecha) → **Run workflow**.
GitHub levanta SQL Server 2022, crea la base, carga los datos, crea las 15 vistas y los 26 procedimientos y ejecuta las pruebas. Al terminar (1 a 2 minutos) se abre la ejecución y se ve el resultado paso a paso; el registro completo queda como artefacto `ci_log`.
(Hace falta haber iniciado sesión en GitHub; los usuarios con acceso de escritura al repositorio pueden ejecutarlo.)

**Autor:** Romero Napanga Walter · **Motor:** Microsoft SQL Server 2022 (T-SQL) · **Licencia:** MIT

## Contenido de la entrega

| Requisito T3 | Cantidad | Archivo |
|---|---|---|
| Vistas | 15 | `database/04_views.sql` |
| Subconsultas | 15 | `database/05_subqueries.sql` |
| Consultas multitabla (INNER, LEFT, RIGHT, FULL JOIN) | 20 | `database/06_multitable_queries.sql` |
| Procedimientos de inserción | 8 | `database/07_procedures_insert.sql` |
| Procedimientos de modificación | 6 | `database/08_procedures_update.sql` |
| Procedimientos de eliminación | 2 | `database/09_procedures_delete.sql` |
| Procedimientos de consulta | 10 | `database/10_procedures_select.sql` |

Todos los ejercicios tienen enunciado, objetivo, código completo y explicación (están en el propio `.sql` y en el informe).

## Estructura

```
├── README.md
├── PROYECTO_T3_LA_FAVORITA.sql      script único (01 a 11 concatenados)
├── database/                        01 crear BD · 02 tablas · 03 datos · 04 vistas · 05 subconsultas · 06 multitabla
│                                    07-10 procedimientos · 11 controles de integridad
├── tests/                           test_views · test_queries · test_procedures · test_integrity (+ scripts de evidencia)
├── scripts/                         run_all.ps1 / run_all.sh · run_in_docker.ps1 · collect_evidence.ps1
├── tools/                           generadores (pruebas, evidencias, informe, documentación)
├── evidencias/                      transcripciones reales de la ejecución en SQL Server
├── docs/                            INFORME_PROYECTO_T3_LA_FAVORITA.docx · VALIDACION_TECNICA.md
├── app/                             interfaz web (Node + Express) y docker-compose.yml en la raíz
├── ci/sqlserver-tests.yml           copia del flujo de GitHub Actions (ver nota)
├── .github/workflows/sqlserver-tests.yml
└── LICENSE
```

> **Nota sobre el flujo de Actions:** debe estar en `.github/workflows/sqlserver-tests.yml`. Si al clonar solo ves `ci/sqlserver-tests.yml`, copia ese archivo a `.github/workflows/`.

## Requisitos

- SQL Server 2019 o superior (desarrollado y probado en 2022) y `sqlcmd`. Alternativa: Docker.
- Los scripts se ejecutan con `sqlcmd -I` (QUOTED_IDENTIFIER ON): la columna calculada persistida `Detalle_Venta.subtotal` lo exige.

## Cómo ejecutar

**1. SQL Server local (autenticación de Windows):**
```powershell
powershell -ExecutionPolicy Bypass -File scripts\\run_all.ps1
# con autenticación SQL:  scripts\\run_all.ps1 -Server localhost -User sa -Password $env:SA_PASSWORD
```
Crea la base `MinimarketLaFavorita`, carga datos, crea vistas y procedimientos y ejecuta todas las pruebas. Termina con error si algo falla.

**2. Contenedor Docker desechable (SQL Server 2022, contraseña aleatoria):**
```powershell
powershell -ExecutionPolicy Bypass -File scripts\\run_in_docker.ps1
```

**3. Solo el script único** (en SSMS o con `sqlcmd -S . -E -C -b -I -i PROYECTO_T3_LA_FAVORITA.sql`).

**4. GitHub Actions:** el flujo levanta SQL Server 2022, espera a que arranque, crea la base, ejecuta los scripts en orden y las pruebas, y falla si algo falla.
La contraseña viene del secreto `MSSQL_SA_PASSWORD` (opcional; si no existe se genera una aleatoria y enmascarada). No hay credenciales en el repositorio.

### Seguridad de la base de datos
`01_create_database.sql` solo elimina y recrea `MinimarketLaFavorita` si lleva la propiedad extendida `proyecto = LA_FAVORITA_T3`; si existe una base con ese nombre sin esa marca, se detiene con error y no la toca.

## Vistas
{tabla('04_views.sql')}

## Subconsultas
{tabla('05_subqueries.sql')}

## Consultas multitabla
{tabla('06_multitable_queries.sql')}

## Procedimientos almacenados
**Inserción**

{tabla('07_procedures_insert.sql')}

**Modificación**

{tabla('08_procedures_update.sql')}

**Eliminación**

{tabla('09_procedures_delete.sql')}

**Consulta**

{tabla('10_procedures_select.sql')}

Códigos de error propios: 50001 destino inexistente · 50002 duplicado · 50003 referencia (FK) inexistente · 50004 stock insuficiente · 50005 dato inválido · 50006 tiene dependencias · 50007 operación o estado no permitido · 50008 empleado inactivo · 50009 lote vencido · 50010 no autorizado.

## Pruebas

| Archivo | Pruebas | Qué comprueba |
|---|---|---|
| `tests/test_views.sql` | 21 | Existencia y resultados de las 15 vistas |
| `tests/test_queries.sql` | 35 | Filas esperadas de S01–S15 y M01–M20 |
| `tests/test_procedures.sql` | 101 | Éxito y error de los 26 procedimientos (DNI duplicado, FK inexistente, venta mayor que el stock, lote vencido, registros inexistentes, eliminación con dependencias, comprobante duplicado, importes o cantidades inválidos) |
| `tests/test_integrity.sql` | 45 | Restricciones con DML directo (2627, 547, 515, 271) |
| `database/11_integrity_tests.sql` | 17 controles | Stock no negativo, coherencia venta-detalle-total, lotes, comprobante-venta, integridad referencial |

Las pruebas son repetibles: los procedimientos se prueban dentro de una transacción que se revierte y la última prueba verifica que las 8 tablas conservan sus conteos.

## Resultado de la validación
Ejecución real en SQL Server (ver [`docs/VALIDACION_TECNICA.md`](docs/VALIDACION_TECNICA.md) y `evidencias/`): **202 pruebas aprobadas, 0 fallidas, 17 controles de integridad con 0 violaciones**.
La corrida completa también se repitió en un contenedor Linux de SQL Server 2022 (misma lógica que el flujo de Actions).

## Limitaciones
- La evidencia son transcripciones de `sqlcmd`, no capturas de pantalla de SSMS.
- El resultado del flujo de GitHub Actions solo se puede confirmar después de ejecutarlo en GitHub; aquí se validó su lógica en Docker local.
- Algunas consultas dependen de la fecha de ejecución (lotes por vencer); las pruebas lo contemplan.

## Informe
`docs/INFORME_PROYECTO_T3_LA_FAVORITA.docx`: informe T2 conservado y entrega T3 como anexos D a L, con código y resultados reales.
Los datos son ficticios (T2).
"""
open(os.path.join(root, "README.md"), "w", encoding="utf-8", newline="\n").write(readme)

val = """# Validación técnica — Proyecto T3 «La Favorita»

Fecha de la validación: 12 de noviembre de 2026. Autor: Romero Napanga Walter.

## 1. Entornos de ejecución reales

| Entorno | Motor | Uso |
|---|---|---|
| Equipo del autor (Windows) | SQL Server 16.0.1000.6 (2022), Enterprise Evaluation, collation Modern_Spanish_CI_AS | Construcción, pruebas y recolección de evidencias |
| Contenedor Docker (Linux) | SQL Server 16.0.4305.5 (2022), Developer, imagen `mcr.microsoft.com/mssql/server:2022-latest` | Réplica local de los pasos del flujo de GitHub Actions (`scripts/run_in_docker.ps1`) |

No se usó SQLite, MySQL ni PostgreSQL. Las salidas provienen de `sqlcmd`.

## 2. Resultados

| Etapa | Resultado |
|---|---|
| Scripts 01 a 11 (reconstrucción completa de la base) | 11/11 con código de salida 0 |
| `tests/test_views.sql` | 21 de 21 aprobadas |
| `tests/test_queries.sql` | 35 de 35 aprobadas |
| `tests/test_procedures.sql` | 101 de 101 aprobadas |
| `tests/test_integrity.sql` | 45 de 45 aprobadas |
| Controles de integridad (`11_integrity_tests.sql`) | 17 controles, 0 violaciones |
| Script único `PROYECTO_T3_LA_FAVORITA.sql` | Código de salida 0 en el motor local; las 4 suites de pruebas posteriores, código 0 |
| Réplica en contenedor Docker | Código de salida 0; 202 pruebas PASS, 0 FAIL |

Inventario real de la base: 8 tablas, 15 vistas, 26 procedimientos, 1 tipo de tabla; 8 PK, 10 UNIQUE, 7 FK (todas confiables), 23 CHECK, 6 DEFAULT.
Conteos originales (20/20/21/20/20/20/37/20) intactos al terminar las pruebas (TP-Z01 y TI-45).

## 3. Cobertura de casos de error y de integridad

- DNI duplicado (cliente y empleado), código de barras y comprobante duplicados.
- Claves foráneas inexistentes (producto, categoría, cliente, empleado, lote, venta).
- Venta mayor que el stock, lote vencido, empleado inactivo, medio de pago inválido, cantidades o importes ≤ 0.
- Modificación de registros inexistentes y operaciones no permitidas (mismo medio de pago, precio bajo el costo, último SUPERADMIN).
- Eliminación de registros con dependencias (cliente con ventas, producto con lotes, lote vendido, venta con detalle y comprobante, categoría con productos).
- Atomicidad: una venta fallida no deja cambios parciales (TP-I34 sin transacción externa).
- Coherencia venta-detalle-total, stock dentro de [0, cantidad inicial] y cuadre por lote, relación 1 a 1 comprobante-venta, series con numeración correlativa, `DBCC CHECKCONSTRAINTS` sin filas.

## 4. Problemas detectados durante el desarrollo y su corrección

| Problema | Corrección |
|---|---|
| Error 1934 (QUOTED_IDENTIFIER) por la columna calculada persistida | Todas las invocaciones usan `sqlcmd -I` |
| Error de sintaxis en `03_insert_data.sql` (corte de línea en la extracción) | Se regeneró desde la línea de inicio correcta del bloque de datos |
| Vista V08 con un borrador inválido (`SUM(DISTINCT total)`) | Reescritas V08–V15 con tabla derivada de unidades por venta; las pruebas TV las validan |
| Error de PowerShell al pasar argumentos a `sqlcmd` (salpicado de un solo elemento) | Argumentos tipados como `[string[]]` |
| Contenedor: `mkdir /work` sin permiso y archivos copiados como root | Se copia con `docker cp` y se ejecuta con `docker exec -u 0` (script y flujo) |

No se eliminó ninguna prueba para ocultar errores ni se debilitaron restricciones para que una corrida pasara.

## 5. Decisiones de diseño

- Modelo del T2 sin cambios: no se inventaron tablas ni columnas.
- Procedimientos anidables: confirman o revierten solo la transacción que ellos abrieron, lo que permite probarlos dentro de una transacción externa que se revierte.
- Bloqueo `UPDLOCK, HOLDLOCK` al verificar stock y al calcular el correlativo del comprobante.
- Las pruebas de consultas se generan a partir de los bloques anotados de los `.sql` (`tools/gen_test_queries.py`); la consulta S09 depende de la fecha y su valor esperado es una expresión SQL.

## 6. Lo que no se ha verificado

- **GitHub Actions:** el flujo no se ejecutó en GitHub (no existe aún una corrida). Solo se verificó su lógica en un contenedor Docker local. Debe revisarse la pestaña Actions del repositorio una vez publicado.
- **Capturas de pantalla de SSMS:** no se incluyen; la evidencia son transcripciones de `sqlcmd` en `evidencias/` (generadas con `scripts/collect_evidence.ps1`).
- **Consultas del T2 (80):** conservan los resultados esperados de la ejecución emulada del T2; en esta entrega se ejecutó en SQL Server el script de tablas y datos del T2 y todo el código nuevo del T3.
- **Otros motores o versiones** (SQL Server 2016/2017/2019): no probados.

## 7. Evidencias

`evidencias/00_build_log.txt` (construcción), `01_inventario.txt`, `02_ejercicios.txt` (resultado de cada ejercicio), `03`–`06` (pruebas), `07_controles_integridad.txt`, `08_docker_ci_log.txt` (réplica en contenedor), `09_script_unico_log.txt` (script único), `99_resumen.txt`.
"""
open(os.path.join(root, "docs", "VALIDACION_TECNICA.md"), "w", encoding="utf-8", newline="\n").write(val)
open(os.path.join(root, "VALIDACION_TECNICA_T3.md"), "w", encoding="utf-8", newline="\n").write(val)
print("ok")
