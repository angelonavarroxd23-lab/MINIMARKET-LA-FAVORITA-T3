/* ============================================================================
   test_views.sql - Pruebas de las 15 vistas (solo lectura)
   Verifica que existan, que se puedan consultar y que devuelvan resultados
   coherentes con los datos de prueba de T2.
   ============================================================================ */
USE MinimarketLaFavorita;
GO
SET NOCOUNT ON;
CREATE TABLE #r (
    id VARCHAR(8) NOT NULL, prueba NVARCHAR(160) NOT NULL, esperado NVARCHAR(200) NOT NULL, obtenido NVARCHAR(200) NULL,
    estado AS CASE WHEN esperado = ISNULL(obtenido, N'') THEN 'PASS' ELSE 'FAIL' END);

INSERT #r SELECT 'TV-00', N'Existen exactamente 15 vistas vw_', N'15', CAST(COUNT(*) AS NVARCHAR(20)) FROM sys.views WHERE name LIKE 'vw[_]%';

INSERT #r SELECT 'TV-01', N'vw_stock_producto: 20 productos',                         N'20', CAST(COUNT(*) AS NVARCHAR(20)) FROM dbo.vw_stock_producto;
INSERT #r SELECT 'TV-02', N'vw_stock_producto: 1 agotado, 3 en alerta',                N'1|3', CONCAT(SUM(CASE WHEN situacion_stock='AGOTADO' AND estado='ACTIVO' THEN 1 ELSE 0 END), '|', SUM(CASE WHEN situacion_stock='ALERTA' THEN 1 ELSE 0 END)) FROM dbo.vw_stock_producto;
INSERT #r SELECT 'TV-03', N'vw_reposicion_urgente: 4 productos a reponer',            N'4',  CAST(COUNT(*) AS NVARCHAR(20)) FROM dbo.vw_reposicion_urgente;
INSERT #r SELECT 'TV-04', N'vw_lotes_vencimiento: 19 lotes perecibles con stock',     N'19', CAST(COUNT(*) AS NVARCHAR(20)) FROM dbo.vw_lotes_vencimiento;
INSERT #r SELECT 'TV-05', N'vw_lotes_vencimiento: lotes 6, 7 y 8 aparecen como VENCIDO', N'3', CAST(COUNT(*) AS NVARCHAR(20)) FROM dbo.vw_lotes_vencimiento WHERE id_lote IN (6,7,8) AND estado_vencimiento = 'VENCIDO';
INSERT #r SELECT 'TV-06', N'vw_valor_inventario_categoria: 20 categorías',            N'20', CAST(COUNT(*) AS NVARCHAR(20)) FROM dbo.vw_valor_inventario_categoria;
INSERT #r SELECT 'TV-07', N'vw_valor_inventario_categoria: unidades = SUM(stock) de Lote', N'1', CAST(CASE WHEN (SELECT SUM(unidades_en_stock) FROM dbo.vw_valor_inventario_categoria) = (SELECT SUM(stock_actual) FROM Lote) THEN 1 ELSE 0 END AS NVARCHAR(20));
INSERT #r SELECT 'TV-08', N'vw_detalle_ventas: 37 líneas',                            N'37', CAST(COUNT(*) AS NVARCHAR(20)) FROM dbo.vw_detalle_ventas;
INSERT #r SELECT 'TV-09', N'vw_detalle_ventas: suma de subtotales = suma de totales de venta', N'1', CAST(CASE WHEN (SELECT SUM(subtotal) FROM dbo.vw_detalle_ventas) = (SELECT SUM(total) FROM Venta) THEN 1 ELSE 0 END AS NVARCHAR(20));
INSERT #r SELECT 'TV-10', N'vw_ventas_cabecera: 20 ventas, 4 sin cliente',            N'20|4', CONCAT(COUNT(*), '|', SUM(CASE WHEN cliente = N'SIN CLIENTE' THEN 1 ELSE 0 END)) FROM dbo.vw_ventas_cabecera;
INSERT #r SELECT 'TV-11', N'vw_ventas_medio_pago: 4 medios y 100 % del ingreso',     N'4|100.00', CONCAT(COUNT(*), '|', CAST(SUM(porcentaje_ingreso) AS DECIMAL(6,2))) FROM dbo.vw_ventas_medio_pago;
INSERT #r SELECT 'TV-12', N'vw_ventas_diarias: 18 días con ventas',                  N'18', CAST(COUNT(*) AS NVARCHAR(20)) FROM dbo.vw_ventas_diarias;
INSERT #r SELECT 'TV-13', N'vw_ventas_diarias: suma diaria = suma de ventas',        N'1', CAST(CASE WHEN (SELECT SUM(monto_total) FROM dbo.vw_ventas_diarias) = (SELECT SUM(total) FROM Venta) THEN 1 ELSE 0 END AS NVARCHAR(20));
INSERT #r SELECT 'TV-14', N'vw_ranking_productos: 19 productos vendidos; el primero es el agua (10 u.)', N'19|10', CONCAT(COUNT(*), '|', MAX(unidades_vendidas)) FROM dbo.vw_ranking_productos;
INSERT #r SELECT 'TV-15', N'vw_rendimiento_empleados: 20 empleados',                 N'20', CAST(COUNT(*) AS NVARCHAR(20)) FROM dbo.vw_rendimiento_empleados;
INSERT #r SELECT 'TV-16', N'vw_clientes_frecuentes: 20 clientes, 5 sin compras',     N'20|5', CONCAT(COUNT(*), '|', SUM(CASE WHEN nro_compras = 0 THEN 1 ELSE 0 END)) FROM dbo.vw_clientes_frecuentes;
INSERT #r SELECT 'TV-17', N'vw_comprobantes_emitidos: 20 comprobantes (3 facturas)', N'20|3', CONCAT(COUNT(*), '|', SUM(CASE WHEN tipo_comprobante='FACTURA' THEN 1 ELSE 0 END)) FROM dbo.vw_comprobantes_emitidos;
INSERT #r SELECT 'TV-18', N'vw_margen_producto: 19 productos y margen total positivo', N'19|1', CONCAT(COUNT(*), '|', CASE WHEN SUM(margen) > 0 THEN 1 ELSE 0 END) FROM dbo.vw_margen_producto;
INSERT #r SELECT 'TV-19', N'vw_empleados_seguros: 20 empleados y SIN columna clave_hash ni dni', N'20|0', CONCAT((SELECT COUNT(*) FROM dbo.vw_empleados_seguros), '|', (SELECT COUNT(*) FROM sys.columns WHERE object_id = OBJECT_ID('dbo.vw_empleados_seguros') AND name IN ('clave_hash','dni')));
INSERT #r SELECT 'TV-20', N'vw_control_integridad_ventas: las 20 ventas están OK',   N'20|0', CONCAT(SUM(CASE WHEN diagnostico='OK' THEN 1 ELSE 0 END), '|', SUM(CASE WHEN diagnostico<>'OK' THEN 1 ELSE 0 END)) FROM dbo.vw_control_integridad_ventas;
GO
SELECT id, prueba, esperado, obtenido, estado FROM #r ORDER BY id;
SELECT COUNT(*) AS pruebas, SUM(CASE WHEN estado = 'PASS' THEN 1 ELSE 0 END) AS aprobadas, SUM(CASE WHEN estado = 'FAIL' THEN 1 ELSE 0 END) AS fallidas FROM #r;
DECLARE @fallidas INT = (SELECT COUNT(*) FROM #r WHERE estado = 'FAIL');
IF @fallidas > 0 THROW 50097, N'Hay pruebas de vistas que fallaron.', 1;
GO
