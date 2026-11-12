/* ============================================================================
   11_integrity_tests.sql - Proyecto T3 La Favorita: controles de integridad
   Verifica el ESTADO de los datos (solo lectura). Cada control cuenta las
   violaciones de una regla; el resultado esperado es 0. Si alguno falla, el
   script termina con error (THROW 50099) para que CI/CD marque el fallo.
   Se puede ejecutar en cualquier momento sobre la base real.
   ============================================================================ */
USE MinimarketLaFavorita;
GO
SET NOCOUNT ON;

CREATE TABLE #ctl (codigo VARCHAR(4) NOT NULL, regla VARCHAR(8) NOT NULL, descripcion NVARCHAR(150) NOT NULL, violaciones INT NOT NULL);

INSERT #ctl SELECT 'I01', 'RN-04', N'Lotes con stock negativo', COUNT(*) FROM Lote WHERE stock_actual < 0;
INSERT #ctl SELECT 'I02', 'RN-04', N'Lotes con stock mayor que la cantidad recibida', COUNT(*) FROM Lote WHERE stock_actual > cantidad_inicial;
INSERT #ctl SELECT 'I03', 'RN-04', N'Lotes cuyo stock no cuadra con lo recibido menos lo vendido', COUNT(*)
FROM Lote l
WHERE l.stock_actual <> l.cantidad_inicial - ISNULL((SELECT SUM(d.cantidad) FROM Detalle_Venta d WHERE d.id_lote = l.id_lote), 0);
INSERT #ctl SELECT 'I04', 'RN-06', N'Ventas sin líneas de detalle', COUNT(*)
FROM Venta v WHERE NOT EXISTS (SELECT 1 FROM Detalle_Venta d WHERE d.id_venta = v.id_venta);
INSERT #ctl SELECT 'I05', 'RN-09', N'Ventas cuyo total no es la suma de sus subtotales', COUNT(*)
FROM Venta v WHERE v.total <> ISNULL((SELECT SUM(d.subtotal) FROM Detalle_Venta d WHERE d.id_venta = v.id_venta), 0);
INSERT #ctl SELECT 'I06', 'RN-09', N'Líneas cuyo subtotal no es cantidad por precio unitario', COUNT(*)
FROM Detalle_Venta WHERE subtotal <> cantidad * precio_unitario;
INSERT #ctl SELECT 'I07', 'RN-08', N'Ventas sin comprobante', COUNT(*)
FROM Venta v WHERE NOT EXISTS (SELECT 1 FROM Comprobante k WHERE k.id_venta = v.id_venta);
INSERT #ctl SELECT 'I08', 'RN-08', N'Comprobantes sin venta asociada', COUNT(*)
FROM Comprobante k WHERE NOT EXISTS (SELECT 1 FROM Venta v WHERE v.id_venta = k.id_venta);
INSERT #ctl SELECT 'I09', 'RN-08', N'Ventas con más de un comprobante', COUNT(*)
FROM (SELECT id_venta FROM Comprobante GROUP BY id_venta HAVING COUNT(*) > 1) x;
INSERT #ctl SELECT 'I10', 'RN-08', N'Facturas sin RUC o boletas con RUC', COUNT(*)
FROM Comprobante
WHERE (tipo_comprobante = 'FACTURA' AND ruc_receptor IS NULL) OR (tipo_comprobante = 'BOLETA' AND ruc_receptor IS NOT NULL);
INSERT #ctl SELECT 'I11', 'RN-08', N'Series con numeración no correlativa (huecos o repetidos)', COUNT(*)
FROM (SELECT serie FROM Comprobante GROUP BY serie HAVING MAX(numero) <> COUNT(*) OR MIN(numero) <> 1) x;
INSERT #ctl SELECT 'I12', 'RN-08', N'Comprobantes emitidos antes de la fecha de la venta', COUNT(*)
FROM Comprobante k JOIN Venta v ON v.id_venta = k.id_venta WHERE k.fecha_emision < v.fecha_venta;
INSERT #ctl SELECT 'I13', 'FK', N'Referencias huérfanas (detalle, venta, lote, producto)', 
       (SELECT COUNT(*) FROM Detalle_Venta d WHERE NOT EXISTS (SELECT 1 FROM Venta  v WHERE v.id_venta = d.id_venta))
     + (SELECT COUNT(*) FROM Detalle_Venta d WHERE NOT EXISTS (SELECT 1 FROM Lote   l WHERE l.id_lote  = d.id_lote))
     + (SELECT COUNT(*) FROM Venta v WHERE NOT EXISTS (SELECT 1 FROM Empleado e WHERE e.id_empleado = v.id_empleado))
     + (SELECT COUNT(*) FROM Venta v WHERE v.id_cliente IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Cliente c WHERE c.id_cliente = v.id_cliente))
     + (SELECT COUNT(*) FROM Lote  l WHERE NOT EXISTS (SELECT 1 FROM Producto p WHERE p.id_producto = l.id_producto))
     + (SELECT COUNT(*) FROM Producto p WHERE NOT EXISTS (SELECT 1 FROM Categoria c WHERE c.id_categoria = p.id_categoria));
INSERT #ctl SELECT 'I14', 'FK', N'Claves foráneas o restricciones CHECK deshabilitadas / no confiables',
       (SELECT COUNT(*) FROM sys.foreign_keys    WHERE is_disabled = 1 OR is_not_trusted = 1)
     + (SELECT COUNT(*) FROM sys.check_constraints WHERE is_disabled = 1 OR is_not_trusted = 1);

-- DBCC CHECKCONSTRAINTS: devuelve una fila por cada fila que viola alguna restricción
CREATE TABLE #dbcc ([Table] NVARCHAR(256), [Constraint] NVARCHAR(256), [Where] NVARCHAR(MAX));
INSERT #dbcc EXEC (N'DBCC CHECKCONSTRAINTS WITH ALL_CONSTRAINTS, NO_INFOMSGS');
INSERT #ctl SELECT 'I15', 'FK/CK', N'Filas que violan alguna restricción (DBCC CHECKCONSTRAINTS)', COUNT(*) FROM #dbcc;

INSERT #ctl SELECT 'I16', 'T2-I6', N'Ventas a clientes registrados después de la fecha de venta', COUNT(*)
FROM Venta v JOIN Cliente c ON c.id_cliente = v.id_cliente WHERE c.fecha_registro > CAST(v.fecha_venta AS DATE);
INSERT #ctl SELECT 'I17', 'RN-10', N'Ventas registradas por empleados inexistentes', COUNT(*)
FROM Venta v WHERE NOT EXISTS (SELECT 1 FROM Empleado e WHERE e.id_empleado = v.id_empleado);

SELECT codigo, regla, descripcion, violaciones,
       CASE WHEN violaciones = 0 THEN 'OK' ELSE 'FALLA' END AS estado
FROM   #ctl ORDER BY codigo;

DECLARE @fallas INT = (SELECT COUNT(*) FROM #ctl WHERE violaciones > 0);
DROP TABLE #dbcc; DROP TABLE #ctl;
IF @fallas > 0 THROW 50099, N'Se detectaron violaciones de integridad en los datos.', 1;
PRINT N'Integridad verificada: 17 controles, 0 violaciones.';
GO
