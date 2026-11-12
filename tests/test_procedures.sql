/* ============================================================================
   test_procedures.sql - Pruebas de los 26 procedimientos almacenados
   Cada prueba se ejecuta dentro de una transacción que termina en ROLLBACK, por
   lo que la base queda intacta y las pruebas se pueden repetir.
   Convención: en los textos SQL dinámicos, ~ representa la comilla simple.
   Resultado: tabla PASS/FAIL; el script falla (THROW) si alguna prueba falla.
   ============================================================================ */
USE MinimarketLaFavorita;
GO
SET NOCOUNT ON;
CREATE TABLE #r (
    id       VARCHAR(8)    NOT NULL,
    prueba   NVARCHAR(160) NOT NULL,
    esperado NVARCHAR(200) NOT NULL,
    obtenido NVARCHAR(200) NULL,
    detalle  NVARCHAR(400) NULL,
    estado   AS CASE WHEN esperado = ISNULL(obtenido, N'') THEN 'PASS' ELSE 'FAIL' END
);
GO
-- Prueba que DEBE FALLAR con el error @codigo (se revierte siempre).
CREATE PROCEDURE #err @id VARCHAR(8), @prueba NVARCHAR(160), @codigo INT, @sql NVARCHAR(MAX)
AS
BEGIN
    DECLARE @n INT = NULL, @m NVARCHAR(400) = NULL;
    SET @sql = REPLACE(@sql, '~', '''');
    BEGIN TRANSACTION;
    BEGIN TRY EXEC sp_executesql @sql; END TRY
    BEGIN CATCH SELECT @n = ERROR_NUMBER(), @m = ERROR_MESSAGE(); END CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT #r (id, prueba, esperado, obtenido, detalle)
    VALUES (@id, @prueba, N'ERROR ' + CAST(@codigo AS NVARCHAR(10)),
            CASE WHEN @n IS NULL THEN N'SIN ERROR' ELSE N'ERROR ' + CAST(@n AS NVARCHAR(10)) END, @m);
END
GO
-- Prueba que DEBE FUNCIONAR: el texto asigna @v con el valor a comprobar. @tran = 1 => dentro de transacción con ROLLBACK.
CREATE PROCEDURE #ok @id VARCHAR(8), @prueba NVARCHAR(160), @esperado NVARCHAR(200), @sql NVARCHAR(MAX), @tran BIT = 1
AS
BEGIN
    DECLARE @v NVARCHAR(200) = NULL, @m NVARCHAR(400) = NULL;
    SET @sql = REPLACE(@sql, '~', '''');
    IF @tran = 1 BEGIN TRANSACTION;
    BEGIN TRY EXEC sp_executesql @sql, N'@v NVARCHAR(200) OUTPUT', @v OUTPUT; END TRY
    BEGIN CATCH SELECT @v = N'ERROR ' + CAST(ERROR_NUMBER() AS NVARCHAR(10)), @m = ERROR_MESSAGE(); END CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT #r (id, prueba, esperado, obtenido, detalle) VALUES (@id, @prueba, @esperado, @v, @m);
END
GO

/* ===================== PROCEDIMIENTOS INSERT (8) ===================== */
EXEC #ok  'TP-I01', N'usp_Categoria_Insertar: inserta una categoría válida', N'1',
  N'DECLARE @id INT; EXEC dbo.usp_Categoria_Insertar @nombre = N~Congelados~, @tipo = ~ALIMENTO~, @id_categoria = @id OUTPUT;
    SET @v = CAST((SELECT COUNT(*) FROM Categoria WHERE id_categoria = @id AND nombre = N~Congelados~) AS NVARCHAR(200));';
EXEC #err 'TP-I02', N'usp_Categoria_Insertar: rechaza nombre duplicado', 50002,
  N'DECLARE @id INT; EXEC dbo.usp_Categoria_Insertar @nombre = N~Lácteos~, @tipo = ~ALIMENTO~, @id_categoria = @id OUTPUT;';
EXEC #err 'TP-I03', N'usp_Categoria_Insertar: rechaza tipo inválido', 50005,
  N'DECLARE @id INT; EXEC dbo.usp_Categoria_Insertar @nombre = N~Otra~, @tipo = ~OTROS~, @id_categoria = @id OUTPUT;';

EXEC #ok  'TP-I04', N'usp_Producto_Insertar: inserta un producto válido', N'1',
  N'DECLARE @id INT; EXEC dbo.usp_Producto_Insertar @codigo_barras = ~7750100100216~, @nombre = N~Helado 1 L~, @precio_venta = 14.90, @stock_minimo = 5, @id_categoria = 1, @id_producto = @id OUTPUT;
    SET @v = CAST((SELECT COUNT(*) FROM Producto WHERE id_producto = @id) AS NVARCHAR(200));';
EXEC #err 'TP-I05', N'usp_Producto_Insertar: rechaza código de barras duplicado', 50002,
  N'DECLARE @id INT; EXEC dbo.usp_Producto_Insertar @codigo_barras = ~7750100100018~, @nombre = N~Repetido~, @precio_venta = 5, @id_categoria = 1, @id_producto = @id OUTPUT;';
EXEC #err 'TP-I06', N'usp_Producto_Insertar: rechaza categoría inexistente (FK)', 50003,
  N'DECLARE @id INT; EXEC dbo.usp_Producto_Insertar @codigo_barras = ~7750100100223~, @nombre = N~Sin categoría~, @precio_venta = 5, @id_categoria = 999, @id_producto = @id OUTPUT;';
EXEC #err 'TP-I07', N'usp_Producto_Insertar: rechaza precio cero', 50005,
  N'DECLARE @id INT; EXEC dbo.usp_Producto_Insertar @codigo_barras = ~7750100100230~, @nombre = N~Gratis~, @precio_venta = 0, @id_categoria = 1, @id_producto = @id OUTPUT;';

EXEC #ok  'TP-I08', N'usp_Lote_Insertar: el stock inicial iguala la cantidad recibida', N'50',
  N'DECLARE @id INT; EXEC dbo.usp_Lote_Insertar @id_producto = 4, @numero_lote = ~LT-FID-2611A~, @fecha_ingreso = ~2026-11-10~, @fecha_vencimiento = ~2028-11-10~, @cantidad_inicial = 50, @costo_unitario = 3.00, @id_lote = @id OUTPUT;
    SET @v = CAST((SELECT stock_actual FROM Lote WHERE id_lote = @id) AS NVARCHAR(200));';
EXEC #err 'TP-I09', N'usp_Lote_Insertar: rechaza producto inexistente (FK)', 50003,
  N'DECLARE @id INT; EXEC dbo.usp_Lote_Insertar @id_producto = 999, @numero_lote = ~X-1~, @cantidad_inicial = 10, @costo_unitario = 1, @id_lote = @id OUTPUT;';
EXEC #err 'TP-I10', N'usp_Lote_Insertar: rechaza número de lote repetido', 50002,
  N'DECLARE @id INT; EXEC dbo.usp_Lote_Insertar @id_producto = 1, @numero_lote = ~LT-ARZ-2609A~, @cantidad_inicial = 10, @costo_unitario = 1, @id_lote = @id OUTPUT;';
EXEC #err 'TP-I11', N'usp_Lote_Insertar: rechaza cantidad cero', 50005,
  N'DECLARE @id INT; EXEC dbo.usp_Lote_Insertar @id_producto = 1, @numero_lote = ~X-2~, @cantidad_inicial = 0, @costo_unitario = 1, @id_lote = @id OUTPUT;';
EXEC #err 'TP-I12', N'usp_Lote_Insertar: rechaza vencimiento anterior al ingreso', 50005,
  N'DECLARE @id INT; EXEC dbo.usp_Lote_Insertar @id_producto = 1, @numero_lote = ~X-3~, @fecha_ingreso = ~2026-11-10~, @fecha_vencimiento = ~2026-11-01~, @cantidad_inicial = 5, @costo_unitario = 1, @id_lote = @id OUTPUT;';
EXEC #err 'TP-I13', N'usp_Lote_Insertar: rechaza producto INACTIVO', 50007,
  N'DECLARE @id INT; EXEC dbo.usp_Lote_Insertar @id_producto = 20, @numero_lote = ~X-4~, @cantidad_inicial = 5, @costo_unitario = 1, @id_lote = @id OUTPUT;';

EXEC #ok  'TP-I14', N'usp_Cliente_Insertar: inserta un cliente válido', N'1',
  N'DECLARE @id INT; EXEC dbo.usp_Cliente_Insertar @dni = ~78123456~, @nombres = N~Rosa María~, @apellidos = N~Cáceres Luna~, @telefono = ~987001122~, @distrito = N~Comas~, @id_cliente = @id OUTPUT;
    SET @v = CAST((SELECT COUNT(*) FROM Cliente WHERE id_cliente = @id AND dni = ~78123456~) AS NVARCHAR(200));';
EXEC #err 'TP-I15', N'usp_Cliente_Insertar: rechaza DNI duplicado', 50002,
  N'DECLARE @id INT; EXEC dbo.usp_Cliente_Insertar @dni = ~10234567~, @nombres = N~Otro~, @apellidos = N~Cliente~, @distrito = N~Comas~, @id_cliente = @id OUTPUT;';
EXEC #err 'TP-I16', N'usp_Cliente_Insertar: rechaza DNI con letras', 50005,
  N'DECLARE @id INT; EXEC dbo.usp_Cliente_Insertar @dni = ~ABC12345~, @nombres = N~Otro~, @apellidos = N~Cliente~, @distrito = N~Comas~, @id_cliente = @id OUTPUT;';

EXEC #ok  'TP-I17', N'usp_Empleado_Insertar: inserta un empleado válido y activo', N'1',
  N'DECLARE @id INT; EXEC dbo.usp_Empleado_Insertar @dni = ~80123456~, @nombres = N~Pedro~, @apellidos = N~Rivas~, @correo = ~privas@lafavorita.pe~, @usuario = ~privas~, @clave_hash = ~pbkdf2_sha256$600000$SaltDePrueba0001$HashDePrueba0123456789abcdefghijklmnopqrst=~, @rol = ~CAJERO~, @id_empleado = @id OUTPUT;
    SET @v = CAST((SELECT COUNT(*) FROM Empleado WHERE id_empleado = @id AND activo = 1) AS NVARCHAR(200));';
EXEC #err 'TP-I18', N'usp_Empleado_Insertar: rechaza DNI duplicado', 50002,
  N'DECLARE @id INT; EXEC dbo.usp_Empleado_Insertar @dni = ~40123456~, @nombres = N~A~, @apellidos = N~B~, @correo = ~a@b.pe~, @usuario = ~nuevo1~, @clave_hash = ~pbkdf2_sha256$1$x$y~, @rol = ~CAJERO~, @id_empleado = @id OUTPUT;';
EXEC #err 'TP-I19', N'usp_Empleado_Insertar: rechaza usuario duplicado', 50002,
  N'DECLARE @id INT; EXEC dbo.usp_Empleado_Insertar @dni = ~80123457~, @nombres = N~A~, @apellidos = N~B~, @correo = ~a2@b.pe~, @usuario = ~cperez~, @clave_hash = ~pbkdf2_sha256$1$x$y~, @rol = ~CAJERO~, @id_empleado = @id OUTPUT;';
EXEC #err 'TP-I20', N'usp_Empleado_Insertar: rechaza rol inválido', 50005,
  N'DECLARE @id INT; EXEC dbo.usp_Empleado_Insertar @dni = ~80123458~, @nombres = N~A~, @apellidos = N~B~, @correo = ~a3@b.pe~, @usuario = ~nuevo3~, @clave_hash = ~pbkdf2_sha256$1$x$y~, @rol = ~GERENTE~, @id_empleado = @id OUTPUT;';
EXEC #err 'TP-I21', N'usp_Empleado_Insertar: rechaza contraseña en texto plano', 50005,
  N'DECLARE @id INT; EXEC dbo.usp_Empleado_Insertar @dni = ~80123459~, @nombres = N~A~, @apellidos = N~B~, @correo = ~a4@b.pe~, @usuario = ~nuevo4~, @clave_hash = ~miClave123~, @rol = ~CAJERO~, @id_empleado = @id OUTPUT;';

EXEC #ok  'TP-I22', N'usp_Venta_Registrar: total, stock descontado (lote 1: 35->33; lote 13: 50->44)', N'52.00|33|44',
  N'DECLARE @l dbo.tvp_LineaVenta, @id INT; INSERT @l VALUES (1, 2), (13, 6);
    EXEC dbo.usp_Venta_Registrar @id_empleado = 3, @id_cliente = 1, @tipo_pago = ~YAPE~, @lineas = @l, @id_venta = @id OUTPUT;
    SET @v = CONCAT((SELECT total FROM Venta WHERE id_venta = @id), ~|~, (SELECT stock_actual FROM Lote WHERE id_lote = 1), ~|~, (SELECT stock_actual FROM Lote WHERE id_lote = 13));';
EXEC #ok  'TP-I23', N'usp_Venta_Registrar: emite la boleta en la misma transacción (B001-18)', N'B001-18',
  N'DECLARE @l dbo.tvp_LineaVenta, @id INT; INSERT @l VALUES (4, 1);
    EXEC dbo.usp_Venta_Registrar @id_empleado = 3, @tipo_pago = ~EFECTIVO~, @lineas = @l, @tipo_comprobante = ~BOLETA~, @id_venta = @id OUTPUT;
    SET @v = (SELECT serie + ~-~ + CAST(numero AS NVARCHAR(10)) FROM Comprobante WHERE id_venta = @id);';
EXEC #ok  'TP-I24', N'usp_Venta_Registrar: total = suma de subtotales y precio vigente conservado', N'1|21.50',
  N'DECLARE @l dbo.tvp_LineaVenta, @id INT; INSERT @l VALUES (1, 1), (20, 1), (4, 2);
    EXEC dbo.usp_Venta_Registrar @id_empleado = 3, @tipo_pago = ~PLIN~, @lineas = @l, @id_venta = @id OUTPUT;
    SET @v = CONCAT(CASE WHEN (SELECT total FROM Venta WHERE id_venta = @id) = (SELECT SUM(subtotal) FROM Detalle_Venta WHERE id_venta = @id) THEN 1 ELSE 0 END,
                    ~|~, (SELECT precio_unitario FROM Detalle_Venta WHERE id_venta = @id AND id_lote = 1));';
EXEC #err 'TP-I25', N'usp_Venta_Registrar: rechaza vender más que el stock (lote 16 tiene 5)', 50004,
  N'DECLARE @l dbo.tvp_LineaVenta, @id INT; INSERT @l VALUES (16, 6);
    EXEC dbo.usp_Venta_Registrar @id_empleado = 3, @tipo_pago = ~EFECTIVO~, @lineas = @l, @id_venta = @id OUTPUT;';
EXEC #err 'TP-I26', N'usp_Venta_Registrar: rechaza lote vencido (lote 7)', 50009,
  N'DECLARE @l dbo.tvp_LineaVenta, @id INT; INSERT @l VALUES (7, 1);
    EXEC dbo.usp_Venta_Registrar @id_empleado = 3, @tipo_pago = ~EFECTIVO~, @lineas = @l, @id_venta = @id OUTPUT;';
EXEC #err 'TP-I27', N'usp_Venta_Registrar: rechaza empleado inactivo (id 17)', 50008,
  N'DECLARE @l dbo.tvp_LineaVenta, @id INT; INSERT @l VALUES (1, 1);
    EXEC dbo.usp_Venta_Registrar @id_empleado = 17, @tipo_pago = ~EFECTIVO~, @lineas = @l, @id_venta = @id OUTPUT;';
EXEC #err 'TP-I28', N'usp_Venta_Registrar: rechaza empleado inexistente (FK)', 50003,
  N'DECLARE @l dbo.tvp_LineaVenta, @id INT; INSERT @l VALUES (1, 1);
    EXEC dbo.usp_Venta_Registrar @id_empleado = 999, @tipo_pago = ~EFECTIVO~, @lineas = @l, @id_venta = @id OUTPUT;';
EXEC #err 'TP-I29', N'usp_Venta_Registrar: rechaza cliente inexistente (FK)', 50003,
  N'DECLARE @l dbo.tvp_LineaVenta, @id INT; INSERT @l VALUES (1, 1);
    EXEC dbo.usp_Venta_Registrar @id_empleado = 3, @id_cliente = 999, @tipo_pago = ~EFECTIVO~, @lineas = @l, @id_venta = @id OUTPUT;';
EXEC #err 'TP-I30', N'usp_Venta_Registrar: rechaza cantidad cero', 50005,
  N'DECLARE @l dbo.tvp_LineaVenta, @id INT; INSERT @l VALUES (1, 0);
    EXEC dbo.usp_Venta_Registrar @id_empleado = 3, @tipo_pago = ~EFECTIVO~, @lineas = @l, @id_venta = @id OUTPUT;';
EXEC #err 'TP-I31', N'usp_Venta_Registrar: rechaza venta sin líneas', 50005,
  N'DECLARE @l dbo.tvp_LineaVenta, @id INT;
    EXEC dbo.usp_Venta_Registrar @id_empleado = 3, @tipo_pago = ~EFECTIVO~, @lineas = @l, @id_venta = @id OUTPUT;';
EXEC #err 'TP-I32', N'usp_Venta_Registrar: rechaza lote inexistente (FK)', 50003,
  N'DECLARE @l dbo.tvp_LineaVenta, @id INT; INSERT @l VALUES (999, 1);
    EXEC dbo.usp_Venta_Registrar @id_empleado = 3, @tipo_pago = ~EFECTIVO~, @lineas = @l, @id_venta = @id OUTPUT;';
EXEC #err 'TP-I33', N'usp_Venta_Registrar: rechaza medio de pago inválido', 50005,
  N'DECLARE @l dbo.tvp_LineaVenta, @id INT; INSERT @l VALUES (1, 1);
    EXEC dbo.usp_Venta_Registrar @id_empleado = 3, @tipo_pago = ~CHEQUE~, @lineas = @l, @id_venta = @id OUTPUT;';
-- Atomicidad real: SIN transacción externa. La venta falla al emitir la factura (sin RUC) DESPUÉS de haber
-- insertado venta, detalle y descontado stock; el procedimiento debe revertir todo.
EXEC #ok  'TP-I34', N'usp_Venta_Registrar: atomicidad (falla la factura sin RUC y se revierte venta, detalle y stock)', N'ATOMICO',
  N'DECLARE @l dbo.tvp_LineaVenta, @id INT, @s1 INT = (SELECT stock_actual FROM Lote WHERE id_lote = 1),
            @nv INT = (SELECT COUNT(*) FROM Venta), @nd INT = (SELECT COUNT(*) FROM Detalle_Venta);
    INSERT @l VALUES (1, 1);
    BEGIN TRY EXEC dbo.usp_Venta_Registrar @id_empleado = 3, @tipo_pago = ~EFECTIVO~, @lineas = @l, @tipo_comprobante = ~FACTURA~, @id_venta = @id OUTPUT; END TRY
    BEGIN CATCH END CATCH
    SET @v = CASE WHEN (SELECT stock_actual FROM Lote WHERE id_lote = 1) = @s1 AND (SELECT COUNT(*) FROM Venta) = @nv
                   AND (SELECT COUNT(*) FROM Detalle_Venta) = @nd THEN ~ATOMICO~ ELSE ~PARCIAL~ END;', 0;

EXEC #ok  'TP-I35', N'usp_DetalleVenta_Agregar: agrega línea, descuenta stock y recalcula total', N'32.90|55',
  N'DECLARE @l dbo.tvp_LineaVenta, @v1 INT, @d INT; INSERT @l VALUES (1, 1);
    EXEC dbo.usp_Venta_Registrar @id_empleado = 3, @tipo_pago = ~EFECTIVO~, @lineas = @l, @id_venta = @v1 OUTPUT;
    EXEC dbo.usp_DetalleVenta_Agregar @id_venta = @v1, @id_lote = 4, @cantidad = 3, @id_detalle = @d OUTPUT;
    SET @v = CONCAT((SELECT total FROM Venta WHERE id_venta = @v1), ~|~, (SELECT stock_actual FROM Lote WHERE id_lote = 4));';
EXEC #err 'TP-I36', N'usp_DetalleVenta_Agregar: rechaza venta que ya tiene comprobante (venta 1)', 50007,
  N'DECLARE @d INT; EXEC dbo.usp_DetalleVenta_Agregar @id_venta = 1, @id_lote = 4, @cantidad = 1, @id_detalle = @d OUTPUT;';
EXEC #err 'TP-I37', N'usp_DetalleVenta_Agregar: rechaza línea repetida del mismo lote', 50002,
  N'DECLARE @l dbo.tvp_LineaVenta, @v1 INT, @d INT; INSERT @l VALUES (1, 1);
    EXEC dbo.usp_Venta_Registrar @id_empleado = 3, @tipo_pago = ~EFECTIVO~, @lineas = @l, @id_venta = @v1 OUTPUT;
    EXEC dbo.usp_DetalleVenta_Agregar @id_venta = @v1, @id_lote = 1, @cantidad = 1, @id_detalle = @d OUTPUT;';
EXEC #err 'TP-I38', N'usp_DetalleVenta_Agregar: rechaza cantidad mayor al stock', 50004,
  N'DECLARE @l dbo.tvp_LineaVenta, @v1 INT, @d INT; INSERT @l VALUES (1, 1);
    EXEC dbo.usp_Venta_Registrar @id_empleado = 3, @tipo_pago = ~EFECTIVO~, @lineas = @l, @id_venta = @v1 OUTPUT;
    EXEC dbo.usp_DetalleVenta_Agregar @id_venta = @v1, @id_lote = 16, @cantidad = 6, @id_detalle = @d OUTPUT;';
EXEC #err 'TP-I39', N'usp_DetalleVenta_Agregar: rechaza venta inexistente (FK)', 50003,
  N'DECLARE @d INT; EXEC dbo.usp_DetalleVenta_Agregar @id_venta = 99999, @id_lote = 4, @cantidad = 1, @id_detalle = @d OUTPUT;';

EXEC #ok  'TP-I40', N'usp_Comprobante_Emitir: boleta con el siguiente correlativo (B001-18)', N'B001-18',
  N'DECLARE @l dbo.tvp_LineaVenta, @v1 INT, @c INT; INSERT @l VALUES (4, 1);
    EXEC dbo.usp_Venta_Registrar @id_empleado = 3, @tipo_pago = ~EFECTIVO~, @lineas = @l, @id_venta = @v1 OUTPUT;
    EXEC dbo.usp_Comprobante_Emitir @id_venta = @v1, @tipo_comprobante = ~BOLETA~, @id_comprobante = @c OUTPUT;
    SET @v = (SELECT serie + ~-~ + CAST(numero AS NVARCHAR(10)) FROM Comprobante WHERE id_comprobante = @c);';
EXEC #ok  'TP-I41', N'usp_Comprobante_Emitir: factura con RUC y siguiente correlativo (F001-4)', N'F001-4|20601234561',
  N'DECLARE @l dbo.tvp_LineaVenta, @v1 INT, @c INT; INSERT @l VALUES (4, 1);
    EXEC dbo.usp_Venta_Registrar @id_empleado = 3, @tipo_pago = ~EFECTIVO~, @lineas = @l, @id_venta = @v1 OUTPUT;
    EXEC dbo.usp_Comprobante_Emitir @id_venta = @v1, @tipo_comprobante = ~FACTURA~, @ruc_receptor = ~20601234561~, @id_comprobante = @c OUTPUT;
    SET @v = (SELECT serie + ~-~ + CAST(numero AS NVARCHAR(10)) + ~|~ + ruc_receptor FROM Comprobante WHERE id_comprobante = @c);';
EXEC #err 'TP-I42', N'usp_Comprobante_Emitir: rechaza segundo comprobante para la misma venta (venta 1)', 50002,
  N'DECLARE @c INT; EXEC dbo.usp_Comprobante_Emitir @id_venta = 1, @tipo_comprobante = ~BOLETA~, @id_comprobante = @c OUTPUT;';
EXEC #err 'TP-I43', N'usp_Comprobante_Emitir: rechaza factura sin RUC', 50005,
  N'DECLARE @l dbo.tvp_LineaVenta, @v1 INT, @c INT; INSERT @l VALUES (4, 1);
    EXEC dbo.usp_Venta_Registrar @id_empleado = 3, @tipo_pago = ~EFECTIVO~, @lineas = @l, @id_venta = @v1 OUTPUT;
    EXEC dbo.usp_Comprobante_Emitir @id_venta = @v1, @tipo_comprobante = ~FACTURA~, @id_comprobante = @c OUTPUT;';
EXEC #err 'TP-I44', N'usp_Comprobante_Emitir: rechaza boleta con RUC', 50005,
  N'DECLARE @l dbo.tvp_LineaVenta, @v1 INT, @c INT; INSERT @l VALUES (4, 1);
    EXEC dbo.usp_Venta_Registrar @id_empleado = 3, @tipo_pago = ~EFECTIVO~, @lineas = @l, @id_venta = @v1 OUTPUT;
    EXEC dbo.usp_Comprobante_Emitir @id_venta = @v1, @tipo_comprobante = ~BOLETA~, @ruc_receptor = ~20601234561~, @id_comprobante = @c OUTPUT;';
EXEC #err 'TP-I45', N'usp_Comprobante_Emitir: rechaza venta inexistente (FK)', 50003,
  N'DECLARE @c INT; EXEC dbo.usp_Comprobante_Emitir @id_venta = 99999, @tipo_comprobante = ~BOLETA~, @id_comprobante = @c OUTPUT;';
EXEC #err 'TP-I46', N'usp_Comprobante_Emitir: rechaza RUC mal formado (empieza con 30)', 50005,
  N'DECLARE @c INT; EXEC dbo.usp_Comprobante_Emitir @id_venta = 99999, @tipo_comprobante = ~FACTURA~, @ruc_receptor = ~30601234561~, @id_comprobante = @c OUTPUT;';

/* ===================== PROCEDIMIENTOS UPDATE (6) ===================== */
EXEC #ok  'TP-U01', N'usp_Producto_ActualizarPrecio: actualiza el precio (producto 3 -> 10.50)', N'10.50',
  N'EXEC dbo.usp_Producto_ActualizarPrecio @id_producto = 3, @precio_nuevo = 10.50;
    SET @v = CAST((SELECT precio_venta FROM Producto WHERE id_producto = 3) AS NVARCHAR(200));';
EXEC #err 'TP-U02', N'usp_Producto_ActualizarPrecio: rechaza producto inexistente', 50001,
  N'EXEC dbo.usp_Producto_ActualizarPrecio @id_producto = 999, @precio_nuevo = 10;';
EXEC #err 'TP-U03', N'usp_Producto_ActualizarPrecio: rechaza precio cero', 50005,
  N'EXEC dbo.usp_Producto_ActualizarPrecio @id_producto = 3, @precio_nuevo = 0;';
EXEC #err 'TP-U04', N'usp_Producto_ActualizarPrecio: rechaza precio menor al costo (arroz costo 18.50)', 50005,
  N'EXEC dbo.usp_Producto_ActualizarPrecio @id_producto = 1, @precio_nuevo = 10.00;';
EXEC #ok  'TP-U05', N'usp_Producto_ActualizarPrecio: las ventas históricas conservan su precio (RN-09)', N'9.80',
  N'EXEC dbo.usp_Producto_ActualizarPrecio @id_producto = 3, @precio_nuevo = 10.50;
    SET @v = CAST((SELECT precio_unitario FROM Detalle_Venta WHERE id_detalle = 6) AS NVARCHAR(200));';
EXEC #ok  'TP-U06', N'usp_Producto_CambiarEstado: reactiva el producto 20', N'ACTIVO',
  N'EXEC dbo.usp_Producto_CambiarEstado @id_producto = 20, @estado = ~ACTIVO~;
    SET @v = (SELECT estado FROM Producto WHERE id_producto = 20);';
EXEC #err 'TP-U07', N'usp_Producto_CambiarEstado: rechaza el mismo estado', 50007,
  N'EXEC dbo.usp_Producto_CambiarEstado @id_producto = 1, @estado = ~ACTIVO~;';
EXEC #err 'TP-U08', N'usp_Producto_CambiarEstado: rechaza estado inválido', 50005,
  N'EXEC dbo.usp_Producto_CambiarEstado @id_producto = 1, @estado = ~BORRADO~;';
EXEC #err 'TP-U09', N'usp_Producto_CambiarEstado: rechaza producto inexistente', 50001,
  N'EXEC dbo.usp_Producto_CambiarEstado @id_producto = 999, @estado = ~ACTIVO~;';
EXEC #ok  'TP-U10', N'usp_Cliente_ActualizarContacto: cambia teléfono y conserva el resto', N'987654000|Independencia',
  N'EXEC dbo.usp_Cliente_ActualizarContacto @id_cliente = 7, @telefono = ~987654000~;
    SET @v = (SELECT telefono + ~|~ + distrito FROM Cliente WHERE id_cliente = 7);';
EXEC #err 'TP-U11', N'usp_Cliente_ActualizarContacto: rechaza cliente inexistente', 50001,
  N'EXEC dbo.usp_Cliente_ActualizarContacto @id_cliente = 999, @telefono = ~987654000~;';
EXEC #err 'TP-U12', N'usp_Cliente_ActualizarContacto: rechaza teléfono que no empieza con 9', 50005,
  N'EXEC dbo.usp_Cliente_ActualizarContacto @id_cliente = 7, @telefono = ~812345678~;';
EXEC #ok  'TP-U13', N'usp_Empleado_CambiarEstado: desactiva al empleado 19', N'0',
  N'EXEC dbo.usp_Empleado_CambiarEstado @id_empleado = 19, @activo = 0;
    SET @v = CAST((SELECT CAST(activo AS INT) FROM Empleado WHERE id_empleado = 19) AS NVARCHAR(200));';
EXEC #err 'TP-U14', N'usp_Empleado_CambiarEstado: rechaza el mismo estado', 50007,
  N'EXEC dbo.usp_Empleado_CambiarEstado @id_empleado = 19, @activo = 1;';
EXEC #err 'TP-U15', N'usp_Empleado_CambiarEstado: protege al único SUPERADMIN activo', 50007,
  N'EXEC dbo.usp_Empleado_CambiarEstado @id_empleado = 1, @activo = 0;';
EXEC #err 'TP-U16', N'usp_Empleado_CambiarEstado: rechaza empleado inexistente', 50001,
  N'EXEC dbo.usp_Empleado_CambiarEstado @id_empleado = 999, @activo = 0;';
EXEC #ok  'TP-U17', N'usp_Lote_AjustarStock: merma de 2 unidades (lote 13: 50 -> 48)', N'48',
  N'EXEC dbo.usp_Lote_AjustarStock @id_lote = 13, @ajuste = -2, @motivo = N~Botellas rotas~;
    SET @v = CAST((SELECT stock_actual FROM Lote WHERE id_lote = 13) AS NVARCHAR(200));';
EXEC #err 'TP-U18', N'usp_Lote_AjustarStock: rechaza ajuste que deja stock negativo (lote 16 tiene 5)', 50004,
  N'EXEC dbo.usp_Lote_AjustarStock @id_lote = 16, @ajuste = -6, @motivo = N~Prueba~;';
EXEC #err 'TP-U19', N'usp_Lote_AjustarStock: rechaza stock superior a lo recibido (lote 1: 35 + 6 > 40)', 50005,
  N'EXEC dbo.usp_Lote_AjustarStock @id_lote = 1, @ajuste = 6, @motivo = N~Prueba~;';
EXEC #err 'TP-U20', N'usp_Lote_AjustarStock: rechaza lote inexistente', 50001,
  N'EXEC dbo.usp_Lote_AjustarStock @id_lote = 999, @ajuste = 1, @motivo = N~Prueba~;';
EXEC #err 'TP-U21', N'usp_Lote_AjustarStock: rechaza ajuste cero', 50005,
  N'EXEC dbo.usp_Lote_AjustarStock @id_lote = 1, @ajuste = 0, @motivo = N~Prueba~;';
EXEC #ok  'TP-U22', N'usp_Venta_CambiarMedioPago: venta 1 de EFECTIVO a YAPE', N'YAPE|29.10',
  N'EXEC dbo.usp_Venta_CambiarMedioPago @id_venta = 1, @tipo_pago = ~YAPE~;
    SET @v = (SELECT tipo_pago + ~|~ + CAST(total AS NVARCHAR(20)) FROM Venta WHERE id_venta = 1);';
EXEC #err 'TP-U23', N'usp_Venta_CambiarMedioPago: rechaza medio de pago inválido', 50005,
  N'EXEC dbo.usp_Venta_CambiarMedioPago @id_venta = 1, @tipo_pago = ~CHEQUE~;';
EXEC #err 'TP-U24', N'usp_Venta_CambiarMedioPago: rechaza venta inexistente', 50001,
  N'EXEC dbo.usp_Venta_CambiarMedioPago @id_venta = 99999, @tipo_pago = ~YAPE~;';
EXEC #err 'TP-U25', N'usp_Venta_CambiarMedioPago: rechaza el mismo medio de pago', 50007,
  N'EXEC dbo.usp_Venta_CambiarMedioPago @id_venta = 1, @tipo_pago = ~EFECTIVO~;';

/* ===================== PROCEDIMIENTOS DELETE (2) ===================== */
EXEC #ok  'TP-D01', N'usp_Cliente_Eliminar: elimina un cliente sin ventas', N'0',
  N'DECLARE @id INT; EXEC dbo.usp_Cliente_Insertar @dni = ~78999001~, @nombres = N~Prueba~, @apellidos = N~Temporal~, @distrito = N~Comas~, @id_cliente = @id OUTPUT;
    EXEC dbo.usp_Cliente_Eliminar @id_cliente = @id;
    SET @v = CAST((SELECT COUNT(*) FROM Cliente WHERE id_cliente = @id) AS NVARCHAR(200));';
EXEC #err 'TP-D02', N'usp_Cliente_Eliminar: rechaza eliminar un cliente con ventas (cliente 1)', 50006,
  N'EXEC dbo.usp_Cliente_Eliminar @id_cliente = 1;';
EXEC #err 'TP-D03', N'usp_Cliente_Eliminar: rechaza cliente inexistente', 50001,
  N'EXEC dbo.usp_Cliente_Eliminar @id_cliente = 999;';
EXEC #ok  'TP-D04', N'usp_Venta_Anular: anula la venta 20, repone stock (lote 11: 21->22; lote 9: 32->33) y borra comprobante', N'22|33|0|0',
  N'EXEC dbo.usp_Venta_Anular @id_venta = 20, @id_empleado_autoriza = 2;
    SET @v = CONCAT((SELECT stock_actual FROM Lote WHERE id_lote = 11), ~|~, (SELECT stock_actual FROM Lote WHERE id_lote = 9), ~|~,
                    (SELECT COUNT(*) FROM Venta WHERE id_venta = 20), ~|~, (SELECT COUNT(*) FROM Comprobante WHERE id_venta = 20));';
EXEC #err 'TP-D05', N'usp_Venta_Anular: rechaza venta inexistente', 50001,
  N'EXEC dbo.usp_Venta_Anular @id_venta = 99999, @id_empleado_autoriza = 2;';
EXEC #err 'TP-D06', N'usp_Venta_Anular: rechaza a un CAJERO (no autorizado)', 50010,
  N'EXEC dbo.usp_Venta_Anular @id_venta = 20, @id_empleado_autoriza = 3;';
EXEC #err 'TP-D07', N'usp_Venta_Anular: rechaza empleado autorizador inexistente', 50010,
  N'EXEC dbo.usp_Venta_Anular @id_venta = 20, @id_empleado_autoriza = 999;';
EXEC #ok  'TP-D08', N'usp_Venta_Anular: una venta nueva anulada deja el stock como estaba (lote 1: 35)', N'35|0',
  N'DECLARE @l dbo.tvp_LineaVenta, @id INT; INSERT @l VALUES (1, 5);
    EXEC dbo.usp_Venta_Registrar @id_empleado = 3, @tipo_pago = ~EFECTIVO~, @lineas = @l, @tipo_comprobante = ~BOLETA~, @id_venta = @id OUTPUT;
    EXEC dbo.usp_Venta_Anular @id_venta = @id, @id_empleado_autoriza = 1;
    SET @v = CONCAT((SELECT stock_actual FROM Lote WHERE id_lote = 1), ~|~, (SELECT COUNT(*) FROM Venta WHERE id_venta = @id));';

/* ===================== PROCEDIMIENTOS SELECT (10) ===================== */
-- Los procedimientos SELECT devuelven sus conjuntos de resultados al cliente; la prueba verifica @@ROWCOUNT
-- del último SELECT ejecutado por el procedimiento.
EXEC #ok  'TP-S01', N'usp_Producto_Buscar: búsqueda por texto «gaseosa» devuelve 2 productos', N'2',
  N'EXEC dbo.usp_Producto_Buscar @texto = N~gaseosa~; SET @v = CAST(@@ROWCOUNT AS NVARCHAR(200));';
EXEC #ok  'TP-S02', N'usp_Producto_Buscar: búsqueda por código de barras exacto devuelve 1 producto', N'1',
  N'EXEC dbo.usp_Producto_Buscar @texto = N~7750100100018~; SET @v = CAST(@@ROWCOUNT AS NVARCHAR(200));';
EXEC #ok  'TP-S03', N'usp_Producto_Buscar: texto sin coincidencias devuelve 0 filas (sin error)', N'0',
  N'EXEC dbo.usp_Producto_Buscar @texto = N~zzzz~; SET @v = CAST(@@ROWCOUNT AS NVARCHAR(200));';
EXEC #ok  'TP-S04', N'usp_Stock_Consultar: el arroz (producto 1) tiene 2 lotes', N'2',
  N'EXEC dbo.usp_Stock_Consultar @id_producto = 1; SET @v = CAST(@@ROWCOUNT AS NVARCHAR(200));';
EXEC #err 'TP-S05', N'usp_Stock_Consultar: rechaza producto inexistente', 50001,
  N'EXEC dbo.usp_Stock_Consultar @id_producto = 999;';
EXEC #ok  'TP-S06', N'usp_Productos_StockBajo: 4 productos agotados o en alerta', N'4',
  N'EXEC dbo.usp_Productos_StockBajo; SET @v = CAST(@@ROWCOUNT AS NVARCHAR(200));';
EXEC #ok  'TP-S07', N'usp_Lotes_PorVencer: con 10000 días devuelve los 19 lotes perecibles con stock', N'19',
  N'EXEC dbo.usp_Lotes_PorVencer @dias = 10000; SET @v = CAST(@@ROWCOUNT AS NVARCHAR(200));';
EXEC #err 'TP-S08', N'usp_Lotes_PorVencer: rechaza días negativos', 50005,
  N'EXEC dbo.usp_Lotes_PorVencer @dias = -1;';
EXEC #ok  'TP-S09', N'usp_Cliente_BuscarPorDni: encuentra al cliente 10234567', N'1',
  N'EXEC dbo.usp_Cliente_BuscarPorDni @dni = ~10234567~; SET @v = CAST(@@ROWCOUNT AS NVARCHAR(200));';
EXEC #err 'TP-S10', N'usp_Cliente_BuscarPorDni: DNI inexistente', 50001,
  N'EXEC dbo.usp_Cliente_BuscarPorDni @dni = ~99999999~;';
EXEC #err 'TP-S11', N'usp_Cliente_BuscarPorDni: DNI con formato inválido', 50005,
  N'EXEC dbo.usp_Cliente_BuscarPorDni @dni = ~ABC~;';
EXEC #ok  'TP-S12', N'usp_Venta_Detalle: la venta 4 tiene 3 líneas', N'3',
  N'EXEC dbo.usp_Venta_Detalle @id_venta = 4; SET @v = CAST(@@ROWCOUNT AS NVARCHAR(200));';
EXEC #err 'TP-S13', N'usp_Venta_Detalle: rechaza venta inexistente', 50001,
  N'EXEC dbo.usp_Venta_Detalle @id_venta = 99999;';
EXEC #ok  'TP-S14', N'usp_Ventas_PorRango: del 01 al 07 de octubre hay 8 ventas', N'8',
  N'EXEC dbo.usp_Ventas_PorRango @desde = ~2026-10-01~, @hasta = ~2026-10-07~; SET @v = CAST(@@ROWCOUNT AS NVARCHAR(200));';
EXEC #err 'TP-S15', N'usp_Ventas_PorRango: rechaza rango invertido', 50005,
  N'EXEC dbo.usp_Ventas_PorRango @desde = ~2026-10-10~, @hasta = ~2026-10-01~;';
EXEC #ok  'TP-S16', N'usp_Comprobante_Consultar: encuentra la factura F001-1', N'1',
  N'EXEC dbo.usp_Comprobante_Consultar @serie = ~F001~, @numero = 1; SET @v = CAST(@@ROWCOUNT AS NVARCHAR(200));';
EXEC #err 'TP-S17', N'usp_Comprobante_Consultar: comprobante inexistente', 50001,
  N'EXEC dbo.usp_Comprobante_Consultar @serie = ~F001~, @numero = 999;';
EXEC #ok  'TP-S18', N'usp_Productos_MasVendidos: top 3', N'3',
  N'EXEC dbo.usp_Productos_MasVendidos @top = 3; SET @v = CAST(@@ROWCOUNT AS NVARCHAR(200));';
EXEC #err 'TP-S19', N'usp_Productos_MasVendidos: rechaza top = 0', 50005,
  N'EXEC dbo.usp_Productos_MasVendidos @top = 0;';
EXEC #ok  'TP-S20', N'usp_Cliente_HistorialCompras: el cliente 4 tiene 2 líneas compradas', N'2',
  N'EXEC dbo.usp_Cliente_HistorialCompras @id_cliente = 4; SET @v = CAST(@@ROWCOUNT AS NVARCHAR(200));';
EXEC #err 'TP-S21', N'usp_Cliente_HistorialCompras: rechaza cliente inexistente', 50001,
  N'EXEC dbo.usp_Cliente_HistorialCompras @id_cliente = 999;';

/* ===================== VERIFICACIÓN FINAL ===================== */
EXEC #ok  'TP-Z01', N'La base queda intacta después de todas las pruebas (conteo de las 8 tablas)', N'20|20|21|20|20|20|37|20',
  N'SET @v = CONCAT((SELECT COUNT(*) FROM Categoria), ~|~, (SELECT COUNT(*) FROM Producto), ~|~, (SELECT COUNT(*) FROM Lote), ~|~,
                    (SELECT COUNT(*) FROM Cliente), ~|~, (SELECT COUNT(*) FROM Empleado), ~|~, (SELECT COUNT(*) FROM Venta), ~|~,
                    (SELECT COUNT(*) FROM Detalle_Venta), ~|~, (SELECT COUNT(*) FROM Comprobante));', 0;
GO
SELECT id, prueba, esperado, obtenido, estado, detalle FROM #r ORDER BY id;
SELECT COUNT(*) AS pruebas, SUM(CASE WHEN estado = 'PASS' THEN 1 ELSE 0 END) AS aprobadas,
       SUM(CASE WHEN estado = 'FAIL' THEN 1 ELSE 0 END) AS fallidas FROM #r;
DECLARE @fallidas INT = (SELECT COUNT(*) FROM #r WHERE estado = 'FAIL');
IF @fallidas > 0 THROW 50098, N'Hay pruebas de procedimientos que fallaron.', 1;
GO
