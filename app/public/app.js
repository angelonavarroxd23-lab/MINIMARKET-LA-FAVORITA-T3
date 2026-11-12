"use strict";
const $ = (s, r = document) => r.querySelector(s);
const esc = s => String(s ?? "").replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
const hoy = () => new Date().toISOString().slice(0, 10);

async function api(path, body) {
  const r = await fetch(path, body === undefined ? {} : { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body) });
  let j = null; try { j = await r.json(); } catch { /* sin cuerpo */ }
  if (!r.ok) { const e = new Error(j?.error || r.statusText); e.codigo = j?.codigo; e.regla = j?.regla; throw e; }
  return j;
}
const proc = (nombre, body = {}) => api("/api/procedimientos/" + nombre, body);
function toast(t) { const e = $("#toast"); e.textContent = t; e.classList.add("on"); setTimeout(() => e.classList.remove("on"), 2600); }
function fmtVal(v) {
  if (v === null || v === undefined) return "";
  if (typeof v === "string" && /^\d{4}-\d\d-\d\dT/.test(v)) return v.endsWith("T00:00:00.000Z") ? v.slice(0, 10) : v.replace("T", " ").replace(/\.\d+Z$/, "");
  return String(v);
}
function tabla(rows) {
  if (!rows || !rows.length) return '<p class="mut">Sin filas.</p>';
  const cols = Object.keys(rows[0]);
  return '<div class="tw"><table><thead><tr>' + cols.map(c => `<th>${esc(c)}</th>`).join("") + "</tr></thead><tbody>" +
    rows.map(r => "<tr>" + cols.map(c => `<td class="${typeof r[c] === "number" ? "n" : ""}">${esc(fmtVal(r[c]))}</td>`).join("") + "</tr>").join("") + "</tbody></table></div>" +
    `<p class="mut">${rows.length} fila(s)</p>`;
}
function conjuntos(sets) { return (sets || []).map((s, i) => (sets.length > 1 ? `<h3>Resultado ${i + 1}</h3>` : "") + tabla(s)).join(""); }
const ok = t => `<div class="msg ok">${esc(t)}</div>`;
const err = e => `<div class="msg err"><b>${e.codigo ? "Error " + esc(e.codigo) + ": " : ""}</b>${esc(e.message)}${e.regla ? ` <span class="pill">${esc(e.regla)}</span>` : ""}</div>`;
async function guard(box, fn, btn) {
  if (btn) btn.disabled = true;
  try { await fn(); } catch (e) { box.innerHTML = err(e); } finally { if (btn) btn.disabled = false; }
}

// ---------------------------------------------------------------- pestañas
const loaders = {};
function show(tab) {
  document.querySelectorAll("#tabs button").forEach(b => b.classList.toggle("on", b.dataset.tab === tab));
  document.querySelectorAll("main > section").forEach(s => s.hidden = s.id !== "tab-" + tab);
  if (loaders[tab]) loaders[tab]();
}
$("#tabs").addEventListener("click", e => { const b = e.target.closest("button"); if (b) show(b.dataset.tab); });

// ---------------------------------------------------------------- Panel
loaders.panel = async () => {
  const box = $("#tab-panel"); box.innerHTML = '<p class="mut">Cargando…</p>';
  try {
    const d = await api("/api/panel"), k = d.kpi;
    const kp = (v, t) => `<div class="card kpi"><b>${esc(v)}</b><span>${t}</span></div>`;
    box.innerHTML = `<div class="grid kpis">${kp(k.ventas, "ventas registradas")}${kp("S/ " + Number(k.monto_total).toFixed(2), "monto vendido")}${kp(k.productos_activos, "productos activos")}${kp(k.productos_a_reponer, "productos a reponer")}${kp(k.clientes, "clientes")}${kp(k.lotes_por_vencer_30d, "lotes por vencer (30 días)")}</div>
    <div class="grid two"><div class="card"><h2>Productos más vendidos</h2>${tabla(d.top)}</div><div class="card"><h2>Ventas por medio de pago</h2>${tabla(d.pagos)}</div></div>
    <div class="card"><h2>Productos por debajo del stock mínimo</h2>${tabla(d.stock_bajo)}</div>`;
  } catch (e) { box.innerHTML = err(e); }
};

// ---------------------------------------------------------------- Punto de venta
let cart = [], catalogo = null, clienteSel = null;
loaders.pos = async () => {
  const box = $("#tab-pos");
  try { catalogo = await api("/api/pos/catalogo"); } catch (e) { box.innerHTML = err(e); return; }
  box.innerHTML = `<div class="grid two">
   <div class="card"><h2>Productos disponibles</h2>
     <label>Buscar<input id="pos-q" placeholder="nombre o código de barras"></label>
     <div class="tw" style="max-height:420px"><table><thead><tr><th>Producto</th><th>Lote</th><th>Stock</th><th>Vence</th><th>Precio</th><th></th></tr></thead><tbody id="pos-lotes"></tbody></table></div></div>
   <div class="card"><h2>Venta</h2>
     <div class="row"><label>Cajero<select id="pos-emp"></select></label>
       <label>Medio de pago<select id="pos-pago"><option>EFECTIVO</option><option>YAPE</option><option>PLIN</option><option>TARJETA</option></select></label></div>
     <div class="row" style="margin-top:8px"><label>DNI del cliente (opcional)<input id="pos-dni" maxlength="8" placeholder="8 dígitos"></label><button class="btn sec" id="pos-bdni">Buscar</button><span id="pos-cli" class="mut"></span></div>
     <div class="row" style="margin-top:8px"><label>Comprobante<select id="pos-comp"><option value="">Sin comprobante</option><option>BOLETA</option><option>FACTURA</option></select></label>
       <label>RUC (solo factura)<input id="pos-ruc" maxlength="11"></label></div>
     <div id="pos-cart"></div>
     <div class="row" style="margin-top:10px"><button class="btn" id="pos-ok">Registrar venta</button><button class="btn sec" id="pos-clear">Vaciar</button></div>
     <div id="pos-res"></div></div></div>`;
  $("#pos-emp").innerHTML = catalogo.empleados.map(e => `<option value="${e.id_empleado}">${esc(e.nombre)} (${esc(e.rol)})</option>`).join("");
  const pintar = () => {
    const q = $("#pos-q").value.trim().toLowerCase();
    $("#pos-lotes").innerHTML = catalogo.lotes.filter(l => !q || l.producto.toLowerCase().includes(q) || l.codigo_barras.includes(q)).map(l =>
      `<tr><td>${esc(l.producto)}</td><td>${esc(l.numero_lote)}</td><td class="n">${l.stock_actual}</td><td>${esc(fmtVal(l.fecha_vencimiento))}</td><td class="n">${Number(l.precio_venta).toFixed(2)}</td><td><button class="btn sec" data-add="${l.id_lote}">+</button></td></tr>`).join("");
  };
  const carrito = () => {
    let tot = 0;
    const filas = cart.map((c, i) => { const l = catalogo.lotes.find(x => x.id_lote === c.id_lote); const sub = l.precio_venta * c.cantidad; tot += sub;
      return `<tr><td>${esc(l.producto)}</td><td><input type="number" min="1" value="${c.cantidad}" data-qty="${i}" style="width:70px"></td><td class="n">${sub.toFixed(2)}</td><td><button class="btn sec" data-del="${i}">×</button></td></tr>`; }).join("");
    $("#pos-cart").innerHTML = cart.length ? `<div class="tw"><table><thead><tr><th>Producto</th><th>Cant.</th><th>Subtotal</th><th></th></tr></thead><tbody>${filas}</tbody></table></div><p><b>Total: S/ ${tot.toFixed(2)}</b></p>` : '<p class="mut">El carrito está vacío.</p>';
  };
  pintar(); carrito();
  $("#pos-q").oninput = pintar;
  $("#pos-lotes").onclick = e => { const b = e.target.closest("[data-add]"); if (!b) return; const id = +b.dataset.add; const x = cart.find(c => c.id_lote === id); x ? x.cantidad++ : cart.push({ id_lote: id, cantidad: 1 }); carrito(); };
  $("#pos-cart").onclick = e => { const b = e.target.closest("[data-del]"); if (b) { cart.splice(+b.dataset.del, 1); carrito(); } };
  $("#pos-cart").onchange = e => { const i = e.target.dataset.qty; if (i !== undefined) { cart[i].cantidad = Math.max(1, parseInt(e.target.value, 10) || 1); carrito(); } };
  $("#pos-clear").onclick = () => { cart = []; carrito(); $("#pos-res").innerHTML = ""; };
  $("#pos-bdni").onclick = () => guard($("#pos-res"), async () => {
    clienteSel = null; $("#pos-cli").textContent = "";
    const r = await proc("usp_Cliente_BuscarPorDni", { dni: $("#pos-dni").value.trim() });
    const f = r.conjuntos[0]?.[0];
    if (f) { clienteSel = f.id_cliente; $("#pos-cli").textContent = `${f.nombres} ${f.apellidos} (id ${f.id_cliente})`; $("#pos-res").innerHTML = ""; } else $("#pos-cli").textContent = "No existe un cliente con ese DNI.";
  });
  $("#pos-ok").onclick = ev => guard($("#pos-res"), async () => {
    const dni = $("#pos-dni").value.trim();
    if (dni && !clienteSel) throw new Error("Busca el DNI primero o déjalo vacío.");
    const r = await api("/api/pos/venta", { id_empleado: +$("#pos-emp").value, id_cliente: clienteSel, tipo_pago: $("#pos-pago").value, tipo_comprobante: $("#pos-comp").value || null, ruc_receptor: $("#pos-ruc").value.trim() || null, lineas: cart });
    $("#pos-res").innerHTML = ok(`Venta ${r.id_venta} registrada. El stock se descontó y el total se calculó en la base de datos.`) + conjuntos(r.conjuntos);
    cart = []; clienteSel = null; catalogo = await api("/api/pos/catalogo"); pintar(); carrito(); toast("Venta registrada");
  }, ev.target);
};

// ---------------------------------------------------------------- Ventas
loaders.ventas = async () => {
  const box = $("#tab-ventas");
  if (!box.dataset.init) {
    box.dataset.init = 1;
    box.innerHTML = `<div class="card"><h2>Ventas por rango de fechas</h2><div class="row"><label>Desde<input type="date" id="v-d" value="2026-09-01"></label><label>Hasta<input type="date" id="v-h" value="${hoy()}"></label><button class="btn" id="v-b">Consultar</button></div><div id="v-lista"></div></div><div class="card" id="v-det" hidden></div>`;
    $("#v-b").onclick = () => guard($("#v-lista"), async () => {
      const r = await proc("usp_Ventas_PorRango", { desde: $("#v-d").value, hasta: $("#v-h").value });
      const rows = r.conjuntos[0] || [];
      $("#v-lista").innerHTML = tabla(rows) + (rows.length ? '<p class="mut">Escribe el número de venta para ver su detalle o anularla:</p>' : "");
      $("#v-lista").insertAdjacentHTML("beforeend", `<div class="row"><label>N.º de venta<input type="number" id="v-id" min="1" style="width:110px"></label><button class="btn sec" id="v-ver">Ver detalle</button></div>`);
      $("#v-ver").onclick = verDetalle;
    });
    $("#v-b").click();
  }
};
async function verDetalle() {
  const det = $("#v-det"); det.hidden = false; det.innerHTML = "";
  await guard(det, async () => {
    const id = +$("#v-id").value;
    const r = await proc("usp_Venta_Detalle", { id_venta: id });
    const emp = (await api("/api/pos/catalogo")).empleados.filter(e => e.rol !== "CAJERO");
    det.innerHTML = `<h2>Venta ${id}</h2>${conjuntos(r.conjuntos)}<h3>Anular esta venta</h3><p class="mut">Restituye el stock y elimina comprobante, detalle y venta. Solo la autoriza un ADMIN o SUPERADMIN.</p>
      <div class="row"><label>Autoriza<select id="v-aut">${emp.map(e => `<option value="${e.id_empleado}">${esc(e.nombre)} (${esc(e.rol)})</option>`).join("")}</select></label><button class="btn del" id="v-anu">Anular venta</button></div><div id="v-res"></div>`;
    let armado = false;
    $("#v-anu").onclick = ev => {
      if (!armado) { armado = true; ev.target.textContent = "Confirmar: anular definitivamente"; return; }
      guard($("#v-res"), async () => { await proc("usp_Venta_Anular", { id_venta: id, id_empleado_autoriza: +$("#v-aut").value }); $("#v-res").innerHTML = ok(`Venta ${id} anulada y stock restituido.`); toast("Venta anulada"); $("#v-b").click(); }, ev.target);
    };
  });
}

// ---------------------------------------------------------------- Inventario
loaders.inventario = async () => {
  const box = $("#tab-inventario");
  if (box.dataset.init) return; box.dataset.init = 1;
  box.innerHTML = `<div class="card"><h2>Inventario</h2><div class="row">
    <button class="btn" data-i="stock">Stock por producto</button><button class="btn sec" data-i="bajo">Stock bajo el mínimo</button>
    <label>Días<input type="number" id="i-dias" value="30" style="width:80px"></label><button class="btn sec" data-i="venc">Lotes por vencer</button>
    <label>Buscar producto<input id="i-q" placeholder="ej. arroz"></label><button class="btn sec" data-i="buscar">Buscar</button></div><div id="i-res"></div></div>
    <div class="card"><h2>Ajustar stock de un lote</h2><div class="row"><label>N.º de lote<input type="number" id="a-l" style="width:100px"></label><label>Ajuste (+/−)<input type="number" id="a-n" style="width:100px"></label><label>Motivo<input id="a-m" placeholder="ej. Botellas rotas"></label><button class="btn" id="a-b">Aplicar ajuste</button></div><div id="a-res"></div></div>`;
  box.onclick = e => { const b = e.target.closest("[data-i]"); if (!b) return; const res = $("#i-res");
    guard(res, async () => {
      const m = { stock: ["usp_Stock_Consultar", {}], bajo: ["usp_Productos_StockBajo", {}], venc: ["usp_Lotes_PorVencer", { dias: +$("#i-dias").value }], buscar: ["usp_Producto_Buscar", { texto: $("#i-q").value }] }[b.dataset.i];
      res.innerHTML = conjuntos((await proc(m[0], m[1])).conjuntos);
    }, b); };
  $("#a-b").onclick = ev => guard($("#a-res"), async () => {
    const r = await proc("usp_Lote_AjustarStock", { id_lote: +$("#a-l").value, ajuste: +$("#a-n").value, motivo: $("#a-m").value });
    $("#a-res").innerHTML = ok("Stock ajustado.") + conjuntos(r.conjuntos);
  }, ev.target);
};

// ---------------------------------------------------------------- Clientes
loaders.clientes = async () => {
  const box = $("#tab-clientes");
  if (box.dataset.init) return; box.dataset.init = 1;
  box.innerHTML = `<div class="grid two"><div class="card"><h2>Buscar por DNI</h2><div class="row"><label>DNI<input id="c-dni" maxlength="8"></label><button class="btn" id="c-b">Buscar</button></div><div id="c-res"></div></div>
    <div class="card"><h2>Registrar cliente</h2><div class="row"><label>DNI<input id="n-dni" maxlength="8"></label><label>Nombres<input id="n-nom"></label><label>Apellidos<input id="n-ape"></label></div>
    <div class="row" style="margin-top:8px"><label>Teléfono<input id="n-tel" maxlength="9"></label><label>Distrito<input id="n-dis" value="Comas"></label><label>Dirección<input id="n-dir"></label><button class="btn" id="n-b">Registrar</button></div><div id="n-res"></div></div></div>
    <div class="card"><h2>Historial de compras de un cliente</h2><div class="row"><label>N.º de cliente<input type="number" id="h-id" style="width:110px"></label><button class="btn" id="h-b">Ver historial</button></div><div id="h-res"></div></div>`;
  $("#c-b").onclick = ev => guard($("#c-res"), async () => { $("#c-res").innerHTML = conjuntos((await proc("usp_Cliente_BuscarPorDni", { dni: $("#c-dni").value.trim() })).conjuntos); }, ev.target);
  $("#n-b").onclick = ev => guard($("#n-res"), async () => {
    const r = await proc("usp_Cliente_Insertar", { dni: $("#n-dni").value.trim(), nombres: $("#n-nom").value, apellidos: $("#n-ape").value, telefono: $("#n-tel").value.trim(), direccion: $("#n-dir").value, distrito: $("#n-dis").value });
    $("#n-res").innerHTML = ok(`Cliente registrado con id ${r.salida.id_cliente}.`); toast("Cliente registrado");
  }, ev.target);
  $("#h-b").onclick = ev => guard($("#h-res"), async () => { $("#h-res").innerHTML = conjuntos((await proc("usp_Cliente_HistorialCompras", { id_cliente: +$("#h-id").value })).conjuntos); }, ev.target);
};

// ---------------------------------------------------------------- Procedimientos (los 26)
loaders.procs = async () => {
  const box = $("#tab-procs");
  if (box.dataset.init) return; box.dataset.init = 1;
  const defs = await (await fetch("/api/procedimientos")).json();
  const grupos = ["Insertar", "Modificar", "Eliminar", "Consultar"];
  box.innerHTML = `<div class="card"><h2>Los 26 procedimientos almacenados</h2><p class="mut">Elige uno, completa los parámetros y ejecútalo. Los campos vacíos usan el valor por defecto del procedimiento. Puedes provocar errores a propósito (DNI duplicado, stock insuficiente…) para ver cómo responde la base.</p>
   ${grupos.map(g => `<h3>${g} (${defs.filter(d => d.grupo === g).length})</h3><div class="list">${defs.filter(d => d.grupo === g).map(d => `<button class="item" data-p="${d.nombre}"><b>${d.nombre}</b><small>${esc(d.desc)}</small></button>`).join("")}</div>`).join("")}</div><div class="card" id="p-form" hidden></div>`;
  box.onclick = e => {
    const it = e.target.closest("[data-p]"); if (!it) return;
    box.querySelectorAll(".item").forEach(x => x.classList.toggle("on", x === it));
    const d = defs.find(x => x.nombre === it.dataset.p), f = $("#p-form"); f.hidden = false;
    if (d.especial) { f.innerHTML = `<h2>${d.nombre}</h2><p>${esc(d.desc)}</p><button class="btn" id="p-go-pos">Ir al punto de venta</button>`; $("#p-go-pos").onclick = () => show("pos"); return; }
    const inputs = d.params.filter(p => !p.out).map(p => `<label>${p.name}${p.req ? " *" : ""}<input data-n="${p.name}" data-t="${p.t}" ${p.t === "date" ? 'type="date"' : ""} ${p.n ? `maxlength="${p.n}"` : ""} placeholder="${esc(p.ayuda || "")}"></label>`).join("");
    f.innerHTML = `<h2>${d.nombre} <span class="pill">${d.id}</span></h2><p class="mut">${esc(d.desc)}</p><div class="row">${inputs || '<span class="mut">Sin parámetros.</span>'}<button class="btn" id="p-run">Ejecutar</button></div><div id="p-res"></div>`;
    $("#p-run").onclick = ev => guard($("#p-res"), async () => {
      const body = {}; f.querySelectorAll("[data-n]").forEach(i => { if (i.value !== "") body[i.dataset.n] = i.value; });
      const r = await proc(d.nombre, body);
      const sal = Object.entries(r.salida || {}).map(([k, v]) => `${k} = ${v}`).join(" · ");
      $("#p-res").innerHTML = ok("Ejecutado correctamente." + (sal ? " Salida: " + sal : "")) + conjuntos(r.conjuntos);
    }, ev.target);
  };
};

// ---------------------------------------------------------------- Vistas y Consultas
function explorador(tab, lista, ruta, etiqueta) {
  const box = $("#tab-" + tab);
  box.innerHTML = `<div class="card"><h2>${etiqueta}</h2><div class="list">${lista.map(x => `<button class="item" data-id="${x.id}"><b>${x.id} · ${esc(x.titulo)}</b></button>`).join("")}</div></div><div class="card" id="${tab}-det" hidden></div>`;
  box.onclick = e => {
    const it = e.target.closest("[data-id]"); if (!it) return;
    box.querySelectorAll(".item").forEach(x => x.classList.toggle("on", x === it));
    const x = lista.find(y => y.id === it.dataset.id), d = $("#" + tab + "-det"); d.hidden = false;
    d.innerHTML = `<h2>${x.id} · ${esc(x.titulo)}</h2><p><b>Enunciado.</b> ${esc(x.enunciado)}</p><p><b>Objetivo.</b> ${esc(x.objetivo)}</p><pre>${esc(x.codigo)}</pre><p><b>Explicación.</b> ${esc(x.explicacion)}</p><h3>Resultado en vivo</h3><div id="${tab}-res"><p class="mut">Ejecutando…</p></div>`;
    api(ruta + (x.vista || x.id)).then(r => { $("#" + tab + "-res").innerHTML = tabla(r.filas) + (r.total > r.filas.length ? `<p class="mut">Se muestran ${r.filas.length} de ${r.total}.</p>` : ""); }).catch(er => { $("#" + tab + "-res").innerHTML = err(er); });
    d.scrollIntoView({ behavior: "smooth", block: "start" });
  };
}
let expl = null;
const cargarExpl = async () => expl || (expl = await api("/api/explorador"));
loaders.vistas = async () => { const b = $("#tab-vistas"); if (b.dataset.init) return; b.dataset.init = 1; explorador("vistas", (await cargarExpl()).vistas, "/api/vistas/", "Las 15 vistas"); };
loaders.consultas = async () => { const b = $("#tab-consultas"); if (b.dataset.init) return; b.dataset.init = 1; explorador("consultas", (await cargarExpl()).consultas, "/api/consultas/", "15 subconsultas y 20 consultas multitabla"); };

// ---------------------------------------------------------------- inicio
api("/api/salud").then(s => { $("#estado").textContent = "conectado a " + s.base; }).catch(() => { $("#estado").textContent = "sin conexión a la base"; });
show("panel");
