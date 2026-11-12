# Validación técnica — Proyecto T3 «La Favorita»

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
