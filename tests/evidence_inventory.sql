/* evidence_inventory.sql - Inventario de objetos creados (evidencia de la implementación real) */
USE MinimarketLaFavorita;
GO
PRINT '@@RES INV_BD';
SELECT @@SERVERNAME AS servidor, DB_NAME() AS base_de_datos, CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(30)) AS version_sql_server,
       CAST(SERVERPROPERTY('Edition') AS VARCHAR(60)) AS edicion, d.create_date AS fecha_creacion, d.collation_name AS collation
FROM sys.databases d WHERE d.name = DB_NAME();
GO
PRINT '@@RES INV_TABLAS';
SELECT t.name AS tabla,
       (SELECT COUNT(*) FROM sys.columns c WHERE c.object_id = t.object_id) AS columnas,
       SUM(p.rows) AS filas
FROM sys.tables t JOIN sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0, 1)
GROUP BY t.name, t.object_id ORDER BY t.name;
GO
PRINT '@@RES INV_RESTRICCIONES';
SELECT 'PRIMARY KEY' AS tipo, COUNT(*) AS cantidad FROM sys.key_constraints WHERE type = 'PK'
UNION ALL SELECT 'UNIQUE', COUNT(*) FROM sys.key_constraints WHERE type = 'UQ'
UNION ALL SELECT 'FOREIGN KEY', COUNT(*) FROM sys.foreign_keys
UNION ALL SELECT 'CHECK', COUNT(*) FROM sys.check_constraints
UNION ALL SELECT 'DEFAULT', COUNT(*) FROM sys.default_constraints;
GO
PRINT '@@RES INV_FK';
SELECT fk.name AS clave_foranea, OBJECT_NAME(fk.parent_object_id) AS tabla_hija, OBJECT_NAME(fk.referenced_object_id) AS tabla_padre,
       CASE WHEN fk.is_not_trusted = 0 THEN 'confiable' ELSE 'NO confiable' END AS estado
FROM sys.foreign_keys fk ORDER BY fk.name;
GO
PRINT '@@RES INV_VISTAS';
SELECT name AS vista FROM sys.views ORDER BY name;
GO
PRINT '@@RES INV_PROCEDIMIENTOS';
SELECT CASE WHEN p.name LIKE 'usp[_]%[_]Insertar' OR p.name IN ('usp_Venta_Registrar','usp_DetalleVenta_Agregar','usp_Comprobante_Emitir') THEN 'INSERT'
            WHEN p.name IN ('usp_Producto_ActualizarPrecio','usp_Producto_CambiarEstado','usp_Cliente_ActualizarContacto','usp_Empleado_CambiarEstado','usp_Lote_AjustarStock','usp_Venta_CambiarMedioPago') THEN 'UPDATE'
            WHEN p.name IN ('usp_Cliente_Eliminar','usp_Venta_Anular') THEN 'DELETE'
            ELSE 'SELECT' END AS tipo,
       p.name AS procedimiento,
       (SELECT COUNT(*) FROM sys.parameters pa WHERE pa.object_id = p.object_id) AS parametros
FROM sys.procedures p WHERE p.name LIKE 'usp[_]%'
ORDER BY CASE WHEN p.name LIKE 'usp[_]%[_]Insertar' OR p.name IN ('usp_Venta_Registrar','usp_DetalleVenta_Agregar','usp_Comprobante_Emitir') THEN 1
              WHEN p.name IN ('usp_Producto_ActualizarPrecio','usp_Producto_CambiarEstado','usp_Cliente_ActualizarContacto','usp_Empleado_CambiarEstado','usp_Lote_AjustarStock','usp_Venta_CambiarMedioPago') THEN 2
              WHEN p.name IN ('usp_Cliente_Eliminar','usp_Venta_Anular') THEN 3 ELSE 4 END, p.name;
GO
PRINT '@@RES INV_RESUMEN';
SELECT (SELECT COUNT(*) FROM sys.tables) AS tablas, (SELECT COUNT(*) FROM sys.views WHERE name LIKE 'vw[_]%') AS vistas,
       (SELECT COUNT(*) FROM sys.procedures WHERE name LIKE 'usp[_]%') AS procedimientos,
       (SELECT COUNT(*) FROM sys.types WHERE is_table_type = 1) AS tipos_tabla;
GO
