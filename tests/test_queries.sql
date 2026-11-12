/* ============================================================================
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
GO
INSERT #r (id, prueba, esperado, obtenido)
SELECT 'TQ-S01', N'S01: Productos con precio superior al promedio (filas)', '8', CAST(COUNT(*) AS NVARCHAR(20))
FROM (
SELECT  id_producto, nombre, precio_venta
FROM    Producto
WHERE   precio_venta > (SELECT AVG(precio_venta) FROM Producto)
) q;
INSERT #r (id, prueba, esperado, obtenido)
SELECT 'TQ-S02', N'S02: Productos que nunca se han vendido (filas)', '1', CAST(COUNT(*) AS NVARCHAR(20))
FROM (
SELECT  p.id_producto, p.nombre, p.estado
FROM    Producto p
WHERE   NOT EXISTS (SELECT 1
                    FROM   Lote l
                    JOIN   Detalle_Venta d ON d.id_lote = l.id_lote
                    WHERE  l.id_producto = p.id_producto)
) q;
INSERT #r (id, prueba, esperado, obtenido)
SELECT 'TQ-S03', N'S03: Clientes registrados que aún no compran (filas)', '5', CAST(COUNT(*) AS NVARCHAR(20))
FROM (
SELECT  c.id_cliente, c.nombres, c.apellidos, c.telefono, c.fecha_registro
FROM    Cliente c
WHERE   c.id_cliente NOT IN (SELECT v.id_cliente FROM Venta v WHERE v.id_cliente IS NOT NULL)
) q;
INSERT #r (id, prueba, esperado, obtenido)
SELECT 'TQ-S04', N'S04: Empleados sin ventas registradas (filas)', '7', CAST(COUNT(*) AS NVARCHAR(20))
FROM (
SELECT  e.id_empleado, e.nombres, e.apellidos, e.rol, e.activo
FROM    Empleado e
WHERE   NOT EXISTS (SELECT 1 FROM Venta v WHERE v.id_empleado = e.id_empleado)
) q;
INSERT #r (id, prueba, esperado, obtenido)
SELECT 'TQ-S05', N'S05: Ventas con total superior al promedio (filas)', '7', CAST(COUNT(*) AS NVARCHAR(20))
FROM (
SELECT  v.id_venta, v.fecha_venta, v.tipo_pago, v.total
FROM    Venta v
WHERE   v.total > (SELECT AVG(total) FROM Venta)
) q;
INSERT #r (id, prueba, esperado, obtenido)
SELECT 'TQ-S06', N'S06: Clientes que gastan más que el cliente promedio (filas)', '5', CAST(COUNT(*) AS NVARCHAR(20))
FROM (
SELECT  c.id_cliente, c.nombres + N' ' + c.apellidos AS cliente, SUM(v.total) AS gasto_total
FROM    Cliente c
JOIN    Venta v ON v.id_cliente = c.id_cliente
GROUP BY c.id_cliente, c.nombres, c.apellidos
HAVING  SUM(v.total) > (SELECT AVG(g.gasto)
                        FROM  (SELECT SUM(total) AS gasto
                               FROM   Venta
                               WHERE  id_cliente IS NOT NULL
                               GROUP BY id_cliente) g)
) q;
INSERT #r (id, prueba, esperado, obtenido)
SELECT 'TQ-S07', N'S07: Producto más vendido por unidades (filas)', '1', CAST(COUNT(*) AS NVARCHAR(20))
FROM (
SELECT  p.id_producto, p.nombre, SUM(d.cantidad) AS unidades_vendidas
FROM    Producto p
JOIN    Lote l          ON l.id_producto = p.id_producto
JOIN    Detalle_Venta d ON d.id_lote     = l.id_lote
GROUP BY p.id_producto, p.nombre
HAVING  SUM(d.cantidad) = (SELECT MAX(x.unidades)
                           FROM  (SELECT SUM(d2.cantidad) AS unidades
                                  FROM   Detalle_Venta d2
                                  JOIN   Lote l2 ON l2.id_lote = d2.id_lote
                                  GROUP BY l2.id_producto) x)
) q;
INSERT #r (id, prueba, esperado, obtenido)
SELECT 'TQ-S08', N'S08: Lotes con menos stock que el promedio de su producto (filas)', '2', CAST(COUNT(*) AS NVARCHAR(20))
FROM (
SELECT  l.id_lote, l.id_producto, l.numero_lote, l.stock_actual
FROM    Lote l
WHERE   l.stock_actual < (SELECT AVG(CAST(l2.stock_actual AS DECIMAL(10,2)))
                          FROM   Lote l2
                          WHERE  l2.id_producto = l.id_producto)
) q;
INSERT #r (id, prueba, esperado, obtenido)
SELECT 'TQ-S09', N'S09: Productos con lotes vencidos o por vencer (filas)', CAST((SELECT COUNT(DISTINCT id_producto) FROM Lote WHERE stock_actual > 0 AND fecha_vencimiento IS NOT NULL AND fecha_vencimiento <= DATEADD(DAY, 30, CAST(GETDATE() AS DATE))) AS NVARCHAR(20)), CAST(COUNT(*) AS NVARCHAR(20))
FROM (
SELECT  p.id_producto, p.nombre, p.estado
FROM    Producto p
WHERE   p.id_producto IN (SELECT l.id_producto
                          FROM   Lote l
                          WHERE  l.stock_actual > 0
                            AND  l.fecha_vencimiento IS NOT NULL
                            AND  l.fecha_vencimiento <= DATEADD(DAY, 30, CAST(GETDATE() AS DATE)))
) q;
INSERT #r (id, prueba, esperado, obtenido)
SELECT 'TQ-S10', N'S10: Categorías con al menos un producto agotado (filas)', '2', CAST(COUNT(*) AS NVARCHAR(20))
FROM (
SELECT  c.id_categoria, c.nombre, c.tipo
FROM    Categoria c
WHERE   EXISTS (SELECT 1
                FROM   Producto p
                WHERE  p.id_categoria = c.id_categoria
                  AND  ISNULL((SELECT SUM(l.stock_actual)
                               FROM   Lote l
                               WHERE  l.id_producto = p.id_producto), 0) = 0)
) q;
INSERT #r (id, prueba, esperado, obtenido)
SELECT 'TQ-S11', N'S11: Fecha de la última compra de cada cliente (filas)', '20', CAST(COUNT(*) AS NVARCHAR(20))
FROM (
SELECT  c.id_cliente,
        c.nombres + N' ' + c.apellidos AS cliente,
        (SELECT MAX(v.fecha_venta) FROM Venta v WHERE v.id_cliente = c.id_cliente) AS ultima_compra,
        ISNULL(CONVERT(NVARCHAR(20), (SELECT MAX(v.fecha_venta) FROM Venta v WHERE v.id_cliente = c.id_cliente), 120), N'Sin compras') AS ultima_compra_texto
FROM    Cliente c
) q;
INSERT #r (id, prueba, esperado, obtenido)
SELECT 'TQ-S12', N'S12: Producto más caro de cada categoría (filas)', '15', CAST(COUNT(*) AS NVARCHAR(20))
FROM (
SELECT  c.nombre AS categoria, p.nombre AS producto, p.precio_venta
FROM    Producto p
JOIN    Categoria c ON c.id_categoria = p.id_categoria
WHERE   p.precio_venta = (SELECT MAX(p2.precio_venta)
                          FROM   Producto p2
                          WHERE  p2.id_categoria = p.id_categoria)
) q;
INSERT #r (id, prueba, esperado, obtenido)
SELECT 'TQ-S13', N'S13: Ventas posiblemente duplicadas (filas)', '2', CAST(COUNT(*) AS NVARCHAR(20))
FROM (
SELECT  v.id_venta, v.fecha_venta, v.id_empleado, v.id_cliente, v.tipo_pago, v.total
FROM    Venta v
WHERE   EXISTS (SELECT 1
                FROM   Venta o
                WHERE  o.id_venta <> v.id_venta
                  AND  o.id_empleado = v.id_empleado
                  AND  ISNULL(o.id_cliente, 0) = ISNULL(v.id_cliente, 0)
                  AND  o.total = v.total
                  AND  ABS(DATEDIFF(MINUTE, o.fecha_venta, v.fecha_venta)) <= 5)
) q;
INSERT #r (id, prueba, esperado, obtenido)
SELECT 'TQ-S14', N'S14: Ventas pagadas con el medio de pago más utilizado (filas)', '7', CAST(COUNT(*) AS NVARCHAR(20))
FROM (
SELECT  v.id_venta, v.fecha_venta, v.tipo_pago, v.total
FROM    Venta v
WHERE   v.tipo_pago = (SELECT TOP 1 tipo_pago
                       FROM   Venta
                       GROUP BY tipo_pago
                       ORDER BY COUNT(*) DESC, tipo_pago)
) q;
INSERT #r (id, prueba, esperado, obtenido)
SELECT 'TQ-S15', N'S15: Participación de cada categoría en los ingresos (filas)', '14', CAST(COUNT(*) AS NVARCHAR(20))
FROM (
SELECT  c.nombre AS categoria,
        SUM(d.subtotal) AS ingreso,
        CAST(100.0 * SUM(d.subtotal) / (SELECT SUM(subtotal) FROM Detalle_Venta) AS DECIMAL(5,2)) AS porcentaje
FROM    Categoria c
JOIN    Producto p      ON p.id_categoria = c.id_categoria
JOIN    Lote l          ON l.id_producto  = p.id_producto
JOIN    Detalle_Venta d ON d.id_lote      = l.id_lote
GROUP BY c.id_categoria, c.nombre
) q;
INSERT #r (id, prueba, esperado, obtenido)
SELECT 'TQ-M01', N'M01: Catálogo de productos con su categoría (INNER JOIN) (filas)', '20', CAST(COUNT(*) AS NVARCHAR(20))
FROM (
SELECT  p.id_producto, p.codigo_barras, p.nombre AS producto, c.nombre AS categoria, c.tipo, p.precio_venta, p.estado
FROM    Producto p
INNER JOIN Categoria c ON c.id_categoria = p.id_categoria
) q;
INSERT #r (id, prueba, esperado, obtenido)
SELECT 'TQ-M02', N'M02: Lotes con producto, categoría y costo (INNER JOIN de 3 tablas) (filas)', '21', CAST(COUNT(*) AS NVARCHAR(20))
FROM (
SELECT  l.id_lote, l.numero_lote, p.nombre AS producto, c.nombre AS categoria,
        l.fecha_ingreso, l.fecha_vencimiento, l.cantidad_inicial, l.stock_actual, l.costo_unitario
FROM    Lote l
INNER JOIN Producto  p ON p.id_producto  = l.id_producto
INNER JOIN Categoria c ON c.id_categoria = p.id_categoria
) q;
INSERT #r (id, prueba, esperado, obtenido)
SELECT 'TQ-M03', N'M03: Detalle de cada venta con cajero, producto y lote (INNER JOIN de 5 tablas) (filas)', '37', CAST(COUNT(*) AS NVARCHAR(20))
FROM (
SELECT  v.id_venta, v.fecha_venta, e.usuario AS cajero, p.nombre AS producto,
        l.numero_lote, d.cantidad, d.precio_unitario, d.subtotal
FROM    Venta v
INNER JOIN Detalle_Venta d ON d.id_venta    = v.id_venta
INNER JOIN Empleado      e ON e.id_empleado = v.id_empleado
INNER JOIN Lote          l ON l.id_lote     = d.id_lote
INNER JOIN Producto      p ON p.id_producto = l.id_producto
) q;
INSERT #r (id, prueba, esperado, obtenido)
SELECT 'TQ-M04', N'M04: Ventas a clientes identificados (INNER JOIN) (filas)', '16', CAST(COUNT(*) AS NVARCHAR(20))
FROM (
SELECT  v.id_venta, v.fecha_venta, c.dni, c.nombres + N' ' + c.apellidos AS cliente, c.distrito,
        e.usuario AS cajero, v.tipo_pago, v.total
FROM    Venta v
INNER JOIN Cliente  c ON c.id_cliente  = v.id_cliente
INNER JOIN Empleado e ON e.id_empleado = v.id_empleado
) q;
INSERT #r (id, prueba, esperado, obtenido)
SELECT 'TQ-M05', N'M05: Comprobantes con venta y cajero (INNER JOIN) (filas)', '20', CAST(COUNT(*) AS NVARCHAR(20))
FROM (
SELECT  k.tipo_comprobante, k.serie, k.numero, k.fecha_emision, v.id_venta,
        e.nombres + N' ' + e.apellidos AS cajero, v.total
FROM    Comprobante k
INNER JOIN Venta    v ON v.id_venta    = k.id_venta
INNER JOIN Empleado e ON e.id_empleado = v.id_empleado
) q;
INSERT #r (id, prueba, esperado, obtenido)
SELECT 'TQ-M06', N'M06: Trazabilidad: lotes vendidos a cada cliente (INNER JOIN de 6 tablas) (filas)', '30', CAST(COUNT(*) AS NVARCHAR(20))
FROM (
SELECT  l.numero_lote, p.nombre AS producto, v.fecha_venta,
        c.nombres + N' ' + c.apellidos AS cliente, c.telefono,
        k.serie + N'-' + CAST(k.numero AS NVARCHAR(10)) AS comprobante, d.cantidad
FROM    Lote l
INNER JOIN Producto      p ON p.id_producto = l.id_producto
INNER JOIN Detalle_Venta d ON d.id_lote     = l.id_lote
INNER JOIN Venta         v ON v.id_venta    = d.id_venta
INNER JOIN Cliente       c ON c.id_cliente  = v.id_cliente
INNER JOIN Comprobante   k ON k.id_venta    = v.id_venta
) q;
INSERT #r (id, prueba, esperado, obtenido)
SELECT 'TQ-M07', N'M07: Ingresos por tipo de categoría (INNER JOIN con GROUP BY) (filas)', '3', CAST(COUNT(*) AS NVARCHAR(20))
FROM (
SELECT  c.tipo,
        COUNT(DISTINCT v.id_venta) AS ventas,
        SUM(d.cantidad)            AS unidades,
        SUM(d.subtotal)            AS ingreso
FROM    Categoria c
INNER JOIN Producto      p ON p.id_categoria = c.id_categoria
INNER JOIN Lote          l ON l.id_producto  = p.id_producto
INNER JOIN Detalle_Venta d ON d.id_lote      = l.id_lote
INNER JOIN Venta         v ON v.id_venta     = d.id_venta
GROUP BY c.tipo
) q;
INSERT #r (id, prueba, esperado, obtenido)
SELECT 'TQ-M08', N'M08: Facturas con cliente y RUC del receptor (INNER JOIN) (filas)', '3', CAST(COUNT(*) AS NVARCHAR(20))
FROM (
SELECT  k.serie, k.numero, k.fecha_emision, k.ruc_receptor,
        c.nombres + N' ' + c.apellidos AS cliente, v.total
FROM    Comprobante k
INNER JOIN Venta   v ON v.id_venta   = k.id_venta
INNER JOIN Cliente c ON c.id_cliente = v.id_cliente
WHERE   k.tipo_comprobante = 'FACTURA'
) q;
INSERT #r (id, prueba, esperado, obtenido)
SELECT 'TQ-M09', N'M09: Ventas por cajero y medio de pago (INNER JOIN con GROUP BY) (filas)', '17', CAST(COUNT(*) AS NVARCHAR(20))
FROM (
SELECT  e.usuario AS cajero, e.rol, v.tipo_pago, COUNT(*) AS ventas, SUM(v.total) AS monto
FROM    Empleado e
INNER JOIN Venta       v ON v.id_empleado = e.id_empleado
INNER JOIN Comprobante k ON k.id_venta    = v.id_venta
GROUP BY e.usuario, e.rol, v.tipo_pago
) q;
INSERT #r (id, prueba, esperado, obtenido)
SELECT 'TQ-M10', N'M10: Todos los productos con sus unidades vendidas (LEFT JOIN) (filas)', '20', CAST(COUNT(*) AS NVARCHAR(20))
FROM (
SELECT  p.id_producto, p.nombre AS producto, p.estado,
        ISNULL(SUM(d.cantidad), 0) AS unidades_vendidas,
        ISNULL(SUM(d.subtotal), 0) AS ingreso
FROM    Producto p
LEFT JOIN Lote          l ON l.id_producto = p.id_producto
LEFT JOIN Detalle_Venta d ON d.id_lote     = l.id_lote
GROUP BY p.id_producto, p.nombre, p.estado
) q;
INSERT #r (id, prueba, esperado, obtenido)
SELECT 'TQ-M11', N'M11: Todos los clientes con su gasto acumulado (LEFT JOIN) (filas)', '20', CAST(COUNT(*) AS NVARCHAR(20))
FROM (
SELECT  c.id_cliente, c.nombres + N' ' + c.apellidos AS cliente, c.distrito,
        COUNT(v.id_venta)       AS compras,
        ISNULL(SUM(v.total), 0) AS monto_gastado
FROM    Cliente c
LEFT JOIN Venta v ON v.id_cliente = c.id_cliente
GROUP BY c.id_cliente, c.nombres, c.apellidos, c.distrito
) q;
INSERT #r (id, prueba, esperado, obtenido)
SELECT 'TQ-M12', N'M12: Todos los empleados con sus ventas (LEFT JOIN) (filas)', '20', CAST(COUNT(*) AS NVARCHAR(20))
FROM (
SELECT  e.id_empleado, e.usuario, e.rol, e.activo,
        COUNT(v.id_venta)       AS ventas,
        ISNULL(SUM(v.total), 0) AS monto_vendido
FROM    Empleado e
LEFT JOIN Venta v ON v.id_empleado = e.id_empleado
GROUP BY e.id_empleado, e.usuario, e.rol, e.activo
) q;
INSERT #r (id, prueba, esperado, obtenido)
SELECT 'TQ-M13', N'M13: Categorías con su número de productos y su stock (LEFT JOIN) (filas)', '20', CAST(COUNT(*) AS NVARCHAR(20))
FROM (
SELECT  c.id_categoria, c.nombre AS categoria, c.tipo,
        COUNT(DISTINCT p.id_producto) AS productos,
        ISNULL(SUM(l.stock_actual), 0) AS stock_total
FROM    Categoria c
LEFT JOIN Producto p ON p.id_categoria = c.id_categoria
LEFT JOIN Lote     l ON l.id_producto  = p.id_producto
GROUP BY c.id_categoria, c.nombre, c.tipo
) q;
INSERT #r (id, prueba, esperado, obtenido)
SELECT 'TQ-M14', N'M14: Lotes con sus ventas, incluidos los que no rotan (LEFT JOIN) (filas)', '21', CAST(COUNT(*) AS NVARCHAR(20))
FROM (
SELECT  l.id_lote, l.numero_lote, p.nombre AS producto, l.cantidad_inicial, l.stock_actual,
        COUNT(d.id_detalle)       AS lineas_de_venta,
        ISNULL(SUM(d.cantidad), 0) AS unidades_vendidas
FROM    Lote l
INNER JOIN Producto p ON p.id_producto = l.id_producto
LEFT JOIN  Detalle_Venta d ON d.id_lote = l.id_lote
GROUP BY l.id_lote, l.numero_lote, p.nombre, l.cantidad_inicial, l.stock_actual
) q;
INSERT #r (id, prueba, esperado, obtenido)
SELECT 'TQ-M15', N'M15: Lotes y sus líneas de venta, desde el lado del lote (RIGHT JOIN) (filas)', '39', CAST(COUNT(*) AS NVARCHAR(20))
FROM (
SELECT  l.id_lote, l.numero_lote, d.id_venta, d.cantidad,
        CASE WHEN d.id_detalle IS NULL THEN 'SIN VENTAS' ELSE 'CON VENTAS' END AS situacion
FROM    Detalle_Venta d
RIGHT JOIN Lote l ON l.id_lote = d.id_lote
) q;
INSERT #r (id, prueba, esperado, obtenido)
SELECT 'TQ-M16', N'M16: Clientes y sus ventas, desde el lado del cliente (RIGHT JOIN) (filas)', '21', CAST(COUNT(*) AS NVARCHAR(20))
FROM (
SELECT  c.id_cliente, c.nombres + N' ' + c.apellidos AS cliente, c.distrito,
        v.id_venta, v.fecha_venta, v.total
FROM    Venta v
RIGHT JOIN Cliente c ON c.id_cliente = v.id_cliente
) q;
INSERT #r (id, prueba, esperado, obtenido)
SELECT 'TQ-M17', N'M17: Empleados y las ventas que atendieron (RIGHT JOIN) (filas)', '27', CAST(COUNT(*) AS NVARCHAR(20))
FROM (
SELECT  e.id_empleado, e.usuario, e.rol, v.id_venta, k.serie, k.numero
FROM    Comprobante k
INNER JOIN Venta v ON v.id_venta = k.id_venta
RIGHT JOIN Empleado e ON e.id_empleado = v.id_empleado
) q;
INSERT #r (id, prueba, esperado, obtenido)
SELECT 'TQ-M18', N'M18: Conciliación de clientes y ventas (FULL JOIN) (filas)', '25', CAST(COUNT(*) AS NVARCHAR(20))
FROM (
SELECT  c.id_cliente, c.nombres + N' ' + c.apellidos AS cliente, v.id_venta, v.total,
        CASE WHEN v.id_venta   IS NULL THEN 'CLIENTE SIN VENTAS'
             WHEN c.id_cliente IS NULL THEN 'VENTA SIN CLIENTE'
             ELSE 'CLIENTE CON VENTA' END AS situacion
FROM    Cliente c
FULL JOIN Venta v ON v.id_cliente = c.id_cliente
) q;
INSERT #r (id, prueba, esperado, obtenido)
SELECT 'TQ-M19', N'M19: Control de ventas y comprobantes (FULL JOIN) (filas)', '20', CAST(COUNT(*) AS NVARCHAR(20))
FROM (
SELECT  v.id_venta, k.id_comprobante, k.serie, k.numero, v.total,
        CASE WHEN k.id_comprobante IS NULL THEN 'VENTA SIN COMPROBANTE'
             WHEN v.id_venta       IS NULL THEN 'COMPROBANTE SIN VENTA'
             ELSE 'OK' END AS control
FROM    Venta v
FULL JOIN Comprobante k ON k.id_venta = v.id_venta
) q;
INSERT #r (id, prueba, esperado, obtenido)
SELECT 'TQ-M20', N'M20: Cobertura de abastecimiento: productos y lotes (FULL JOIN) (filas)', '22', CAST(COUNT(*) AS NVARCHAR(20))
FROM (
SELECT  p.id_producto, p.nombre AS producto, p.estado, l.id_lote, l.numero_lote, l.stock_actual,
        CASE WHEN l.id_lote     IS NULL THEN 'SIN LOTES'
             WHEN p.id_producto IS NULL THEN 'LOTE HUERFANO'
             WHEN l.stock_actual = 0    THEN 'LOTE AGOTADO'
             ELSE 'ABASTECIDO' END AS estado_abastecimiento
FROM    Producto p
FULL JOIN Lote l ON l.id_producto = p.id_producto
) q;
GO
SELECT id, prueba, esperado, obtenido, estado FROM #r ORDER BY id;
SELECT COUNT(*) AS pruebas, SUM(CASE WHEN estado = 'PASS' THEN 1 ELSE 0 END) AS aprobadas, SUM(CASE WHEN estado = 'FAIL' THEN 1 ELSE 0 END) AS fallidas FROM #r;
DECLARE @fallidas INT = (SELECT COUNT(*) FROM #r WHERE estado = 'FAIL');
IF @fallidas > 0 THROW 50095, N'Hay consultas con resultados distintos a los esperados.', 1;
GO
