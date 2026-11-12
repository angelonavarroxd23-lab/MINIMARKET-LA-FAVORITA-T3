# Minimarket «La Favorita» — Proyecto T3 (SQL Server)

Sistema de gestión de ventas y control de inventario para un minimarket de Comas, Lima. Este repositorio contiene la entrega **T3** de Base de Datos:
vistas, subconsultas, consultas multitabla y procedimientos almacenados sobre el modelo de **8 tablas** del T2
(`Categoria`, `Producto`, `Lote`, `Cliente`, `Empleado`, `Venta`, `Detalle_Venta`, `Comprobante`), sin cambios al modelo.

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
powershell -ExecutionPolicy Bypass -File scripts\run_all.ps1
# con autenticación SQL:  scripts\run_all.ps1 -Server localhost -User sa -Password $env:SA_PASSWORD
```
Crea la base `MinimarketLaFavorita`, carga datos, crea vistas y procedimientos y ejecuta todas las pruebas. Termina con error si algo falla.

**2. Contenedor Docker desechable (SQL Server 2022, contraseña aleatoria):**
```powershell
powershell -ExecutionPolicy Bypass -File scripts\run_in_docker.ps1
```

**3. Solo el script único** (en SSMS o con `sqlcmd -S . -E -C -b -I -i PROYECTO_T3_LA_FAVORITA.sql`).

**4. GitHub Actions:** el flujo levanta SQL Server 2022, espera a que arranque, crea la base, ejecuta los scripts en orden y las pruebas, y falla si algo falla.
La contraseña viene del secreto `MSSQL_SA_PASSWORD` (opcional; si no existe se genera una aleatoria y enmascarada). No hay credenciales en el repositorio.

### Seguridad de la base de datos
`01_create_database.sql` solo elimina y recrea `MinimarketLaFavorita` si lleva la propiedad extendida `proyecto = LA_FAVORITA_T3`; si existe una base con ese nombre sin esa marca, se detiene con error y no la toca.

## Vistas
| Id | Nombre |
|---|---|
| V01 | Stock consolidado por producto |
| V02 | Productos por reponer |
| V03 | Lotes con stock y su estado de vencimiento |
| V04 | Valor del inventario por categoría |
| V05 | Detalle completo de ventas |
| V06 | Cabecera de ventas con comprobante |
| V07 | Ingresos por medio de pago |
| V08 | Ventas diarias |
| V09 | Ranking de productos más vendidos |
| V10 | Rendimiento por empleado |
| V11 | Clientes frecuentes |
| V12 | Comprobantes emitidos |
| V13 | Margen bruto por producto |
| V14 | Personal sin datos sensibles |
| V15 | Control de integridad de ventas |

## Subconsultas
| Id | Nombre |
|---|---|
| S01 | Productos con precio superior al promedio |
| S02 | Productos que nunca se han vendido |
| S03 | Clientes registrados que aún no compran |
| S04 | Empleados sin ventas registradas |
| S05 | Ventas con total superior al promedio |
| S06 | Clientes que gastan más que el cliente promedio |
| S07 | Producto más vendido por unidades |
| S08 | Lotes con menos stock que el promedio de su producto |
| S09 | Productos con lotes vencidos o por vencer |
| S10 | Categorías con al menos un producto agotado |
| S11 | Fecha de la última compra de cada cliente |
| S12 | Producto más caro de cada categoría |
| S13 | Ventas posiblemente duplicadas |
| S14 | Ventas pagadas con el medio de pago más utilizado |
| S15 | Participación de cada categoría en los ingresos |

## Consultas multitabla
| Id | Nombre |
|---|---|
| M01 | Catálogo de productos con su categoría (INNER JOIN) |
| M02 | Lotes con producto, categoría y costo (INNER JOIN de 3 tablas) |
| M03 | Detalle de cada venta con cajero, producto y lote (INNER JOIN de 5 tablas) |
| M04 | Ventas a clientes identificados (INNER JOIN) |
| M05 | Comprobantes con venta y cajero (INNER JOIN) |
| M06 | Trazabilidad: lotes vendidos a cada cliente (INNER JOIN de 6 tablas) |
| M07 | Ingresos por tipo de categoría (INNER JOIN con GROUP BY) |
| M08 | Facturas con cliente y RUC del receptor (INNER JOIN) |
| M09 | Ventas por cajero y medio de pago (INNER JOIN con GROUP BY) |
| M10 | Todos los productos con sus unidades vendidas (LEFT JOIN) |
| M11 | Todos los clientes con su gasto acumulado (LEFT JOIN) |
| M12 | Todos los empleados con sus ventas (LEFT JOIN) |
| M13 | Categorías con su número de productos y su stock (LEFT JOIN) |
| M14 | Lotes con sus ventas, incluidos los que no rotan (LEFT JOIN) |
| M15 | Lotes y sus líneas de venta, desde el lado del lote (RIGHT JOIN) |
| M16 | Clientes y sus ventas, desde el lado del cliente (RIGHT JOIN) |
| M17 | Empleados y las ventas que atendieron (RIGHT JOIN) |
| M18 | Conciliación de clientes y ventas (FULL JOIN) |
| M19 | Control de ventas y comprobantes (FULL JOIN) |
| M20 | Cobertura de abastecimiento: productos y lotes (FULL JOIN) |

## Procedimientos almacenados
**Inserción**

| Id | Nombre |
|---|---|
| PI01 | usp_Categoria_Insertar |
| PI02 | usp_Producto_Insertar |
| PI03 | usp_Lote_Insertar |
| PI04 | usp_Cliente_Insertar |
| PI05 | usp_Empleado_Insertar |
| PI06 | usp_Venta_Registrar |
| PI07 | usp_DetalleVenta_Agregar |
| PI08 | usp_Comprobante_Emitir |

**Modificación**

| Id | Nombre |
|---|---|
| PU01 | usp_Producto_ActualizarPrecio |
| PU02 | usp_Producto_CambiarEstado |
| PU03 | usp_Cliente_ActualizarContacto |
| PU04 | usp_Empleado_CambiarEstado |
| PU05 | usp_Lote_AjustarStock |
| PU06 | usp_Venta_CambiarMedioPago |

**Eliminación**

| Id | Nombre |
|---|---|
| PD01 | usp_Cliente_Eliminar |
| PD02 | usp_Venta_Anular |

**Consulta**

| Id | Nombre |
|---|---|
| PS01 | usp_Producto_Buscar |
| PS02 | usp_Stock_Consultar |
| PS03 | usp_Productos_StockBajo |
| PS04 | usp_Lotes_PorVencer |
| PS05 | usp_Cliente_BuscarPorDni |
| PS06 | usp_Venta_Detalle |
| PS07 | usp_Ventas_PorRango |
| PS08 | usp_Comprobante_Consultar |
| PS09 | usp_Productos_MasVendidos |
| PS10 | usp_Cliente_HistorialCompras |

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
