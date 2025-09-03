// script_materias_actual.js
(() => {
  // Endpoint que devuelve las materias del estudiante
  const ENDPOINT_MATERIAS = "https://im-ventas-de-computadoras.com/Sistema_Academico/materias_estudiante.php";

  // Al cargar la página: pinta bienvenida y carga materias actuales
  document.addEventListener("DOMContentLoaded", () => {
    pintarBienvenidaDesdeSession();
    cargarMateriasActuales();
  });

  /* ------------------------- UTILIDADES DE ESTADO ------------------------- */
  function getNR() {
    // nro_registro que guardaste en login.html
    return sessionStorage.getItem("nro_registro_estudiante") || "";
  }

  function getNombreCompleto() {
    const nombre = sessionStorage.getItem("nombre_estudiante") || "";
    const apellido = sessionStorage.getItem("apellido_estudiante") || "";
    const full = `${nombre} ${apellido}`.trim();
    return full || "Estudiante";
  }

  /* --------------------------- PINTAR BIENVENIDA -------------------------- */
  function pintarBienvenidaDesdeSession() {
    const el = document.getElementById("alumno-nombre");
    if (el) el.textContent = getNombreCompleto();
  }

  /* ------------------------- CARGA / RENDER MATERIAS ---------------------- */
  async function cargarMateriasActuales() {
    const cont = document.getElementById("materias-actuales");
    if (!cont) return;

    const nro_registro = getNR();
    if (!nro_registro) {
      cont.innerHTML = `<p class="error">No se encontró el Nro. de registro en esta sesión. Inicie sesión nuevamente.</p>`;
      return;
    }

    cont.innerHTML = `<p>Cargando materias...</p>`;

    try {
      // POST x-www-form-urlencoded (igual estilo que tu login.js)
      const body = new URLSearchParams({ nro_registro });

      const resp = await fetch(ENDPOINT_MATERIAS, {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body
        // credentials: "include"
      });

      const raw = await resp.text();
      let data;
      try { data = JSON.parse(raw); } catch { data = { ok:false, error:"RESP_JSON_INVALIDA", raw }; }

      if (!resp.ok || !data.ok) {
        const msg = data.msg || data.error || `HTTP ${resp.status}`;
        cont.innerHTML = `<p class="error">No se pudieron cargar las materias. ${escapeHTML(String(msg))}</p>`;
        console.error("materias_estudiante.php respuesta:", raw);
        return;
      }

      const items = Array.isArray(data.items) ? data.items : [];
      if (items.length === 0) {
        cont.innerHTML = `<p>No tienes materias registradas actualmente.</p>`;
        return;
      }

      cont.innerHTML = items.map(renderCardMateria).join("");

    } catch (err) {
      cont.innerHTML = `<p class="error">Error de conexión al cargar materias.</p>`;
      console.error(err);
    }
  }

  /* ------------------------------ RENDER UI ------------------------------- */
  function renderCardMateria(item) {
    // item esperado (del PHP)
    const sigla   = safe(item, "materia.sigla") || "Materia";
    const docente = joinNombreApellido(
                      safe(item, "docente.nombre"),
                      safe(item, "docente.apellido")
                    ) || "Por asignar";
    const aula    = safe(item, "aula.codigo") || "";
    const bloque  = (safe(item, "aula.bloque") || "").trim();
    const grupo   = safe(item, "oferta.grupo");
    const hi      = formatHora(safe(item, "horario.hora_inicio"));
    const hf      = formatHora(safe(item, "horario.hora_fin"));
    const horario = (hi && hf) ? `${hi} - ${hf}` : "Por definir";

    // Construcción "Aula 222 (Bloque Norte)" con tolerancia si bloque ya trae la palabra "Bloque"
    let aulaLinea = "Aula —";
    if (aula) {
      const bloqueTxt = bloque ? ( /^bloque/i.test(bloque) ? bloque : `Bloque ${bloque}` ) : "";
      aulaLinea = `Aula ${aula}${bloqueTxt ? ` (${bloqueTxt})` : ""}`;
    } else if (bloque) {
      // Si no hay código de aula pero sí bloque, al menos mostrar bloque
      const bloqueTxt = /^bloque/i.test(bloque) ? bloque : `Bloque ${bloque}`;
      aulaLinea = `Aula — (${bloqueTxt})`;
    }

    const badgeText = grupo != null && grupo !== "" ? `Grupo ${grupo}` : "Grupo —";

    return `
    <article class="subject-card" data-oferta="${escapeAttr(safe(item, 'oferta.id_oferta_materia') ?? '')}">
      <div class="subject-header">
        <h3>${escapeHTML(sigla)}</h3>
        <span class="module-badge">${escapeHTML(String(badgeText))}</span>
      </div>
      <div class="subject-info">
        <p><i class="fas fa-clock" aria-hidden="true"></i> ${escapeHTML(horario)}</p>
        <p><i class="fas fa-map-marker-alt" aria-hidden="true"></i> ${escapeHTML(aulaLinea)}</p>
        <p><i class="fas fa-user-tie" aria-hidden="true"></i> ${escapeHTML(docente)}</p>
      </div>
    </article>`;
  }

  /* ----------------------------- HELPERS ---------------------------------- */
  function safe(obj, path) {
    // safe(item, "oferta.grupo") -> valor o undefined
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
    // Acepta "HH:MM:SS" o "HH:MM" y devuelve "HH:MM"
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
      "&": "&amp;",
      "<": "&lt;",
      ">": "&gt;",
      "\"": "&quot;",
      "'": "&#39;"
    }[s]));
  }
})();