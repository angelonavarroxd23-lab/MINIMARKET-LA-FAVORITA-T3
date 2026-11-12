/* evidence_run.sql - GENERADO por tools/gen_evidence_script.py. Ejecuta todos los ejercicios para capturar su salida real.
   Los procedimientos se prueban dentro de BEGIN TRANSACTION ... ROLLBACK: la base no se modifica. */
USE MinimarketLaFavorita;
GO
PRINT '@@RES V01';
SELECT * FROM dbo.vw_stock_producto ORDER BY id_producto;
GO
PRINT '@@END V01';
GO
PRINT '@@RES V02';
SELECT * FROM dbo.vw_reposicion_urgente ORDER BY faltante_para_minimo DESC;
GO
PRINT '@@END V02';
GO
PRINT '@@RES V03';
SELECT * FROM dbo.vw_lotes_vencimiento ORDER BY dias_para_vencer;
GO
PRINT '@@END V03';
GO
PRINT '@@RES V04';
SELECT * FROM dbo.vw_valor_inventario_categoria ORDER BY valor_costo DESC;
GO
PRINT '@@END V04';
GO
PRINT '@@RES V05';
SELECT * FROM dbo.vw_detalle_ventas ORDER BY id_venta, id_detalle;
GO
PRINT '@@END V05';
GO
PRINT '@@RES V06';
SELECT * FROM dbo.vw_ventas_cabecera ORDER BY id_venta;
GO
PRINT '@@END V06';
GO
PRINT '@@RES V07';
SELECT * FROM dbo.vw_ventas_medio_pago ORDER BY monto_total DESC;
GO
PRINT '@@END V07';
GO
PRINT '@@RES V08';
SELECT * FROM dbo.vw_ventas_diarias ORDER BY fecha;
GO
PRINT '@@END V08';
GO
PRINT '@@RES V09';
SELECT * FROM dbo.vw_ranking_productos ORDER BY posicion, producto;
GO
PRINT '@@END V09';
GO
PRINT '@@RES V10';
SELECT * FROM dbo.vw_rendimiento_empleados ORDER BY monto_vendido DESC, empleado;
GO
PRINT '@@END V10';
GO
PRINT '@@RES V11';
SELECT * FROM dbo.vw_clientes_frecuentes ORDER BY monto_total DESC, cliente;
GO
PRINT '@@END V11';
GO
PRINT '@@RES V12';
SELECT * FROM dbo.vw_comprobantes_emitidos ORDER BY tipo_comprobante, serie, numero;
GO
PRINT '@@END V12';
GO
PRINT '@@RES V13';
SELECT * FROM dbo.vw_margen_producto ORDER BY margen DESC;
GO
PRINT '@@END V13';
GO
PRINT '@@RES V14';
SELECT * FROM dbo.vw_empleados_seguros ORDER BY rol, empleado;
GO
PRINT '@@END V14';
GO
PRINT '@@RES V15';
SELECT * FROM dbo.vw_control_integridad_ventas ORDER BY id_venta;
GO
PRINT '@@END V15';
GO
PRINT '@@RES S01';
SELECT  id_producto, nombre, precio_venta
FROM    Producto
WHERE   precio_venta > (SELECT AVG(precio_venta) FROM Producto)
ORDER BY precio_venta DESC;
GO
PRINT '@@END S01';
GO
PRINT '@@RES S02';
SELECT  p.id_producto, p.nombre, p.estado
FROM    Producto p
WHERE   NOT EXISTS (SELECT 1
                    FROM   Lote l
                    JOIN   Detalle_Venta d ON d.id_lote = l.id_lote
                    WHERE  l.id_producto = p.id_producto)
ORDER BY p.id_producto;
GO
PRINT '@@END S02';
GO
PRINT '@@RES S03';
SELECT  c.id_cliente, c.nombres, c.apellidos, c.telefono, c.fecha_registro
FROM    Cliente c
WHERE   c.id_cliente NOT IN (SELECT v.id_cliente FROM Venta v WHERE v.id_cliente IS NOT NULL)
ORDER BY c.fecha_registro;
GO
PRINT '@@END S03';
GO
PRINT '@@RES S04';
SELECT  e.id_empleado, e.nombres, e.apellidos, e.rol, e.activo
FROM    Empleado e
WHERE   NOT EXISTS (SELECT 1 FROM Venta v WHERE v.id_empleado = e.id_empleado)
ORDER BY e.id_empleado;
GO
PRINT '@@END S04';
GO
PRINT '@@RES S05';
SELECT  v.id_venta, v.fecha_venta, v.tipo_pago, v.total
FROM    Venta v
WHERE   v.total > (SELECT AVG(total) FROM Venta)
ORDER BY v.total DESC;
GO
PRINT '@@END S05';
GO
PRINT '@@RES S06';
SELECT  c.id_cliente, c.nombres + N' ' + c.apellidos AS cliente, SUM(v.total) AS gasto_total
FROM    Cliente c
JOIN    Venta v ON v.id_cliente = c.id_cliente
GROUP BY c.id_cliente, c.nombres, c.apellidos
HAVING  SUM(v.total) > (SELECT AVG(g.gasto)
                        FROM  (SELECT SUM(total) AS gasto
                               FROM   Venta
                               WHERE  id_cliente IS NOT NULL
                               GROUP BY id_cliente) g)
ORDER BY gasto_total DESC;
GO
PRINT '@@END S06';
GO
PRINT '@@RES S07';
SELECT  p.id_producto, p.nombre, SUM(d.cantidad) AS unidades_vendidas
FROM    Producto p
JOIN    Lote l          ON l.id_producto = p.id_producto
JOIN    Detalle_Venta d ON d.id_lote     = l.id_lote
GROUP BY p.id_producto, p.nombre
HAVING  SUM(d.cantidad) = (SELECT MAX(x.unidades)
                           FROM  (SELECT SUM(d2.cantidad) AS unidades
                                  FROM   Detalle_Venta d2
                                  JOIN   Lote l2 ON l2.id_lote = d2.id_lote
                                  GROUP BY l2.id_producto) x);
GO
PRINT '@@END S07';
GO
PRINT '@@RES S08';
SELECT  l.id_lote, l.id_producto, l.numero_lote, l.stock_actual
FROM    Lote l
WHERE   l.stock_actual < (SELECT AVG(CAST(l2.stock_actual AS DECIMAL(10,2)))
                          FROM   Lote l2
                          WHERE  l2.id_producto = l.id_producto)
ORDER BY l.id_producto, l.id_lote;
GO
PRINT '@@END S08';
GO
PRINT '@@RES S09';
SELECT  p.id_producto, p.nombre, p.estado
FROM    Producto p
WHERE   p.id_producto IN (SELECT l.id_producto
                          FROM   Lote l
                          WHERE  l.stock_actual > 0
                            AND  l.fecha_vencimiento IS NOT NULL
                            AND  l.fecha_vencimiento <= DATEADD(DAY, 30, CAST(GETDATE() AS DATE)))
ORDER BY p.nombre;
GO
PRINT '@@END S09';
GO
PRINT '@@RES S10';
SELECT  c.id_categoria, c.nombre, c.tipo
FROM    Categoria c
WHERE   EXISTS (SELECT 1
                FROM   Producto p
                WHERE  p.id_categoria = c.id_categoria
                  AND  ISNULL((SELECT SUM(l.stock_actual)
                               FROM   Lote l
                               WHERE  l.id_producto = p.id_producto), 0) = 0)
ORDER BY c.id_categoria;
GO
PRINT '@@END S10';
GO
PRINT '@@RES S11';
SELECT  c.id_cliente,
        c.nombres + N' ' + c.apellidos AS cliente,
        (SELECT MAX(v.fecha_venta) FROM Venta v WHERE v.id_cliente = c.id_cliente) AS ultima_compra,
        ISNULL(CONVERT(NVARCHAR(20), (SELECT MAX(v.fecha_venta) FROM Venta v WHERE v.id_cliente = c.id_cliente), 120), N'Sin compras') AS ultima_compra_texto
FROM    Cliente c
ORDER BY ultima_compra DESC, c.id_cliente;
GO
PRINT '@@END S11';
GO
PRINT '@@RES S12';
SELECT  c.nombre AS categoria, p.nombre AS producto, p.precio_venta
FROM    Producto p
JOIN    Categoria c ON c.id_categoria = p.id_categoria
WHERE   p.precio_venta = (SELECT MAX(p2.precio_venta)
                          FROM   Producto p2
                          WHERE  p2.id_categoria = p.id_categoria)
ORDER BY p.precio_venta DESC;
GO
PRINT '@@END S12';
GO
PRINT '@@RES S13';
SELECT  v.id_venta, v.fecha_venta, v.id_empleado, v.id_cliente, v.tipo_pago, v.total
FROM    Venta v
WHERE   EXISTS (SELECT 1
                FROM   Venta o
                WHERE  o.id_venta <> v.id_venta
                  AND  o.id_empleado = v.id_empleado
                  AND  ISNULL(o.id_cliente, 0) = ISNULL(v.id_cliente, 0)
                  AND  o.total = v.total
                  AND  ABS(DATEDIFF(MINUTE, o.fecha_venta, v.fecha_venta)) <= 5)
ORDER BY v.fecha_venta;
GO
PRINT '@@END S13';
GO
PRINT '@@RES S14';
SELECT  v.id_venta, v.fecha_venta, v.tipo_pago, v.total
FROM    Venta v
WHERE   v.tipo_pago = (SELECT TOP 1 tipo_pago
                       FROM   Venta
                       GROUP BY tipo_pago
                       ORDER BY COUNT(*) DESC, tipo_pago)
ORDER BY v.fecha_venta;
GO
PRINT '@@END S14';
GO
PRINT '@@RES S15';
SELECT  c.nombre AS categoria,
        SUM(d.subtotal) AS ingreso,
        CAST(100.0 * SUM(d.subtotal) / (SELECT SUM(subtotal) FROM Detalle_Venta) AS DECIMAL(5,2)) AS porcentaje
FROM    Categoria c
JOIN    Producto p      ON p.id_categoria = c.id_categoria
JOIN    Lote l          ON l.id_producto  = p.id_producto
JOIN    Detalle_Venta d ON d.id_lote      = l.id_lote
GROUP BY c.id_categoria, c.nombre
ORDER BY ingreso DESC;
GO
PRINT '@@END S15';
GO
PRINT '@@RES M01';
SELECT  p.id_producto, p.codigo_barras, p.nombre AS producto, c.nombre AS categoria, c.tipo, p.precio_venta, p.estado
FROM    Producto p
INNER JOIN Categoria c ON c.id_categoria = p.id_categoria
ORDER BY c.tipo, c.nombre, p.nombre;
GO
PRINT '@@END M01';
GO
PRINT '@@RES M02';
SELECT  l.id_lote, l.numero_lote, p.nombre AS producto, c.nombre AS categoria,
        l.fecha_ingreso, l.fecha_vencimiento, l.cantidad_inicial, l.stock_actual, l.costo_unitario
FROM    Lote l
INNER JOIN Producto  p ON p.id_producto  = l.id_producto
INNER JOIN Categoria c ON c.id_categoria = p.id_categoria
ORDER BY l.fecha_ingreso, l.id_lote;
GO
PRINT '@@END M02';
GO
PRINT '@@RES M03';
SELECT  v.id_venta, v.fecha_venta, e.usuario AS cajero, p.nombre AS producto,
        l.numero_lote, d.cantidad, d.precio_unitario, d.subtotal
FROM    Venta v
INNER JOIN Detalle_Venta d ON d.id_venta    = v.id_venta
INNER JOIN Empleado      e ON e.id_empleado = v.id_empleado
INNER JOIN Lote          l ON l.id_lote     = d.id_lote
INNER JOIN Producto      p ON p.id_producto = l.id_producto
ORDER BY v.id_venta, d.id_detalle;
GO
PRINT '@@END M03';
GO
PRINT '@@RES M04';
SELECT  v.id_venta, v.fecha_venta, c.dni, c.nombres + N' ' + c.apellidos AS cliente, c.distrito,
        e.usuario AS cajero, v.tipo_pago, v.total
FROM    Venta v
INNER JOIN Cliente  c ON c.id_cliente  = v.id_cliente
INNER JOIN Empleado e ON e.id_empleado = v.id_empleado
ORDER BY v.fecha_venta;
GO
PRINT '@@END M04';
GO
PRINT '@@RES M05';
SELECT  k.tipo_comprobante, k.serie, k.numero, k.fecha_emision, v.id_venta,
        e.nombres + N' ' + e.apellidos AS cajero, v.total
FROM    Comprobante k
INNER JOIN Venta    v ON v.id_venta    = k.id_venta
INNER JOIN Empleado e ON e.id_empleado = v.id_empleado
ORDER BY k.serie, k.numero;
GO
PRINT '@@END M05';
GO
PRINT '@@RES M06';
SELECT  l.numero_lote, p.nombre AS producto, v.fecha_venta,
        c.nombres + N' ' + c.apellidos AS cliente, c.telefono,
        k.serie + N'-' + CAST(k.numero AS NVARCHAR(10)) AS comprobante, d.cantidad
FROM    Lote l
INNER JOIN Producto      p ON p.id_producto = l.id_producto
INNER JOIN Detalle_Venta d ON d.id_lote     = l.id_lote
INNER JOIN Venta         v ON v.id_venta    = d.id_venta
INNER JOIN Cliente       c ON c.id_cliente  = v.id_cliente
INNER JOIN Comprobante   k ON k.id_venta    = v.id_venta
ORDER BY l.numero_lote, v.fecha_venta;
GO
PRINT '@@END M06';
GO
PRINT '@@RES M07';
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
ORDER BY ingreso DESC;
GO
PRINT '@@END M07';
GO
PRINT '@@RES M08';
SELECT  k.serie, k.numero, k.fecha_emision, k.ruc_receptor,
        c.nombres + N' ' + c.apellidos AS cliente, v.total
FROM    Comprobante k
INNER JOIN Venta   v ON v.id_venta   = k.id_venta
INNER JOIN Cliente c ON c.id_cliente = v.id_cliente
WHERE   k.tipo_comprobante = 'FACTURA'
ORDER BY k.numero;
GO
PRINT '@@END M08';
GO
PRINT '@@RES M09';
SELECT  e.usuario AS cajero, e.rol, v.tipo_pago, COUNT(*) AS ventas, SUM(v.total) AS monto
FROM    Empleado e
INNER JOIN Venta       v ON v.id_empleado = e.id_empleado
INNER JOIN Comprobante k ON k.id_venta    = v.id_venta
GROUP BY e.usuario, e.rol, v.tipo_pago
ORDER BY e.usuario, v.tipo_pago;
GO
PRINT '@@END M09';
GO
PRINT '@@RES M10';
SELECT  p.id_producto, p.nombre AS producto, p.estado,
        ISNULL(SUM(d.cantidad), 0) AS unidades_vendidas,
        ISNULL(SUM(d.subtotal), 0) AS ingreso
FROM    Producto p
LEFT JOIN Lote          l ON l.id_producto = p.id_producto
LEFT JOIN Detalle_Venta d ON d.id_lote     = l.id_lote
GROUP BY p.id_producto, p.nombre, p.estado
ORDER BY unidades_vendidas DESC, p.nombre;
GO
PRINT '@@END M10';
GO
PRINT '@@RES M11';
SELECT  c.id_cliente, c.nombres + N' ' + c.apellidos AS cliente, c.distrito,
        COUNT(v.id_venta)       AS compras,
        ISNULL(SUM(v.total), 0) AS monto_gastado
FROM    Cliente c
LEFT JOIN Venta v ON v.id_cliente = c.id_cliente
GROUP BY c.id_cliente, c.nombres, c.apellidos, c.distrito
ORDER BY monto_gastado DESC, c.id_cliente;
GO
PRINT '@@END M11';
GO
PRINT '@@RES M12';
SELECT  e.id_empleado, e.usuario, e.rol, e.activo,
        COUNT(v.id_venta)       AS ventas,
        ISNULL(SUM(v.total), 0) AS monto_vendido
FROM    Empleado e
LEFT JOIN Venta v ON v.id_empleado = e.id_empleado
GROUP BY e.id_empleado, e.usuario, e.rol, e.activo
ORDER BY monto_vendido DESC, e.id_empleado;
GO
PRINT '@@END M12';
GO
PRINT '@@RES M13';
SELECT  c.id_categoria, c.nombre AS categoria, c.tipo,
        COUNT(DISTINCT p.id_producto) AS productos,
        ISNULL(SUM(l.stock_actual), 0) AS stock_total
FROM    Categoria c
LEFT JOIN Producto p ON p.id_categoria = c.id_categoria
LEFT JOIN Lote     l ON l.id_producto  = p.id_producto
GROUP BY c.id_categoria, c.nombre, c.tipo
ORDER BY stock_total, c.id_categoria;
GO
PRINT '@@END M13';
GO
PRINT '@@RES M14';
SELECT  l.id_lote, l.numero_lote, p.nombre AS producto, l.cantidad_inicial, l.stock_actual,
        COUNT(d.id_detalle)       AS lineas_de_venta,
        ISNULL(SUM(d.cantidad), 0) AS unidades_vendidas
FROM    Lote l
INNER JOIN Producto p ON p.id_producto = l.id_producto
LEFT JOIN  Detalle_Venta d ON d.id_lote = l.id_lote
GROUP BY l.id_lote, l.numero_lote, p.nombre, l.cantidad_inicial, l.stock_actual
ORDER BY unidades_vendidas, l.id_lote;
GO
PRINT '@@END M14';
GO
PRINT '@@RES M15';
SELECT  l.id_lote, l.numero_lote, d.id_venta, d.cantidad,
        CASE WHEN d.id_detalle IS NULL THEN 'SIN VENTAS' ELSE 'CON VENTAS' END AS situacion
FROM    Detalle_Venta d
RIGHT JOIN Lote l ON l.id_lote = d.id_lote
ORDER BY situacion, l.id_lote, d.id_venta;
GO
PRINT '@@END M15';
GO
PRINT '@@RES M16';
SELECT  c.id_cliente, c.nombres + N' ' + c.apellidos AS cliente, c.distrito,
        v.id_venta, v.fecha_venta, v.total
FROM    Venta v
RIGHT JOIN Cliente c ON c.id_cliente = v.id_cliente
ORDER BY c.id_cliente, v.fecha_venta;
GO
PRINT '@@END M16';
GO
PRINT '@@RES M17';
SELECT  e.id_empleado, e.usuario, e.rol, v.id_venta, k.serie, k.numero
FROM    Comprobante k
INNER JOIN Venta v ON v.id_venta = k.id_venta
RIGHT JOIN Empleado e ON e.id_empleado = v.id_empleado
ORDER BY e.id_empleado, v.id_venta;
GO
PRINT '@@END M17';
GO
PRINT '@@RES M18';
SELECT  c.id_cliente, c.nombres + N' ' + c.apellidos AS cliente, v.id_venta, v.total,
        CASE WHEN v.id_venta   IS NULL THEN 'CLIENTE SIN VENTAS'
             WHEN c.id_cliente IS NULL THEN 'VENTA SIN CLIENTE'
             ELSE 'CLIENTE CON VENTA' END AS situacion
FROM    Cliente c
FULL JOIN Venta v ON v.id_cliente = c.id_cliente
ORDER BY situacion, c.id_cliente, v.id_venta;
GO
PRINT '@@END M18';
GO
PRINT '@@RES M19';
SELECT  v.id_venta, k.id_comprobante, k.serie, k.numero, v.total,
        CASE WHEN k.id_comprobante IS NULL THEN 'VENTA SIN COMPROBANTE'
             WHEN v.id_venta       IS NULL THEN 'COMPROBANTE SIN VENTA'
             ELSE 'OK' END AS control
FROM    Venta v
FULL JOIN Comprobante k ON k.id_venta = v.id_venta
ORDER BY control DESC, v.id_venta;
GO
PRINT '@@END M19';
GO
PRINT '@@RES M20';
SELECT  p.id_producto, p.nombre AS producto, p.estado, l.id_lote, l.numero_lote, l.stock_actual,
        CASE WHEN l.id_lote     IS NULL THEN 'SIN LOTES'
             WHEN p.id_producto IS NULL THEN 'LOTE HUERFANO'
             WHEN l.stock_actual = 0    THEN 'LOTE AGOTADO'
             ELSE 'ABASTECIDO' END AS estado_abastecimiento
FROM    Producto p
FULL JOIN Lote l ON l.id_producto = p.id_producto
ORDER BY estado_abastecimiento, p.id_producto, l.id_lote;
GO
PRINT '@@END M20';
GO
PRINT '@@RES PI01';
BEGIN TRANSACTION;
DECLARE @id INT;
EXEC dbo.usp_Categoria_Insertar @nombre = N'Congelados', @tipo = 'ALIMENTO', @descripcion = N'Helados, nuggets y verduras congeladas', @id_categoria = @id OUTPUT;
SELECT * FROM Categoria WHERE id_categoria = @id;
ROLLBACK TRANSACTION;
GO
PRINT '@@END PI01';
GO
PRINT '@@RES PI02';
BEGIN TRANSACTION;
DECLARE @id INT;
EXEC dbo.usp_Producto_Insertar @codigo_barras = '7750100100216', @nombre = N'Helado de vainilla 1 L', @descripcion = N'Helado en pote de 1 L', @precio_venta = 14.90, @stock_minimo = 5, @estado = 'ACTIVO', @id_categoria = 1, @id_producto = @id OUTPUT;
SELECT * FROM Producto WHERE id_producto = @id;
ROLLBACK TRANSACTION;
GO
PRINT '@@END PI02';
GO
PRINT '@@RES PI03';
BEGIN TRANSACTION;
DECLARE @id INT;
EXEC dbo.usp_Lote_Insertar @id_producto = 4, @numero_lote = 'LT-FID-2611A', @fecha_ingreso = '2026-11-10', @fecha_vencimiento = '2028-11-10', @cantidad_inicial = 50, @costo_unitario = 3.00, @id_lote = @id OUTPUT;
SELECT * FROM Lote WHERE id_lote = @id;
ROLLBACK TRANSACTION;
GO
PRINT '@@END PI03';
GO
PRINT '@@RES PI04';
BEGIN TRANSACTION;
DECLARE @id INT;
EXEC dbo.usp_Cliente_Insertar @dni = '78123456', @nombres = N'Rosa María', @apellidos = N'Cáceres Luna', @telefono = '987001122', @direccion = N'Jr. Cusco 321', @distrito = N'Comas', @id_cliente = @id OUTPUT;
SELECT * FROM Cliente WHERE id_cliente = @id;
ROLLBACK TRANSACTION;
GO
PRINT '@@END PI04';
GO
PRINT '@@RES PI05';
BEGIN TRANSACTION;
DECLARE @id INT;
EXEC dbo.usp_Empleado_Insertar @dni = '80123456', @nombres = N'Pedro Antonio', @apellidos = N'Rivas Mena', @correo = 'privas@lafavorita.pe', @usuario = 'privas', @clave_hash = 'pbkdf2_sha256$600000$EjemploSalt0001$EjemploHashDePrueba0123456789abcdefghijklmn=', @rol = 'CAJERO', @telefono = '981100030', @id_empleado = @id OUTPUT;
SELECT id_empleado, dni, usuario, rol, activo FROM Empleado WHERE id_empleado = @id;
ROLLBACK TRANSACTION;
GO
PRINT '@@END PI05';
GO
PRINT '@@RES PI06';
BEGIN TRANSACTION;
DECLARE @lineas dbo.tvp_LineaVenta, @id INT;
INSERT INTO @lineas (id_lote, cantidad) VALUES (1, 2), (13, 6);
EXEC dbo.usp_Venta_Registrar @id_empleado = 3, @id_cliente = 1, @tipo_pago = 'YAPE', @lineas = @lineas, @tipo_comprobante = 'BOLETA', @id_venta = @id OUTPUT;
SELECT * FROM dbo.vw_ventas_cabecera WHERE id_venta = @id;
SELECT id_lote, stock_actual FROM Lote WHERE id_lote IN (1, 13);
ROLLBACK TRANSACTION;
GO
PRINT '@@END PI06';
GO
PRINT '@@RES PI07';
BEGIN TRANSACTION;
DECLARE @lineas dbo.tvp_LineaVenta, @v INT, @d INT;
INSERT INTO @lineas VALUES (1, 1);
EXEC dbo.usp_Venta_Registrar @id_empleado = 3, @tipo_pago = 'EFECTIVO', @lineas = @lineas, @id_venta = @v OUTPUT;
EXEC dbo.usp_DetalleVenta_Agregar @id_venta = @v, @id_lote = 4, @cantidad = 3, @id_detalle = @d OUTPUT;
SELECT * FROM dbo.vw_detalle_ventas WHERE id_venta = @v;
SELECT id_venta, total FROM Venta WHERE id_venta = @v;
ROLLBACK TRANSACTION;
GO
PRINT '@@END PI07';
GO
PRINT '@@RES PI08';
BEGIN TRANSACTION;
DECLARE @lineas dbo.tvp_LineaVenta, @v INT, @c INT;
INSERT INTO @lineas VALUES (2, 1);
EXEC dbo.usp_Venta_Registrar @id_empleado = 4, @id_cliente = 2, @tipo_pago = 'TARJETA', @lineas = @lineas, @id_venta = @v OUTPUT;
EXEC dbo.usp_Comprobante_Emitir @id_venta = @v, @tipo_comprobante = 'FACTURA', @ruc_receptor = '20601234561', @id_comprobante = @c OUTPUT;
SELECT * FROM dbo.vw_comprobantes_emitidos WHERE id_venta = @v;
ROLLBACK TRANSACTION;
GO
PRINT '@@END PI08';
GO
PRINT '@@RES PU01';
BEGIN TRANSACTION;
EXEC dbo.usp_Producto_ActualizarPrecio @id_producto = 3, @precio_nuevo = 10.50;
SELECT id_producto, nombre, precio_venta FROM Producto WHERE id_producto = 3;
ROLLBACK TRANSACTION;
GO
PRINT '@@END PU01';
GO
PRINT '@@RES PU02';
BEGIN TRANSACTION;
EXEC dbo.usp_Producto_CambiarEstado @id_producto = 20, @estado = 'ACTIVO';
SELECT id_producto, nombre, estado FROM Producto WHERE id_producto = 20;
ROLLBACK TRANSACTION;
GO
PRINT '@@END PU02';
GO
PRINT '@@RES PU03';
BEGIN TRANSACTION;
EXEC dbo.usp_Cliente_ActualizarContacto @id_cliente = 7, @telefono = '987654000', @direccion = N'Calle Santa Rosa 40';
SELECT id_cliente, dni, telefono, direccion, distrito FROM Cliente WHERE id_cliente = 7;
ROLLBACK TRANSACTION;
GO
PRINT '@@END PU03';
GO
PRINT '@@RES PU04';
BEGIN TRANSACTION;
EXEC dbo.usp_Empleado_CambiarEstado @id_empleado = 19, @activo = 0;
SELECT id_empleado, usuario, rol, activo FROM Empleado WHERE id_empleado = 19;
ROLLBACK TRANSACTION;
GO
PRINT '@@END PU04';
GO
PRINT '@@RES PU05';
BEGIN TRANSACTION;
EXEC dbo.usp_Lote_AjustarStock @id_lote = 13, @ajuste = -2, @motivo = N'Botellas rotas en almacén';
SELECT id_lote, cantidad_inicial, stock_actual FROM Lote WHERE id_lote = 13;
ROLLBACK TRANSACTION;
GO
PRINT '@@END PU05';
GO
PRINT '@@RES PU06';
BEGIN TRANSACTION;
EXEC dbo.usp_Venta_CambiarMedioPago @id_venta = 1, @tipo_pago = 'YAPE';
SELECT id_venta, tipo_pago, total FROM Venta WHERE id_venta = 1;
ROLLBACK TRANSACTION;
GO
PRINT '@@END PU06';
GO
PRINT '@@RES PD01';
BEGIN TRANSACTION;
DECLARE @id INT;
EXEC dbo.usp_Cliente_Insertar @dni = '78999001', @nombres = N'Prueba', @apellidos = N'Temporal', @distrito = N'Comas', @id_cliente = @id OUTPUT;
EXEC dbo.usp_Cliente_Eliminar @id_cliente = @id;
SELECT COUNT(*) AS filas_restantes FROM Cliente WHERE id_cliente = @id;
ROLLBACK TRANSACTION;
GO
PRINT '@@END PD01';
GO
PRINT '@@RES PD02';
BEGIN TRANSACTION;
SELECT id_lote, stock_actual FROM Lote WHERE id_lote IN (11, 9);
EXEC dbo.usp_Venta_Anular @id_venta = 20, @id_empleado_autoriza = 2;
SELECT id_lote, stock_actual FROM Lote WHERE id_lote IN (11, 9);
SELECT COUNT(*) AS ventas_con_id_20 FROM Venta WHERE id_venta = 20;
ROLLBACK TRANSACTION;
GO
PRINT '@@END PD02';
GO
PRINT '@@RES PS01';
BEGIN TRANSACTION;
EXEC dbo.usp_Producto_Buscar @texto = N'gaseosa';
EXEC dbo.usp_Producto_Buscar @texto = N'7750100100018';
ROLLBACK TRANSACTION;
GO
PRINT '@@END PS01';
GO
PRINT '@@RES PS02';
BEGIN TRANSACTION;
EXEC dbo.usp_Stock_Consultar @id_producto = 1;
ROLLBACK TRANSACTION;
GO
PRINT '@@END PS02';
GO
PRINT '@@RES PS03';
BEGIN TRANSACTION;
EXEC dbo.usp_Productos_StockBajo;
ROLLBACK TRANSACTION;
GO
PRINT '@@END PS03';
GO
PRINT '@@RES PS04';
BEGIN TRANSACTION;
EXEC dbo.usp_Lotes_PorVencer @dias = 60;
ROLLBACK TRANSACTION;
GO
PRINT '@@END PS04';
GO
PRINT '@@RES PS05';
BEGIN TRANSACTION;
EXEC dbo.usp_Cliente_BuscarPorDni @dni = '10234567';
ROLLBACK TRANSACTION;
GO
PRINT '@@END PS05';
GO
PRINT '@@RES PS06';
BEGIN TRANSACTION;
EXEC dbo.usp_Venta_Detalle @id_venta = 4;
ROLLBACK TRANSACTION;
GO
PRINT '@@END PS06';
GO
PRINT '@@RES PS07';
BEGIN TRANSACTION;
EXEC dbo.usp_Ventas_PorRango @desde = '2026-10-01', @hasta = '2026-10-07';
ROLLBACK TRANSACTION;
GO
PRINT '@@END PS07';
GO
PRINT '@@RES PS08';
BEGIN TRANSACTION;
EXEC dbo.usp_Comprobante_Consultar @serie = 'F001', @numero = 1;
ROLLBACK TRANSACTION;
GO
PRINT '@@END PS08';
GO
PRINT '@@RES PS09';
BEGIN TRANSACTION;
EXEC dbo.usp_Productos_MasVendidos @top = 5, @desde = '2026-10-01', @hasta = '2026-10-31';
ROLLBACK TRANSACTION;
GO
PRINT '@@END PS09';
GO
PRINT '@@RES PS10';
BEGIN TRANSACTION;
EXEC dbo.usp_Cliente_HistorialCompras @id_cliente = 4;
ROLLBACK TRANSACTION;
GO
PRINT '@@END PS10';
GO
