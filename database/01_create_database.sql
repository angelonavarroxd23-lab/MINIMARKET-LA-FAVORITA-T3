/* ============================================================================
   01_create_database.sql
   Proyecto T3 - Minimarket "La Favorita" - Microsoft SQL Server (2016 SP1+)
   Crea la base de datos MinimarketLaFavorita.

   SEGURIDAD: solo se elimina y recrea una base con ese nombre si fue creada
   por este proyecto (propiedad extendida 'proyecto' = 'LA_FAVORITA_T3').
   Si existe una base homónima ajena, el script se cancela sin tocarla.
   ============================================================================ */
USE master;
GO
IF DB_ID(N'MinimarketLaFavorita') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM MinimarketLaFavorita.sys.extended_properties
               WHERE class = 0 AND name = N'proyecto'
                 AND CAST(value AS NVARCHAR(100)) = N'LA_FAVORITA_T3')
    BEGIN
        ALTER DATABASE MinimarketLaFavorita SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
        DROP DATABASE MinimarketLaFavorita;
    END
    ELSE
        THROW 50000, N'Ya existe una base MinimarketLaFavorita que NO fue creada por este proyecto. Se cancela para no destruir datos ajenos.', 1;
END
GO
CREATE DATABASE MinimarketLaFavorita;
GO
EXEC MinimarketLaFavorita.sys.sp_addextendedproperty
     @name = N'proyecto', @value = N'LA_FAVORITA_T3';
GO
