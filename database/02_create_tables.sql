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
 
 
