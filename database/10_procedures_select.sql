/* ============================================================================
   10_procedures_select.sql - Proyecto T3 La Favorita: 10 procedimientos SELECT
   (códigos de error: ver cabecera de 07_procedures_insert.sql)
   ============================================================================ */
USE MinimarketLaFavorita;
GO

/*@@
ID: PS01
TITULO: usp_Producto_Buscar
ENUNCIADO: En caja, el cajero escribe parte del nombre o el código de barras de un producto y necesita ver su precio y su disponibilidad al instante; opcionalmente filtra por categoría.
OBJETIVO: Agilizar la atención (objetivo de reducir el tiempo de atención a menos de 2 minutos) consultando precio y stock en una sola llamada.
EXPLICACION: Busca por coincidencia parcial en el nombre (LIKE) o por código de barras exacto, con filtros opcionales de categoría y estado ACTIVO. Reutiliza la vista vw_stock_producto, de modo que el stock y la situación (AGOTADO, ALERTA, NORMAL) se calculan siempre igual.
EJEMPLO: EXEC dbo.usp_Producto_Buscar @texto = N'gaseosa';
EXEC dbo.usp_Producto_Buscar @texto = N'7750100100018';
@@*/
CREATE OR ALTER PROCEDURE dbo.usp_Producto_Buscar
    @texto        NVARCHAR(100) = NULL,
    @id_categoria INT = NULL,
    @solo_activos BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    SELECT  s.id_producto, s.codigo_barras, s.producto, s.categoria, p.precio_venta,
            s.stock_total, s.situacion_stock, s.estado
    FROM    dbo.vw_stock_producto s
    JOIN    Producto p ON p.id_producto = s.id_producto
    WHERE   (@texto IS NULL OR s.producto LIKE N'%' + @texto + N'%' OR s.codigo_barras = @texto)
      AND   (@id_categoria IS NULL OR p.id_categoria = @id_categoria)
      AND   (@solo_activos = 0 OR s.estado = 'ACTIVO')
    ORDER BY s.producto;
END
GO

/*@@
ID: PS02
TITULO: usp_Stock_Consultar
ENUNCIADO: El almacenero necesita ver el stock de un producto (o de todos) desglosado por lote, con fecha de vencimiento y valor a costo.
OBJETIVO: Dar visibilidad del inventario por lote (FEFO: primero en vencer, primero en salir).
EXPLICACION: Si se indica @id_producto, valida que exista (50001) y lista sus lotes; si no, lista todos los lotes con stock. Los lotes se ordenan por fecha de vencimiento ascendente (los que no vencen van al final) para facilitar el despacho FEFO.
EJEMPLO: EXEC dbo.usp_Stock_Consultar @id_producto = 1;
@@*/
CREATE OR ALTER PROCEDURE dbo.usp_Stock_Consultar
    @id_producto INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @id_producto IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Producto WHERE id_producto = @id_producto)
        THROW 50001, N'El producto indicado no existe.', 1;
    SELECT  p.id_producto, p.nombre AS producto, l.id_lote, l.numero_lote, l.fecha_vencimiento,
            l.cantidad_inicial, l.stock_actual,
            CAST(l.stock_actual * l.costo_unitario AS DECIMAL(12,2)) AS valor_costo
    FROM    Lote l
    JOIN    Producto p ON p.id_producto = l.id_producto
    WHERE   (@id_producto IS NULL OR l.id_producto = @id_producto)
      AND   (@id_producto IS NOT NULL OR l.stock_actual > 0)
    ORDER BY p.nombre,
             CASE WHEN l.fecha_vencimiento IS NULL THEN 1 ELSE 0 END, l.fecha_vencimiento, l.id_lote;
END
GO

/*@@
ID: PS03
TITULO: usp_Productos_StockBajo
ENUNCIADO: El comprador revisa cada mañana qué productos activos están agotados o por debajo del stock mínimo para preparar el pedido a proveedores.
OBJETIVO: Automatizar la alerta de reposición (RN-05).
EXPLICACION: Consulta la vista vw_reposicion_urgente (productos ACTIVOS con situación AGOTADO o ALERTA) y permite limitar el resultado a una categoría. Ordena primero los agotados y luego los de mayor faltante.
EJEMPLO: EXEC dbo.usp_Productos_StockBajo;
@@*/
CREATE OR ALTER PROCEDURE dbo.usp_Productos_StockBajo
    @id_categoria INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT  r.id_producto, r.producto, r.categoria, r.stock_total, r.stock_minimo,
            r.faltante_para_minimo, r.situacion_stock
    FROM    dbo.vw_reposicion_urgente r
    JOIN    Producto p ON p.id_producto = r.id_producto
    WHERE   @id_categoria IS NULL OR p.id_categoria = @id_categoria
    ORDER BY CASE r.situacion_stock WHEN 'AGOTADO' THEN 0 ELSE 1 END, r.faltante_para_minimo DESC, r.producto;
END
GO

/*@@
ID: PS04
TITULO: usp_Lotes_PorVencer
ENUNCIADO: El encargado de almacén quiere la lista de lotes con stock que ya vencieron o vencerán dentro de N días (por defecto 30), con el valor en riesgo, para retirarlos o remarcarlos.
OBJETIVO: Reducir las pérdidas por productos vencidos (problemática de T2).
EXPLICACION: Valida que @dias no sea negativo (50005) y filtra la vista vw_lotes_vencimiento por dias_para_vencer menor o igual a @dias. Los vencidos aparecen con días negativos y primero en el orden.
EJEMPLO: EXEC dbo.usp_Lotes_PorVencer @dias = 60;
@@*/
CREATE OR ALTER PROCEDURE dbo.usp_Lotes_PorVencer
    @dias INT = 30
AS
BEGIN
    SET NOCOUNT ON;
    IF @dias IS NULL OR @dias < 0
        THROW 50005, N'El número de días no puede ser negativo.', 1;
    SELECT  id_lote, numero_lote, producto, fecha_vencimiento, dias_para_vencer,
            stock_actual, valor_en_riesgo, estado_vencimiento
    FROM    dbo.vw_lotes_vencimiento
    WHERE   dias_para_vencer <= @dias
    ORDER BY dias_para_vencer, id_lote;
END
GO

/*@@
ID: PS05
TITULO: usp_Cliente_BuscarPorDni
ENUNCIADO: Al momento del pago, el cajero ingresa el DNI del cliente para identificarlo y asociarlo a la venta.
OBJETIVO: Localizar rápidamente a un cliente por su DNI (único, RN-02) y mostrar sus datos y su actividad.
EXPLICACION: Valida que el DNI tenga 8 dígitos (50005). Si no existe, informa 50001 para que el cajero pueda registrarlo. Devuelve los datos del cliente junto con el número de compras y el monto acumulado.
EJEMPLO: EXEC dbo.usp_Cliente_BuscarPorDni @dni = '10234567';
@@*/
CREATE OR ALTER PROCEDURE dbo.usp_Cliente_BuscarPorDni
    @dni CHAR(8)
AS
BEGIN
    SET NOCOUNT ON;
    IF @dni IS NULL OR LEN(@dni) <> 8 OR @dni LIKE '%[^0-9]%'
        THROW 50005, N'El DNI debe tener exactamente 8 dígitos numéricos.', 1;
    IF NOT EXISTS (SELECT 1 FROM Cliente WHERE dni = @dni)
        THROW 50001, N'No existe un cliente con ese DNI.', 1;
    SELECT  c.id_cliente, c.dni, c.nombres, c.apellidos, c.telefono, c.direccion, c.distrito, c.fecha_registro,
            COUNT(v.id_venta)       AS compras,
            ISNULL(SUM(v.total), 0) AS monto_acumulado
    FROM    Cliente c
    LEFT JOIN Venta v ON v.id_cliente = c.id_cliente
    WHERE   c.dni = @dni
    GROUP BY c.id_cliente, c.dni, c.nombres, c.apellidos, c.telefono, c.direccion, c.distrito, c.fecha_registro;
END
GO

/*@@
ID: PS06
TITULO: usp_Venta_Detalle
ENUNCIADO: Ante un reclamo, el cajero o el administrador necesita ver todas las líneas de una venta: productos, lotes, cantidades, precios cobrados y subtotales, junto con el total.
OBJETIVO: Consultar el documento de venta completo a partir de su número.
EXPLICACION: Valida que la venta exista (50001) y devuelve primero la cabecera (cajero, cliente, medio de pago, total y comprobante) desde vw_ventas_cabecera y luego, como segundo resultado, las líneas desde vw_detalle_ventas.
EJEMPLO: EXEC dbo.usp_Venta_Detalle @id_venta = 4;
@@*/
CREATE OR ALTER PROCEDURE dbo.usp_Venta_Detalle
    @id_venta INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM Venta WHERE id_venta = @id_venta)
        THROW 50001, N'La venta indicada no existe.', 1;
    SELECT id_venta, fecha_venta, cajero, cliente, tipo_pago, items, total, comprobante
    FROM   dbo.vw_ventas_cabecera
    WHERE  id_venta = @id_venta;
    SELECT id_detalle, producto, numero_lote, cantidad, precio_unitario, subtotal
    FROM   dbo.vw_detalle_ventas
    WHERE  id_venta = @id_venta
    ORDER BY id_detalle;
END
GO

/*@@
ID: PS07
TITULO: usp_Ventas_PorRango
ENUNCIADO: El administrador quiere listar las ventas realizadas entre dos fechas, opcionalmente de un solo cajero, con el medio de pago y el total, para el cierre de caja.
OBJETIVO: Consultar ventas por periodo y por empleado para el cuadre y la supervisión.
EXPLICACION: Valida que @desde no sea posterior a @hasta (50005). Filtra por fecha_venta >= @desde y < @hasta + 1 día (así se incluye todo el último día) y, si se indica, por empleado. Usa la vista vw_ventas_cabecera.
EJEMPLO: EXEC dbo.usp_Ventas_PorRango @desde = '2026-10-01', @hasta = '2026-10-07';
@@*/
CREATE OR ALTER PROCEDURE dbo.usp_Ventas_PorRango
    @desde       DATE,
    @hasta       DATE,
    @id_empleado INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @desde IS NULL OR @hasta IS NULL OR @desde > @hasta
        THROW 50005, N'El rango de fechas es inválido: la fecha inicial no puede ser mayor que la final.', 1;
    SELECT  c.id_venta, c.fecha_venta, c.cajero, c.cliente, c.tipo_pago, c.items, c.total, c.comprobante
    FROM    dbo.vw_ventas_cabecera c
    JOIN    Venta v ON v.id_venta = c.id_venta
    WHERE   v.fecha_venta >= @desde AND v.fecha_venta < DATEADD(DAY, 1, CAST(@hasta AS DATETIME2(0)))
      AND   (@id_empleado IS NULL OR v.id_empleado = @id_empleado)
    ORDER BY c.fecha_venta, c.id_venta;
END
GO

/*@@
ID: PS08
TITULO: usp_Comprobante_Consultar
ENUNCIADO: Un cliente reclama con su boleta o factura en mano. El cajero ingresa la serie y el número para ubicar la venta, el cliente y el total.
OBJETIVO: Consultar un comprobante por su numeración (UQ serie + número).
EXPLICACION: Valida la serie y el número y busca el comprobante en vw_comprobantes_emitidos. Si no existe, lanza 50001. Devuelve el tipo, la fecha de emisión, el cliente, el RUC y el total de la venta asociada.
EJEMPLO: EXEC dbo.usp_Comprobante_Consultar @serie = 'F001', @numero = 1;
@@*/
CREATE OR ALTER PROCEDURE dbo.usp_Comprobante_Consultar
    @serie  CHAR(4),
    @numero INT
AS
BEGIN
    SET NOCOUNT ON;
    IF @serie IS NULL OR @numero IS NULL OR @numero <= 0
        THROW 50005, N'Debe indicar una serie y un número mayor que cero.', 1;
    IF NOT EXISTS (SELECT 1 FROM Comprobante WHERE serie = @serie AND numero = @numero)
        THROW 50001, N'No existe un comprobante con esa serie y número.', 1;
    SELECT  tipo_comprobante, numero_completo, fecha_emision, id_venta, cliente, ruc_receptor, total
    FROM    dbo.vw_comprobantes_emitidos
    WHERE   serie = @serie AND numero = @numero;
END
GO

/*@@
ID: PS09
TITULO: usp_Productos_MasVendidos
ENUNCIADO: El administrador quiere conocer los N productos más vendidos, en todo el historial o en un rango de fechas, para decidir qué reponer y qué promocionar.
OBJETIVO: Obtener rankings de rotación por periodo.
EXPLICACION: Valida el top (mayor que cero) y el rango de fechas. Agrupa las líneas de venta por producto dentro del periodo y devuelve los primeros @top ordenados por unidades vendidas y por ingreso.
EJEMPLO: EXEC dbo.usp_Productos_MasVendidos @top = 5, @desde = '2026-10-01', @hasta = '2026-10-31';
@@*/
CREATE OR ALTER PROCEDURE dbo.usp_Productos_MasVendidos
    @top   INT = 5,
    @desde DATE = NULL,
    @hasta DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @top IS NULL OR @top <= 0
        THROW 50005, N'El valor de top debe ser mayor que cero.', 1;
    IF @desde IS NOT NULL AND @hasta IS NOT NULL AND @desde > @hasta
        THROW 50005, N'El rango de fechas es inválido: la fecha inicial no puede ser mayor que la final.', 1;
    SELECT TOP (@top)
            p.id_producto, p.nombre AS producto,
            SUM(d.cantidad) AS unidades_vendidas,
            SUM(d.subtotal) AS ingreso
    FROM    Detalle_Venta d
    JOIN    Venta    v ON v.id_venta    = d.id_venta
    JOIN    Lote     l ON l.id_lote     = d.id_lote
    JOIN    Producto p ON p.id_producto = l.id_producto
    WHERE   (@desde IS NULL OR v.fecha_venta >= @desde)
      AND   (@hasta IS NULL OR v.fecha_venta <  DATEADD(DAY, 1, CAST(@hasta AS DATETIME2(0))))
    GROUP BY p.id_producto, p.nombre
    ORDER BY unidades_vendidas DESC, ingreso DESC, p.nombre;
END
GO

/*@@
ID: PS10
TITULO: usp_Cliente_HistorialCompras
ENUNCIADO: Para atender mejor a un cliente frecuente, el cajero quiere ver el historial de sus compras: fecha, comprobante, medio de pago, productos y montos.
OBJETIVO: Consultar el historial de un cliente para la fidelización.
EXPLICACION: Valida que el cliente exista (50001). Une Venta, Detalle_Venta, Lote y Producto y muestra cada línea con la fecha y el comprobante (LEFT JOIN, por si la venta no tiene comprobante), ordenado de la compra más reciente a la más antigua.
EJEMPLO: EXEC dbo.usp_Cliente_HistorialCompras @id_cliente = 4;
@@*/
CREATE OR ALTER PROCEDURE dbo.usp_Cliente_HistorialCompras
    @id_cliente INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM Cliente WHERE id_cliente = @id_cliente)
        THROW 50001, N'El cliente indicado no existe.', 1;
    SELECT  v.id_venta, v.fecha_venta, v.tipo_pago,
            ISNULL(k.serie + N'-' + CAST(k.numero AS NVARCHAR(10)), N'SIN COMPROBANTE') AS comprobante,
            p.nombre AS producto, d.cantidad, d.precio_unitario, d.subtotal, v.total AS total_venta
    FROM    Venta v
    JOIN    Detalle_Venta d ON d.id_venta    = v.id_venta
    JOIN    Lote          l ON l.id_lote     = d.id_lote
    JOIN    Producto      p ON p.id_producto = l.id_producto
    LEFT JOIN Comprobante k ON k.id_venta    = v.id_venta
    WHERE   v.id_cliente = @id_cliente
    ORDER BY v.fecha_venta DESC, d.id_detalle;
END
GO
