/* ============================================================================
   06_multitable_queries.sql - Proyecto T3 La Favorita: 20 consultas multitabla
   9 INNER JOIN (M01-M09), 5 LEFT JOIN (M10-M14), 3 RIGHT JOIN (M15-M17) y
   3 FULL JOIN (M18-M20).
   ============================================================================ */
USE MinimarketLaFavorita;
GO

/* ------------------------------ INNER JOIN ------------------------------ */

/*@@
ID: M01
TITULO: Catálogo de productos con su categoría (INNER JOIN)
ENUNCIADO: El cajero necesita el catálogo de productos con el nombre y tipo de su categoría y su precio de venta.
OBJETIVO: Relacionar Producto con Categoria mediante INNER JOIN (relación 1:N).
EXPLICACION: Cada producto tiene una única categoría (FK obligatoria), por lo que INNER JOIN devuelve todos los productos con los datos de su categoría.
@@*/
SELECT  p.id_producto, p.codigo_barras, p.nombre AS producto, c.nombre AS categoria, c.tipo, p.precio_venta, p.estado
FROM    Producto p
INNER JOIN Categoria c ON c.id_categoria = p.id_categoria
ORDER BY c.tipo, c.nombre, p.nombre;
GO

/*@@
ID: M02
TITULO: Lotes con producto, categoría y costo (INNER JOIN de 3 tablas)
ENUNCIADO: El almacenero quiere ver los lotes recibidos, de qué producto y categoría son, cuándo ingresaron, cuándo vencen y cuánto cuesta cada unidad.
OBJETIVO: Encadenar tres tablas (Lote, Producto, Categoria) con INNER JOIN.
EXPLICACION: Lote se une con Producto por id_producto y Producto con Categoria por id_categoria. Solo aparecen lotes con producto y categoría válidos, lo que garantiza la integridad referencial.
@@*/
SELECT  l.id_lote, l.numero_lote, p.nombre AS producto, c.nombre AS categoria,
        l.fecha_ingreso, l.fecha_vencimiento, l.cantidad_inicial, l.stock_actual, l.costo_unitario
FROM    Lote l
INNER JOIN Producto  p ON p.id_producto  = l.id_producto
INNER JOIN Categoria c ON c.id_categoria = p.id_categoria
ORDER BY l.fecha_ingreso, l.id_lote;
GO

/*@@
ID: M03
TITULO: Detalle de cada venta con cajero, producto y lote (INNER JOIN de 5 tablas)
ENUNCIADO: Contabilidad necesita ver cada línea vendida con la fecha, el cajero, el producto, el lote del que salió y el subtotal.
OBJETIVO: Reconstruir el documento de venta uniendo Venta, Detalle_Venta, Empleado, Lote y Producto.
EXPLICACION: Detalle_Venta es la tabla asociativa entre Venta y Lote. Las uniones INNER JOIN recorren la cadena venta → línea → lote → producto y venta → empleado para obtener la trazabilidad completa.
@@*/
SELECT  v.id_venta, v.fecha_venta, e.usuario AS cajero, p.nombre AS producto,
        l.numero_lote, d.cantidad, d.precio_unitario, d.subtotal
FROM    Venta v
INNER JOIN Detalle_Venta d ON d.id_venta    = v.id_venta
INNER JOIN Empleado      e ON e.id_empleado = v.id_empleado
INNER JOIN Lote          l ON l.id_lote     = d.id_lote
INNER JOIN Producto      p ON p.id_producto = l.id_producto
ORDER BY v.id_venta, d.id_detalle;
GO

/*@@
ID: M04
TITULO: Ventas a clientes identificados (INNER JOIN)
ENUNCIADO: El área comercial quiere listar solo las ventas hechas a clientes identificados, con su DNI, su distrito, el cajero y el total.
OBJETIVO: Usar INNER JOIN para excluir deliberadamente las ventas sin cliente (RN-07).
EXPLICACION: Como Venta.id_cliente puede ser NULL, INNER JOIN con Cliente descarta esas ventas y deja solo las que tienen un cliente asociado.
@@*/
SELECT  v.id_venta, v.fecha_venta, c.dni, c.nombres + N' ' + c.apellidos AS cliente, c.distrito,
        e.usuario AS cajero, v.tipo_pago, v.total
FROM    Venta v
INNER JOIN Cliente  c ON c.id_cliente  = v.id_cliente
INNER JOIN Empleado e ON e.id_empleado = v.id_empleado
ORDER BY v.fecha_venta;
GO

/*@@
ID: M05
TITULO: Comprobantes con venta y cajero (INNER JOIN)
ENUNCIADO: Contabilidad necesita el libro de comprobantes con la serie, el número, la fecha de emisión, el cajero que atendió y el total de la venta.
OBJETIVO: Relacionar Comprobante, Venta y Empleado (relación 1:1 entre Venta y Comprobante).
EXPLICACION: Cada comprobante pertenece a una sola venta (UQ_Comprobante_Venta). Con INNER JOIN se obtienen los datos de la venta y del empleado responsable de cada comprobante.
@@*/
SELECT  k.tipo_comprobante, k.serie, k.numero, k.fecha_emision, v.id_venta,
        e.nombres + N' ' + e.apellidos AS cajero, v.total
FROM    Comprobante k
INNER JOIN Venta    v ON v.id_venta    = k.id_venta
INNER JOIN Empleado e ON e.id_empleado = v.id_empleado
ORDER BY k.serie, k.numero;
GO

/*@@
ID: M06
TITULO: Trazabilidad: lotes vendidos a cada cliente (INNER JOIN de 6 tablas)
ENUNCIADO: Ante un reclamo o una alerta sanitaria, el administrador debe saber a qué clientes se vendió mercadería de un lote determinado y con qué comprobante.
OBJETIVO: Demostrar la trazabilidad del lote hasta el cliente y el comprobante.
EXPLICACION: Se unen Lote, Producto, Detalle_Venta, Venta, Cliente y Comprobante. Solo aparecen ventas con cliente identificado y comprobante emitido, que son las que permiten contactar al comprador.
@@*/
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

/*@@
ID: M07
TITULO: Ingresos por tipo de categoría (INNER JOIN con GROUP BY)
ENUNCIADO: Gerencia quiere saber cuánto ingresa por cada tipo de mercadería (ALIMENTO, BEBIDA, LIMPIEZA, GENERAL) y cuántas unidades se venden.
OBJETIVO: Agregar datos de cinco tablas encadenadas con INNER JOIN.
EXPLICACION: Se recorre Categoria → Producto → Lote → Detalle_Venta → Venta (para contar ventas distintas). SUM(subtotal) da el ingreso y COUNT(DISTINCT id_venta) evita contar dos veces una venta con varias líneas del mismo tipo.
@@*/
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

/*@@
ID: M08
TITULO: Facturas con cliente y RUC del receptor (INNER JOIN)
ENUNCIADO: Contabilidad necesita las facturas emitidas con el RUC del receptor, el cliente asociado a la venta y el monto, para el registro de ventas.
OBJETIVO: Combinar Comprobante, Venta y Cliente filtrando solo las facturas (RN-08).
EXPLICACION: El filtro tipo_comprobante = 'FACTURA' limita a los comprobantes que exigen RUC. INNER JOIN con Cliente muestra el cliente de cada factura.
@@*/
SELECT  k.serie, k.numero, k.fecha_emision, k.ruc_receptor,
        c.nombres + N' ' + c.apellidos AS cliente, v.total
FROM    Comprobante k
INNER JOIN Venta   v ON v.id_venta   = k.id_venta
INNER JOIN Cliente c ON c.id_cliente = v.id_cliente
WHERE   k.tipo_comprobante = 'FACTURA'
ORDER BY k.numero;
GO

/*@@
ID: M09
TITULO: Ventas por cajero y medio de pago (INNER JOIN con GROUP BY)
ENUNCIADO: El administrador quiere saber cuánto vendió cada cajero con cada medio de pago, para el cuadre de caja por empleado.
OBJETIVO: Cruzar Empleado, Venta y Comprobante agrupando por cajero y medio de pago.
EXPLICACION: Se usan INNER JOIN para considerar únicamente ventas con comprobante emitido, y se agrupa por empleado y tipo_pago con COUNT y SUM.
@@*/
SELECT  e.usuario AS cajero, e.rol, v.tipo_pago, COUNT(*) AS ventas, SUM(v.total) AS monto
FROM    Empleado e
INNER JOIN Venta       v ON v.id_empleado = e.id_empleado
INNER JOIN Comprobante k ON k.id_venta    = v.id_venta
GROUP BY e.usuario, e.rol, v.tipo_pago
ORDER BY e.usuario, v.tipo_pago;
GO

/* ------------------------------- LEFT JOIN ------------------------------ */

/*@@
ID: M10
TITULO: Todos los productos con sus unidades vendidas (LEFT JOIN)
ENUNCIADO: El administrador quiere un reporte de todos los productos del catálogo con las unidades vendidas, mostrando también los que no se han vendido (con cero).
OBJETIVO: Conservar todas las filas de la tabla izquierda (Producto) aunque no tengan coincidencias.
EXPLICACION: Producto se une con Lote y Detalle_Venta mediante LEFT JOIN. Los productos sin lote o sin ventas quedan con NULL, que ISNULL convierte en 0.
@@*/
SELECT  p.id_producto, p.nombre AS producto, p.estado,
        ISNULL(SUM(d.cantidad), 0) AS unidades_vendidas,
        ISNULL(SUM(d.subtotal), 0) AS ingreso
FROM    Producto p
LEFT JOIN Lote          l ON l.id_producto = p.id_producto
LEFT JOIN Detalle_Venta d ON d.id_lote     = l.id_lote
GROUP BY p.id_producto, p.nombre, p.estado
ORDER BY unidades_vendidas DESC, p.nombre;
GO

/*@@
ID: M11
TITULO: Todos los clientes con su gasto acumulado (LEFT JOIN)
ENUNCIADO: El área comercial necesita la lista completa de clientes con el número de compras y el monto gastado, incluyendo a los que todavía no compran.
OBJETIVO: Usar LEFT JOIN para no perder clientes sin ventas.
EXPLICACION: Cliente es la tabla izquierda. Los clientes sin ventas tienen NULL en las columnas de Venta; COUNT(v.id_venta) cuenta 0 para ellos y ISNULL deja el monto en 0.
@@*/
SELECT  c.id_cliente, c.nombres + N' ' + c.apellidos AS cliente, c.distrito,
        COUNT(v.id_venta)       AS compras,
        ISNULL(SUM(v.total), 0) AS monto_gastado
FROM    Cliente c
LEFT JOIN Venta v ON v.id_cliente = c.id_cliente
GROUP BY c.id_cliente, c.nombres, c.apellidos, c.distrito
ORDER BY monto_gastado DESC, c.id_cliente;
GO

/*@@
ID: M12
TITULO: Todos los empleados con sus ventas (LEFT JOIN)
ENUNCIADO: Recursos humanos quiere ver a todo el personal con el número de ventas y el monto vendido, incluso a quienes no registran ventas.
OBJETIVO: Medir la actividad de todos los empleados sin excluir a los inactivos o nuevos.
EXPLICACION: Empleado se une con Venta mediante LEFT JOIN. Los empleados sin ventas aparecen con 0 ventas y monto 0.
@@*/
SELECT  e.id_empleado, e.usuario, e.rol, e.activo,
        COUNT(v.id_venta)       AS ventas,
        ISNULL(SUM(v.total), 0) AS monto_vendido
FROM    Empleado e
LEFT JOIN Venta v ON v.id_empleado = e.id_empleado
GROUP BY e.id_empleado, e.usuario, e.rol, e.activo
ORDER BY monto_vendido DESC, e.id_empleado;
GO

/*@@
ID: M13
TITULO: Categorías con su número de productos y su stock (LEFT JOIN)
ENUNCIADO: El comprador quiere revisar todas las categorías con la cantidad de productos que tienen y su stock total, para ver qué categorías están vacías o sin stock.
OBJETIVO: Detectar categorías sin productos o sin existencias mediante LEFT JOIN.
EXPLICACION: Categoria se une con Producto y Lote por LEFT JOIN. COUNT(DISTINCT p.id_producto) cuenta productos y SUM(l.stock_actual) suma existencias; los NULL se muestran como 0.
@@*/
SELECT  c.id_categoria, c.nombre AS categoria, c.tipo,
        COUNT(DISTINCT p.id_producto) AS productos,
        ISNULL(SUM(l.stock_actual), 0) AS stock_total
FROM    Categoria c
LEFT JOIN Producto p ON p.id_categoria = c.id_categoria
LEFT JOIN Lote     l ON l.id_producto  = p.id_producto
GROUP BY c.id_categoria, c.nombre, c.tipo
ORDER BY stock_total, c.id_categoria;
GO

/*@@
ID: M14
TITULO: Lotes con sus ventas, incluidos los que no rotan (LEFT JOIN)
ENUNCIADO: El almacenero quiere saber, por cada lote, cuántas unidades se vendieron y cuántas ventas lo incluyen, identificando lotes sin ninguna venta.
OBJETIVO: Detectar lotes sin rotación (mercadería inmovilizada).
EXPLICACION: Lote es la tabla izquierda y Detalle_Venta la derecha. Los lotes sin ventas muestran 0 unidades; WHERE no se usa para no eliminarlos.
@@*/
SELECT  l.id_lote, l.numero_lote, p.nombre AS producto, l.cantidad_inicial, l.stock_actual,
        COUNT(d.id_detalle)       AS lineas_de_venta,
        ISNULL(SUM(d.cantidad), 0) AS unidades_vendidas
FROM    Lote l
INNER JOIN Producto p ON p.id_producto = l.id_producto
LEFT JOIN  Detalle_Venta d ON d.id_lote = l.id_lote
GROUP BY l.id_lote, l.numero_lote, p.nombre, l.cantidad_inicial, l.stock_actual
ORDER BY unidades_vendidas, l.id_lote;
GO

/* ------------------------------- RIGHT JOIN ----------------------------- */

/*@@
ID: M15
TITULO: Lotes y sus líneas de venta, desde el lado del lote (RIGHT JOIN)
ENUNCIADO: El almacenero necesita listar todos los lotes y, si existen, las ventas en las que participaron, para detectar rápidamente los lotes que aún no se han vendido.
OBJETIVO: Aplicar RIGHT JOIN conservando todos los registros de la tabla derecha (Lote).
EXPLICACION: Detalle_Venta se coloca a la izquierda y Lote a la derecha. RIGHT JOIN conserva todos los lotes; los que no tienen líneas de venta aparecen con NULL en id_detalle y se marcan con la columna situacion.
@@*/
SELECT  l.id_lote, l.numero_lote, d.id_venta, d.cantidad,
        CASE WHEN d.id_detalle IS NULL THEN 'SIN VENTAS' ELSE 'CON VENTAS' END AS situacion
FROM    Detalle_Venta d
RIGHT JOIN Lote l ON l.id_lote = d.id_lote
ORDER BY situacion, l.id_lote, d.id_venta;
GO

/*@@
ID: M16
TITULO: Clientes y sus ventas, desde el lado del cliente (RIGHT JOIN)
ENUNCIADO: El área comercial quiere ver todos los clientes con las ventas que realizaron, resaltando a los que nunca compraron, para campañas de reactivación.
OBJETIVO: Aplicar RIGHT JOIN para priorizar la tabla Cliente.
EXPLICACION: Venta se escribe a la izquierda y Cliente a la derecha. Con RIGHT JOIN todos los clientes se conservan; los que no tienen ventas muestran NULL en las columnas de Venta.
@@*/
SELECT  c.id_cliente, c.nombres + N' ' + c.apellidos AS cliente, c.distrito,
        v.id_venta, v.fecha_venta, v.total
FROM    Venta v
RIGHT JOIN Cliente c ON c.id_cliente = v.id_cliente
ORDER BY c.id_cliente, v.fecha_venta;
GO

/*@@
ID: M17
TITULO: Empleados y las ventas que atendieron (RIGHT JOIN)
ENUNCIADO: La administración necesita la actividad de cada empleado: listar a todos los empleados con sus ventas y el comprobante emitido, mostrando a quienes no registraron ninguna.
OBJETIVO: Aplicar RIGHT JOIN con encadenamiento de una tabla adicional.
EXPLICACION: Comprobante y Venta se unen a la izquierda mediante INNER JOIN y el resultado se une por RIGHT JOIN con Empleado, de modo que todos los empleados permanecen aunque no tengan ventas.
@@*/
SELECT  e.id_empleado, e.usuario, e.rol, v.id_venta, k.serie, k.numero
FROM    Comprobante k
INNER JOIN Venta v ON v.id_venta = k.id_venta
RIGHT JOIN Empleado e ON e.id_empleado = v.id_empleado
ORDER BY e.id_empleado, v.id_venta;
GO

/* ------------------------------- FULL JOIN ------------------------------ */

/*@@
ID: M18
TITULO: Conciliación de clientes y ventas (FULL JOIN)
ENUNCIADO: Se necesita una vista conjunta que muestre las ventas con su cliente, los clientes que no tienen ventas y las ventas sin cliente identificado.
OBJETIVO: Aplicar FULL JOIN para conservar los registros sin correspondencia en ambos lados.
EXPLICACION: FULL JOIN entre Cliente y Venta devuelve coincidencias, clientes sin ventas (id_venta NULL) y ventas sin cliente (id_cliente NULL). La columna situacion clasifica cada fila.
@@*/
SELECT  c.id_cliente, c.nombres + N' ' + c.apellidos AS cliente, v.id_venta, v.total,
        CASE WHEN v.id_venta   IS NULL THEN 'CLIENTE SIN VENTAS'
             WHEN c.id_cliente IS NULL THEN 'VENTA SIN CLIENTE'
             ELSE 'CLIENTE CON VENTA' END AS situacion
FROM    Cliente c
FULL JOIN Venta v ON v.id_cliente = c.id_cliente
ORDER BY situacion, c.id_cliente, v.id_venta;
GO

/*@@
ID: M19
TITULO: Control de ventas y comprobantes (FULL JOIN)
ENUNCIADO: Contabilidad debe verificar la regla RN-08 (cada venta genera un único comprobante): hay que detectar ventas sin comprobante y comprobantes sin venta.
OBJETIVO: Usar FULL JOIN como herramienta de auditoría de integridad.
EXPLICACION: FULL JOIN entre Venta y Comprobante deja a la vista las anomalías en cualquier sentido. Con los datos correctos todas las filas tienen ambos lados y el resumen no muestra anomalías.
@@*/
SELECT  v.id_venta, k.id_comprobante, k.serie, k.numero, v.total,
        CASE WHEN k.id_comprobante IS NULL THEN 'VENTA SIN COMPROBANTE'
             WHEN v.id_venta       IS NULL THEN 'COMPROBANTE SIN VENTA'
             ELSE 'OK' END AS control
FROM    Venta v
FULL JOIN Comprobante k ON k.id_venta = v.id_venta
ORDER BY control DESC, v.id_venta;
GO

/*@@
ID: M20
TITULO: Cobertura de abastecimiento: productos y lotes (FULL JOIN)
ENUNCIADO: El comprador quiere verificar qué productos del catálogo no tienen ningún lote registrado (nunca se compraron) y qué lotes existen para cada producto, en un solo reporte.
OBJETIVO: Aplicar FULL JOIN para auditar la relación Producto–Lote en ambos sentidos.
EXPLICACION: FULL JOIN entre Producto y Lote muestra los productos sin lotes (id_lote NULL) y, en caso de existir, lotes sin producto (imposible por la clave foránea, lo que confirma la integridad). La columna estado_abastecimiento resume cada fila.
@@*/
SELECT  p.id_producto, p.nombre AS producto, p.estado, l.id_lote, l.numero_lote, l.stock_actual,
        CASE WHEN l.id_lote     IS NULL THEN 'SIN LOTES'
             WHEN p.id_producto IS NULL THEN 'LOTE HUERFANO'
             WHEN l.stock_actual = 0    THEN 'LOTE AGOTADO'
             ELSE 'ABASTECIDO' END AS estado_abastecimiento
FROM    Producto p
FULL JOIN Lote l ON l.id_producto = p.id_producto
ORDER BY estado_abastecimiento, p.id_producto, l.id_lote;
GO
