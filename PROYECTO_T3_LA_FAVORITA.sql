/* ============================================================================
 PROYECTO T3 - Minimarket «La Favorita» - Script único (scripts 01 a 11 de database/)
 Ejecutar con sqlcmd -b -I (QUOTED_IDENTIFIER ON; la columna calculada persistida lo exige) o en SSMS.
 Crea la base MinimarketLaFavorita (solo recrea una base que lleve la marca del proyecto).
 ============================================================================ */
GO

/* ##### 01_create_database.sql ##### */
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
GO

/* ##### 02_create_tables.sql ##### */
/* 02_create_tables.sql - Proyecto T3 La Favorita: 8 tablas, PK, FK y restricciones (modelo T2) */
USE MinimarketLaFavorita;
GO

/* ================================================================
   SECCIÓN 1. CREACIÓN DE TABLAS (orden: tablas padre antes que tablas hijas)
   ================================================================ */
 
CREATE TABLE Categoria (
    id_categoria  INT IDENTITY(1,1) NOT NULL,
    nombre        NVARCHAR(50)      NOT NULL,
    tipo          VARCHAR(10)       NOT NULL,
    descripcion   NVARCHAR(150)     NULL,
    CONSTRAINT PK_Categoria        PRIMARY KEY (id_categoria),
    CONSTRAINT UQ_Categoria_Nombre UNIQUE (nombre),
    CONSTRAINT CK_Categoria_Tipo   CHECK (tipo IN ('ALIMENTO', 'BEBIDA', 'LIMPIEZA', 'GENERAL'))
);
GO
 
CREATE TABLE Producto (
    id_producto    INT IDENTITY(1,1) NOT NULL,
    codigo_barras  VARCHAR(13)       NOT NULL,
    nombre         NVARCHAR(100)     NOT NULL,
    descripcion    NVARCHAR(200)     NULL,
    precio_venta   DECIMAL(10,2)     NOT NULL,
    stock_minimo   INT               NOT NULL CONSTRAINT DF_Producto_StockMin DEFAULT (0),
    estado         VARCHAR(8)        NOT NULL CONSTRAINT DF_Producto_Estado DEFAULT ('ACTIVO'),
    id_categoria   INT               NOT NULL,
    CONSTRAINT PK_Producto           PRIMARY KEY (id_producto),
    CONSTRAINT UQ_Producto_Codigo    UNIQUE (codigo_barras),
    CONSTRAINT CK_Producto_Codigo    CHECK (LEN(codigo_barras) BETWEEN 8 AND 13
                                            AND codigo_barras NOT LIKE '%[^0-9]%'),
    CONSTRAINT CK_Producto_Precio    CHECK (precio_venta > 0),
    CONSTRAINT CK_Producto_StockMin  CHECK (stock_minimo >= 0),
    CONSTRAINT CK_Producto_Estado    CHECK (estado IN ('ACTIVO', 'INACTIVO')),
    CONSTRAINT FK_Producto_Categoria FOREIGN KEY (id_categoria)
        REFERENCES Categoria (id_categoria)
);
GO
 
CREATE TABLE Lote (
    id_lote            INT IDENTITY(1,1) NOT NULL,
    id_producto        INT               NOT NULL,
    numero_lote        VARCHAR(30)       NOT NULL,
    fecha_ingreso      DATE              NOT NULL,
    fecha_vencimiento  DATE              NULL,  -- NULL: producto no perecible
    cantidad_inicial   INT               NOT NULL,
    stock_actual       INT               NOT NULL,
    costo_unitario     DECIMAL(10,2)     NOT NULL,
    CONSTRAINT PK_Lote            PRIMARY KEY (id_lote),
    CONSTRAINT UQ_Lote_Numero     UNIQUE (id_producto, numero_lote),
    CONSTRAINT CK_Lote_Cantidad   CHECK (cantidad_inicial > 0),
    CONSTRAINT CK_Lote_Stock      CHECK (stock_actual >= 0 AND stock_actual <= cantidad_inicial),
    CONSTRAINT CK_Lote_Costo      CHECK (costo_unitario > 0),
    CONSTRAINT CK_Lote_Fechas     CHECK (fecha_vencimiento IS NULL
                                         OR fecha_vencimiento > fecha_ingreso),
    CONSTRAINT FK_Lote_Producto   FOREIGN KEY (id_producto)
        REFERENCES Producto (id_producto)
);
GO
 
CREATE TABLE Cliente (
    id_cliente      INT IDENTITY(1,1) NOT NULL,
    dni             CHAR(8)           NOT NULL,
    nombres         NVARCHAR(50)      NOT NULL,
    apellidos       NVARCHAR(50)      NOT NULL,
    telefono        CHAR(9)           NULL,
    direccion       NVARCHAR(150)     NULL,
    distrito        NVARCHAR(40)      NOT NULL,
    fecha_registro  DATE              NOT NULL
                    CONSTRAINT DF_Cliente_Fecha DEFAULT (CAST(GETDATE() AS DATE)),
    CONSTRAINT PK_Cliente          PRIMARY KEY (id_cliente),
    CONSTRAINT UQ_Cliente_Dni      UNIQUE (dni),
    CONSTRAINT CK_Cliente_Dni      CHECK (LEN(dni) = 8 AND dni NOT LIKE '%[^0-9]%'),
    CONSTRAINT CK_Cliente_Telefono CHECK (telefono IS NULL
                                          OR (telefono LIKE '9%' AND telefono NOT LIKE '%[^0-9]%'))
);
GO
 
CREATE TABLE Empleado (
    id_empleado    INT IDENTITY(1,1) NOT NULL,
    dni            CHAR(8)           NOT NULL,
    nombres        NVARCHAR(50)      NOT NULL,
    apellidos      NVARCHAR(50)      NOT NULL,
    correo         VARCHAR(100)      NOT NULL,
    usuario        VARCHAR(30)       NOT NULL,
    clave_hash     VARCHAR(255)      NOT NULL,  -- hash PBKDF2 generado por la aplicación
    rol            VARCHAR(10)       NOT NULL,
    telefono       CHAR(9)           NULL,
    fecha_ingreso  DATE              NOT NULL,
    activo         BIT               NOT NULL CONSTRAINT DF_Empleado_Activo DEFAULT (1),
    CONSTRAINT PK_Empleado          PRIMARY KEY (id_empleado),
    CONSTRAINT UQ_Empleado_Dni      UNIQUE (dni),
    CONSTRAINT UQ_Empleado_Correo   UNIQUE (correo),
    CONSTRAINT UQ_Empleado_Usuario  UNIQUE (usuario),
    CONSTRAINT CK_Empleado_Dni      CHECK (LEN(dni) = 8 AND dni NOT LIKE '%[^0-9]%'),
    CONSTRAINT CK_Empleado_Correo   CHECK (correo LIKE '%_@_%._%'),
    CONSTRAINT CK_Empleado_Rol      CHECK (rol IN ('SUPERADMIN', 'ADMIN', 'CAJERO')),
    CONSTRAINT CK_Empleado_Telefono CHECK (telefono IS NULL
                                           OR (telefono LIKE '9%' AND telefono NOT LIKE '%[^0-9]%'))
);
GO
 
CREATE TABLE Venta (
    id_venta     INT IDENTITY(1,1) NOT NULL,
    fecha_venta  DATETIME2(0)      NOT NULL CONSTRAINT DF_Venta_Fecha DEFAULT (SYSDATETIME()),
    id_empleado  INT               NOT NULL,
    id_cliente   INT               NULL,      -- venta sin cliente identificado
    tipo_pago    VARCHAR(8)        NOT NULL,
    total        DECIMAL(10,2)     NOT NULL CONSTRAINT DF_Venta_Total DEFAULT (0),
    CONSTRAINT PK_Venta           PRIMARY KEY (id_venta),
    CONSTRAINT CK_Venta_TipoPago  CHECK (tipo_pago IN ('EFECTIVO', 'YAPE', 'PLIN', 'TARJETA')),
    CONSTRAINT CK_Venta_Total     CHECK (total >= 0),
    CONSTRAINT FK_Venta_Empleado  FOREIGN KEY (id_empleado) REFERENCES Empleado (id_empleado),
    CONSTRAINT FK_Venta_Cliente   FOREIGN KEY (id_cliente)  REFERENCES Cliente (id_cliente)
);
GO
 
CREATE TABLE Detalle_Venta (
    id_detalle       INT IDENTITY(1,1) NOT NULL,
    id_venta         INT               NOT NULL,
    id_lote          INT               NOT NULL,
    cantidad         INT               NOT NULL,
    precio_unitario  DECIMAL(10,2)     NOT NULL,  -- precio vigente al momento de la venta
    subtotal         AS CAST(cantidad * precio_unitario AS DECIMAL(10,2)) PERSISTED,
    CONSTRAINT PK_Detalle_Venta    PRIMARY KEY (id_detalle),
    CONSTRAINT UQ_Detalle_VentaLote UNIQUE (id_venta, id_lote),
    CONSTRAINT CK_Detalle_Cantidad CHECK (cantidad > 0),
    CONSTRAINT CK_Detalle_Precio   CHECK (precio_unitario > 0),
    CONSTRAINT FK_Detalle_Venta    FOREIGN KEY (id_venta) REFERENCES Venta (id_venta),
    CONSTRAINT FK_Detalle_Lote     FOREIGN KEY (id_lote)  REFERENCES Lote (id_lote)
);
GO
 
CREATE TABLE Comprobante (
    id_comprobante    INT IDENTITY(1,1) NOT NULL,
    id_venta          INT               NOT NULL,
    tipo_comprobante  VARCHAR(7)        NOT NULL,
    serie             CHAR(4)           NOT NULL,
    numero            INT               NOT NULL,
    fecha_emision     DATETIME2(0)      NOT NULL,
    ruc_receptor      CHAR(11)          NULL,  -- obligatorio solo en facturas
    CONSTRAINT PK_Comprobante         PRIMARY KEY (id_comprobante),
    CONSTRAINT UQ_Comprobante_Venta   UNIQUE (id_venta),          -- relación 1:1 con Venta
    CONSTRAINT UQ_Comprobante_Serie   UNIQUE (serie, numero),
    CONSTRAINT CK_Comprobante_Tipo    CHECK (tipo_comprobante IN ('BOLETA', 'FACTURA')),
    CONSTRAINT CK_Comprobante_Numero  CHECK (numero > 0),
    CONSTRAINT CK_Comprobante_Serie   CHECK ((tipo_comprobante = 'BOLETA'  AND serie LIKE 'B[0-9][0-9][0-9]')
                                          OR (tipo_comprobante = 'FACTURA' AND serie LIKE 'F[0-9][0-9][0-9]')),
    CONSTRAINT CK_Comprobante_Ruc     CHECK ((tipo_comprobante = 'BOLETA' AND ruc_receptor IS NULL)
                                          OR (tipo_comprobante = 'FACTURA'
                                              AND ruc_receptor IS NOT NULL
                                              AND (ruc_receptor LIKE '10%' OR ruc_receptor LIKE '20%')
                                              AND ruc_receptor NOT LIKE '%[^0-9]%')),
    CONSTRAINT FK_Comprobante_Venta   FOREIGN KEY (id_venta) REFERENCES Venta (id_venta)
);
GO
GO

/* ##### 03_insert_data.sql ##### */
/* 03_insert_data.sql - Proyecto T3 La Favorita: datos de prueba de T2 (20 filas por tabla; 21 lotes; 37 detalles) */
USE MinimarketLaFavorita;
GO

/* ================================================================
   SECCIÓN 2. CARGA INICIAL (IDENTITY_INSERT con identificadores explícitos)
   ================================================================ */
 
-- 20 categorías agrupadas en los 4 tipos del negocio (ALIMENTO, BEBIDA, LIMPIEZA, GENERAL)
SET IDENTITY_INSERT Categoria ON;
INSERT INTO Categoria (id_categoria, nombre, tipo, descripcion) VALUES
    (1, N'Abarrotes', 'ALIMENTO', N'Arroz, azúcar, aceite, fideos y menestras'),
    (2, N'Lácteos', 'ALIMENTO', N'Leche, yogurt, queso y mantequilla'),
    (3, N'Panadería', 'ALIMENTO', N'Pan de molde, tostadas y bizcochos envasados'),
    (4, N'Embutidos', 'ALIMENTO', N'Jamonada, hot dog y otros embutidos refrigerados'),
    (5, N'Conservas', 'ALIMENTO', N'Atún, sardinas y otros productos enlatados'),
    (6, N'Snacks y golosinas', 'ALIMENTO', N'Galletas, chocolates y piqueos'),
    (7, N'Frutas y verduras', 'ALIMENTO', N'Productos frescos de venta por unidad'),
    (8, N'Gaseosas', 'BEBIDA', N'Bebidas carbonatadas en distintos formatos'),
    (9, N'Aguas', 'BEBIDA', N'Agua de mesa con y sin gas'),
    (10, N'Jugos y néctares', 'BEBIDA', N'Néctares y refrescos envasados'),
    (11, N'Bebidas energizantes', 'BEBIDA', N'Energizantes e hidratantes'),
    (12, N'Infusiones y café', 'BEBIDA', N'Café instantáneo, té e infusiones'),
    (13, N'Detergentes', 'LIMPIEZA', N'Detergentes en polvo y líquidos para ropa'),
    (14, N'Limpiadores del hogar', 'LIMPIEZA', N'Lejía, desinfectantes y limpiadores para el hogar'),
    (15, N'Papel y servilletas', 'LIMPIEZA', N'Papel higiénico, papel toalla y servilletas'),
    (16, N'Cuidado personal', 'GENERAL', N'Jabón, champú, pasta dental y artículos de aseo del hogar'),
    (17, N'Descartables', 'GENERAL', N'Vasos, platos y bolsas descartables'),
    (18, N'Útiles escolares', 'GENERAL', N'Cuadernos, lapiceros y útiles básicos'),
    (19, N'Pilas y focos', 'GENERAL', N'Pilas, baterías y focos ahorradores'),
    (20, N'Mascotas', 'GENERAL', N'Alimento y accesorios para mascotas');
SET IDENTITY_INSERT Categoria OFF;
GO
 
-- 20 productos; cada uno referencia una categoría existente
SET IDENTITY_INSERT Producto ON;
INSERT INTO Producto (id_producto, codigo_barras, nombre, descripcion, precio_venta, stock_minimo, estado, id_categoria) VALUES
    (1, '7750100100018', N'Arroz extra 5 kg', N'Arroz extra graneado, bolsa de 5 kg', 21.50, 10, 'ACTIVO', 1),
    (2, '7750100100025', N'Azúcar rubia 5 kg', N'Azúcar rubia doméstica, bolsa de 5 kg', 18.00, 10, 'ACTIVO', 1),
    (3, '7750100100032', N'Aceite vegetal 1 L', N'Aceite vegetal comestible, botella de 1 L', 9.80, 15, 'ACTIVO', 1),
    (4, '7750100100049', N'Fideo spaghetti 500 g', N'Fideo largo, paquete de 500 g', 3.80, 20, 'ACTIVO', 1),
    (5, '7750100100056', N'Leche evaporada 400 g', N'Leche evaporada entera, lata de 400 g', 4.20, 24, 'ACTIVO', 2),
    (6, '7750100100063', N'Yogurt de fresa 1 L', N'Yogurt bebible sabor fresa, botella de 1 L', 6.50, 8, 'ACTIVO', 2),
    (7, '7750100100070', N'Pan de molde blanco 600 g', N'Pan de molde blanco, bolsa de 600 g', 7.90, 5, 'ACTIVO', 3),
    (8, '7750100100087', N'Jamonada 250 g', N'Jamonada de cerdo en tajadas, 250 g', 5.60, 6, 'ACTIVO', 4),
    (9, '7750100100094', N'Atún en trozos 170 g', N'Atún en trozos en aceite vegetal, lata de 170 g', 6.20, 12, 'ACTIVO', 5),
    (10, '7750100100100', N'Galleta de soda x6', N'Galleta de soda, paquete de 6 unidades', 2.50, 15, 'ACTIVO', 6),
    (11, '7750100100117', N'Gaseosa cola 3 L', N'Bebida gaseosa sabor cola, botella de 3 L', 12.50, 8, 'ACTIVO', 8),
    (12, '7750100100124', N'Gaseosa cola 500 ml', N'Bebida gaseosa sabor cola, botella de 500 ml', 2.50, 20, 'ACTIVO', 8),
    (13, '7750100100131', N'Agua sin gas 625 ml', N'Agua de mesa sin gas, botella de 625 ml', 1.50, 30, 'ACTIVO', 9),
    (14, '7750100100148', N'Néctar de durazno 1 L', N'Néctar de durazno, caja de 1 L', 4.50, 4, 'ACTIVO', 10),
    (15, '7750100100155', N'Bebida energizante 473 ml', N'Bebida energizante en lata de 473 ml', 3.50, 10, 'ACTIVO', 11),
    (16, '7750100100162', N'Café instantáneo 50 g', N'Café instantáneo, frasco de 50 g', 8.90, 6, 'ACTIVO', 12),
    (17, '7750100100179', N'Detergente en polvo 900 g', N'Detergente multiusos en polvo, bolsa de 900 g', 10.90, 6, 'ACTIVO', 13),
    (18, '7750100100186', N'Lejía 1 L', N'Lejía tradicional, botella de 1 L', 3.20, 8, 'ACTIVO', 14),
    (19, '7750100100193', N'Papel higiénico x4', N'Papel higiénico doble hoja, paquete de 4 rollos', 5.90, 10, 'ACTIVO', 15),
    (20, '7750100100209', N'Pilas AA x2', N'Pilas alcalinas AA, blíster de 2 unidades', 7.50, 5, 'INACTIVO', 19);
SET IDENTITY_INSERT Producto OFF;
GO
 
-- 21 lotes (21: el agua tiene dos partidas); stock_actual = cantidad_inicial - unidades vendidas en la carga inicial de ventas
SET IDENTITY_INSERT Lote ON;
INSERT INTO Lote (id_lote, id_producto, numero_lote, fecha_ingreso, fecha_vencimiento, cantidad_inicial, stock_actual, costo_unitario) VALUES
    (1, 1, 'LT-ARZ-2609A', '2026-09-05', '2027-09-05', 40, 35, 18.20),
    (2, 2, 'LT-AZR-2609A', '2026-09-06', '2027-09-06', 40, 37, 15.10),
    (3, 3, 'LT-ACE-2609A', '2026-09-08', '2027-06-30', 48, 45, 8.10),
    (4, 4, 'LT-FID-2609A', '2026-09-10', '2027-12-31', 60, 58, 2.90),
    (5, 5, 'LT-LEV-2609A', '2026-09-12', '2027-03-15', 48, 45, 3.40),
    (6, 6, 'LT-YOG-2610A', '2026-10-08', '2026-11-05', 20, 17, 4.90),
    (7, 7, 'LT-PAN-2610A', '2026-10-14', '2026-10-29', 10, 4, 5.80),
    (8, 8, 'LT-JAM-2610A', '2026-10-12', '2026-11-02', 10, 5, 4.10),
    (9, 9, 'LT-ATU-2609A', '2026-09-15', '2029-09-15', 36, 32, 4.70),
    (10, 10, 'LT-GAL-2609A', '2026-09-20', '2027-03-20', 40, 35, 1.80),
    (11, 11, 'LT-GC3-2609A', '2026-09-25', '2027-01-25', 24, 21, 9.60),
    (12, 12, 'LT-GC5-2609X', '2026-09-25', '2027-01-10', 48, 40, 1.70),
    (13, 13, 'LT-AGU-2609A', '2026-09-28', '2027-09-28', 60, 50, 0.90),
    (14, 14, 'LT-NEC-2610A', '2026-10-01', '2026-12-15', 6, 0, 3.20),
    (15, 15, 'LT-ENE-2610A', '2026-10-02', '2027-10-02', 24, 22, 2.40),
    (16, 16, 'LT-CAF-2609A', '2026-09-18', '2028-03-18', 8, 5, 6.70),
    (17, 17, 'LT-DET-2609A', '2026-09-03', '2028-09-03', 20, 17, 8.30),
    (18, 18, 'LT-LEJ-2609A', '2026-09-03', '2027-09-03', 24, 22, 2.10),
    (19, 19, 'LT-PAP-2609A', '2026-09-04', NULL, 30, 27, 4.10),
    (20, 1, 'LT-ARZ-2610B', '2026-10-18', '2027-10-18', 30, 30, 18.50),
    (21, 13, 'LT-AGU-2610B', '2026-10-15', '2027-10-15', 48, 48, 0.95);
SET IDENTITY_INSERT Lote OFF;
GO
 
-- 20 clientes con DNI de 8 dígitos y único (datos ficticios)
SET IDENTITY_INSERT Cliente ON;
INSERT INTO Cliente (id_cliente, dni, nombres, apellidos, telefono, direccion, distrito, fecha_registro) VALUES
    (1, '10234567', N'Juan José', N'Pérez Alva', '987654321', N'Av. Universitaria 1200', N'Comas', '2026-09-02'),
    (2, '10345678', N'María Teresa', N'Gómez Ramos', '912345678', N'Jr. Asunción 450', N'Comas', '2026-09-02'),
    (3, '10456789', N'Carlos Daniel', N'Salinas Cárdenas', '923456789', N'Calle Los Pinos 102', N'Los Olivos', '2026-09-05'),
    (4, '41567890', N'Rosa Elena', N'Huamán Flores', '934567801', N'Av. Túpac Amaru 3450', N'Comas', '2026-09-08'),
    (5, '42678901', N'Pedro Pablo', N'Quispe Mamani', '945678012', N'Jr. Los Andes 215', N'Comas', '2026-09-10'),
    (6, '43789012', N'Lucía Fernanda', N'Vargas Chávez', '956780123', N'Av. Belaúnde 870', N'Comas', '2026-09-12'),
    (7, '44890123', N'Jorge Luis', N'Ramírez Soto', NULL, N'Calle Santa Rosa 34', N'Independencia', '2026-09-15'),
    (8, '45901234', N'Ana Lucía', N'Castillo Paredes', '967801234', N'Av. Trapiche 560', N'Comas', '2026-09-18'),
    (9, '46012345', N'Miguel Ángel', N'Torres Huerta', '978012345', N'Jr. Libertad 1021', N'Carabayllo', '2026-09-20'),
    (10, '47123456', N'Sofía Isabel', N'Mendoza Rojas', '989123456', N'Av. Revolución 145', N'Comas', '2026-09-25'),
    (11, '48234567', N'Diego Alonso', N'Córdova León', '990234567', N'Calle Las Begonias 77', N'Los Olivos', '2026-09-28'),
    (12, '49345678', N'Carmen Rosa', N'Ñahui Poma', NULL, N'Jr. Huancavelica 310', N'Comas', '2026-10-01'),
    (13, '70456789', N'Luis Alberto', N'Gutiérrez Díaz', '901345678', N'Av. Universitaria 5400', N'Los Olivos', '2026-10-03'),
    (14, '71567890', N'Valeria', N'Espinoza Cruz', '912456789', N'Jr. Puno 88', N'Comas', '2026-10-05'),
    (15, '72678901', N'Ricardo', N'Palacios Vega', '923567890', N'Av. Guillermo de la Fuente 230', N'Comas', '2026-10-07'),
    (16, '73789012', N'Gabriela', N'Aguilar Medina', '934678901', N'Calle Los Cedros 19', N'Independencia', '2026-10-09'),
    (17, '74890123', N'Andrés', N'Rivera Campos', '945789012', N'Jr. Amazonas 402', N'Comas', '2026-10-12'),
    (18, '75901234', N'Patricia', N'Salazar Núñez', NULL, N'Av. Micaela Bastidas 615', N'Comas', '2026-10-14'),
    (19, '76012345', N'Fernando', N'Lozano Ortiz', '956890123', N'Calle 12 Mz. B Lt. 7', N'Carabayllo', '2026-10-16'),
    (20, '77123456', N'Milagros', N'Benites Ramos', '967901234', N'Jr. Ayacucho 129', N'Comas', '2026-10-18');
SET IDENTITY_INSERT Cliente OFF;
GO
 
-- 20 empleados; clave_hash contiene hashes PBKDF2-SHA256 de contraseñas ficticias (nunca texto plano)
SET IDENTITY_INSERT Empleado ON;
INSERT INTO Empleado (id_empleado, dni, nombres, apellidos, correo, usuario, clave_hash, rol, telefono, fecha_ingreso, activo) VALUES
    (1, '40123456', N'Carlos Alberto', N'Pérez Gómez', 'cperez@lafavorita.pe', 'cperez', 'pbkdf2_sha256$600000$AsRm2VPuSh1Ywxh7$iuNlFatxnej5ZvePeDfDSVOesM59bKEEeigKLDhrDqk=', 'SUPERADMIN', '981100001', '2021-03-01', 1),
    (2, '41234567', N'Ana María', N'Torres Rojas', 'atorres@lafavorita.pe', 'atorres', 'pbkdf2_sha256$600000$chXXUOJyu3EjKQtL$9oEzz62TfwFlnWkHFIsdcd3eNvMLxipRkKEvry224Ok=', 'ADMIN', '981100002', '2022-01-15', 1),
    (3, '42345678', N'Luis Enrique', N'Mendoza Quispe', 'lmendoza@lafavorita.pe', 'lmendoza', 'pbkdf2_sha256$600000$gTdQeXePaqP9RW5g$LDQ+WFhVsYt/fmHFwa7n7de+ja2S/AF3IpCBE0dkzvA=', 'CAJERO', '981100003', '2022-06-01', 1),
    (4, '43456789', N'Karina Paola', N'Ríos Valdivia', 'krios@lafavorita.pe', 'krios', 'pbkdf2_sha256$600000$3DXaqUlFNKBBQnmN$/GwraRnWKUM0cdSI1vP/bake8IPda02hmxmoKTeCHqE=', 'CAJERO', '981100004', '2023-02-10', 1),
    (5, '44567890', N'José Manuel', N'Huamaní Cruz', 'jhuamani@lafavorita.pe', 'jhuamani', 'pbkdf2_sha256$600000$AIygzsboQYUEkADn$7QK+3gBJ+LmnE/lElLzeQO32g87mc5EuRJZAtjErW7I=', 'CAJERO', '981100005', '2023-05-02', 1),
    (6, '45678901', N'Daniela', N'Acosta Bravo', 'dacosta@lafavorita.pe', 'dacosta', 'pbkdf2_sha256$600000$wElb72nyxPifa9Ou$6Eb7+NL0LkhZzi+PstuWWlCGFw7r35Eq9Dm+ubddqVg=', 'CAJERO', '981100006', '2023-08-20', 1),
    (7, '46789012', N'Martín Ernesto', N'Saavedra Lima', 'msaavedra@lafavorita.pe', 'msaavedra', 'pbkdf2_sha256$600000$AOe8JxGEA0fdYK8O$6rV/JDYbPvpe1Qyw1ELBa2uk6Q6uZKwob9Z3tlvMNnw=', 'CAJERO', '981100007', '2024-01-08', 1),
    (8, '47890123', N'Silvia Roxana', N'Delgado Ponce', 'sdelgado@lafavorita.pe', 'sdelgado', 'pbkdf2_sha256$600000$STMAalHE07avIMRL$ok+UeW5IC5B7gZyJcPJE7Zzf31czR9VXyRz/2r6F968=', 'ADMIN', '981100008', '2024-03-11', 1),
    (9, '48901234', N'Renzo Alejandro', N'Paucar Tello', 'rpaucar@lafavorita.pe', 'rpaucar', 'pbkdf2_sha256$600000$J0oc5PLIwbbPXSbf$Aktp3rKcAjn3i+0D6o8DcqPTMAZJXcEUfPkLRiWE1FM=', 'CAJERO', '981100009', '2024-05-20', 1),
    (10, '49012345', N'Milagros del Pilar', N'Arce Nole', 'marce@lafavorita.pe', 'marce', 'pbkdf2_sha256$600000$H2i5hFrw0bwC6qo2$p2hK0lTCX50kbeS5zhmGMCyDwwqUWkbxfufYehJ4t0U=', 'CAJERO', '981100010', '2024-07-01', 1),
    (11, '70123456', N'Kevin Jesús', N'Ccahuana Rojas', 'kccahuana@lafavorita.pe', 'kccahuana', 'pbkdf2_sha256$600000$DteHSUmuZaG4TwvI$00U58qk6uYYl8WszPDlMmM9nz+P6ENMIJ0jmlK9Ma94=', 'CAJERO', '981100011', '2024-09-16', 1),
    (12, '71234567', N'Lizbeth Carolina', N'Yupanqui Soto', 'lyupanqui@lafavorita.pe', 'lyupanqui', 'pbkdf2_sha256$600000$t0lDDlhBMezCN3ri$kmOpZs19s7lPkuTugCH22ANgjciwJBTR77xenG5JY8M=', 'CAJERO', '981100012', '2025-01-06', 1),
    (13, '72345678', N'Bruno Sebastián', N'Chumpitaz Vera', 'bchumpitaz@lafavorita.pe', 'bchumpitaz', 'pbkdf2_sha256$600000$wtncIo9PERGoounl$MXiqulbv8Lgw8Trk3Jd5/UeD1u4dBVMoHAX2gxRxBcI=', 'CAJERO', '981100013', '2025-03-03', 1),
    (14, '73456789', N'Gianella Rocío', N'Fuentes Alarcón', 'gfuentes@lafavorita.pe', 'gfuentes', 'pbkdf2_sha256$600000$iarsaikfN7KzILTj$QLTIyXSGbPxSggEPrp1w7nVtQnuKdMSoCcHtFHUXtb8=', 'CAJERO', '981100014', '2025-06-09', 1),
    (15, '74567890', N'Héctor Raúl', N'Mejía Pinto', 'hmejia@lafavorita.pe', 'hmejia', 'pbkdf2_sha256$600000$e19DemMKRDsvaJ6K$Uc5TZoTfXUvSqjLI6Az/aKNo9KMpMfl9AHQXw3UjomE=', 'CAJERO', '981100015', '2025-08-18', 1),
    (16, '75678901', N'Fiorella Andrea', N'Cueva Ramos', 'fcueva@lafavorita.pe', 'fcueva', 'pbkdf2_sha256$600000$J235kM7kq8fPdZ2i$p+wCN15a65ZQWGkf1lvuyw+30f9yhiA1OxO6on/+1Oc=', 'ADMIN', '981100016', '2025-11-03', 1),
    (17, '76789012', N'Edwin Omar', N'Laura Condori', 'elaura@lafavorita.pe', 'elaura', 'pbkdf2_sha256$600000$IVdRAHT2ldGy7sha$qgkoSrpQ9ZeBi6uJ0c8LfP6oKdJTMB+TMtIeQ9GtmIk=', 'CAJERO', NULL, '2023-04-12', 0),
    (18, '77890123', N'Yessenia Marisol', N'Tapia Ruiz', 'ytapia@lafavorita.pe', 'ytapia', 'pbkdf2_sha256$600000$LBodaYBrJIf4CO1B$5AwYQtiQZ4sr/Lx142RiZgC+XN4SkwSMfNTzzZuGNPY=', 'CAJERO', '981100018', '2026-02-02', 1),
    (19, '78901234', N'Jhon Paul', N'Gamarra Lazo', 'jgamarra@lafavorita.pe', 'jgamarra', 'pbkdf2_sha256$600000$rbczpSpfXTVe1cX0$BcPHc/JHsHOD73I1Z6GlbtTqvC5s+uTqUPMYQy8+tTs=', 'CAJERO', NULL, '2026-10-15', 1),
    (20, '79012345', N'Rosa Angélica', N'Inga Salcedo', 'ringa@lafavorita.pe', 'ringa', 'pbkdf2_sha256$600000$CQrWxzGomQ9ZEaSL$2lZg/FQGcS3aiLiL1I+eNZBA8Yf8h6Mbs9VzcHHIFlQ=', 'CAJERO', '981100020', '2026-09-01', 1);
SET IDENTITY_INSERT Empleado OFF;
GO
 
-- 20 ventas; total = suma de los subtotales de su detalle; id_cliente NULL = venta sin cliente identificado
SET IDENTITY_INSERT Venta ON;
INSERT INTO Venta (id_venta, fecha_venta, id_empleado, id_cliente, tipo_pago, total) VALUES
    (1, '2026-10-01 08:30:00', 3, 1, 'EFECTIVO', 29.10),
    (2, '2026-10-01 09:15:00', 4, 2, 'YAPE', 18.00),
    (3, '2026-10-02 10:05:00', 5, NULL, 'EFECTIVO', 11.00),
    (4, '2026-10-03 11:20:00', 3, 3, 'TARJETA', 44.60),
    (5, '2026-10-04 12:05:00', 6, 4, 'PLIN', 17.50),
    (6, '2026-10-05 13:40:00', 7, NULL, 'YAPE', 19.10),
    (7, '2026-10-06 14:10:00', 4, 5, 'EFECTIVO', 17.30),
    (8, '2026-10-07 15:30:00', 8, 6, 'TARJETA', 86.00),
    (9, '2026-10-08 16:45:00', 9, 7, 'YAPE', 20.50),
    (10, '2026-10-09 09:50:00', 5, 8, 'EFECTIVO', 21.90),
    (11, '2026-10-10 10:30:00', 10, NULL, 'PLIN', 11.80),
    (12, '2026-10-11 18:15:00', 6, 9, 'TARJETA', 45.80),
    (13, '2026-10-12 19:00:00', 11, 10, 'EFECTIVO', 32.60),
    (14, '2026-10-13 08:40:00', 12, 11, 'YAPE', 22.50),
    (15, '2026-10-14 11:55:00', 7, 12, 'EFECTIVO', 17.80),
    (16, '2026-10-15 17:25:00', 13, NULL, 'EFECTIVO', 22.50),
    (17, '2026-10-16 12:35:00', 3, 13, 'TARJETA', 27.70),
    (18, '2026-10-17 20:10:00', 14, 14, 'PLIN', 30.20),
    (19, '2026-10-18 09:05:00', 15, 15, 'YAPE', 18.70),
    (20, '2026-10-18 09:06:00', 15, 15, 'YAPE', 18.70);
SET IDENTITY_INSERT Venta OFF;
GO
 
-- 37 líneas de detalle (cada venta tiene al menos una); subtotal es columna calculada
SET IDENTITY_INSERT Detalle_Venta ON;
INSERT INTO Detalle_Venta (id_detalle, id_venta, id_lote, cantidad, precio_unitario) VALUES
    (1, 1, 1, 1, 21.50),
    (2, 1, 4, 2, 3.80),
    (3, 2, 2, 1, 18.00),
    (4, 3, 13, 4, 1.50),
    (5, 3, 10, 2, 2.50),
    (6, 4, 3, 2, 9.80),
    (7, 4, 5, 3, 4.20),
    (8, 4, 9, 2, 6.20),
    (9, 5, 11, 1, 12.50),
    (10, 5, 12, 2, 2.50),
    (11, 6, 8, 2, 5.60),
    (12, 6, 7, 1, 7.90),
    (13, 7, 17, 1, 10.90),
    (14, 7, 18, 2, 3.20),
    (15, 8, 1, 4, 21.50),
    (16, 9, 14, 3, 4.50),
    (17, 9, 15, 2, 3.50),
    (18, 10, 16, 1, 8.90),
    (19, 10, 6, 2, 6.50),
    (20, 11, 19, 2, 5.90),
    (21, 12, 2, 2, 18.00),
    (22, 12, 3, 1, 9.80),
    (23, 13, 8, 3, 5.60),
    (24, 13, 7, 2, 7.90),
    (25, 14, 14, 3, 4.50),
    (26, 14, 13, 6, 1.50),
    (27, 15, 16, 2, 8.90),
    (28, 16, 12, 6, 2.50),
    (29, 16, 10, 3, 2.50),
    (30, 17, 17, 2, 10.90),
    (31, 17, 19, 1, 5.90),
    (32, 18, 7, 3, 7.90),
    (33, 18, 6, 1, 6.50),
    (34, 19, 11, 1, 12.50),
    (35, 19, 9, 1, 6.20),
    (36, 20, 11, 1, 12.50),
    (37, 20, 9, 1, 6.20);
SET IDENTITY_INSERT Detalle_Venta OFF;
GO
 
-- 20 comprobantes, uno por venta (relación 1:1); facturas con RUC del receptor
SET IDENTITY_INSERT Comprobante ON;
INSERT INTO Comprobante (id_comprobante, id_venta, tipo_comprobante, serie, numero, fecha_emision, ruc_receptor) VALUES
    (1, 1, 'BOLETA', 'B001', 1, '2026-10-01 08:30:00', NULL),
    (2, 2, 'BOLETA', 'B001', 2, '2026-10-01 09:51:00', NULL),
    (3, 3, 'BOLETA', 'B001', 3, '2026-10-02 10:05:00', NULL),
    (4, 4, 'BOLETA', 'B001', 4, '2026-10-03 11:20:00', NULL),
    (5, 5, 'BOLETA', 'B001', 5, '2026-10-04 12:05:00', NULL),
    (6, 6, 'BOLETA', 'B001', 6, '2026-10-05 13:40:00', NULL),
    (7, 7, 'BOLETA', 'B001', 7, '2026-10-06 14:10:00', NULL),
    (8, 8, 'FACTURA', 'F001', 1, '2026-10-07 15:30:00', '20601234561'),
    (9, 9, 'BOLETA', 'B001', 8, '2026-10-08 16:46:00', NULL),
    (10, 10, 'BOLETA', 'B001', 9, '2026-10-09 09:50:00', NULL),
    (11, 11, 'BOLETA', 'B001', 10, '2026-10-10 10:30:00', NULL),
    (12, 12, 'FACTURA', 'F001', 2, '2026-10-11 18:15:00', '10460123451'),
    (13, 13, 'BOLETA', 'B001', 11, '2026-10-12 19:00:00', NULL),
    (14, 14, 'BOLETA', 'B001', 12, '2026-10-13 08:41:00', NULL),
    (15, 15, 'BOLETA', 'B001', 13, '2026-10-14 11:55:00', NULL),
    (16, 16, 'BOLETA', 'B001', 14, '2026-10-15 17:25:00', NULL),
    (17, 17, 'FACTURA', 'F001', 3, '2026-10-16 12:35:00', '20605432107'),
    (18, 18, 'BOLETA', 'B001', 15, '2026-10-17 20:10:00', NULL),
    (19, 19, 'BOLETA', 'B001', 16, '2026-10-18 09:05:00', NULL),
    (20, 20, 'BOLETA', 'B001', 17, '2026-10-18 09:06:00', NULL);
SET IDENTITY_INSERT Comprobante OFF;
GO
GO

/* ##### 04_views.sql ##### */
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
GO

/* ##### 05_subqueries.sql ##### */
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
GO

/* ##### 06_multitable_queries.sql ##### */
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
GO

/* ##### 07_procedures_insert.sql ##### */
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
GO

/* ##### 08_procedures_update.sql ##### */
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
GO

/* ##### 09_procedures_delete.sql ##### */
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
GO

/* ##### 10_procedures_select.sql ##### */
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
GO

/* ##### 11_integrity_tests.sql ##### */
/* ============================================================================
   11_integrity_tests.sql - Proyecto T3 La Favorita: controles de integridad
   Verifica el ESTADO de los datos (solo lectura). Cada control cuenta las
   violaciones de una regla; el resultado esperado es 0. Si alguno falla, el
   script termina con error (THROW 50099) para que CI/CD marque el fallo.
   Se puede ejecutar en cualquier momento sobre la base real.
   ============================================================================ */
USE MinimarketLaFavorita;
GO
SET NOCOUNT ON;

CREATE TABLE #ctl (codigo VARCHAR(4) NOT NULL, regla VARCHAR(8) NOT NULL, descripcion NVARCHAR(150) NOT NULL, violaciones INT NOT NULL);

INSERT #ctl SELECT 'I01', 'RN-04', N'Lotes con stock negativo', COUNT(*) FROM Lote WHERE stock_actual < 0;
INSERT #ctl SELECT 'I02', 'RN-04', N'Lotes con stock mayor que la cantidad recibida', COUNT(*) FROM Lote WHERE stock_actual > cantidad_inicial;
INSERT #ctl SELECT 'I03', 'RN-04', N'Lotes cuyo stock no cuadra con lo recibido menos lo vendido', COUNT(*)
FROM Lote l
WHERE l.stock_actual <> l.cantidad_inicial - ISNULL((SELECT SUM(d.cantidad) FROM Detalle_Venta d WHERE d.id_lote = l.id_lote), 0);
INSERT #ctl SELECT 'I04', 'RN-06', N'Ventas sin líneas de detalle', COUNT(*)
FROM Venta v WHERE NOT EXISTS (SELECT 1 FROM Detalle_Venta d WHERE d.id_venta = v.id_venta);
INSERT #ctl SELECT 'I05', 'RN-09', N'Ventas cuyo total no es la suma de sus subtotales', COUNT(*)
FROM Venta v WHERE v.total <> ISNULL((SELECT SUM(d.subtotal) FROM Detalle_Venta d WHERE d.id_venta = v.id_venta), 0);
INSERT #ctl SELECT 'I06', 'RN-09', N'Líneas cuyo subtotal no es cantidad por precio unitario', COUNT(*)
FROM Detalle_Venta WHERE subtotal <> cantidad * precio_unitario;
INSERT #ctl SELECT 'I07', 'RN-08', N'Ventas sin comprobante', COUNT(*)
FROM Venta v WHERE NOT EXISTS (SELECT 1 FROM Comprobante k WHERE k.id_venta = v.id_venta);
INSERT #ctl SELECT 'I08', 'RN-08', N'Comprobantes sin venta asociada', COUNT(*)
FROM Comprobante k WHERE NOT EXISTS (SELECT 1 FROM Venta v WHERE v.id_venta = k.id_venta);
INSERT #ctl SELECT 'I09', 'RN-08', N'Ventas con más de un comprobante', COUNT(*)
FROM (SELECT id_venta FROM Comprobante GROUP BY id_venta HAVING COUNT(*) > 1) x;
INSERT #ctl SELECT 'I10', 'RN-08', N'Facturas sin RUC o boletas con RUC', COUNT(*)
FROM Comprobante
WHERE (tipo_comprobante = 'FACTURA' AND ruc_receptor IS NULL) OR (tipo_comprobante = 'BOLETA' AND ruc_receptor IS NOT NULL);
INSERT #ctl SELECT 'I11', 'RN-08', N'Series con numeración no correlativa (huecos o repetidos)', COUNT(*)
FROM (SELECT serie FROM Comprobante GROUP BY serie HAVING MAX(numero) <> COUNT(*) OR MIN(numero) <> 1) x;
INSERT #ctl SELECT 'I12', 'RN-08', N'Comprobantes emitidos antes de la fecha de la venta', COUNT(*)
FROM Comprobante k JOIN Venta v ON v.id_venta = k.id_venta WHERE k.fecha_emision < v.fecha_venta;
INSERT #ctl SELECT 'I13', 'FK', N'Referencias huérfanas (detalle, venta, lote, producto)', 
       (SELECT COUNT(*) FROM Detalle_Venta d WHERE NOT EXISTS (SELECT 1 FROM Venta  v WHERE v.id_venta = d.id_venta))
     + (SELECT COUNT(*) FROM Detalle_Venta d WHERE NOT EXISTS (SELECT 1 FROM Lote   l WHERE l.id_lote  = d.id_lote))
     + (SELECT COUNT(*) FROM Venta v WHERE NOT EXISTS (SELECT 1 FROM Empleado e WHERE e.id_empleado = v.id_empleado))
     + (SELECT COUNT(*) FROM Venta v WHERE v.id_cliente IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Cliente c WHERE c.id_cliente = v.id_cliente))
     + (SELECT COUNT(*) FROM Lote  l WHERE NOT EXISTS (SELECT 1 FROM Producto p WHERE p.id_producto = l.id_producto))
     + (SELECT COUNT(*) FROM Producto p WHERE NOT EXISTS (SELECT 1 FROM Categoria c WHERE c.id_categoria = p.id_categoria));
INSERT #ctl SELECT 'I14', 'FK', N'Claves foráneas o restricciones CHECK deshabilitadas / no confiables',
       (SELECT COUNT(*) FROM sys.foreign_keys    WHERE is_disabled = 1 OR is_not_trusted = 1)
     + (SELECT COUNT(*) FROM sys.check_constraints WHERE is_disabled = 1 OR is_not_trusted = 1);

-- DBCC CHECKCONSTRAINTS: devuelve una fila por cada fila que viola alguna restricción
CREATE TABLE #dbcc ([Table] NVARCHAR(256), [Constraint] NVARCHAR(256), [Where] NVARCHAR(MAX));
INSERT #dbcc EXEC (N'DBCC CHECKCONSTRAINTS WITH ALL_CONSTRAINTS, NO_INFOMSGS');
INSERT #ctl SELECT 'I15', 'FK/CK', N'Filas que violan alguna restricción (DBCC CHECKCONSTRAINTS)', COUNT(*) FROM #dbcc;

INSERT #ctl SELECT 'I16', 'T2-I6', N'Ventas a clientes registrados después de la fecha de venta', COUNT(*)
FROM Venta v JOIN Cliente c ON c.id_cliente = v.id_cliente WHERE c.fecha_registro > CAST(v.fecha_venta AS DATE);
INSERT #ctl SELECT 'I17', 'RN-10', N'Ventas registradas por empleados inexistentes', COUNT(*)
FROM Venta v WHERE NOT EXISTS (SELECT 1 FROM Empleado e WHERE e.id_empleado = v.id_empleado);

SELECT codigo, regla, descripcion, violaciones,
       CASE WHEN violaciones = 0 THEN 'OK' ELSE 'FALLA' END AS estado
FROM   #ctl ORDER BY codigo;

DECLARE @fallas INT = (SELECT COUNT(*) FROM #ctl WHERE violaciones > 0);
DROP TABLE #dbcc; DROP TABLE #ctl;
IF @fallas > 0 THROW 50099, N'Se detectaron violaciones de integridad en los datos.', 1;
PRINT N'Integridad verificada: 17 controles, 0 violaciones.';
GO
GO
