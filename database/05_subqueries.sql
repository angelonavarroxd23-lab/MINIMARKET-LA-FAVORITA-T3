/* ============================================================================
   05_subqueries.sql - Proyecto T3 La Favorita: 15 subconsultas
   Tipos usados: escalar (WHERE/SELECT), IN, NOT IN, EXISTS, NOT EXISTS,
   correlacionada, tabla derivada (FROM) y subconsulta en HAVING.
   ============================================================================ */
USE MinimarketLaFavorita;
GO

/*@@
ID: S01
TITULO: Productos con precio superior al promedio
ENUNCIADO: El administrador quiere identificar los productos cuyo precio de venta es mayor que el precio promedio del catálogo, para revisar su margen y su rotación.
OBJETIVO: Aplicar una subconsulta escalar en la cláusula WHERE.
EXPLICACION: La subconsulta (SELECT AVG(precio_venta) FROM Producto) devuelve un único valor, el promedio de precios, y la consulta externa solo conserva los productos que lo superan.
@@*/
SELECT  id_producto, nombre, precio_venta
FROM    Producto
WHERE   precio_venta > (SELECT AVG(precio_venta) FROM Producto)
ORDER BY precio_venta DESC;
GO

/*@@
ID: S02
TITULO: Productos que nunca se han vendido
ENUNCIADO: Para decidir descuentos o devoluciones al proveedor, el administrador necesita saber qué productos del catálogo no aparecen en ninguna venta.
OBJETIVO: Aplicar NOT EXISTS con una subconsulta correlacionada de varias tablas.
EXPLICACION: Para cada producto, la subconsulta busca si alguno de sus lotes figura en Detalle_Venta. Si no devuelve filas (NOT EXISTS), el producto nunca se vendió.
@@*/
SELECT  p.id_producto, p.nombre, p.estado
FROM    Producto p
WHERE   NOT EXISTS (SELECT 1
                    FROM   Lote l
                    JOIN   Detalle_Venta d ON d.id_lote = l.id_lote
                    WHERE  l.id_producto = p.id_producto)
ORDER BY p.id_producto;
GO

/*@@
ID: S03
TITULO: Clientes registrados que aún no compran
ENUNCIADO: El área comercial quiere contactar a los clientes que se registraron pero nunca han realizado una compra, para invitarlos con una promoción de bienvenida.
OBJETIVO: Aplicar NOT IN con una subconsulta no correlacionada.
EXPLICACION: La subconsulta lista los id_cliente que sí aparecen en Venta. Se excluyen los NULL (ventas sin cliente) porque un NULL dentro de NOT IN anularía todo el resultado.
@@*/
SELECT  c.id_cliente, c.nombres, c.apellidos, c.telefono, c.fecha_registro
FROM    Cliente c
WHERE   c.id_cliente NOT IN (SELECT v.id_cliente FROM Venta v WHERE v.id_cliente IS NOT NULL)
ORDER BY c.fecha_registro;
GO

/*@@
ID: S04
TITULO: Empleados sin ventas registradas
ENUNCIADO: Recursos humanos necesita saber qué empleados (activos o no) no han registrado ninguna venta, para evaluar su asignación o su permanencia.
OBJETIVO: Aplicar NOT EXISTS correlacionado sobre la tabla Venta.
EXPLICACION: Por cada empleado, la subconsulta verifica si existe alguna venta con su id_empleado; si no existe, el empleado se incluye en el resultado.
@@*/
SELECT  e.id_empleado, e.nombres, e.apellidos, e.rol, e.activo
FROM    Empleado e
WHERE   NOT EXISTS (SELECT 1 FROM Venta v WHERE v.id_empleado = e.id_empleado)
ORDER BY e.id_empleado;
GO

/*@@
ID: S05
TITULO: Ventas con total superior al promedio
ENUNCIADO: Gerencia quiere revisar las ventas de mayor valor, es decir, aquellas cuyo total supera al ticket promedio del minimarket.
OBJETIVO: Aplicar una subconsulta escalar para comparar cada fila con un agregado global.
EXPLICACION: (SELECT AVG(total) FROM Venta) calcula el ticket promedio una sola vez; la consulta externa devuelve las ventas que lo superan junto con el medio de pago.
@@*/
SELECT  v.id_venta, v.fecha_venta, v.tipo_pago, v.total
FROM    Venta v
WHERE   v.total > (SELECT AVG(total) FROM Venta)
ORDER BY v.total DESC;
GO

/*@@
ID: S06
TITULO: Clientes que gastan más que el cliente promedio
ENUNCIADO: Para el programa de fidelización se requiere la lista de clientes cuyo gasto acumulado es superior al gasto promedio por cliente.
OBJETIVO: Aplicar una subconsulta en HAVING que a su vez usa una tabla derivada.
EXPLICACION: La tabla derivada calcula el gasto total de cada cliente; el AVG de esos gastos es el gasto promedio por cliente. HAVING compara el gasto de cada cliente con ese promedio.
@@*/
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

/*@@
ID: S07
TITULO: Producto más vendido por unidades
ENUNCIADO: El administrador quiere saber cuál es el producto (o los productos, si hay empate) con mayor cantidad de unidades vendidas.
OBJETIVO: Comparar un agregado con el máximo de otros agregados mediante una subconsulta.
EXPLICACION: La subconsulta interna suma las unidades vendidas por producto y MAX obtiene la mayor suma. HAVING deja solo los productos cuyas unidades igualan ese máximo, de modo que los empates no se pierden.
@@*/
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

/*@@
ID: S08
TITULO: Lotes con menos stock que el promedio de su producto
ENUNCIADO: Cuando un producto tiene varios lotes, el almacenero debe saber cuáles tienen menos stock que el promedio de los lotes de ese mismo producto, para despacharlos primero (rotación).
OBJETIVO: Aplicar una subconsulta correlacionada que depende de cada fila de la consulta externa.
EXPLICACION: Para cada lote, la subconsulta calcula el stock promedio de los lotes del mismo producto (l2.id_producto = l.id_producto). Se comparan ambos valores; los productos de un solo lote nunca aparecen porque su promedio es igual a su stock.
@@*/
SELECT  l.id_lote, l.id_producto, l.numero_lote, l.stock_actual
FROM    Lote l
WHERE   l.stock_actual < (SELECT AVG(CAST(l2.stock_actual AS DECIMAL(10,2)))
                          FROM   Lote l2
                          WHERE  l2.id_producto = l.id_producto)
ORDER BY l.id_producto, l.id_lote;
GO

/*@@
ID: S09
TITULO: Productos con lotes vencidos o por vencer
ENUNCIADO: El administrador quiere la lista de productos que tienen al menos un lote con stock que ya venció o vence dentro de los próximos 30 días, para retirarlos del anaquel o aplicar ofertas.
OBJETIVO: Aplicar IN con una subconsulta que filtra por fecha.
EXPLICACION: La subconsulta devuelve los id_producto de los lotes perecibles con stock cuya fecha de vencimiento es menor o igual a la fecha actual más 30 días. La consulta externa muestra los productos correspondientes.
@@*/
SELECT  p.id_producto, p.nombre, p.estado
FROM    Producto p
WHERE   p.id_producto IN (SELECT l.id_producto
                          FROM   Lote l
                          WHERE  l.stock_actual > 0
                            AND  l.fecha_vencimiento IS NOT NULL
                            AND  l.fecha_vencimiento <= DATEADD(DAY, 30, CAST(GETDATE() AS DATE)))
ORDER BY p.nombre;
GO

/*@@
ID: S10
TITULO: Categorías con al menos un producto agotado
ENUNCIADO: El comprador quiere saber en qué categorías hay productos agotados (stock total cero) para priorizar los pedidos.
OBJETIVO: Aplicar EXISTS con una subconsulta anidada de dos niveles.
EXPLICACION: EXISTS evalúa, por categoría, si hay un producto cuyo stock total es cero. El stock total del producto se obtiene con otra subconsulta escalar sobre Lote; ISNULL cuenta como cero a los productos sin lotes.
@@*/
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

/*@@
ID: S11
TITULO: Fecha de la última compra de cada cliente
ENUNCIADO: El área comercial necesita ver, para cada cliente, la fecha de su última compra, para contactar a quienes llevan tiempo sin comprar.
OBJETIVO: Aplicar una subconsulta correlacionada en la lista SELECT.
EXPLICACION: Por cada cliente, la subconsulta devuelve MAX(fecha_venta) de sus ventas; si no compró, devuelve NULL, que se presenta como «Sin compras».
@@*/
SELECT  c.id_cliente,
        c.nombres + N' ' + c.apellidos AS cliente,
        (SELECT MAX(v.fecha_venta) FROM Venta v WHERE v.id_cliente = c.id_cliente) AS ultima_compra,
        ISNULL(CONVERT(NVARCHAR(20), (SELECT MAX(v.fecha_venta) FROM Venta v WHERE v.id_cliente = c.id_cliente), 120), N'Sin compras') AS ultima_compra_texto
FROM    Cliente c
ORDER BY ultima_compra DESC, c.id_cliente;
GO

/*@@
ID: S12
TITULO: Producto más caro de cada categoría
ENUNCIADO: Gerencia desea conocer el producto de mayor precio en cada categoría para evaluar la política de precios.
OBJETIVO: Aplicar una subconsulta correlacionada con MAX por grupo.
EXPLICACION: La subconsulta calcula el precio máximo de los productos de la misma categoría; la consulta externa conserva los productos cuyo precio coincide con ese máximo.
@@*/
SELECT  c.nombre AS categoria, p.nombre AS producto, p.precio_venta
FROM    Producto p
JOIN    Categoria c ON c.id_categoria = p.id_categoria
WHERE   p.precio_venta = (SELECT MAX(p2.precio_venta)
                          FROM   Producto p2
                          WHERE  p2.id_categoria = p.id_categoria)
ORDER BY p.precio_venta DESC;
GO

/*@@
ID: S13
TITULO: Ventas posiblemente duplicadas
ENUNCIADO: Se sospecha que algunas ventas se registraron dos veces por error (mismo cajero, mismo cliente, mismo total y con minutos de diferencia). Contabilidad necesita identificarlas para revisarlas.
OBJETIVO: Detectar anomalías operativas con EXISTS correlacionado sobre la misma tabla.
EXPLICACION: Cada venta se compara con las demás ventas (alias o). Si existe otra con el mismo empleado, el mismo cliente, el mismo total y a no más de 5 minutos de diferencia, ambas se reportan. ISNULL permite comparar clientes nulos.
@@*/
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

/*@@
ID: S14
TITULO: Ventas pagadas con el medio de pago más utilizado
ENUNCIADO: Para negociar comisiones con las billeteras y el POS, gerencia quiere listar las ventas realizadas con el medio de pago que más se usa.
OBJETIVO: Usar una subconsulta con TOP 1 y ORDER BY para obtener un valor de decisión.
EXPLICACION: La subconsulta agrupa las ventas por tipo_pago y devuelve el medio con más ventas (en caso de empate, el primero alfabéticamente). La consulta externa lista las ventas que usaron ese medio.
@@*/
SELECT  v.id_venta, v.fecha_venta, v.tipo_pago, v.total
FROM    Venta v
WHERE   v.tipo_pago = (SELECT TOP 1 tipo_pago
                       FROM   Venta
                       GROUP BY tipo_pago
                       ORDER BY COUNT(*) DESC, tipo_pago)
ORDER BY v.fecha_venta;
GO

/*@@
ID: S15
TITULO: Participación de cada categoría en los ingresos
ENUNCIADO: El dueño quiere saber qué porcentaje de los ingresos totales por ventas aporta cada categoría, para enfocar el surtido.
OBJETIVO: Combinar una subconsulta escalar (total general) con una agregación por categoría.
EXPLICACION: El ingreso de cada categoría se calcula uniendo Categoria, Producto, Lote y Detalle_Venta. La subconsulta (SELECT SUM(subtotal) FROM Detalle_Venta) entrega el total general sobre el que se calcula el porcentaje.
@@*/
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
