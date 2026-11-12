/* ============================================================================
   test_integrity.sql - Pruebas de integridad y reglas de negocio a nivel de tabla
   Intenta operaciones INVÁLIDAS directamente sobre las tablas (sin pasar por los
   procedimientos). Todas deben ser rechazadas por las restricciones del modelo.
   Cada intento se hace dentro de una transacción con ROLLBACK (la base no cambia).
   Códigos de SQL Server: 2627 = clave única/primaria duplicada; 547 = FK o CHECK;
   515 = NULL en columna NOT NULL; 271 = columna calculada no actualizable.
   ============================================================================ */
USE MinimarketLaFavorita;
GO
SET NOCOUNT ON;
CREATE TABLE #r (
    id VARCHAR(8) NOT NULL, prueba NVARCHAR(160) NOT NULL, esperado NVARCHAR(200) NOT NULL, obtenido NVARCHAR(200) NULL, detalle NVARCHAR(400) NULL,
    estado AS CASE WHEN esperado = ISNULL(obtenido, N'') THEN 'PASS' ELSE 'FAIL' END);
GO
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
            CASE WHEN @n IS NULL THEN N'SIN ERROR' ELSE N'ERROR ' + CAST(@n AS NVARCHAR(10)) END, LEFT(@m, 400));
END
GO
-- Duplicados (clave única) -----------------------------------------------------------
EXEC #err 'TI-01', N'Insertar cliente con DNI duplicado', 2627,
  N'INSERT INTO Cliente (dni, nombres, apellidos, distrito) VALUES (~10234567~, N~X~, N~Y~, N~Comas~);';
EXEC #err 'TI-02', N'Insertar empleado con DNI duplicado', 2627,
  N'INSERT INTO Empleado (dni, nombres, apellidos, correo, usuario, clave_hash, rol, fecha_ingreso) VALUES (~40123456~, N~X~, N~Y~, ~x1@y.pe~, ~x1~, ~h~, ~CAJERO~, ~2026-11-01~);';
EXEC #err 'TI-03', N'Insertar producto con código de barras duplicado', 2627,
  N'INSERT INTO Producto (codigo_barras, nombre, precio_venta, id_categoria) VALUES (~7750100100018~, N~Repetido~, 5, 1);';
EXEC #err 'TI-04', N'Insertar lote con el mismo número para el mismo producto', 2627,
  N'INSERT INTO Lote (id_producto, numero_lote, fecha_ingreso, cantidad_inicial, stock_actual, costo_unitario) VALUES (1, ~LT-ARZ-2609A~, ~2026-11-01~, 5, 5, 1);';
EXEC #err 'TI-05', N'Registrar comprobante duplicado (misma serie y número)', 2627,
  N'INSERT INTO Venta (id_empleado, tipo_pago) VALUES (3, ~EFECTIVO~);
    INSERT INTO Comprobante (id_venta, tipo_comprobante, serie, numero, fecha_emision) VALUES (SCOPE_IDENTITY(), ~BOLETA~, ~B001~, 1, SYSDATETIME());';
EXEC #err 'TI-06', N'Registrar un segundo comprobante para la misma venta (1:1)', 2627,
  N'INSERT INTO Comprobante (id_venta, tipo_comprobante, serie, numero, fecha_emision) VALUES (1, ~BOLETA~, ~B001~, 999, SYSDATETIME());';
-- Claves foráneas inexistentes ---------------------------------------------------------
EXEC #err 'TI-07', N'Insertar producto con categoría inexistente', 547,
  N'INSERT INTO Producto (codigo_barras, nombre, precio_venta, id_categoria) VALUES (~7750100100299~, N~X~, 5, 999);';
EXEC #err 'TI-08', N'Insertar lote con producto inexistente', 547,
  N'INSERT INTO Lote (id_producto, numero_lote, fecha_ingreso, cantidad_inicial, stock_actual, costo_unitario) VALUES (999, ~L-X~, ~2026-11-01~, 5, 5, 1);';
EXEC #err 'TI-09', N'Insertar venta con cliente inexistente', 547,
  N'INSERT INTO Venta (id_empleado, id_cliente, tipo_pago) VALUES (3, 999, ~EFECTIVO~);';
EXEC #err 'TI-10', N'Insertar venta con empleado inexistente', 547,
  N'INSERT INTO Venta (id_empleado, tipo_pago) VALUES (999, ~EFECTIVO~);';
EXEC #err 'TI-11', N'Insertar detalle con lote inexistente', 547,
  N'INSERT INTO Detalle_Venta (id_venta, id_lote, cantidad, precio_unitario) VALUES (1, 999, 1, 5);';
EXEC #err 'TI-12', N'Insertar detalle con venta inexistente', 547,
  N'INSERT INTO Detalle_Venta (id_venta, id_lote, cantidad, precio_unitario) VALUES (99999, 1, 1, 5);';
EXEC #err 'TI-13', N'Insertar comprobante con venta inexistente', 547,
  N'INSERT INTO Comprobante (id_venta, tipo_comprobante, serie, numero, fecha_emision) VALUES (99999, ~BOLETA~, ~B001~, 500, SYSDATETIME());';
-- Stock ------------------------------------------------------------------------------
EXEC #err 'TI-14', N'Stock negativo: UPDATE Lote SET stock_actual = -1', 547,
  N'UPDATE Lote SET stock_actual = -1 WHERE id_lote = 1;';
EXEC #err 'TI-15', N'Vender más de lo disponible: descontar 100 unidades a un lote con 35', 547,
  N'UPDATE Lote SET stock_actual = stock_actual - 100 WHERE id_lote = 1;';
EXEC #err 'TI-16', N'Stock mayor que la cantidad recibida', 547,
  N'UPDATE Lote SET stock_actual = 1000 WHERE id_lote = 1;';
-- Importes y cantidades inválidos ----------------------------------------------------------
EXEC #err 'TI-17', N'Cantidad vendida igual a cero', 547,
  N'INSERT INTO Detalle_Venta (id_venta, id_lote, cantidad, precio_unitario) VALUES (3, 1, 0, 5);';
EXEC #err 'TI-18', N'Cantidad vendida negativa', 547,
  N'INSERT INTO Detalle_Venta (id_venta, id_lote, cantidad, precio_unitario) VALUES (3, 1, -3, 5);';
EXEC #err 'TI-19', N'Precio unitario igual a cero', 547,
  N'INSERT INTO Detalle_Venta (id_venta, id_lote, cantidad, precio_unitario) VALUES (3, 1, 1, 0);';
EXEC #err 'TI-20', N'Total de venta negativo', 547,
  N'INSERT INTO Venta (id_empleado, tipo_pago, total) VALUES (3, ~EFECTIVO~, -10);';
EXEC #err 'TI-21', N'Precio de venta de producto negativo', 547,
  N'INSERT INTO Producto (codigo_barras, nombre, precio_venta, id_categoria) VALUES (~7750100100306~, N~X~, -5, 1);';
EXEC #err 'TI-22', N'Costo unitario de lote igual a cero', 547,
  N'INSERT INTO Lote (id_producto, numero_lote, fecha_ingreso, cantidad_inicial, stock_actual, costo_unitario) VALUES (1, ~L-Y~, ~2026-11-01~, 5, 5, 0);';
EXEC #err 'TI-23', N'Cantidad inicial de lote igual a cero', 547,
  N'INSERT INTO Lote (id_producto, numero_lote, fecha_ingreso, cantidad_inicial, stock_actual, costo_unitario) VALUES (1, ~L-Z~, ~2026-11-01~, 0, 0, 1);';
EXEC #err 'TI-24', N'Lote que vence antes de ingresar', 547,
  N'INSERT INTO Lote (id_producto, numero_lote, fecha_ingreso, fecha_vencimiento, cantidad_inicial, stock_actual, costo_unitario) VALUES (1, ~L-W~, ~2026-11-01~, ~2026-10-01~, 5, 5, 1);';
EXEC #err 'TI-25', N'Subtotal es columna calculada: no se puede modificar a mano', 271,
  N'UPDATE Detalle_Venta SET subtotal = 1 WHERE id_detalle = 1;';
-- Dominios y formatos -------------------------------------------------------------------
EXEC #err 'TI-26', N'DNI de cliente con letras', 547,
  N'INSERT INTO Cliente (dni, nombres, apellidos, distrito) VALUES (~ABC12345~, N~X~, N~Y~, N~Comas~);';
EXEC #err 'TI-27', N'DNI de cliente con menos de 8 dígitos', 547,
  N'INSERT INTO Cliente (dni, nombres, apellidos, distrito) VALUES (~1234~, N~X~, N~Y~, N~Comas~);';
EXEC #err 'TI-28', N'Teléfono que no empieza con 9', 547,
  N'INSERT INTO Cliente (dni, nombres, apellidos, telefono, distrito) VALUES (~12345678~, N~X~, N~Y~, ~812345678~, N~Comas~);';
EXEC #err 'TI-29', N'Medio de pago inexistente', 547,
  N'INSERT INTO Venta (id_empleado, tipo_pago) VALUES (3, ~CHEQUE~);';
EXEC #err 'TI-30', N'Rol de empleado inexistente', 547,
  N'INSERT INTO Empleado (dni, nombres, apellidos, correo, usuario, clave_hash, rol, fecha_ingreso) VALUES (~80000001~, N~X~, N~Y~, ~r@y.pe~, ~r1~, ~h~, ~GERENTE~, ~2026-11-01~);';
EXEC #err 'TI-31', N'Correo de empleado mal formado', 547,
  N'INSERT INTO Empleado (dni, nombres, apellidos, correo, usuario, clave_hash, rol, fecha_ingreso) VALUES (~80000002~, N~X~, N~Y~, ~sin-arroba~, ~r2~, ~h~, ~CAJERO~, ~2026-11-01~);';
EXEC #err 'TI-32', N'Venta sin medio de pago (NOT NULL)', 515,
  N'INSERT INTO Venta (id_empleado, tipo_pago) VALUES (3, NULL);';
EXEC #err 'TI-33', N'Factura sin RUC del receptor', 547,
  N'INSERT INTO Venta (id_empleado, tipo_pago) VALUES (3, ~EFECTIVO~);
    INSERT INTO Comprobante (id_venta, tipo_comprobante, serie, numero, fecha_emision) VALUES (SCOPE_IDENTITY(), ~FACTURA~, ~F001~, 900, SYSDATETIME());';
EXEC #err 'TI-34', N'Boleta con RUC del receptor', 547,
  N'INSERT INTO Venta (id_empleado, tipo_pago) VALUES (3, ~EFECTIVO~);
    INSERT INTO Comprobante (id_venta, tipo_comprobante, serie, numero, fecha_emision, ruc_receptor) VALUES (SCOPE_IDENTITY(), ~BOLETA~, ~B001~, 900, SYSDATETIME(), ~20601234561~);';
EXEC #err 'TI-35', N'Boleta con serie de factura (F001)', 547,
  N'INSERT INTO Venta (id_empleado, tipo_pago) VALUES (3, ~EFECTIVO~);
    INSERT INTO Comprobante (id_venta, tipo_comprobante, serie, numero, fecha_emision) VALUES (SCOPE_IDENTITY(), ~BOLETA~, ~F001~, 901, SYSDATETIME());';
-- Eliminar registros con dependencias (sin cascada) -------------------------------------------
EXEC #err 'TI-36', N'Eliminar un cliente que tiene ventas', 547,   N'DELETE FROM Cliente WHERE id_cliente = 1;';
EXEC #err 'TI-37', N'Eliminar un empleado que tiene ventas', 547,  N'DELETE FROM Empleado WHERE id_empleado = 3;';
EXEC #err 'TI-38', N'Eliminar un producto que tiene lotes', 547,    N'DELETE FROM Producto WHERE id_producto = 1;';
EXEC #err 'TI-39', N'Eliminar un lote vendido', 547,                N'DELETE FROM Lote WHERE id_lote = 1;';
EXEC #err 'TI-40', N'Eliminar una venta que tiene detalle y comprobante', 547, N'DELETE FROM Venta WHERE id_venta = 1;';
EXEC #err 'TI-41', N'Eliminar una categoría con productos', 547,    N'DELETE FROM Categoria WHERE id_categoria = 1;';
GO
-- Coherencia positiva ----------------------------------------------------------------------
INSERT #r (id, prueba, esperado, obtenido) SELECT 'TI-42', N'Coherencia ventas-detalle-total: 0 ventas con diagnóstico distinto de OK', N'0', CAST(COUNT(*) AS NVARCHAR(20)) FROM dbo.vw_control_integridad_ventas WHERE diagnostico <> 'OK';
INSERT #r (id, prueba, esperado, obtenido) SELECT 'TI-43', N'Integridad de lotes: ningún lote con stock fuera de [0, cantidad_inicial]', N'0', CAST(COUNT(*) AS NVARCHAR(20)) FROM Lote WHERE stock_actual < 0 OR stock_actual > cantidad_inicial;
INSERT #r (id, prueba, esperado, obtenido) SELECT 'TI-44', N'Comprobantes-ventas: relación 1 a 1 (20 ventas, 20 comprobantes, 20 pares)', N'20|20|20', CONCAT((SELECT COUNT(*) FROM Venta), '|', (SELECT COUNT(*) FROM Comprobante), '|', (SELECT COUNT(*) FROM Venta v JOIN Comprobante k ON k.id_venta = v.id_venta));
INSERT #r (id, prueba, esperado, obtenido) SELECT 'TI-45', N'Las pruebas no alteraron los datos (conteo de las 8 tablas)', N'20|20|21|20|20|20|37|20',
  CONCAT((SELECT COUNT(*) FROM Categoria), '|', (SELECT COUNT(*) FROM Producto), '|', (SELECT COUNT(*) FROM Lote), '|', (SELECT COUNT(*) FROM Cliente), '|',
         (SELECT COUNT(*) FROM Empleado), '|', (SELECT COUNT(*) FROM Venta), '|', (SELECT COUNT(*) FROM Detalle_Venta), '|', (SELECT COUNT(*) FROM Comprobante));
GO
SELECT id, prueba, esperado, obtenido, estado, detalle FROM #r ORDER BY id;
SELECT COUNT(*) AS pruebas, SUM(CASE WHEN estado = 'PASS' THEN 1 ELSE 0 END) AS aprobadas, SUM(CASE WHEN estado = 'FAIL' THEN 1 ELSE 0 END) AS fallidas FROM #r;
DECLARE @fallidas INT = (SELECT COUNT(*) FROM #r WHERE estado = 'FAIL');
IF @fallidas > 0 THROW 50096, N'Hay pruebas de integridad que fallaron.', 1;
GO
