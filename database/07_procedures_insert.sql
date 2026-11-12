/* ============================================================================
   07_procedures_insert.sql - Proyecto T3 La Favorita: 8 procedimientos INSERT
   Convención de errores (THROW):
     50001 registro inexistente      50002 duplicado        50003 referencia (FK) inexistente
     50004 stock insuficiente        50005 dato inválido    50006 tiene dependencias
     50007 estado/operación no permitida   50008 empleado inactivo
     50009 lote vencido              50010 no autorizado
   Los procedimientos con varias escrituras usan transacción propia SOLO si no hay
   una transacción abierta por el llamador (se pueden anidar y probar con ROLLBACK).
   ============================================================================ */
USE MinimarketLaFavorita;
GO

IF TYPE_ID(N'dbo.tvp_LineaVenta') IS NULL
    CREATE TYPE dbo.tvp_LineaVenta AS TABLE (id_lote INT NOT NULL, cantidad INT NOT NULL);
GO

/*@@
ID: PI01
TITULO: usp_Categoria_Insertar
ENUNCIADO: El administrador necesita registrar una nueva categoría de mercadería (por ejemplo, «Congelados») sin duplicar nombres y respetando los cuatro tipos del negocio.
OBJETIVO: Insertar en Categoria validando nombre obligatorio, tipo válido y unicidad, y devolver el identificador generado.
EXPLICACION: Valida el nombre (no vacío), el tipo (ALIMENTO, BEBIDA, LIMPIEZA o GENERAL) y que el nombre no exista. Inserta la fila y devuelve el id con SCOPE_IDENTITY() en el parámetro OUTPUT. Los errores se informan con THROW y un código propio.
EJEMPLO: DECLARE @id INT;
EXEC dbo.usp_Categoria_Insertar @nombre = N'Congelados', @tipo = 'ALIMENTO', @descripcion = N'Helados, nuggets y verduras congeladas', @id_categoria = @id OUTPUT;
SELECT * FROM Categoria WHERE id_categoria = @id;
@@*/
CREATE OR ALTER PROCEDURE dbo.usp_Categoria_Insertar
    @nombre       NVARCHAR(50),
    @tipo         VARCHAR(10),
    @descripcion  NVARCHAR(150) = NULL,
    @id_categoria INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    IF @nombre IS NULL OR LTRIM(RTRIM(@nombre)) = N''
        THROW 50005, N'El nombre de la categoría es obligatorio.', 1;
    IF @tipo IS NULL OR @tipo NOT IN ('ALIMENTO','BEBIDA','LIMPIEZA','GENERAL')
        THROW 50005, N'Tipo de categoría inválido. Use ALIMENTO, BEBIDA, LIMPIEZA o GENERAL.', 1;
    IF EXISTS (SELECT 1 FROM Categoria WHERE nombre = LTRIM(RTRIM(@nombre)))
        THROW 50002, N'Ya existe una categoría con ese nombre.', 1;

    INSERT INTO Categoria (nombre, tipo, descripcion)
    VALUES (LTRIM(RTRIM(@nombre)), @tipo, @descripcion);
    SET @id_categoria = SCOPE_IDENTITY();
END
GO

/*@@
ID: PI02
TITULO: usp_Producto_Insertar
ENUNCIADO: El administrador debe dar de alta un producto nuevo en el catálogo con su código de barras, precio, stock mínimo y categoría.
OBJETIVO: Registrar productos garantizando código único (RN-02), precio positivo y categoría existente.
EXPLICACION: Verifica que la categoría exista (error 50003), que el código tenga de 8 a 13 dígitos, que el código no esté repetido (50002), que el precio sea mayor que cero y que el stock mínimo no sea negativo. Después inserta y devuelve el id.
EJEMPLO: DECLARE @id INT;
EXEC dbo.usp_Producto_Insertar @codigo_barras = '7750100100216', @nombre = N'Helado de vainilla 1 L', @descripcion = N'Helado en pote de 1 L', @precio_venta = 14.90, @stock_minimo = 5, @estado = 'ACTIVO', @id_categoria = 1, @id_producto = @id OUTPUT;
SELECT * FROM Producto WHERE id_producto = @id;
@@*/
CREATE OR ALTER PROCEDURE dbo.usp_Producto_Insertar
    @codigo_barras VARCHAR(13),
    @nombre        NVARCHAR(100),
    @descripcion   NVARCHAR(200) = NULL,
    @precio_venta  DECIMAL(10,2),
    @stock_minimo  INT = 0,
    @estado        VARCHAR(8) = 'ACTIVO',
    @id_categoria  INT,
    @id_producto   INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    IF @nombre IS NULL OR LTRIM(RTRIM(@nombre)) = N''
        THROW 50005, N'El nombre del producto es obligatorio.', 1;
    IF @codigo_barras IS NULL OR LEN(@codigo_barras) NOT BETWEEN 8 AND 13 OR @codigo_barras LIKE '%[^0-9]%'
        THROW 50005, N'El código de barras debe tener de 8 a 13 dígitos numéricos.', 1;
    IF @precio_venta IS NULL OR @precio_venta <= 0
        THROW 50005, N'El precio de venta debe ser mayor que cero.', 1;
    IF @stock_minimo IS NULL OR @stock_minimo < 0
        THROW 50005, N'El stock mínimo no puede ser negativo.', 1;
    IF @estado IS NULL OR @estado NOT IN ('ACTIVO','INACTIVO')
        THROW 50005, N'Estado inválido. Use ACTIVO o INACTIVO.', 1;
    IF NOT EXISTS (SELECT 1 FROM Categoria WHERE id_categoria = @id_categoria)
        THROW 50003, N'La categoría indicada no existe.', 1;
    IF EXISTS (SELECT 1 FROM Producto WHERE codigo_barras = @codigo_barras)
        THROW 50002, N'Ya existe un producto con ese código de barras.', 1;

    INSERT INTO Producto (codigo_barras, nombre, descripcion, precio_venta, stock_minimo, estado, id_categoria)
    VALUES (@codigo_barras, LTRIM(RTRIM(@nombre)), @descripcion, @precio_venta, @stock_minimo, @estado, @id_categoria);
    SET @id_producto = SCOPE_IDENTITY();
END
GO

/*@@
ID: PI03
TITULO: usp_Lote_Insertar
ENUNCIADO: Cuando llega mercadería de un proveedor, el almacenero registra un lote nuevo con su número, fecha de vencimiento, cantidad recibida y costo unitario.
OBJETIVO: Registrar el ingreso de un lote dejando el stock actual igual a la cantidad recibida y validando fechas, cantidad y costo.
EXPLICACION: Comprueba que el producto exista (50003) y esté ACTIVO (50007), que el número de lote no se repita para ese producto (50002), que cantidad y costo sean positivos y que la fecha de vencimiento sea posterior al ingreso. El stock inicial se fija igual a la cantidad recibida.
EJEMPLO: DECLARE @id INT;
EXEC dbo.usp_Lote_Insertar @id_producto = 4, @numero_lote = 'LT-FID-2611A', @fecha_ingreso = '2026-11-10', @fecha_vencimiento = '2028-11-10', @cantidad_inicial = 50, @costo_unitario = 3.00, @id_lote = @id OUTPUT;
SELECT * FROM Lote WHERE id_lote = @id;
@@*/
CREATE OR ALTER PROCEDURE dbo.usp_Lote_Insertar
    @id_producto       INT,
    @numero_lote       VARCHAR(30),
    @fecha_ingreso     DATE = NULL,
    @fecha_vencimiento DATE = NULL,
    @cantidad_inicial  INT,
    @costo_unitario    DECIMAL(10,2),
    @id_lote           INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @ingreso DATE = ISNULL(@fecha_ingreso, CAST(GETDATE() AS DATE));
    IF @numero_lote IS NULL OR LTRIM(RTRIM(@numero_lote)) = ''
        THROW 50005, N'El número de lote es obligatorio.', 1;
    IF @cantidad_inicial IS NULL OR @cantidad_inicial <= 0
        THROW 50005, N'La cantidad recibida debe ser mayor que cero.', 1;
    IF @costo_unitario IS NULL OR @costo_unitario <= 0
        THROW 50005, N'El costo unitario debe ser mayor que cero.', 1;
    IF @fecha_vencimiento IS NOT NULL AND @fecha_vencimiento <= @ingreso
        THROW 50005, N'La fecha de vencimiento debe ser posterior a la fecha de ingreso.', 1;
    IF NOT EXISTS (SELECT 1 FROM Producto WHERE id_producto = @id_producto)
        THROW 50003, N'El producto indicado no existe.', 1;
    IF EXISTS (SELECT 1 FROM Producto WHERE id_producto = @id_producto AND estado <> 'ACTIVO')
        THROW 50007, N'No se pueden registrar lotes de un producto INACTIVO.', 1;
    IF EXISTS (SELECT 1 FROM Lote WHERE id_producto = @id_producto AND numero_lote = @numero_lote)
        THROW 50002, N'Ya existe ese número de lote para el producto.', 1;

    INSERT INTO Lote (id_producto, numero_lote, fecha_ingreso, fecha_vencimiento, cantidad_inicial, stock_actual, costo_unitario)
    VALUES (@id_producto, @numero_lote, @ingreso, @fecha_vencimiento, @cantidad_inicial, @cantidad_inicial, @costo_unitario);
    SET @id_lote = SCOPE_IDENTITY();
END
GO

/*@@
ID: PI04
TITULO: usp_Cliente_Insertar
ENUNCIADO: El cajero registra a un cliente frecuente nuevo con su DNI, nombres, apellidos, teléfono y distrito, sin permitir DNI repetidos ni mal formados.
OBJETIVO: Insertar clientes aplicando las reglas RN-02 y RN-03 (DNI único de 8 dígitos).
EXPLICACION: Valida que el DNI tenga exactamente 8 dígitos, que el teléfono (si se envía) tenga 9 dígitos y empiece con 9, que nombres, apellidos y distrito no estén vacíos y que el DNI no exista (50002). La fecha de registro toma el valor por defecto de la tabla.
EJEMPLO: DECLARE @id INT;
EXEC dbo.usp_Cliente_Insertar @dni = '78123456', @nombres = N'Rosa María', @apellidos = N'Cáceres Luna', @telefono = '987001122', @direccion = N'Jr. Cusco 321', @distrito = N'Comas', @id_cliente = @id OUTPUT;
SELECT * FROM Cliente WHERE id_cliente = @id;
@@*/
CREATE OR ALTER PROCEDURE dbo.usp_Cliente_Insertar
    @dni        CHAR(8),
    @nombres    NVARCHAR(50),
    @apellidos  NVARCHAR(50),
    @telefono   CHAR(9) = NULL,
    @direccion  NVARCHAR(150) = NULL,
    @distrito   NVARCHAR(40),
    @id_cliente INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    IF @dni IS NULL OR LEN(@dni) <> 8 OR @dni LIKE '%[^0-9]%'
        THROW 50005, N'El DNI debe tener exactamente 8 dígitos numéricos.', 1;
    IF @nombres IS NULL OR LTRIM(RTRIM(@nombres)) = N'' OR @apellidos IS NULL OR LTRIM(RTRIM(@apellidos)) = N''
        THROW 50005, N'Nombres y apellidos son obligatorios.', 1;
    IF @distrito IS NULL OR LTRIM(RTRIM(@distrito)) = N''
        THROW 50005, N'El distrito es obligatorio.', 1;
    IF @telefono IS NOT NULL AND (@telefono NOT LIKE '9%' OR @telefono LIKE '%[^0-9]%' OR LEN(@telefono) <> 9)
        THROW 50005, N'El teléfono debe tener 9 dígitos y empezar con 9.', 1;
    IF EXISTS (SELECT 1 FROM Cliente WHERE dni = @dni)
        THROW 50002, N'Ya existe un cliente con ese DNI.', 1;

    INSERT INTO Cliente (dni, nombres, apellidos, telefono, direccion, distrito)
    VALUES (@dni, @nombres, @apellidos, @telefono, @direccion, @distrito);
    SET @id_cliente = SCOPE_IDENTITY();
END
GO

/*@@
ID: PI05
TITULO: usp_Empleado_Insertar
ENUNCIADO: El administrador da de alta a un nuevo empleado con su usuario, rol y la contraseña ya convertida en hash por la aplicación; no se permiten DNI, correos ni usuarios repetidos.
OBJETIVO: Cumplir RN-01: acceso con credenciales válidas, rol permitido y contraseñas solo como hash.
EXPLICACION: Valida DNI de 8 dígitos, correo con formato válido, rol (SUPERADMIN, ADMIN o CAJERO) y que la clave tenga el formato de hash PBKDF2 (nunca texto plano). Revisa la unicidad de DNI, correo y usuario (50002) y registra al empleado como activo.
EJEMPLO: DECLARE @id INT;
EXEC dbo.usp_Empleado_Insertar @dni = '80123456', @nombres = N'Pedro Antonio', @apellidos = N'Rivas Mena', @correo = 'privas@lafavorita.pe', @usuario = 'privas', @clave_hash = 'pbkdf2_sha256$600000$EjemploSalt0001$EjemploHashDePrueba0123456789abcdefghijklmn=', @rol = 'CAJERO', @telefono = '981100030', @id_empleado = @id OUTPUT;
SELECT id_empleado, dni, usuario, rol, activo FROM Empleado WHERE id_empleado = @id;
@@*/
CREATE OR ALTER PROCEDURE dbo.usp_Empleado_Insertar
    @dni           CHAR(8),
    @nombres       NVARCHAR(50),
    @apellidos     NVARCHAR(50),
    @correo        VARCHAR(100),
    @usuario       VARCHAR(30),
    @clave_hash    VARCHAR(255),
    @rol           VARCHAR(10),
    @telefono      CHAR(9) = NULL,
    @fecha_ingreso DATE = NULL,
    @id_empleado   INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    IF @dni IS NULL OR LEN(@dni) <> 8 OR @dni LIKE '%[^0-9]%'
        THROW 50005, N'El DNI debe tener exactamente 8 dígitos numéricos.', 1;
    IF @nombres IS NULL OR LTRIM(RTRIM(@nombres)) = N'' OR @apellidos IS NULL OR LTRIM(RTRIM(@apellidos)) = N''
        THROW 50005, N'Nombres y apellidos son obligatorios.', 1;
    IF @correo IS NULL OR @correo NOT LIKE '%_@_%._%'
        THROW 50005, N'El correo no tiene un formato válido.', 1;
    IF @usuario IS NULL OR LTRIM(RTRIM(@usuario)) = ''
        THROW 50005, N'El usuario es obligatorio.', 1;
    IF @rol IS NULL OR @rol NOT IN ('SUPERADMIN','ADMIN','CAJERO')
        THROW 50005, N'Rol inválido. Use SUPERADMIN, ADMIN o CAJERO.', 1;
    IF @clave_hash IS NULL OR @clave_hash NOT LIKE 'pbkdf2[_]sha256$%'
        THROW 50005, N'La clave debe enviarse como hash PBKDF2 (nunca en texto plano).', 1;
    IF @telefono IS NOT NULL AND (@telefono NOT LIKE '9%' OR @telefono LIKE '%[^0-9]%' OR LEN(@telefono) <> 9)
        THROW 50005, N'El teléfono debe tener 9 dígitos y empezar con 9.', 1;
    IF EXISTS (SELECT 1 FROM Empleado WHERE dni = @dni)
        THROW 50002, N'Ya existe un empleado con ese DNI.', 1;
    IF EXISTS (SELECT 1 FROM Empleado WHERE correo = @correo)
        THROW 50002, N'Ya existe un empleado con ese correo.', 1;
    IF EXISTS (SELECT 1 FROM Empleado WHERE usuario = @usuario)
        THROW 50002, N'Ya existe un empleado con ese usuario.', 1;

    INSERT INTO Empleado (dni, nombres, apellidos, correo, usuario, clave_hash, rol, telefono, fecha_ingreso, activo)
    VALUES (@dni, @nombres, @apellidos, @correo, @usuario, @clave_hash, @rol, @telefono,
            ISNULL(@fecha_ingreso, CAST(GETDATE() AS DATE)), 1);
    SET @id_empleado = SCOPE_IDENTITY();
END
GO

/*@@
ID: PI06
TITULO: usp_Venta_Registrar
ENUNCIADO: El cajero registra una venta completa: elige los lotes y las cantidades, indica el medio de pago, opcionalmente el cliente y el tipo de comprobante. El sistema debe descontar el stock, calcular el total y emitir el comprobante en una sola operación.
OBJETIVO: Implementar RN-04, RN-06, RN-07 y RN-09: venta, detalle, descuento de stock y comprobante dentro de una misma transacción, con el precio vigente guardado en cada línea.
EXPLICACION: Recibe las líneas en un parámetro tipo tabla (dbo.tvp_LineaVenta). Valida empleado activo, cliente existente, medio de pago, productos activos, lotes no vencidos y stock suficiente (se bloquean los lotes con UPDLOCK/HOLDLOCK). Inserta la venta, las líneas con el precio vigente, descuenta el stock y recalcula el total como suma de subtotales. Si algo falla, todo se revierte (ROLLBACK) y no queda ningún cambio parcial.
EJEMPLO: DECLARE @lineas dbo.tvp_LineaVenta, @id INT;
INSERT INTO @lineas (id_lote, cantidad) VALUES (1, 2), (13, 6);
EXEC dbo.usp_Venta_Registrar @id_empleado = 3, @id_cliente = 1, @tipo_pago = 'YAPE', @lineas = @lineas, @tipo_comprobante = 'BOLETA', @id_venta = @id OUTPUT;
SELECT * FROM dbo.vw_ventas_cabecera WHERE id_venta = @id;
SELECT id_lote, stock_actual FROM Lote WHERE id_lote IN (1, 13);
@@*/
CREATE OR ALTER PROCEDURE dbo.usp_Venta_Registrar
    @id_empleado      INT,
    @id_cliente       INT = NULL,
    @tipo_pago        VARCHAR(8),
    @lineas           dbo.tvp_LineaVenta READONLY,
    @tipo_comprobante VARCHAR(7) = NULL,
    @ruc_receptor     CHAR(11) = NULL,
    @id_venta         INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @owns BIT = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
    DECLARE @msg NVARCHAR(300), @idc INT;
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM @lineas)
            THROW 50005, N'La venta debe tener al menos una línea.', 1;
        IF EXISTS (SELECT 1 FROM @lineas WHERE cantidad <= 0)
            THROW 50005, N'Las cantidades deben ser mayores que cero.', 1;
        IF @tipo_pago IS NULL OR @tipo_pago NOT IN ('EFECTIVO','YAPE','PLIN','TARJETA')
            THROW 50005, N'Medio de pago inválido. Use EFECTIVO, YAPE, PLIN o TARJETA.', 1;
        IF NOT EXISTS (SELECT 1 FROM Empleado WHERE id_empleado = @id_empleado)
            THROW 50003, N'El empleado indicado no existe.', 1;
        IF NOT EXISTS (SELECT 1 FROM Empleado WHERE id_empleado = @id_empleado AND activo = 1)
            THROW 50008, N'El empleado está inactivo y no puede registrar ventas.', 1;
        IF @id_cliente IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Cliente WHERE id_cliente = @id_cliente)
            THROW 50003, N'El cliente indicado no existe.', 1;
        IF EXISTS (SELECT 1 FROM @lineas a WHERE NOT EXISTS (SELECT 1 FROM Lote lo WHERE lo.id_lote = a.id_lote))
            THROW 50003, N'Alguno de los lotes indicados no existe.', 1;

        IF @owns = 1 BEGIN TRANSACTION;

        DECLARE @l TABLE (id_lote INT PRIMARY KEY, cantidad INT NOT NULL, precio DECIMAL(10,2) NOT NULL);
        INSERT INTO @l (id_lote, cantidad, precio)
        SELECT a.id_lote, SUM(a.cantidad), MAX(p.precio_venta)
        FROM   @lineas a
        JOIN   Lote lo     ON lo.id_lote     = a.id_lote
        JOIN   Producto p  ON p.id_producto  = lo.id_producto
        GROUP BY a.id_lote;

        IF EXISTS (SELECT 1 FROM @l x JOIN Lote lo ON lo.id_lote = x.id_lote
                   JOIN Producto p ON p.id_producto = lo.id_producto WHERE p.estado <> 'ACTIVO')
            THROW 50007, N'Hay productos INACTIVOS en la venta.', 1;
        IF EXISTS (SELECT 1 FROM @l x JOIN Lote lo ON lo.id_lote = x.id_lote
                   WHERE lo.fecha_vencimiento IS NOT NULL AND lo.fecha_vencimiento < CAST(SYSDATETIME() AS DATE))
            THROW 50009, N'No se puede vender mercadería de un lote vencido.', 1;

        -- Bloqueo de los lotes involucrados y verificación de stock (RN-04)
        SELECT TOP (1) @msg = CONCAT(N'Stock insuficiente en el lote ', lo.id_lote, N' (', lo.numero_lote,
                                     N'): disponible ', lo.stock_actual, N', solicitado ', x.cantidad, N'.')
        FROM   @l x
        JOIN   Lote lo WITH (UPDLOCK, HOLDLOCK) ON lo.id_lote = x.id_lote
        WHERE  lo.stock_actual < x.cantidad
        ORDER BY lo.id_lote;
        IF @msg IS NOT NULL THROW 50004, @msg, 1;

        INSERT INTO Venta (fecha_venta, id_empleado, id_cliente, tipo_pago, total)
        VALUES (SYSDATETIME(), @id_empleado, @id_cliente, @tipo_pago, 0);
        SET @id_venta = SCOPE_IDENTITY();

        INSERT INTO Detalle_Venta (id_venta, id_lote, cantidad, precio_unitario)
        SELECT @id_venta, id_lote, cantidad, precio FROM @l;

        UPDATE lo SET stock_actual = lo.stock_actual - x.cantidad
        FROM   Lote lo JOIN @l x ON x.id_lote = lo.id_lote;

        UPDATE Venta
        SET    total = (SELECT SUM(subtotal) FROM Detalle_Venta WHERE id_venta = @id_venta)
        WHERE  id_venta = @id_venta;

        IF @tipo_comprobante IS NOT NULL
            EXEC dbo.usp_Comprobante_Emitir @id_venta = @id_venta, @tipo_comprobante = @tipo_comprobante,
                                            @ruc_receptor = @ruc_receptor, @id_comprobante = @idc OUTPUT;

        IF @owns = 1 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @owns = 1 AND XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        SET @id_venta = NULL;
        THROW;
    END CATCH
END
GO

/*@@
ID: PI07
TITULO: usp_DetalleVenta_Agregar
ENUNCIADO: Antes de emitir el comprobante, el cajero se da cuenta de que el cliente quiere llevar un producto más. Se necesita agregar una línea a una venta ya registrada, descontando el stock y actualizando el total.
OBJETIVO: Agregar líneas a una venta abierta manteniendo la coherencia entre detalle, stock y total (RN-04 y RN-09).
EXPLICACION: Solo permite agregar líneas a ventas que existen (50003) y que todavía NO tienen comprobante (50007), porque un comprobante emitido no se modifica. Rechaza líneas repetidas del mismo lote (50002), lotes vencidos (50009) y cantidades superiores al stock (50004). Todo se ejecuta en una transacción.
EJEMPLO: DECLARE @lineas dbo.tvp_LineaVenta, @v INT, @d INT;
INSERT INTO @lineas VALUES (1, 1);
EXEC dbo.usp_Venta_Registrar @id_empleado = 3, @tipo_pago = 'EFECTIVO', @lineas = @lineas, @id_venta = @v OUTPUT;
EXEC dbo.usp_DetalleVenta_Agregar @id_venta = @v, @id_lote = 4, @cantidad = 3, @id_detalle = @d OUTPUT;
SELECT * FROM dbo.vw_detalle_ventas WHERE id_venta = @v;
SELECT id_venta, total FROM Venta WHERE id_venta = @v;
@@*/
CREATE OR ALTER PROCEDURE dbo.usp_DetalleVenta_Agregar
    @id_venta   INT,
    @id_lote    INT,
    @cantidad   INT,
    @id_detalle INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @owns BIT = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
    DECLARE @precio DECIMAL(10,2), @stock INT, @venc DATE, @estado VARCHAR(8), @msg NVARCHAR(300);
    BEGIN TRY
        IF @cantidad IS NULL OR @cantidad <= 0
            THROW 50005, N'La cantidad debe ser mayor que cero.', 1;
        IF NOT EXISTS (SELECT 1 FROM Venta WHERE id_venta = @id_venta)
            THROW 50003, N'La venta indicada no existe.', 1;
        IF EXISTS (SELECT 1 FROM Comprobante WHERE id_venta = @id_venta)
            THROW 50007, N'La venta ya tiene comprobante emitido; no se puede modificar.', 1;
        IF NOT EXISTS (SELECT 1 FROM Lote WHERE id_lote = @id_lote)
            THROW 50003, N'El lote indicado no existe.', 1;
        IF EXISTS (SELECT 1 FROM Detalle_Venta WHERE id_venta = @id_venta AND id_lote = @id_lote)
            THROW 50002, N'La venta ya tiene una línea para ese lote.', 1;

        IF @owns = 1 BEGIN TRANSACTION;

        SELECT @precio = p.precio_venta, @stock = lo.stock_actual, @venc = lo.fecha_vencimiento, @estado = p.estado
        FROM   Lote lo WITH (UPDLOCK, HOLDLOCK)
        JOIN   Producto p ON p.id_producto = lo.id_producto
        WHERE  lo.id_lote = @id_lote;

        IF @estado <> 'ACTIVO' THROW 50007, N'El producto está INACTIVO.', 1;
        IF @venc IS NOT NULL AND @venc < CAST(SYSDATETIME() AS DATE)
            THROW 50009, N'No se puede vender mercadería de un lote vencido.', 1;
        IF @stock < @cantidad
        BEGIN
            SET @msg = CONCAT(N'Stock insuficiente en el lote ', @id_lote, N': disponible ', @stock, N', solicitado ', @cantidad, N'.');
            THROW 50004, @msg, 1;
        END

        INSERT INTO Detalle_Venta (id_venta, id_lote, cantidad, precio_unitario)
        VALUES (@id_venta, @id_lote, @cantidad, @precio);
        SET @id_detalle = SCOPE_IDENTITY();

        UPDATE Lote SET stock_actual = stock_actual - @cantidad WHERE id_lote = @id_lote;
        UPDATE Venta SET total = (SELECT SUM(subtotal) FROM Detalle_Venta WHERE id_venta = @id_venta)
        WHERE  id_venta = @id_venta;

        IF @owns = 1 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @owns = 1 AND XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        SET @id_detalle = NULL;
        THROW;
    END CATCH
END
GO

/*@@
ID: PI08
TITULO: usp_Comprobante_Emitir
ENUNCIADO: Tras cobrar una venta, el cajero emite la boleta (cliente final) o la factura (con RUC). El sistema debe asignar el siguiente número correlativo de la serie y nunca emitir dos comprobantes para la misma venta.
OBJETIVO: Cumplir RN-08: un comprobante por venta, factura con RUC, numeración correlativa por serie.
EXPLICACION: Comprueba que la venta exista (50003) y no tenga comprobante (50002). Para FACTURA exige un RUC de 11 dígitos que empiece con 10 o 20; para BOLETA no admite RUC. La serie es B001 (boleta) o F001 (factura) y el número es el máximo de la serie más uno, calculado con UPDLOCK/HOLDLOCK para que dos cajeros no obtengan el mismo número.
EJEMPLO: DECLARE @lineas dbo.tvp_LineaVenta, @v INT, @c INT;
INSERT INTO @lineas VALUES (2, 1);
EXEC dbo.usp_Venta_Registrar @id_empleado = 4, @id_cliente = 2, @tipo_pago = 'TARJETA', @lineas = @lineas, @id_venta = @v OUTPUT;
EXEC dbo.usp_Comprobante_Emitir @id_venta = @v, @tipo_comprobante = 'FACTURA', @ruc_receptor = '20601234561', @id_comprobante = @c OUTPUT;
SELECT * FROM dbo.vw_comprobantes_emitidos WHERE id_venta = @v;
@@*/
CREATE OR ALTER PROCEDURE dbo.usp_Comprobante_Emitir
    @id_venta         INT,
    @tipo_comprobante VARCHAR(7),
    @ruc_receptor     CHAR(11) = NULL,
    @id_comprobante   INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @owns BIT = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
    DECLARE @serie CHAR(4), @numero INT, @fecha_venta DATETIME2(0);
    BEGIN TRY
        IF @tipo_comprobante IS NULL OR @tipo_comprobante NOT IN ('BOLETA','FACTURA')
            THROW 50005, N'Tipo de comprobante inválido. Use BOLETA o FACTURA.', 1;
        IF @tipo_comprobante = 'FACTURA'
           AND (@ruc_receptor IS NULL OR LEN(@ruc_receptor) <> 11 OR @ruc_receptor LIKE '%[^0-9]%'
                OR (@ruc_receptor NOT LIKE '10%' AND @ruc_receptor NOT LIKE '20%'))
            THROW 50005, N'La factura exige un RUC de 11 dígitos que empiece con 10 o 20.', 1;
        IF @tipo_comprobante = 'BOLETA' AND @ruc_receptor IS NOT NULL
            THROW 50005, N'La boleta no admite RUC del receptor.', 1;

        SELECT @fecha_venta = fecha_venta FROM Venta WHERE id_venta = @id_venta;
        IF @fecha_venta IS NULL
            THROW 50003, N'La venta indicada no existe.', 1;
        IF EXISTS (SELECT 1 FROM Comprobante WHERE id_venta = @id_venta)
            THROW 50002, N'La venta ya tiene un comprobante emitido.', 1;

        IF @owns = 1 BEGIN TRANSACTION;

        SET @serie = CASE @tipo_comprobante WHEN 'BOLETA' THEN 'B001' ELSE 'F001' END;
        SELECT @numero = ISNULL(MAX(numero), 0) + 1
        FROM   Comprobante WITH (UPDLOCK, HOLDLOCK)
        WHERE  serie = @serie;

        INSERT INTO Comprobante (id_venta, tipo_comprobante, serie, numero, fecha_emision, ruc_receptor)
        VALUES (@id_venta, @tipo_comprobante, @serie, @numero,
                CASE WHEN SYSDATETIME() < @fecha_venta THEN @fecha_venta ELSE SYSDATETIME() END,
                @ruc_receptor);
        SET @id_comprobante = SCOPE_IDENTITY();

        IF @owns = 1 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @owns = 1 AND XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        SET @id_comprobante = NULL;
        THROW;
    END CATCH
END
GO
