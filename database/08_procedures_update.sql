/* ============================================================================
   08_procedures_update.sql - Proyecto T3 La Favorita: 6 procedimientos UPDATE
   (códigos de error: ver cabecera de 07_procedures_insert.sql)
   ============================================================================ */
USE MinimarketLaFavorita;
GO

/*@@
ID: PU01
TITULO: usp_Producto_ActualizarPrecio
ENUNCIADO: Cuando sube el costo de un proveedor, el administrador debe actualizar el precio de venta de un producto sin vender por debajo del costo y sin alterar las ventas ya registradas.
OBJETIVO: Modificar precio_venta validando que sea positivo y no inferior al costo de los lotes con stock; las ventas pasadas conservan su precio (RN-09).
EXPLICACION: Verifica que el producto exista (50001), que el nuevo precio sea mayor que cero y que no sea menor que el mayor costo unitario entre los lotes con stock (50005). Como Detalle_Venta guarda precio_unitario, las ventas anteriores no cambian. Devuelve el precio anterior y el nuevo.
EJEMPLO: EXEC dbo.usp_Producto_ActualizarPrecio @id_producto = 3, @precio_nuevo = 10.50;
SELECT id_producto, nombre, precio_venta FROM Producto WHERE id_producto = 3;
@@*/
CREATE OR ALTER PROCEDURE dbo.usp_Producto_ActualizarPrecio
    @id_producto  INT,
    @precio_nuevo DECIMAL(10,2)
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @anterior DECIMAL(10,2), @costo_max DECIMAL(10,2);
    SELECT @anterior = precio_venta FROM Producto WHERE id_producto = @id_producto;
    IF @anterior IS NULL
        THROW 50001, N'El producto indicado no existe.', 1;
    IF @precio_nuevo IS NULL OR @precio_nuevo <= 0
        THROW 50005, N'El precio nuevo debe ser mayor que cero.', 1;
    SELECT @costo_max = MAX(costo_unitario) FROM Lote WHERE id_producto = @id_producto AND stock_actual > 0;
    IF @costo_max IS NOT NULL AND @precio_nuevo < @costo_max
        THROW 50005, N'El precio de venta no puede ser menor que el costo unitario de los lotes en stock.', 1;

    UPDATE Producto SET precio_venta = @precio_nuevo WHERE id_producto = @id_producto;
    SELECT @id_producto AS id_producto, @anterior AS precio_anterior, @precio_nuevo AS precio_nuevo;
END
GO

/*@@
ID: PU02
TITULO: usp_Producto_CambiarEstado
ENUNCIADO: El administrador necesita descatalogar (INACTIVO) o reactivar (ACTIVO) un producto sin borrarlo, para conservar su historial de ventas.
OBJETIVO: Cambiar el estado del producto validando el valor y evitando cambios sin efecto.
EXPLICACION: Comprueba que el producto exista (50001), que el estado sea ACTIVO o INACTIVO (50005) y que sea distinto del actual (50007). Un producto INACTIVO deja de poder venderse y de recibir lotes en los demás procedimientos.
EJEMPLO: EXEC dbo.usp_Producto_CambiarEstado @id_producto = 20, @estado = 'ACTIVO';
SELECT id_producto, nombre, estado FROM Producto WHERE id_producto = 20;
@@*/
CREATE OR ALTER PROCEDURE dbo.usp_Producto_CambiarEstado
    @id_producto INT,
    @estado      VARCHAR(8)
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @actual VARCHAR(8);
    SELECT @actual = estado FROM Producto WHERE id_producto = @id_producto;
    IF @actual IS NULL
        THROW 50001, N'El producto indicado no existe.', 1;
    IF @estado IS NULL OR @estado NOT IN ('ACTIVO','INACTIVO')
        THROW 50005, N'Estado inválido. Use ACTIVO o INACTIVO.', 1;
    IF @actual = @estado
        THROW 50007, N'El producto ya se encuentra en ese estado.', 1;

    UPDATE Producto SET estado = @estado WHERE id_producto = @id_producto;
END
GO

/*@@
ID: PU03
TITULO: usp_Cliente_ActualizarContacto
ENUNCIADO: Un cliente frecuente cambió de celular o de dirección y el cajero debe actualizar sus datos de contacto sin tocar su DNI ni su historial de compras.
OBJETIVO: Actualizar teléfono, dirección y distrito del cliente; los parámetros omitidos (NULL) conservan el valor actual.
EXPLICACION: Verifica que el cliente exista (50001) y que el teléfono, si se envía, tenga 9 dígitos y empiece con 9 (50005). Con ISNULL solo se modifican los datos enviados. El DNI no se puede cambiar desde este procedimiento.
EJEMPLO: EXEC dbo.usp_Cliente_ActualizarContacto @id_cliente = 7, @telefono = '987654000', @direccion = N'Calle Santa Rosa 40';
SELECT id_cliente, dni, telefono, direccion, distrito FROM Cliente WHERE id_cliente = 7;
@@*/
CREATE OR ALTER PROCEDURE dbo.usp_Cliente_ActualizarContacto
    @id_cliente INT,
    @telefono   CHAR(9) = NULL,
    @direccion  NVARCHAR(150) = NULL,
    @distrito   NVARCHAR(40) = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    IF NOT EXISTS (SELECT 1 FROM Cliente WHERE id_cliente = @id_cliente)
        THROW 50001, N'El cliente indicado no existe.', 1;
    IF @telefono IS NOT NULL AND (@telefono NOT LIKE '9%' OR @telefono LIKE '%[^0-9]%' OR LEN(@telefono) <> 9)
        THROW 50005, N'El teléfono debe tener 9 dígitos y empezar con 9.', 1;
    IF @distrito IS NOT NULL AND LTRIM(RTRIM(@distrito)) = N''
        THROW 50005, N'El distrito no puede quedar vacío.', 1;

    UPDATE Cliente
    SET    telefono  = ISNULL(@telefono,  telefono),
           direccion = ISNULL(@direccion, direccion),
           distrito  = ISNULL(@distrito,  distrito)
    WHERE  id_cliente = @id_cliente;
END
GO

/*@@
ID: PU04
TITULO: usp_Empleado_CambiarEstado
ENUNCIADO: Cuando un empleado deja de trabajar, el administrador debe desactivarlo (no eliminarlo) para que no pueda registrar ventas pero se conserve su historial; también debe poder reactivarlo.
OBJETIVO: Aplicar RN-01 y RN-10: bloquear el acceso del personal cesado sin perder historial y proteger al único SUPERADMIN activo.
EXPLICACION: Valida que el empleado exista (50001) y que el nuevo estado sea distinto del actual (50007). No permite desactivar al último SUPERADMIN activo (50007), porque el sistema quedaría sin administrador principal.
EJEMPLO: EXEC dbo.usp_Empleado_CambiarEstado @id_empleado = 19, @activo = 0;
SELECT id_empleado, usuario, rol, activo FROM Empleado WHERE id_empleado = 19;
@@*/
CREATE OR ALTER PROCEDURE dbo.usp_Empleado_CambiarEstado
    @id_empleado INT,
    @activo      BIT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @actual BIT, @rol VARCHAR(10);
    SELECT @actual = activo, @rol = rol FROM Empleado WHERE id_empleado = @id_empleado;
    IF @actual IS NULL
        THROW 50001, N'El empleado indicado no existe.', 1;
    IF @activo IS NULL
        THROW 50005, N'Debe indicar el nuevo estado (1 = activo, 0 = inactivo).', 1;
    IF @actual = @activo
        THROW 50007, N'El empleado ya se encuentra en ese estado.', 1;
    IF @activo = 0 AND @rol = 'SUPERADMIN'
       AND NOT EXISTS (SELECT 1 FROM Empleado WHERE rol = 'SUPERADMIN' AND activo = 1 AND id_empleado <> @id_empleado)
        THROW 50007, N'No se puede desactivar al único SUPERADMIN activo.', 1;

    UPDATE Empleado SET activo = @activo WHERE id_empleado = @id_empleado;
END
GO

/*@@
ID: PU05
TITULO: usp_Lote_AjustarStock
ENUNCIADO: Tras un conteo físico, el almacenero encuentra diferencias (merma, rotura o error de registro) y necesita ajustar el stock de un lote sumando o restando unidades, indicando el motivo.
OBJETIVO: Corregir descuadres de inventario sin permitir stock negativo (RN-04) ni superior a lo recibido.
EXPLICACION: Valida que el lote exista (50001), que el ajuste no sea cero y que se indique un motivo (50005). El stock resultante debe quedar entre 0 y cantidad_inicial: si fuese negativo se informa 50004 y si superase lo recibido, 50005. Devuelve el stock anterior, el nuevo y el motivo.
EJEMPLO: EXEC dbo.usp_Lote_AjustarStock @id_lote = 13, @ajuste = -2, @motivo = N'Botellas rotas en almacén';
SELECT id_lote, cantidad_inicial, stock_actual FROM Lote WHERE id_lote = 13;
@@*/
CREATE OR ALTER PROCEDURE dbo.usp_Lote_AjustarStock
    @id_lote INT,
    @ajuste  INT,
    @motivo  NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @owns BIT = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
    DECLARE @stock INT, @inicial INT, @nuevo INT;
    BEGIN TRY
        IF @owns = 1 BEGIN TRANSACTION;
        SELECT @stock = stock_actual, @inicial = cantidad_inicial
        FROM   Lote WITH (UPDLOCK, HOLDLOCK) WHERE id_lote = @id_lote;
        IF @stock IS NULL
            THROW 50001, N'El lote indicado no existe.', 1;
        IF @ajuste IS NULL OR @ajuste = 0
            THROW 50005, N'El ajuste no puede ser cero.', 1;
        IF @motivo IS NULL OR LTRIM(RTRIM(@motivo)) = N''
            THROW 50005, N'Debe indicar el motivo del ajuste.', 1;
        SET @nuevo = @stock + @ajuste;
        IF @nuevo < 0
            THROW 50004, N'El ajuste dejaría el stock del lote en negativo.', 1;
        IF @nuevo > @inicial
            THROW 50005, N'El stock resultante no puede superar la cantidad recibida del lote.', 1;

        UPDATE Lote SET stock_actual = @nuevo WHERE id_lote = @id_lote;
        IF @owns = 1 COMMIT TRANSACTION;
        SELECT @id_lote AS id_lote, @stock AS stock_anterior, @nuevo AS stock_nuevo, @motivo AS motivo;
    END TRY
    BEGIN CATCH
        IF @owns = 1 AND XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

/*@@
ID: PU06
TITULO: usp_Venta_CambiarMedioPago
ENUNCIADO: El cliente dijo que pagaría en efectivo, pero finalmente pagó con Yape. El cajero necesita corregir el medio de pago de la venta para que el cuadre de caja sea correcto.
OBJETIVO: Corregir el medio de pago de una venta existente sin alterar sus montos ni su detalle.
EXPLICACION: Verifica que la venta exista (50001), que el medio sea EFECTIVO, YAPE, PLIN o TARJETA (50005) y que sea distinto del actual (50007). Solo se modifica la columna tipo_pago; el total y el comprobante permanecen intactos.
EJEMPLO: EXEC dbo.usp_Venta_CambiarMedioPago @id_venta = 1, @tipo_pago = 'YAPE';
SELECT id_venta, tipo_pago, total FROM Venta WHERE id_venta = 1;
@@*/
CREATE OR ALTER PROCEDURE dbo.usp_Venta_CambiarMedioPago
    @id_venta  INT,
    @tipo_pago VARCHAR(8)
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @actual VARCHAR(8);
    SELECT @actual = tipo_pago FROM Venta WHERE id_venta = @id_venta;
    IF @actual IS NULL
        THROW 50001, N'La venta indicada no existe.', 1;
    IF @tipo_pago IS NULL OR @tipo_pago NOT IN ('EFECTIVO','YAPE','PLIN','TARJETA')
        THROW 50005, N'Medio de pago inválido. Use EFECTIVO, YAPE, PLIN o TARJETA.', 1;
    IF @actual = @tipo_pago
        THROW 50007, N'La venta ya tiene ese medio de pago.', 1;

    UPDATE Venta SET tipo_pago = @tipo_pago WHERE id_venta = @id_venta;
END
GO
