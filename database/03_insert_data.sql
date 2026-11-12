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
 
 
