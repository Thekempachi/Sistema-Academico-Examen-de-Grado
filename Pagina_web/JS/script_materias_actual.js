(() => {
  // Endpoint
  const ENDPOINT_MATERIAS = "https://im-ventas-de-computadoras.com/Sistema_Academico/materias_estudiante.php";

  document.addEventListener("DOMContentLoaded", () => {
    pintarBienvenidaDesdeSession();
    cargarMateriasActuales();
  });

  function getNR() {
    return sessionStorage.getItem("nro_registro_estudiante") || "";
  }

  function getNombreCompleto() {
    const nombre = sessionStorage.getItem("nombre_estudiante") || "";
    const apellido = sessionStorage.getItem("apellido_estudiante") || "";
    const full = `${nombre} ${apellido}`.trim();
    return full || "Estudiante";
  }

  function pintarBienvenidaDesdeSession() {
    const el = document.getElementById("alumno-nombre");
    if (el) el.textContent = getNombreCompleto();
  }

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
      const body = new URLSearchParams({ nro_registro });

      const resp = await fetch(ENDPOINT_MATERIAS, {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body
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

    let aulaLinea = "Aula —";
    if (aula) {
      const bloqueTxt = bloque ? ( /^bloque/i.test(bloque) ? bloque : `Bloque ${bloque}` ) : "";
      aulaLinea = `Aula ${aula}${bloqueTxt ? ` (${bloqueTxt})` : ""}`;
    } else if (bloque) {
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
      "&": "&amp;",
      "<": "&lt;",
      ">": "&gt;",
      "\"": "&quot;",
      "'": "&#39;"
    }[s]));
  }
})();