// script_ofertas_estudiante.js

// Endpoint que devuelve las ofertas disponibles para el estudiante
const ENDPOINT_OFERTAS = "https://im-ventas-de-computadoras.com/Sistema_Academico/oferta_estudiante.php";

// Al cargar la página: intenta pintar bienvenida (si existe el nodo) y carga ofertas
document.addEventListener("DOMContentLoaded", () => {
  pintarBienvenidaDesdeSession();
  cargarOfertasEstudiante(); // por defecto usa el contenedor #ofertas-materias
});

/* ------------------------- UTILIDADES DE ESTADO ------------------------- */
function getFromStores(key) {
  return sessionStorage.getItem(key) || localStorage.getItem(key) || "";
}

function getNR() {
  return getFromStores("nro_registro_estudiante");
}

function getNombreCompleto() {
  const nombre   = getFromStores("nombre_estudiante");
  const apellido = getFromStores("apellido_estudiante");
  const full = `${nombre} ${apellido}`.trim();
  return full || "Estudiante";
}

/* --------------------------- PINTAR BIENVENIDA -------------------------- */
function pintarBienvenidaDesdeSession() {
  const el = document.getElementById("alumno-nombre");
  if (el) el.textContent = getNombreCompleto();
}

/* ------------------------- CARGA / RENDER OFERTAS ----------------------- */
async function cargarOfertasEstudiante(containerId = "ofertas-materias") {
  const cont = document.getElementById(containerId);
  if (!cont) return;

  const nro_registro = getNR();
  if (!nro_registro) {
    cont.innerHTML = `<p class="error">No se encontró el Nro. de registro en esta sesión. Inicie sesión nuevamente.</p>`;
    return;
  }

  cont.innerHTML = `<p>Cargando ofertas...</p>`;

  try {
    const body = new URLSearchParams({ nro_registro });

    const resp = await fetch(ENDPOINT_OFERTAS, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body
    });

    const raw = await resp.text();
    let data;
    try { data = JSON.parse(raw); } catch { data = { ok:false, error:"RESP_JSON_INVALIDA", raw }; }

    if (!resp.ok || !data.ok) {
      const msg = data.msg || data.error || `HTTP ${resp.status}`;
      cont.innerHTML = `<p class="error">No se pudieron cargar las ofertas. ${escapeHTML(String(msg))}</p>`;
      console.error("oferta_estudiante.php respuesta:", raw);
      return;
    }

    const items = Array.isArray(data.items) ? data.items : [];
    if (items.length === 0) {
      cont.innerHTML = `<p>No hay ofertas disponibles para registrar en este período.</p>`;
      return;
    }

    cont.innerHTML = items.map(renderCardOferta).join("");

  } catch (err) {
    cont.innerHTML = `<p class="error">Error de conexión al cargar ofertas.</p>`;
    console.error(err);
  }
}

/* ------------------------------ RENDER UI ------------------------------- */
function renderCardOferta(item) {
  // Estructura esperada del PHP:
  // {
  //   id_oferta_materia, grupo, cupos, fecha_creacion,
  //   materia: { id_materia, sigla },
  //   aula: { codigo, bloque },
  //   horario: { hora_inicio, hora_fin },
  //   docente: { nombre, apellido }
  // }

  const sigla   = safe(item, "materia.sigla") || "Materia";
  const docente = joinNombreApellido(
                    safe(item, "docente.nombre"),
                    safe(item, "docente.apellido")
                  ) || "Por asignar";
  const aulaCod = safe(item, "aula.codigo") || "—";
  const bloque  = safe(item, "aula.bloque");
  const aulaTxt = bloque ? `Aula ${aulaCod} (Bloque ${bloque})` : `Aula ${aulaCod}`;

  const grupo   = safe(item, "grupo");
  const badge   = grupo != null && String(grupo) !== "" ? `Grupo ${grupo}` : "Grupo —";

  const hi      = formatHora(safe(item, "horario.hora_inicio"));
  const hf      = formatHora(safe(item, "horario.hora_fin"));
  const horario = (hi && hf) ? `${hi} - ${hf}` : "Por definir";

  const cupos   = safe(item, "cupos");
  const cuposTxt = (cupos === null || cupos === undefined) ? "" : `<p><i class="fas fa-users" aria-hidden="true"></i> Cupos: ${escapeHTML(String(cupos))}</p>`;

  return `
  <article class="subject-card" data-oferta="${escapeAttr(safe(item, 'id_oferta_materia') ?? '')}">
    <div class="subject-header">
      <h3>${escapeHTML(sigla)}</h3>
      <span class="module-badge">${escapeHTML(String(badge))}</span>
    </div>
    <div class="subject-info">
      <p><i class="fas fa-clock" aria-hidden="true"></i> ${escapeHTML(horario)}</p>
      <p><i class="fas fa-map-marker-alt" aria-hidden="true"></i> ${escapeHTML(aulaTxt)}</p>
      <p><i class="fas fa-user-tie" aria-hidden="true"></i> ${escapeHTML(docente)}</p>
      ${cuposTxt}
    </div>
  </article>`;
}

/* ----------------------------- HELPERS ---------------------------------- */
function safe(obj, path) {
  try {
    return path.split(".").reduce((o, k) => (o && k in o ? o[k] : undefined), obj);
  } catch { return undefined; }
}

function joinNombreApellido(nombre, apellido) {
  const n = (nombre || "").trim();
  const a = (apellido || "").trim();
  return (n || a) ? `${n} ${a}`.trim() : "";
}

function formatHora(h) {
  if (!h) return "";
  const m = String(h).match(/^(\d{2}):(\d{2})/);
  return m ? `${m[1]}:${m[2]}` : String(h);
}

function escapeHTML(str) {
  return String(str).replace(/[&<>"']/g, s => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", "\"": "&quot;", "'": "&#39;"
  }[s]));
}

function escapeAttr(val) {
  return String(val ?? "").replace(/[&<>"']/g, s => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", "\"": "&quot;", "'": "&#39;"
  }[s]));
}
