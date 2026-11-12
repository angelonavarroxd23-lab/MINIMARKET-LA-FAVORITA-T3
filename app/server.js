// API de la interfaz web. Solo expone operaciones del proyecto: procedimientos del registro, vistas y consultas
// de la lista blanca (data/explorer.json). No acepta SQL arbitrario.
const express = require("express");
const sql = require("mssql");
const path = require("path");
const PROCS = require("./procs");
const EXPL = require("./data/explorer.json");

const cfg = {
  server: process.env.DB_SERVER || "localhost",
  port: parseInt(process.env.DB_PORT || "1433", 10),
  database: process.env.DB_NAME || "MinimarketLaFavorita",
  user: process.env.DB_USER || "sa",
  password: process.env.DB_PASSWORD,
  options: { encrypt: true, trustServerCertificate: true, enableArithAbort: true },
  pool: { max: 10, min: 0, idleTimeoutMillis: 30000 },
  requestTimeout: 30000
};
if (!cfg.password) { console.error("Falta la variable de entorno DB_PASSWORD."); process.exit(1); }

let poolPromise;
function pool() {
  if (!poolPromise) poolPromise = new sql.ConnectionPool(cfg).connect().catch(e => { poolPromise = null; throw e; });
  return poolPromise;
}
const TYPES = { int: () => sql.Int, nvarchar: n => sql.NVarChar(n || 200), varchar: n => sql.VarChar(n || 200), char: n => sql.Char(n || 1), dec: () => sql.Decimal(10, 2), date: () => sql.Date, bit: () => sql.Bit };
const MAXROWS = 500;

const app = express();
app.use(express.json({ limit: "100kb" }));
app.use(express.static(path.join(__dirname, "public")));

const wrap = fn => async (req, res) => {
  try { res.json(await fn(req)); }
  catch (e) {
    const user = e.number && e.number >= 50000 && e.number < 51000;
    const code = e.number || null;
    const status = e.status || (e.number ? 400 : 500);
    if (status === 500) console.error(e);
    res.status(status).json({ error: e.message, codigo: code, regla: user ? "Regla de negocio del procedimiento" : (e.number ? "Restricción de SQL Server" : null) });
  }
};
const clip = sets => sets.map(r => r.slice(0, MAXROWS));
const bad = msg => Object.assign(new Error(msg), { status: 400 });

async function runProc(def, body) {
  const rq = (await pool()).request();
  const outs = [];
  for (const p of def.params) {
    const type = TYPES[p.t](p.n);
    if (p.out) { rq.output(p.name, type); outs.push(p.name); continue; }
    let v = body[p.name];
    if (v === undefined || v === null || v === "") {
      if (p.req) throw bad(`Falta el parámetro obligatorio «${p.name}».`);
      continue; // se usa el valor por defecto del procedimiento
    }
    if (p.t === "int" || p.t === "bit") { v = Number(v); if (!Number.isFinite(v)) throw bad(`«${p.name}» debe ser numérico.`); }
    if (p.t === "dec") { v = Number(v); if (!Number.isFinite(v)) throw bad(`«${p.name}» debe ser numérico.`); }
    if (p.t === "bit") v = v ? 1 : 0;
    rq.input(p.name, type, v);
  }
  const r = await rq.execute("dbo." + def.nombre);
  return { conjuntos: clip(r.recordsets || []), salida: r.output || {}, filasAfectadas: r.rowsAffected };
}

app.get("/api/salud", wrap(async () => { const r = await (await pool()).request().query("SELECT DB_NAME() AS base, @@VERSION AS version"); return { ok: true, ...r.recordset[0] }; }));
app.get("/api/procedimientos", (req, res) => res.json(PROCS));
app.get("/api/procedimientos/:nombre", (req, res, next) => next());
app.post("/api/procedimientos/:nombre", wrap(async req => {
  const def = PROCS.find(p => p.nombre === req.params.nombre);
  if (!def) throw Object.assign(new Error("Procedimiento no encontrado."), { status: 404 });
  if (def.especial) throw bad("Este procedimiento se usa desde la pestaña «Punto de venta».");
  return runProc(def, req.body || {});
}));

app.get("/api/explorador", (req, res) => res.json({
  vistas: EXPL.vistas.map(({ id, titulo, enunciado, objetivo, explicacion, codigo, vista }) => ({ id, titulo, enunciado, objetivo, explicacion, codigo, vista })),
  consultas: EXPL.consultas.map(({ id, titulo, enunciado, objetivo, explicacion, codigo }) => ({ id, titulo, enunciado, objetivo, explicacion, codigo }))
}));
app.get("/api/vistas/:vista", wrap(async req => {
  const v = EXPL.vistas.find(x => x.vista === req.params.vista);
  if (!v) throw Object.assign(new Error("Vista no encontrada."), { status: 404 });
  const r = await (await pool()).request().query(`SELECT TOP (${MAXROWS}) * FROM dbo.${v.vista}`);
  return { filas: r.recordset };
}));
app.get("/api/consultas/:id", wrap(async req => {
  const q = EXPL.consultas.find(x => x.id === req.params.id);
  if (!q) throw Object.assign(new Error("Consulta no encontrada."), { status: 404 });
  const r = await (await pool()).request().query(q.sql);
  return { filas: r.recordset.slice(0, MAXROWS), total: r.recordset.length };
}));

// ---- Punto de venta
app.get("/api/pos/catalogo", wrap(async () => {
  const p = await pool();
  const lotes = await p.request().query(`SELECT l.id_lote, p.nombre AS producto, p.codigo_barras, p.precio_venta, l.numero_lote, l.stock_actual, l.fecha_vencimiento
    FROM dbo.Lote l JOIN dbo.Producto p ON p.id_producto = l.id_producto
    WHERE p.estado = 'ACTIVO' AND l.stock_actual > 0 AND (l.fecha_vencimiento IS NULL OR l.fecha_vencimiento >= CAST(SYSDATETIME() AS DATE))
    ORDER BY p.nombre, l.fecha_vencimiento`);
  const emp = await p.request().query(`SELECT id_empleado, nombres + N' ' + apellidos AS nombre, rol FROM dbo.Empleado WHERE activo = 1 ORDER BY id_empleado`);
  return { lotes: lotes.recordset, empleados: emp.recordset };
}));
app.post("/api/pos/venta", wrap(async req => {
  const b = req.body || {};
  if (!Array.isArray(b.lineas) || b.lineas.length === 0) throw bad("Agrega al menos un producto.");
  if (b.lineas.length > 100) throw bad("Demasiadas líneas.");
  const tvp = new sql.Table("dbo.tvp_LineaVenta");
  tvp.columns.add("id_lote", sql.Int); tvp.columns.add("cantidad", sql.Int);
  for (const l of b.lineas) {
    const idl = Number(l.id_lote), c = Number(l.cantidad);
    if (!Number.isInteger(idl) || !Number.isInteger(c)) throw bad("Línea inválida.");
    tvp.rows.add(idl, c);
  }
  const rq = (await pool()).request();
  rq.input("id_empleado", sql.Int, Number(b.id_empleado));
  if (b.id_cliente) rq.input("id_cliente", sql.Int, Number(b.id_cliente));
  rq.input("tipo_pago", sql.VarChar(8), b.tipo_pago);
  rq.input("lineas", tvp);
  if (b.tipo_comprobante) rq.input("tipo_comprobante", sql.VarChar(7), b.tipo_comprobante);
  if (b.ruc_receptor) rq.input("ruc_receptor", sql.Char(11), b.ruc_receptor);
  rq.output("id_venta", sql.Int);
  const r = await rq.execute("dbo.usp_Venta_Registrar");
  const id = r.output.id_venta;
  const d = await (await pool()).request().input("id_venta", sql.Int, id).execute("dbo.usp_Venta_Detalle");
  return { id_venta: id, conjuntos: clip(d.recordsets || []) };
}));

// ---- Panel
app.get("/api/panel", wrap(async () => {
  const p = await pool();
  const kpi = await p.request().query(`SELECT
      (SELECT COUNT(*) FROM dbo.Venta) AS ventas,
      (SELECT ISNULL(SUM(total), 0) FROM dbo.Venta) AS monto_total,
      (SELECT COUNT(*) FROM dbo.Producto WHERE estado = 'ACTIVO') AS productos_activos,
      (SELECT COUNT(*) FROM dbo.vw_stock_producto WHERE situacion_stock <> 'NORMAL') AS productos_a_reponer,
      (SELECT COUNT(*) FROM dbo.Cliente) AS clientes,
      (SELECT COUNT(*) FROM dbo.Lote WHERE stock_actual > 0 AND fecha_vencimiento IS NOT NULL AND fecha_vencimiento <= DATEADD(DAY, 30, CAST(SYSDATETIME() AS DATE))) AS lotes_por_vencer_30d`);
  const top = await p.request().input("top", sql.Int, 5).execute("dbo.usp_Productos_MasVendidos");
  const pago = await p.request().query("SELECT * FROM dbo.vw_ventas_medio_pago");
  const bajo = await p.request().execute("dbo.usp_Productos_StockBajo");
  return { kpi: kpi.recordset[0], top: top.recordset, pagos: pago.recordset, stock_bajo: bajo.recordset };
}));

const port = parseInt(process.env.PORT || "3000", 10);
app.listen(port, "0.0.0.0", () => console.log(`La Favorita web escuchando en el puerto ${port}`));
