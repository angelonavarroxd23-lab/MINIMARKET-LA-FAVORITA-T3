// Registro de los 26 procedimientos almacenados: nombre, grupo, descripción y parámetros.
// t: int | nvarchar | varchar | char | dec | date | bit ; n: longitud ; req: obligatorio ; out: parámetro OUTPUT
const P = (name, t, o = {}) => ({ name, t, ...o });
module.exports = [
  // ---- INSERTAR
  { id: "PI01", nombre: "usp_Categoria_Insertar", grupo: "Insertar", desc: "Registra una categoría.", params: [P("nombre","nvarchar",{n:50,req:1}), P("tipo","varchar",{n:10,req:1,ayuda:"ALIMENTO, BEBIDA, LIMPIEZA u OTROS"}), P("descripcion","nvarchar",{n:150}), P("id_categoria","int",{out:1})] },
  { id: "PI02", nombre: "usp_Producto_Insertar", grupo: "Insertar", desc: "Registra un producto.", params: [P("codigo_barras","varchar",{n:13,req:1}), P("nombre","nvarchar",{n:100,req:1}), P("descripcion","nvarchar",{n:200}), P("precio_venta","dec",{req:1}), P("stock_minimo","int"), P("estado","varchar",{n:8,ayuda:"ACTIVO o INACTIVO"}), P("id_categoria","int",{req:1}), P("id_producto","int",{out:1})] },
  { id: "PI03", nombre: "usp_Lote_Insertar", grupo: "Insertar", desc: "Registra el ingreso de un lote.", params: [P("id_producto","int",{req:1}), P("numero_lote","varchar",{n:30,req:1}), P("fecha_ingreso","date"), P("fecha_vencimiento","date"), P("cantidad_inicial","int",{req:1}), P("costo_unitario","dec",{req:1}), P("id_lote","int",{out:1})] },
  { id: "PI04", nombre: "usp_Cliente_Insertar", grupo: "Insertar", desc: "Registra un cliente.", params: [P("dni","char",{n:8,req:1}), P("nombres","nvarchar",{n:50,req:1}), P("apellidos","nvarchar",{n:50,req:1}), P("telefono","char",{n:9,ayuda:"9 dígitos, empieza con 9"}), P("direccion","nvarchar",{n:150}), P("distrito","nvarchar",{n:40,req:1}), P("id_cliente","int",{out:1})] },
  { id: "PI05", nombre: "usp_Empleado_Insertar", grupo: "Insertar", desc: "Registra un empleado (la clave debe venir ya con hash pbkdf2_sha256$...).", params: [P("dni","char",{n:8,req:1}), P("nombres","nvarchar",{n:50,req:1}), P("apellidos","nvarchar",{n:50,req:1}), P("correo","varchar",{n:100,req:1}), P("usuario","varchar",{n:30,req:1}), P("clave_hash","varchar",{n:255,req:1,ayuda:"Debe empezar con pbkdf2_sha256$"}), P("rol","varchar",{n:10,req:1,ayuda:"CAJERO, ADMIN o SUPERADMIN"}), P("telefono","char",{n:9}), P("fecha_ingreso","date"), P("id_empleado","int",{out:1})] },
  { id: "PI06", nombre: "usp_Venta_Registrar", grupo: "Insertar", desc: "Registra una venta completa. Úsalo desde la pestaña «Punto de venta» (recibe las líneas en un parámetro tipo tabla).", especial: "pos", params: [] },
  { id: "PI07", nombre: "usp_DetalleVenta_Agregar", grupo: "Insertar", desc: "Agrega una línea a una venta existente y descuenta stock.", params: [P("id_venta","int",{req:1}), P("id_lote","int",{req:1}), P("cantidad","int",{req:1}), P("id_detalle","int",{out:1})] },
  { id: "PI08", nombre: "usp_Comprobante_Emitir", grupo: "Insertar", desc: "Emite el comprobante de una venta.", params: [P("id_venta","int",{req:1}), P("tipo_comprobante","varchar",{n:7,req:1,ayuda:"BOLETA o FACTURA"}), P("ruc_receptor","char",{n:11,ayuda:"Obligatorio en FACTURA"}), P("id_comprobante","int",{out:1})] },
  // ---- MODIFICAR
  { id: "PU01", nombre: "usp_Producto_ActualizarPrecio", grupo: "Modificar", desc: "Cambia el precio de venta (no puede quedar bajo el costo).", params: [P("id_producto","int",{req:1}), P("precio_nuevo","dec",{req:1})] },
  { id: "PU02", nombre: "usp_Producto_CambiarEstado", grupo: "Modificar", desc: "Activa o desactiva un producto.", params: [P("id_producto","int",{req:1}), P("estado","varchar",{n:8,req:1,ayuda:"ACTIVO o INACTIVO"})] },
  { id: "PU03", nombre: "usp_Cliente_ActualizarContacto", grupo: "Modificar", desc: "Actualiza teléfono, dirección o distrito.", params: [P("id_cliente","int",{req:1}), P("telefono","char",{n:9}), P("direccion","nvarchar",{n:150}), P("distrito","nvarchar",{n:40})] },
  { id: "PU04", nombre: "usp_Empleado_CambiarEstado", grupo: "Modificar", desc: "Activa o desactiva un empleado.", params: [P("id_empleado","int",{req:1}), P("activo","bit",{req:1,ayuda:"1 = activo, 0 = inactivo"})] },
  { id: "PU05", nombre: "usp_Lote_AjustarStock", grupo: "Modificar", desc: "Ajusta el stock de un lote (positivo o negativo) con motivo.", params: [P("id_lote","int",{req:1}), P("ajuste","int",{req:1}), P("motivo","nvarchar",{n:100,req:1})] },
  { id: "PU06", nombre: "usp_Venta_CambiarMedioPago", grupo: "Modificar", desc: "Corrige el medio de pago de una venta.", params: [P("id_venta","int",{req:1}), P("tipo_pago","varchar",{n:8,req:1,ayuda:"EFECTIVO, YAPE, PLIN o TARJETA"})] },
  // ---- ELIMINAR
  { id: "PD01", nombre: "usp_Cliente_Eliminar", grupo: "Eliminar", desc: "Elimina un cliente sin ventas.", params: [P("id_cliente","int",{req:1})] },
  { id: "PD02", nombre: "usp_Venta_Anular", grupo: "Eliminar", desc: "Anula una venta y devuelve el stock (solo ADMIN o SUPERADMIN).", params: [P("id_venta","int",{req:1}), P("id_empleado_autoriza","int",{req:1})] },
  // ---- CONSULTAR
  { id: "PS01", nombre: "usp_Producto_Buscar", grupo: "Consultar", desc: "Busca productos por texto y categoría.", params: [P("texto","nvarchar",{n:100}), P("id_categoria","int"), P("solo_activos","bit",{ayuda:"1 por defecto"})] },
  { id: "PS02", nombre: "usp_Stock_Consultar", grupo: "Consultar", desc: "Stock por producto.", params: [P("id_producto","int")] },
  { id: "PS03", nombre: "usp_Productos_StockBajo", grupo: "Consultar", desc: "Productos por debajo del stock mínimo.", params: [P("id_categoria","int")] },
  { id: "PS04", nombre: "usp_Lotes_PorVencer", grupo: "Consultar", desc: "Lotes que vencen en los próximos N días.", params: [P("dias","int",{ayuda:"30 por defecto"})] },
  { id: "PS05", nombre: "usp_Cliente_BuscarPorDni", grupo: "Consultar", desc: "Busca un cliente por DNI.", params: [P("dni","char",{n:8,req:1})] },
  { id: "PS06", nombre: "usp_Venta_Detalle", grupo: "Consultar", desc: "Cabecera y líneas de una venta.", params: [P("id_venta","int",{req:1})] },
  { id: "PS07", nombre: "usp_Ventas_PorRango", grupo: "Consultar", desc: "Ventas entre dos fechas.", params: [P("desde","date",{req:1}), P("hasta","date",{req:1}), P("id_empleado","int")] },
  { id: "PS08", nombre: "usp_Comprobante_Consultar", grupo: "Consultar", desc: "Busca un comprobante por serie y número.", params: [P("serie","char",{n:4,req:1,ayuda:"B001 o F001"}), P("numero","int",{req:1})] },
  { id: "PS09", nombre: "usp_Productos_MasVendidos", grupo: "Consultar", desc: "Ranking de productos más vendidos.", params: [P("top","int",{ayuda:"5 por defecto"}), P("desde","date"), P("hasta","date")] },
  { id: "PS10", nombre: "usp_Cliente_HistorialCompras", grupo: "Consultar", desc: "Historial de compras de un cliente.", params: [P("id_cliente","int",{req:1})] }
];
