// Prueba de humo de la interfaz web: ejercita la API real contra SQL Server (Node 18+).
// Uso: node tests/web_smoke.js [http://localhost:3000]
const base = process.argv[2] || "http://localhost:3000";
let pass = 0, fail = 0;
const rows = [];
async function call(path, body) {
  const r = await fetch(base + path, body === undefined ? {} : { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body) });
  let j = null; try { j = await r.json(); } catch { }
  return { status: r.status, j };
}
function check(id, desc, cond, detalle = "") {
  if (cond) pass++; else fail++;
  rows.push(`${cond ? "PASS" : "FAIL"}\t${id}\t${desc}${cond ? "" : "\t" + detalle}`);
}
(async () => {
  let r = await call("/api/salud");
  check("W-01", "La API se conecta a MinimarketLaFavorita", r.status === 200 && r.j.base === "MinimarketLaFavorita");
  const ex = (await call("/api/explorador")).j;
  check("W-02", "Explorador: 15 vistas y 35 consultas", ex.vistas.length === 15 && ex.consultas.length === 35);
  for (const v of ex.vistas) { r = await call("/api/vistas/" + v.vista); check("W-V" + v.id, `Vista ${v.vista} responde con filas`, r.status === 200 && Array.isArray(r.j.filas) && r.j.filas.length > 0, JSON.stringify(r.j).slice(0, 200)); }
  for (const q of ex.consultas) { r = await call("/api/consultas/" + q.id); check("W-Q" + q.id, `Consulta ${q.id} ejecuta sin error`, r.status === 200 && Array.isArray(r.j.filas), JSON.stringify(r.j).slice(0, 200)); }
  r = await call("/api/panel");
  const ventas0 = r.j.kpi?.ventas;
  check("W-03", "Panel: 20 ventas iniciales y KPIs", r.status === 200 && ventas0 === 20 && r.j.kpi.clientes === 20, JSON.stringify(r.j.kpi));
  const sel = { PS01: {}, PS02: {}, PS03: {}, PS04: { dias: 30 }, PS05: { dni: "10234567" }, PS06: { id_venta: 1 }, PS07: { desde: "2026-09-01", hasta: "2026-12-31" }, PS08: { serie: "B001", numero: 1 }, PS09: {}, PS10: { id_cliente: 1 } };
  const defs = (await call("/api/procedimientos")).j;
  check("W-04", "Registro de 26 procedimientos", defs.length === 26);
  for (const [id, p] of Object.entries(sel)) { const d = defs.find(x => x.id === id); r = await call("/api/procedimientos/" + d.nombre, p); check("W-" + id, `${d.nombre} responde`, r.status === 200 && Array.isArray(r.j.conjuntos), JSON.stringify(r.j).slice(0, 200)); }
  // errores esperados (reglas de negocio y restricciones)
  r = await call("/api/procedimientos/usp_Cliente_Insertar", { dni: "10234567", nombres: "Prueba", apellidos: "Web", distrito: "Comas" });
  check("W-E1", "DNI duplicado -> error 50002", r.status === 400 && r.j.codigo === 50002, JSON.stringify(r.j));
  r = await call("/api/procedimientos/usp_Producto_ActualizarPrecio", { id_producto: 999999, precio_nuevo: 5 });
  check("W-E2", "Producto inexistente -> error 50001", r.status === 400 && r.j.codigo === 50001, JSON.stringify(r.j));
  r = await call("/api/procedimientos/usp_Cliente_Eliminar", { id_cliente: 1 });
  check("W-E3", "Cliente con ventas no se elimina -> error 50006", r.status === 400 && r.j.codigo === 50006, JSON.stringify(r.j));
  r = await call("/api/procedimientos/usp_Cliente_BuscarPorDni", {});
  check("W-E4", "Falta parámetro obligatorio -> 400", r.status === 400, JSON.stringify(r.j));
  r = await call("/api/procedimientos/usp_Venta_Registrar", {});
  check("W-E5", "usp_Venta_Registrar solo desde el punto de venta -> 400", r.status === 400);
  r = await call("/api/procedimientos/no_existe", {});
  check("W-E6", "Procedimiento fuera del registro -> 404", r.status === 404);
  r = await call("/api/vistas/Cliente");
  check("W-E7", "Solo vistas de la lista blanca (Cliente -> 404)", r.status === 404);
  // venta real por el punto de venta
  const cat = (await call("/api/pos/catalogo")).j;
  const cajero = cat.empleados.find(e => e.rol === "CAJERO"), admin = cat.empleados.find(e => e.rol !== "CAJERO");
  const lote = cat.lotes.find(l => l.stock_actual >= 3);
  check("W-05", "Catálogo del punto de venta con lotes y empleados", cat.lotes.length > 0 && !!cajero && !!admin);
  r = await call("/api/pos/venta", { id_empleado: cajero.id_empleado, tipo_pago: "EFECTIVO", tipo_comprobante: "BOLETA", lineas: [{ id_lote: lote.id_lote, cantidad: 2 }] });
  check("W-06", "Venta registrada con comprobante (TVP)", r.status === 200 && r.j.id_venta > 0 && r.j.conjuntos.length >= 1, JSON.stringify(r.j).slice(0, 300));
  const idv = r.j.id_venta;
  const esperado = Number((lote.precio_venta * 2).toFixed(2));
  const tot = r.j.conjuntos[0]?.[0]?.total;
  check("W-07", "El total calculado por la base es precio × cantidad", Number(tot) === esperado, `total=${tot} esperado=${esperado}`);
  const cat2 = (await call("/api/pos/catalogo")).j;
  check("W-08", "El stock del lote bajó en 2", cat2.lotes.find(l => l.id_lote === lote.id_lote).stock_actual === lote.stock_actual - 2);
  r = await call("/api/pos/venta", { id_empleado: cajero.id_empleado, tipo_pago: "EFECTIVO", lineas: [{ id_lote: lote.id_lote, cantidad: 999999 }] });
  check("W-E8", "Vender más que el stock -> error 50004", r.status === 400 && r.j.codigo === 50004, JSON.stringify(r.j));
  r = await call("/api/pos/venta", { id_empleado: cajero.id_empleado, tipo_pago: "EFECTIVO", lineas: [] });
  check("W-E9", "Venta sin líneas -> 400", r.status === 400);
  r = await call("/api/procedimientos/usp_Venta_Anular", { id_venta: idv, id_empleado_autoriza: cajero.id_empleado });
  check("W-E10", "Un cajero no puede anular -> error 50010", r.status === 400 && r.j.codigo === 50010, JSON.stringify(r.j));
  r = await call("/api/procedimientos/usp_Venta_Anular", { id_venta: idv, id_empleado_autoriza: admin.id_empleado });
  check("W-09", "Anulación por ADMIN", r.status === 200, JSON.stringify(r.j));
  const cat3 = (await call("/api/pos/catalogo")).j;
  check("W-10", "Stock restituido tras anular", cat3.lotes.find(l => l.id_lote === lote.id_lote).stock_actual === lote.stock_actual);
  r = await call("/api/panel");
  check("W-11", "Panel vuelve a 20 ventas (base íntegra)", r.j.kpi.ventas === ventas0, JSON.stringify(r.j.kpi));
  console.log("estado\tid\tprueba\n" + rows.join("\n"));
  console.log(`\npruebas web: ${pass + fail}, aprobadas: ${pass}, fallidas: ${fail}`);
  process.exit(fail ? 1 : 0);
})().catch(e => { console.error("Error de ejecución:", e); process.exit(2); });
