/* ============================================================================
   09_procedures_delete.sql - Proyecto T3 La Favorita: 2 procedimientos DELETE
   (códigos de error: ver cabecera de 07_procedures_insert.sql)
   ============================================================================ */
USE MinimarketLaFavorita;
GO

/*@@
ID: PD01
TITULO: usp_Cliente_Eliminar
ENUNCIADO: Un cliente se registró por error o pidió que se eliminen sus datos. El administrador puede eliminarlo solo si nunca compró; si tiene ventas, el sistema debe impedirlo para no perder el historial.
OBJETIVO: Eliminar con seguridad aplicando RN-10: no se borra información con historial.
EXPLICACION: Comprueba que el cliente exista (50001) y cuenta sus ventas. Si tiene alguna, lanza el error 50006 con la cantidad de ventas asociadas y no borra nada. Solo cuando no hay dependencias ejecuta el DELETE.
EJEMPLO: DECLARE @id INT;
EXEC dbo.usp_Cliente_Insertar @dni = '78999001', @nombres = N'Prueba', @apellidos = N'Temporal', @distrito = N'Comas', @id_cliente = @id OUTPUT;
EXEC dbo.usp_Cliente_Eliminar @id_cliente = @id;
SELECT COUNT(*) AS filas_restantes FROM Cliente WHERE id_cliente = @id;
@@*/
CREATE OR ALTER PROCEDURE dbo.usp_Cliente_Eliminar
    @id_cliente INT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @ventas INT, @msg NVARCHAR(200);
    IF NOT EXISTS (SELECT 1 FROM Cliente WHERE id_cliente = @id_cliente)
        THROW 50001, N'El cliente indicado no existe.', 1;
    SELECT @ventas = COUNT(*) FROM Venta WHERE id_cliente = @id_cliente;
    IF @ventas > 0
    BEGIN
        SET @msg = CONCAT(N'No se puede eliminar: el cliente tiene ', @ventas, N' venta(s) registrada(s).');
        THROW 50006, @msg, 1;
    END

    DELETE FROM Cliente WHERE id_cliente = @id_cliente;
END
GO

/*@@
ID: PD02
TITULO: usp_Venta_Anular
ENUNCIADO: Se registró una venta por error (por ejemplo, la venta duplicada del 18/10 a las 09:06). Un administrador debe poder anularla: se eliminan el comprobante, el detalle y la venta, y las unidades regresan al stock de sus lotes.
OBJETIVO: Anular una venta completa de forma atómica, devolviendo el inventario y respetando el orden de las claves foráneas (hijas antes que padres).
EXPLICACION: Solo puede autorizarla un empleado activo con rol ADMIN o SUPERADMIN (50010, RN-01). En una transacción: repone el stock de cada lote con la cantidad vendida, elimina el Comprobante, luego Detalle_Venta y por último Venta. Si cualquier paso falla, se revierte todo.
EJEMPLO: SELECT id_lote, stock_actual FROM Lote WHERE id_lote IN (11, 9);
EXEC dbo.usp_Venta_Anular @id_venta = 20, @id_empleado_autoriza = 2;
SELECT id_lote, stock_actual FROM Lote WHERE id_lote IN (11, 9);
SELECT COUNT(*) AS ventas_con_id_20 FROM Venta WHERE id_venta = 20;
@@*/
CREATE OR ALTER PROCEDURE dbo.usp_Venta_Anular
    @id_venta             INT,
    @id_empleado_autoriza INT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @owns BIT = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM Venta WHERE id_venta = @id_venta)
            THROW 50001, N'La venta indicada no existe.', 1;
        IF NOT EXISTS (SELECT 1 FROM Empleado
                       WHERE id_empleado = @id_empleado_autoriza AND activo = 1 AND rol IN ('ADMIN','SUPERADMIN'))
            THROW 50010, N'Solo un ADMIN o SUPERADMIN activo puede anular ventas.', 1;

        IF @owns = 1 BEGIN TRANSACTION;

        UPDATE lo SET stock_actual = lo.stock_actual + d.cantidad
        FROM   Lote lo
        JOIN   Detalle_Venta d ON d.id_lote = lo.id_lote
        WHERE  d.id_venta = @id_venta;

        DELETE FROM Comprobante   WHERE id_venta = @id_venta;
        DELETE FROM Detalle_Venta WHERE id_venta = @id_venta;
        DELETE FROM Venta         WHERE id_venta = @id_venta;

        IF @owns = 1 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @owns = 1 AND XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO
