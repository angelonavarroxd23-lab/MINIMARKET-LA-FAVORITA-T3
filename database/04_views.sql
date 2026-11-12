/* ============================================================================
   04_views.sql - Proyecto T3 La Favorita: 15 vistas (VIEW)
   Cada vista resuelve una necesidad real del minimarket. El bloque /*@@ ... @@*/
   contiene el enunciado, el objetivo, la explicación y un ejemplo de consulta
   (lo usa tools/build_report.py para generar el informe).
   ============================================================================ */
USE MinimarketLaFavorita;
GO

/*@@
ID: V01
TITULO: Stock consolidado por producto
ENUNCIADO: El cajero y el administrador necesitan ver, en una sola consulta, cuántas unidades hay de cada producto sumando todos sus lotes y si el producto está agotado, en alerta o normal.
OBJETIVO: Centralizar la regla RN-05 (stock 0 = AGOTADO; stock menor al mínimo = ALERTA) para que todas las consultas y procedimientos usen el mismo criterio.
EXPLICACION: Se unen Producto y Categoria con INNER JOIN y se agregan los lotes con LEFT JOIN para no perder los productos que aún no tienen lote. SUM(stock_actual) calcula el stock total y un CASE clasifica la situación del producto.
EJEMPLO: SELECT * FROM dbo.vw_stock_producto ORDER BY id_producto;
@@*/
CREATE OR ALTER VIEW dbo.vw_stock_producto
AS
SELECT  p.id_producto,
        p.codigo_barras,
        p.nombre                               AS producto,
        c.nombre                               AS categoria,
        c.tipo                                 AS tipo_categoria,
        p.estado,
        p.stock_minimo,
        ISNULL(SUM(l.stock_actual), 0)         AS stock_total,
        COUNT(l.id_lote)                       AS nro_lotes,
        CASE WHEN ISNULL(SUM(l.stock_actual), 0) = 0              THEN 'AGOTADO'
             WHEN ISNULL(SUM(l.stock_actual), 0) < p.stock_minimo THEN 'ALERTA'
             ELSE 'NORMAL' END                 AS situacion_stock
FROM    Producto  p
JOIN    Categoria c ON c.id_categoria = p.id_categoria
LEFT JOIN Lote    l ON l.id_producto   = p.id_producto
GROUP BY p.id_producto, p.codigo_barras, p.nombre, c.nombre, c.tipo, p.estado, p.stock_minimo;
GO

/*@@
ID: V02
TITULO: Productos por reponer
ENUNCIADO: El administrador necesita la lista de productos ACTIVOS cuyo stock está agotado o por debajo del mínimo, con la cantidad que falta para llegar al mínimo, para decidir las compras a proveedores.
OBJETIVO: Apoyar la reposición de mercadería y evitar quiebres de stock.
EXPLICACION: Reutiliza la vista vw_stock_producto y filtra los productos activos cuya situación no es NORMAL. La columna faltante_para_minimo es la diferencia entre el stock mínimo y el stock actual.
EJEMPLO: SELECT * FROM dbo.vw_reposicion_urgente ORDER BY faltante_para_minimo DESC;
@@*/
CREATE OR ALTER VIEW dbo.vw_reposicion_urgente
AS
SELECT  id_producto,
        producto,
        categoria,
        stock_total,
        stock_minimo,
        stock_minimo - stock_total AS faltante_para_minimo,
        situacion_stock
FROM    dbo.vw_stock_producto
WHERE   estado = 'ACTIVO'
  AND   situacion_stock <> 'NORMAL';
GO

/*@@
ID: V03
TITULO: Lotes con stock y su estado de vencimiento
ENUNCIADO: El encargado de almacén debe saber qué lotes con stock disponible ya vencieron o están por vencer para sacarlos de la venta o rematarlos y así reducir las pérdidas por productos vencidos.
OBJETIVO: Controlar los vencimientos y cuantificar el valor en riesgo de cada lote.
EXPLICACION: Se calcula dias_para_vencer con DATEDIFF contra la fecha actual y un CASE clasifica el lote en VENCIDO, CRITICO (hasta 15 días), PROXIMO (hasta 30 días) o VIGENTE. Solo se consideran lotes perecibles (fecha_vencimiento no nula) con stock mayor que cero. El valor en riesgo es stock por costo unitario.
EJEMPLO: SELECT * FROM dbo.vw_lotes_vencimiento ORDER BY dias_para_vencer;
@@*/
CREATE OR ALTER VIEW dbo.vw_lotes_vencimiento
AS
SELECT  l.id_lote,
        l.numero_lote,
        p.nombre                                                        AS producto,
        l.fecha_vencimiento,
        DATEDIFF(DAY, CAST(GETDATE() AS DATE), l.fecha_vencimiento)     AS dias_para_vencer,
        l.stock_actual,
        CAST(l.stock_actual * l.costo_unitario AS DECIMAL(12,2))        AS valor_en_riesgo,
        CASE WHEN l.fecha_vencimiento <  CAST(GETDATE() AS DATE)                  THEN 'VENCIDO'
             WHEN l.fecha_vencimiento <= DATEADD(DAY, 15, CAST(GETDATE() AS DATE)) THEN 'CRITICO'
             WHEN l.fecha_vencimiento <= DATEADD(DAY, 30, CAST(GETDATE() AS DATE)) THEN 'PROXIMO'
             ELSE 'VIGENTE' END                                         AS estado_vencimiento
FROM    Lote l
JOIN    Producto p ON p.id_producto = l.id_producto
WHERE   l.stock_actual > 0
  AND   l.fecha_vencimiento IS NOT NULL;
GO

/*@@
ID: V04
TITULO: Valor del inventario por categoría
ENUNCIADO: El administrador quiere saber cuánto dinero tiene invertido en mercadería (a costo) y cuánto podría recaudar (a precio de venta) en cada categoría.
OBJETIVO: Valorizar el inventario para decisiones de compra y para el control contable.
EXPLICACION: Se parte de Categoria y se usan dos LEFT JOIN (Producto y Lote) para que también aparezcan las categorías sin productos o sin stock. El valor a costo es SUM(stock_actual*costo_unitario) y el valor potencial es SUM(stock_actual*precio_venta).
EJEMPLO: SELECT * FROM dbo.vw_valor_inventario_categoria ORDER BY valor_costo DESC;
@@*/
CREATE OR ALTER VIEW dbo.vw_valor_inventario_categoria
AS
SELECT  c.id_categoria,
        c.nombre                                                     AS categoria,
        c.tipo,
        COUNT(DISTINCT p.id_producto)                                AS productos,
        ISNULL(SUM(l.stock_actual), 0)                               AS unidades_en_stock,
        CAST(ISNULL(SUM(l.stock_actual * l.costo_unitario), 0) AS DECIMAL(12,2)) AS valor_costo,
        CAST(ISNULL(SUM(l.stock_actual * p.precio_venta), 0)   AS DECIMAL(12,2)) AS valor_venta_potencial
FROM    Categoria c
LEFT JOIN Producto p ON p.id_categoria = c.id_categoria
LEFT JOIN Lote     l ON l.id_producto  = p.id_producto
GROUP BY c.id_categoria, c.nombre, c.tipo;
GO

/*@@
ID: V05
TITULO: Detalle completo de ventas
ENUNCIADO: Contabilidad y administración necesitan ver cada línea vendida con la fecha, el cajero, el cliente (si fue identificado), el producto, el lote de origen, la cantidad, el precio cobrado y el subtotal.
OBJETIVO: Dar trazabilidad total de la venta al lote de origen (objetivo específico de control y trazabilidad de T2).
EXPLICACION: Une Detalle_Venta con Venta, Empleado, Lote y Producto mediante INNER JOIN y con Cliente mediante LEFT JOIN, porque la venta puede no tener cliente (RN-07).
EJEMPLO: SELECT * FROM dbo.vw_detalle_ventas ORDER BY id_venta, id_detalle;
@@*/
CREATE OR ALTER VIEW dbo.vw_detalle_ventas
AS
SELECT  d.id_detalle,
        v.id_venta,
        v.fecha_venta,
        e.usuario                       AS cajero,
        ISNULL(c.nombres + N' ' + c.apellidos, N'SIN CLIENTE') AS cliente,
        p.nombre                        AS producto,
        l.numero_lote,
        d.cantidad,
        d.precio_unitario,
        d.subtotal
FROM    Detalle_Venta d
JOIN    Venta    v ON v.id_venta    = d.id_venta
JOIN    Empleado e ON e.id_empleado = v.id_empleado
JOIN    Lote     l ON l.id_lote     = d.id_lote
JOIN    Producto p ON p.id_producto = l.id_producto
LEFT JOIN Cliente c ON c.id_cliente = v.id_cliente;
GO

/*@@
ID: V06
TITULO: Cabecera de ventas con comprobante
ENUNCIADO: El administrador quiere revisar cada venta con su cajero, su cliente, el medio de pago, el número de ítems, el total y el comprobante emitido (serie y número).
OBJETIVO: Tener una vista única del documento de venta para consultas en caja y auditoría.
EXPLICACION: Venta se une con Empleado (INNER JOIN) y con Cliente y Comprobante (LEFT JOIN, por si no hay cliente o aún no se emitió comprobante). Una subconsulta correlacionada cuenta las líneas de cada venta.
EJEMPLO: SELECT * FROM dbo.vw_ventas_cabecera ORDER BY id_venta;
@@*/
CREATE OR ALTER VIEW dbo.vw_ventas_cabecera
AS
SELECT  v.id_venta,
        v.fecha_venta,
        e.nombres + N' ' + e.apellidos                          AS cajero,
        ISNULL(c.nombres + N' ' + c.apellidos, N'SIN CLIENTE')  AS cliente,
        v.tipo_pago,
        (SELECT COUNT(*) FROM Detalle_Venta d WHERE d.id_venta = v.id_venta) AS items,
        v.total,
        CASE WHEN k.id_comprobante IS NULL THEN N'SIN COMPROBANTE'
             ELSE k.tipo_comprobante + N' ' + k.serie + N'-' + RIGHT(N'00000000' + CAST(k.numero AS NVARCHAR(8)), 8) END AS comprobante
FROM    Venta v
JOIN    Empleado e ON e.id_empleado = v.id_empleado
LEFT JOIN Cliente     c ON c.id_cliente = v.id_cliente
LEFT JOIN Comprobante k ON k.id_venta   = v.id_venta;
GO

/*@@
ID: V07
TITULO: Ingresos por medio de pago
ENUNCIADO: Gerencia necesita conocer cuántas ventas y cuánto dinero ingresa por cada medio de pago (efectivo, Yape, Plin y tarjeta) para el cuadre de caja y la conciliación con las billeteras digitales.
OBJETIVO: Conocer la preferencia de pago de los clientes y cuadrar la caja.
EXPLICACION: Agrupa Venta por tipo_pago y calcula el número de ventas, el monto total, el ticket promedio y el porcentaje que representa cada medio sobre el ingreso total mediante una subconsulta escalar.
EJEMPLO: SELECT * FROM dbo.vw_ventas_medio_pago ORDER BY monto_total DESC;
@@*/
CREATE OR ALTER VIEW dbo.vw_ventas_medio_pago
AS
SELECT  v.tipo_pago,
        COUNT(*)                                             AS nro_ventas,
        SUM(v.total)                                         AS monto_total,
        CAST(AVG(v.total) AS DECIMAL(10,2))                  AS ticket_promedio,
        CAST(100.0 * SUM(v.total) / (SELECT SUM(total) FROM Venta) AS DECIMAL(5,2)) AS porcentaje_ingreso
FROM    Venta v
GROUP BY v.tipo_pago;
GO

/*@@
ID: V08
TITULO: Ventas diarias
ENUNCIADO: El dueño quiere ver, día por día, cuántas ventas se hicieron, cuánto se vendió, cuántas unidades salieron y cuál fue el ticket promedio.
OBJETIVO: Seguir la evolución diaria de las ventas para detectar los días de mayor movimiento.
EXPLICACION: Primero se resumen las unidades por venta en una tabla derivada (así el total de la venta no se duplica al unir con el detalle) y luego se agrupa por CAST(fecha_venta AS DATE) para obtener ventas, monto, unidades y ticket promedio.
EJEMPLO: SELECT * FROM dbo.vw_ventas_diarias ORDER BY fecha;
@@*/
CREATE OR ALTER VIEW dbo.vw_ventas_diarias
AS
SELECT  CAST(v.fecha_venta AS DATE)          AS fecha,
        COUNT(*)                             AS nro_ventas,
        SUM(v.total)                         AS monto_total,
        SUM(u.unidades)                      AS unidades_vendidas,
        CAST(AVG(v.total) AS DECIMAL(10,2))  AS ticket_promedio
FROM    Venta v
JOIN   (SELECT id_venta, SUM(cantidad) AS unidades
        FROM Detalle_Venta GROUP BY id_venta) u ON u.id_venta = v.id_venta
GROUP BY CAST(v.fecha_venta AS DATE);
GO

/*@@
ID: V09
TITULO: Ranking de productos más vendidos
ENUNCIADO: El administrador quiere un ranking de los productos por unidades vendidas e ingresos, para decidir qué productos priorizar en las compras y en las promociones.
OBJETIVO: Identificar los productos de mayor rotación.
EXPLICACION: Se enlazan Detalle_Venta, Lote y Producto (INNER JOIN) y se agrupa por producto. La función de ventana RANK() OVER (ORDER BY unidades DESC) asigna la posición, respetando los empates.
EJEMPLO: SELECT * FROM dbo.vw_ranking_productos ORDER BY posicion, producto;
@@*/
CREATE OR ALTER VIEW dbo.vw_ranking_productos
AS
SELECT  RANK() OVER (ORDER BY SUM(d.cantidad) DESC) AS posicion,
        p.id_producto,
        p.nombre                                    AS producto,
        SUM(d.cantidad)                             AS unidades_vendidas,
        SUM(d.subtotal)                             AS ingreso_total
FROM    Detalle_Venta d
JOIN    Lote     l ON l.id_lote     = d.id_lote
JOIN    Producto p ON p.id_producto = l.id_producto
GROUP BY p.id_producto, p.nombre;
GO

/*@@
ID: V10
TITULO: Rendimiento por empleado
ENUNCIADO: El administrador quiere evaluar a todo el personal: cuántas ventas registró cada empleado, cuánto vendió y su ticket promedio, incluyendo a quienes todavía no registran ventas.
OBJETIVO: Medir la productividad del personal de caja y detectar personal sin actividad.
EXPLICACION: Empleado se une con Venta mediante LEFT JOIN para conservar a los empleados sin ventas; COUNT(v.id_venta) cuenta solo ventas reales y ISNULL evita valores nulos en los montos.
EJEMPLO: SELECT * FROM dbo.vw_rendimiento_empleados ORDER BY monto_vendido DESC, empleado;
@@*/
CREATE OR ALTER VIEW dbo.vw_rendimiento_empleados
AS
SELECT  e.id_empleado,
        e.nombres + N' ' + e.apellidos                    AS empleado,
        e.rol,
        e.activo,
        COUNT(v.id_venta)                                 AS nro_ventas,
        ISNULL(SUM(v.total), 0)                           AS monto_vendido,
        ISNULL(CAST(AVG(v.total) AS DECIMAL(10,2)), 0)    AS ticket_promedio
FROM    Empleado e
LEFT JOIN Venta v ON v.id_empleado = e.id_empleado
GROUP BY e.id_empleado, e.nombres, e.apellidos, e.rol, e.activo;
GO

/*@@
ID: V11
TITULO: Clientes frecuentes
ENUNCIADO: Para el programa de fidelización, el administrador necesita el historial resumido de cada cliente: número de compras, monto acumulado, ticket promedio y fecha de la última compra.
OBJETIVO: Identificar a los clientes más valiosos para orientar promociones (objetivo de fidelización de T2).
EXPLICACION: Cliente se une con Venta mediante LEFT JOIN para incluir a los clientes que aún no compran. MAX(fecha_venta) da la última compra y los agregados se calculan por cliente.
EJEMPLO: SELECT * FROM dbo.vw_clientes_frecuentes ORDER BY monto_total DESC, cliente;
@@*/
CREATE OR ALTER VIEW dbo.vw_clientes_frecuentes
AS
SELECT  c.id_cliente,
        c.dni,
        c.nombres + N' ' + c.apellidos                   AS cliente,
        c.distrito,
        COUNT(v.id_venta)                                AS nro_compras,
        ISNULL(SUM(v.total), 0)                          AS monto_total,
        ISNULL(CAST(AVG(v.total) AS DECIMAL(10,2)), 0)   AS ticket_promedio,
        MAX(v.fecha_venta)                               AS ultima_compra
FROM    Cliente c
LEFT JOIN Venta v ON v.id_cliente = c.id_cliente
GROUP BY c.id_cliente, c.dni, c.nombres, c.apellidos, c.distrito;
GO

/*@@
ID: V12
TITULO: Comprobantes emitidos
ENUNCIADO: Contabilidad necesita el registro de boletas y facturas con su numeración, la fecha de emisión, el cliente, el RUC del receptor, el total y el tiempo transcurrido entre la venta y la emisión.
OBJETIVO: Controlar la emisión de comprobantes y detectar emisiones con retraso (regla RN-08).
EXPLICACION: Comprobante se une con Venta (INNER JOIN) y con Cliente (LEFT JOIN). El número se formatea con 8 dígitos y minutos_hasta_emision se calcula con DATEDIFF entre la venta y la emisión.
EJEMPLO: SELECT * FROM dbo.vw_comprobantes_emitidos ORDER BY tipo_comprobante, serie, numero;
@@*/
CREATE OR ALTER VIEW dbo.vw_comprobantes_emitidos
AS
SELECT  k.id_comprobante,
        k.tipo_comprobante,
        k.serie + N'-' + RIGHT(N'00000000' + CAST(k.numero AS NVARCHAR(8)), 8) AS numero_completo,
        k.serie,
        k.numero,
        k.fecha_emision,
        v.id_venta,
        ISNULL(c.nombres + N' ' + c.apellidos, N'SIN CLIENTE') AS cliente,
        k.ruc_receptor,
        v.total,
        DATEDIFF(MINUTE, v.fecha_venta, k.fecha_emision)        AS minutos_hasta_emision
FROM    Comprobante k
JOIN    Venta v ON v.id_venta = k.id_venta
LEFT JOIN Cliente c ON c.id_cliente = v.id_cliente;
GO

/*@@
ID: V13
TITULO: Margen bruto por producto
ENUNCIADO: Gerencia quiere conocer cuánto gana el minimarket por cada producto vendido, comparando lo cobrado con el costo del lote del que salió la mercadería.
OBJETIVO: Medir la rentabilidad por producto para ajustar precios y compras.
EXPLICACION: Por cada línea se compara subtotal (precio cobrado, que se conserva según RN-09) con cantidad*costo_unitario del lote. Se agrupa por producto y se calcula el margen en soles y en porcentaje (NULLIF evita la división por cero).
EJEMPLO: SELECT * FROM dbo.vw_margen_producto ORDER BY margen DESC;
@@*/
CREATE OR ALTER VIEW dbo.vw_margen_producto
AS
SELECT  p.id_producto,
        p.nombre                                                   AS producto,
        SUM(d.cantidad)                                            AS unidades_vendidas,
        SUM(d.subtotal)                                            AS ingreso,
        CAST(SUM(d.cantidad * l.costo_unitario) AS DECIMAL(12,2))  AS costo,
        CAST(SUM(d.subtotal - d.cantidad * l.costo_unitario) AS DECIMAL(12,2)) AS margen,
        CAST(100.0 * SUM(d.subtotal - d.cantidad * l.costo_unitario)
             / NULLIF(SUM(d.subtotal), 0) AS DECIMAL(6,2))         AS margen_pct
FROM    Detalle_Venta d
JOIN    Lote     l ON l.id_lote     = d.id_lote
JOIN    Producto p ON p.id_producto = l.id_producto
GROUP BY p.id_producto, p.nombre;
GO

/*@@
ID: V14
TITULO: Personal sin datos sensibles
ENUNCIADO: Las áreas que consultan el directorio del personal (por ejemplo, el cajero que quiere saber quién es el supervisor) no deben ver las claves de acceso. Se necesita una vista de empleados que oculte clave_hash.
OBJETIVO: Cumplir el objetivo de seguridad y control de accesos: restringir la información sensible según el rol.
EXPLICACION: La vista expone solo datos no sensibles (nombre, usuario, correo, rol, estado y antigüedad en meses calculada con DATEDIFF) y omite clave_hash y el DNI. Se puede otorgar SELECT sobre la vista sin dar acceso a la tabla.
EJEMPLO: SELECT * FROM dbo.vw_empleados_seguros ORDER BY rol, empleado;
@@*/
CREATE OR ALTER VIEW dbo.vw_empleados_seguros
AS
SELECT  e.id_empleado,
        e.nombres + N' ' + e.apellidos                      AS empleado,
        e.usuario,
        e.correo,
        e.rol,
        CASE e.activo WHEN 1 THEN 'ACTIVO' ELSE 'INACTIVO' END AS estado,
        e.fecha_ingreso,
        DATEDIFF(MONTH, e.fecha_ingreso, CAST(GETDATE() AS DATE)) AS antiguedad_meses
FROM    Empleado e;
GO

/*@@
ID: V15
TITULO: Control de integridad de ventas
ENUNCIADO: El administrador necesita detectar automáticamente las ventas inconsistentes: total distinto de la suma de sus subtotales, ventas sin líneas de detalle o ventas sin comprobante.
OBJETIVO: Verificar las reglas RN-06, RN-08 y RN-09 (coherencia entre ventas, detalles y comprobantes) de forma permanente.
EXPLICACION: Por cada venta se calcula la suma de subtotales y se compara con el total. Con LEFT JOIN a Comprobante se detecta la ausencia de comprobante. La columna diagnostico resume el problema; una venta correcta muestra OK.
EJEMPLO: SELECT * FROM dbo.vw_control_integridad_ventas ORDER BY id_venta;
@@*/
CREATE OR ALTER VIEW dbo.vw_control_integridad_ventas
AS
SELECT  v.id_venta,
        v.total,
        ISNULL(s.suma_subtotales, 0)                  AS suma_subtotales,
        v.total - ISNULL(s.suma_subtotales, 0)        AS diferencia,
        ISNULL(s.lineas, 0)                           AS lineas,
        CASE WHEN k.id_comprobante IS NULL THEN 0 ELSE 1 END AS tiene_comprobante,
        CASE WHEN ISNULL(s.lineas, 0) = 0                    THEN 'SIN DETALLE'
             WHEN v.total <> ISNULL(s.suma_subtotales, 0)    THEN 'TOTAL DESCUADRADO'
             WHEN k.id_comprobante IS NULL                   THEN 'SIN COMPROBANTE'
             ELSE 'OK' END                            AS diagnostico
FROM    Venta v
LEFT JOIN (SELECT id_venta, SUM(subtotal) AS suma_subtotales, COUNT(*) AS lineas
           FROM Detalle_Venta GROUP BY id_venta) s ON s.id_venta = v.id_venta
LEFT JOIN Comprobante k ON k.id_venta = v.id_venta;
GO
